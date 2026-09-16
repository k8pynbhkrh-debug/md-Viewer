import SwiftUI
import WebKit

/// The outcome of rendering one Mermaid diagram.
enum MermaidRenderResult {
    case success(UIImage)
    case failure
}

/// Renders `` ```mermaid ``` `` code blocks to a diagram image via a hidden,
/// bundled Mermaid.js instance (`Resources/mermaid.min.js`, v10.9.8) — fully
/// offline, no network access. Mermaid does the actual diagram layout/SVG
/// generation in JavaScript; WebKit rasterizes the result to a `UIImage`.
///
/// One shared, never-visibly-attached `WKWebView` handles every diagram in
/// the app, one at a time (`acquireLock`/`releaseLock` serialize requests so
/// concurrent diagrams don't race on the same DOM). Results are cached by
/// source + color scheme, so re-renders (scrolling, SwiftUI re-evaluating the
/// preview) are free after the first.
@MainActor
final class MermaidRenderer: NSObject, WKNavigationDelegate {
    static let shared = MermaidRenderer()

    private lazy var webView: WKWebView = makeWebView()
    private var isReady = false
    private var readyWaiters: [CheckedContinuation<Void, Never>] = []

    private var isRendering = false
    private var lockWaiters: [CheckedContinuation<Void, Never>] = []

    private var pending: [String: CheckedContinuation<MermaidMessageOutcome, Never>] = [:]
    private let cache = NSCache<NSString, UIImage>()

    private func makeWebView() -> WKWebView {
        let controller = WKUserContentController()
        controller.add(MermaidMessageProxy(owner: self), name: "mermaid")
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.navigationDelegate = self
        view.loadHTMLString(Self.harnessHTML, baseURL: Bundle.main.resourceURL)
        return view
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            isReady = true
            let waiters = readyWaiters
            readyWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }
    }

    /// Renders `source` (the raw Mermaid diagram text) as a `colorScheme`-
    /// matched image, or `.failure` if Mermaid couldn't parse it.
    func render(source: String, colorScheme: ColorScheme) async -> MermaidRenderResult {
        let theme = colorScheme == .dark ? "dark" : "default"
        let cacheKey = "\(theme)\n\(source)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return .success(cached)
        }

        await acquireLock()
        defer { releaseLock() }
        _ = webView // ensure the lazy web view (and its initial load) exists
        await waitUntilReady()

        let id = UUID().uuidString
        let js = "window.mermaidRender(\(jsString(id)), \(jsString(source)), \(jsString(theme)));"

        let outcome = await withCheckedContinuation { (continuation: CheckedContinuation<MermaidMessageOutcome, Never>) in
            pending[id] = continuation
            webView.evaluateJavaScript(js)
        }

        switch outcome {
        case .failure:
            return .failure
        case .success(let width, let height):
            guard width > 0, height > 0 else { return .failure }
            let size = CGSize(width: ceil(width), height: ceil(height))
            webView.frame = CGRect(origin: .zero, size: size)
            // A snapshot taken immediately after resizing the frame can
            // otherwise still capture the previous (larger, default) layout
            // — this web view is never attached to a window, so nothing
            // drives its render loop on a predictable schedule. A brief
            // delay plus one idle JS round-trip gives WebKit time to
            // actually repaint at the new size before the snapshot.
            _ = try? await webView.evaluateJavaScript("document.body.offsetHeight")
            try? await Task.sleep(for: .milliseconds(100))
            guard let image = await snapshot(size: size) else { return .failure }
            cache.setObject(image, forKey: cacheKey)
            return .success(image)
        }
    }

    private func snapshot(size: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let configuration = WKSnapshotConfiguration()
            configuration.afterScreenUpdates = true
            // Explicit, matching the just-set frame — belt and suspenders
            // against capturing a stale, larger viewport (see the comment at
            // the call site).
            configuration.rect = CGRect(origin: .zero, size: size)
            webView.takeSnapshot(with: configuration) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    private func waitUntilReady() async {
        if isReady { return }
        await withCheckedContinuation { readyWaiters.append($0) }
    }

    private func acquireLock() async {
        if !isRendering {
            isRendering = true
            return
        }
        await withCheckedContinuation { lockWaiters.append($0) }
    }

    private func releaseLock() {
        if lockWaiters.isEmpty {
            isRendering = false
        } else {
            lockWaiters.removeFirst().resume()
        }
    }

    fileprivate func handleMessage(_ message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let id = body["id"] as? String,
              let continuation = pending.removeValue(forKey: id) else { return }
        if let status = body["status"] as? String, status == "success",
           let width = body["width"] as? Double, let height = body["height"] as? Double {
            continuation.resume(returning: .success(width: width, height: height))
        } else {
            continuation.resume(returning: .failure)
        }
    }

    /// Encodes `value` as a JSON string literal (quotes, escaping, unicode —
    /// all handled) suitable for splicing straight into a JavaScript call.
    private func jsString(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let json = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return String(json.dropFirst().dropLast())
    }

    private static let harnessHTML = """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <style>html,body{margin:0;padding:0;background:transparent;}</style>
    <script src="mermaid.min.js"></script>
    </head>
    <body>
    <div id="target"></div>
    <script>
    window.mermaidRender = function(id, source, theme) {
      // Mermaid's default error handling, on a parse failure, appends its
      // own "error" SVG (a bomb icon) directly to document.body as a side
      // effect of the same call whose promise otherwise correctly rejects
      // below — not just to whatever element the caller points it at. Left
      // in place, that stray element bleeds into every later snapshot taken
      // from this shared page. Resetting the page to a single clean target
      // element before each render, success or failure, keeps every
      // snapshot showing only that render's own output.
      document.body.innerHTML = '<div id="target"></div>';
      var target = document.getElementById('target');
      try {
        mermaid.initialize({ startOnLoad: false, theme: theme });
        mermaid.render('graph-' + id, source).then(function(result) {
          target.innerHTML = result.svg;
          var svgEl = target.firstElementChild;
          // Mermaid's <svg> carries `max-width: 100%` styling meant for a
          // web page's flowing layout, which stretches it to this (wide,
          // fixed-size) body's full width, unrelated to the diagram's actual
          // size. The `viewBox` is the SVG's own authoritative coordinate
          // space — pin width/height to it explicitly so the element renders
          // at its true natural size instead of stretched, before measuring.
          var box = svgEl.viewBox && svgEl.viewBox.baseVal;
          if (box && box.width && box.height) {
            svgEl.style.maxWidth = 'none';
            svgEl.style.width = box.width + 'px';
            svgEl.style.height = box.height + 'px';
          }
          var rect = svgEl.getBoundingClientRect();
          window.webkit.messageHandlers.mermaid.postMessage({
            id: id, status: 'success', width: rect.width, height: rect.height
          });
        }).catch(function(error) {
          window.webkit.messageHandlers.mermaid.postMessage({
            id: id, status: 'error', message: String(error)
          });
        });
      } catch (error) {
        window.webkit.messageHandlers.mermaid.postMessage({
          id: id, status: 'error', message: String(error)
        });
      }
    };
    </script>
    </body>
    </html>
    """
}

/// The parsed result of one `mermaid` script-message round-trip.
private enum MermaidMessageOutcome {
    case success(width: Double, height: Double)
    case failure
}

/// `WKUserContentController.add(_:name:)` retains its handler strongly; this
/// weak proxy breaks the resulting `webView → controller → renderer` cycle.
private final class MermaidMessageProxy: NSObject, WKScriptMessageHandler {
    private weak var owner: MermaidRenderer?
    init(owner: MermaidRenderer) { self.owner = owner }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        owner?.handleMessage(message)
    }
}

/// A `` ```mermaid ``` `` code block rendered as a diagram image. Falls back
/// to `fallback` (the normal, syntax-highlighted code block) when Mermaid
/// can't parse the source — a visible explanation rather than a dead end,
/// matching the image placeholders' "say why, don't stay silent" approach.
struct MermaidDiagramView: View {
    let source: String
    let fallback: AnyView

    @Environment(\.colorScheme) private var colorScheme
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                FitWidthLayout {
                    Image(uiImage: image)
                        .resizable()
                }
            } else if failed {
                VStack(alignment: .leading, spacing: 8) {
                    Label(String(localized: "Diagram could not be rendered"), systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    fallback
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .task(id: "\(colorScheme)\n\(source)") { await render() }
    }

    private func render() async {
        image = nil
        failed = false
        switch await MermaidRenderer.shared.render(source: source, colorScheme: colorScheme) {
        case .success(let uiImage):
            image = uiImage
        case .failure:
            failed = true
        }
    }
}
