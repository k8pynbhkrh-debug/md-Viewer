import SwiftUI
import WebKit

/// The outcome of rendering one Mermaid diagram.
enum MermaidRenderResult: Equatable {
    case success(UIImage)
    case failure(MermaidRenderFailure)
}

/// Why a diagram fell back to its code block. Deliberately coarse: the
/// JavaScript error text never leaves the web view.
enum MermaidRenderFailure: Equatable {
    /// Mermaid could not parse or lay out the source.
    case invalid
    /// Source longer than `MermaidRenderer.maxSourceLength`, or a result
    /// larger than `MermaidRenderer.maxDiagramDimension` on either side.
    case tooLarge
    /// No answer within `renderTimeout` (page not ready, or no result).
    case timedOut
}

/// Renders `` ```mermaid ``` `` code blocks to a diagram image via a hidden,
/// bundled Mermaid.js instance (`Resources/mermaid.min.js`, v10.9.8 — see
/// `docs/dependencies.md`) — fully offline, no network access. Mermaid does
/// the actual diagram layout/SVG generation in JavaScript; WebKit rasterizes
/// the result to a `UIImage`.
///
/// One shared, never-visibly-attached `WKWebView` handles every diagram in
/// the app, one at a time (`acquireLock`/`releaseLock` serialize requests so
/// concurrent diagrams don't race on the same DOM). Results are cached by
/// source + color scheme, so re-renders (scrolling, SwiftUI re-evaluating the
/// preview) are free after the first.
///
/// ## Contract (`render(source:colorScheme:)`)
/// - Precondition: none — any text is accepted; the source is untrusted.
/// - Postcondition: returns within `pageLoadTimeout` + 2 × `renderTimeout`
///   (page ready, script answer, snapshot — each bounded); `.success` images are at most
///   `maxDiagramDimension` points and at most `maxDiagramDimension` pixels
///   on their longer side; oversized input or output yields
///   `.failure(.tooLarge)` without rasterizing.
/// - Invariant: the render lock is released and no continuation is left
///   pending when `render` returns, whatever the outcome — so the next
///   diagram always gets a turn. After a timeout the web view is discarded
///   (its script may still be stuck) and a fresh one is built on demand.
/// - Invariant: the web view only ever loads the local harness page, once;
///   every other navigation is cancelled (`navigationPolicy`).
@MainActor
final class MermaidRenderer: NSObject, WKNavigationDelegate {
    static let shared = MermaidRenderer()

    /// Longest accepted diagram source, in UTF-16 code units (what
    /// JavaScript and Mermaid's own `maxTextSize` count).
    static let maxSourceLength = 20_000
    /// Longest accepted diagram side, in points — and the pixel cap for the
    /// rasterized image, matching the 4096 px limit for Markdown images.
    static let maxDiagramDimension: CGFloat = 4096

    /// Limit for one diagram's script answer and for its snapshot.
    private let renderTimeout: Duration
    /// Limit for the harness page to load. Larger than `renderTimeout`: the
    /// first diagram after launch also pays for starting WebKit's content
    /// process and parsing the ~3 MB Mermaid bundle.
    private let pageLoadTimeout: Duration
    /// The JavaScript that starts one render. Replaceable only so tests can
    /// simulate a page that never answers.
    var makeRenderScript: (_ id: String, _ source: String, _ theme: String) -> String = { id, source, theme in
        "window.mermaidRender(\(MermaidRenderer.jsString(id)), \(MermaidRenderer.jsString(source)), \(MermaidRenderer.jsString(theme)));"
    }

    private var webView: WKWebView?
    /// True until the current web view's harness page has been allowed to
    /// load; every navigation after that is cancelled.
    private var harnessLoadPending = false
    private var isReady = false
    private var readyWaiters: [OneShot<Bool>] = []

    private var isRendering = false
    private var lockWaiters: [CheckedContinuation<Void, Never>] = []

    private var pending: [String: OneShot<MermaidMessageOutcome>] = [:]
    private let cache = NSCache<NSString, UIImage>()

    init(renderTimeout: Duration = .seconds(5), pageLoadTimeout: Duration = .seconds(20)) {
        self.renderTimeout = renderTimeout
        self.pageLoadTimeout = pageLoadTimeout
    }

    /// Whether the page may navigate to `url`. Only the harness page itself
    /// (loaded from the bundle's resource folder) is allowed, and only for
    /// the initial load — a diagram can never send the web view elsewhere.
    static func navigationPolicy(for url: URL?, harnessURL: URL?, harnessLoadPending: Bool) -> WKNavigationActionPolicy {
        guard harnessLoadPending, let url, let harnessURL,
              url.isFileURL, url.standardizedFileURL == harnessURL.standardizedFileURL else {
            return .cancel
        }
        return .allow
    }

    private func currentWebView() -> WKWebView {
        if let webView { return webView }
        let controller = WKUserContentController()
        controller.add(MermaidMessageProxy(owner: self), name: "mermaid")
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.navigationDelegate = self
        webView = view
        isReady = false
        harnessLoadPending = true
        view.loadHTMLString(Self.harnessHTML, baseURL: Bundle.main.resourceURL)
        return view
    }

    /// Throws the current web view away after a timeout — its script may
    /// still be running — so the next render starts from a clean page.
    private func discardWebView() {
        guard let old = webView else { return }
        old.navigationDelegate = nil
        old.stopLoading()
        old.configuration.userContentController.removeScriptMessageHandler(forName: "mermaid")
        webView = nil
        isReady = false
        harnessLoadPending = false
        readyWaiters.forEach { $0.resume(false) }
        readyWaiters.removeAll()
        let stale = pending
        pending.removeAll()
        stale.values.forEach { $0.resume(.failure) }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        let isCurrent = webView === self.webView
        let policy = Self.navigationPolicy(
            for: navigationAction.request.url,
            harnessURL: Bundle.main.resourceURL,
            harnessLoadPending: isCurrent && harnessLoadPending && navigationAction.targetFrame?.isMainFrame == true
        )
        if policy == .allow { harnessLoadPending = false }
        decisionHandler(policy)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === self.webView else { return }
        isReady = true
        let waiters = readyWaiters
        readyWaiters.removeAll()
        waiters.forEach { $0.resume(true) }
    }

    /// Renders `source` (the raw Mermaid diagram text) as a `colorScheme`-
    /// matched image, or a `.failure` saying why it fell back to code.
    func render(source: String, colorScheme: ColorScheme) async -> MermaidRenderResult {
        guard source.utf16.count <= Self.maxSourceLength else { return .failure(.tooLarge) }
        let theme = colorScheme == .dark ? "dark" : "default"
        let cacheKey = "\(theme)\n\(source)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return .success(cached)
        }

        await acquireLock()
        defer {
            releaseLock()
            assert(pending.isEmpty, "a Mermaid continuation outlived its render")
        }
        let result = await renderLocked(source: source, theme: theme)
        if case .success(let image) = result {
            cache.setObject(image, forKey: cacheKey)
        }
        return result
    }

    private func renderLocked(source: String, theme: String) async -> MermaidRenderResult {
        let webView = currentWebView()
        guard await waitUntilReady() else {
            discardWebView()
            return .failure(.timedOut)
        }

        let id = UUID().uuidString
        let js = makeRenderScript(id, source, theme)
        let outcome = await awaitWithTimeout(renderTimeout, onTimeout: MermaidMessageOutcome.timedOut) { box in
            pending[id] = box
            webView.evaluateJavaScript(js)
        }
        pending[id] = nil

        switch outcome {
        case .timedOut:
            discardWebView()
            return .failure(.timedOut)
        case .failure:
            return .failure(.invalid)
        case .success(let width, let height):
            guard width > 0, height > 0 else { return .failure(.invalid) }
            let size = CGSize(width: ceil(width), height: ceil(height))
            guard size.width <= Self.maxDiagramDimension, size.height <= Self.maxDiagramDimension else {
                return .failure(.tooLarge)
            }
            webView.frame = CGRect(origin: .zero, size: size)
            // A snapshot taken immediately after resizing the frame can
            // otherwise still capture the previous (larger, default) layout
            // — this web view is never attached to a window, so nothing
            // drives its render loop on a predictable schedule. A brief
            // delay plus one idle JS round-trip gives WebKit time to
            // actually repaint at the new size before the snapshot.
            _ = try? await webView.evaluateJavaScript("document.body.offsetHeight")
            try? await Task.sleep(for: .milliseconds(100))
            guard let image = await snapshot(of: webView, size: size) else {
                discardWebView()
                return .failure(.timedOut)
            }
            return .success(image)
        }
    }

    /// Rasterizes the diagram at screen scale, capped so the longer side is
    /// at most `maxDiagramDimension` pixels; the returned image keeps the
    /// diagram's natural size in points either way.
    private func snapshot(of webView: WKWebView, size: CGSize) async -> UIImage? {
        let screenScale = webView.traitCollection.displayScale > 0 ? webView.traitCollection.displayScale : 2
        let pixelFactor = min(1, Self.maxDiagramDimension / (max(size.width, size.height) * screenScale))
        let image: UIImage? = await awaitWithTimeout(renderTimeout, onTimeout: nil) { box in
            let configuration = WKSnapshotConfiguration()
            configuration.afterScreenUpdates = true
            // Explicit, matching the just-set frame — belt and suspenders
            // against capturing a stale, larger viewport (see the comment at
            // the call site).
            configuration.rect = CGRect(origin: .zero, size: size)
            configuration.snapshotWidth = NSNumber(value: Double(size.width * pixelFactor))
            webView.takeSnapshot(with: configuration) { image, _ in
                box.resume(image)
            }
        }
        guard let cgImage = image?.cgImage else { return image }
        return UIImage(cgImage: cgImage, scale: CGFloat(cgImage.width) / size.width, orientation: .up)
    }

    /// Returns `false` if the harness page did not finish loading within
    /// `pageLoadTimeout`.
    private func waitUntilReady() async -> Bool {
        if isReady { return true }
        return await awaitWithTimeout(pageLoadTimeout, onTimeout: false) { box in
            readyWaiters.append(box)
        }
    }

    /// Suspends until `start`'s callback (via the `OneShot` box) or the
    /// timeout resumes it — whichever comes first; the other is a no-op.
    private func awaitWithTimeout<T>(_ timeout: Duration, onTimeout: T, _ start: (OneShot<T>) -> Void) async -> T {
        let box = OneShot<T>()
        return await withCheckedContinuation { continuation in
            box.install(continuation)
            box.timeoutTask = Task { @MainActor in
                try? await Task.sleep(for: timeout)
                box.resume(onTimeout)
            }
            start(box)
        }
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
        guard message.webView === webView,
              let body = message.body as? [String: Any],
              let id = body["id"] as? String,
              let box = pending.removeValue(forKey: id) else { return }
        if let status = body["status"] as? String, status == "success",
           let width = body["width"] as? Double, let height = body["height"] as? Double,
           width.isFinite, height.isFinite {
            box.resume(.success(width: width, height: height))
        } else {
            box.resume(.failure)
        }
    }

    /// Encodes `value` as a JSON string literal (quotes, escaping, unicode —
    /// all handled) suitable for splicing straight into a JavaScript call.
    static func jsString(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let json = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return String(json.dropFirst().dropLast())
    }

    /// The Content-Security-Policy is what makes "no network access" hold
    /// for diagrams too: whatever a diagram's source contains (an `<img>` in
    /// a label, a CSS `url(…)`, a `fetch`), the page may only run the bundled
    /// script and use inline styles and `data:` images — every other load is
    /// refused by WebKit before a request is made.
    static let harnessHTML = """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'self' file: 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; font-src data:">
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
        // `strict`: Mermaid sanitizes labels and disables click handlers /
        // links in diagrams; `maxTextSize` mirrors the Swift-side limit.
        mermaid.initialize({
          startOnLoad: false, theme: theme, securityLevel: 'strict',
          maxTextSize: \(maxSourceLength)
        });
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
        }).catch(function() {
          // Only the status leaves the page — never Mermaid's error text.
          window.webkit.messageHandlers.mermaid.postMessage({ id: id, status: 'error' });
        });
      } catch (error) {
        window.webkit.messageHandlers.mermaid.postMessage({ id: id, status: 'error' });
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
    case timedOut
}

/// A continuation that may be resumed from two racing sides (the awaited
/// callback and a timeout); only the first `resume` counts, later ones are
/// no-ops. Main-actor bound, so the race needs no further locking.
@MainActor
private final class OneShot<T> {
    private var continuation: CheckedContinuation<T, Never>?
    var timeoutTask: Task<Void, Never>?

    func install(_ continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: T) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation.resume(returning: value)
    }
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
/// can't parse the source, the diagram is too large, or rendering takes too
/// long — a visible explanation rather than a dead end, matching the image
/// placeholders' "say why, don't stay silent" approach.
struct MermaidDiagramView: View {
    let source: String
    let fallback: AnyView

    @Environment(\.colorScheme) private var colorScheme
    @State private var image: UIImage?
    @State private var failure: MermaidRenderFailure?

    var body: some View {
        Group {
            if let image {
                FitWidthLayout {
                    Image(uiImage: image)
                        .resizable()
                }
            } else if let failure {
                VStack(alignment: .leading, spacing: 8) {
                    Label(Self.message(for: failure), systemImage: "exclamationmark.triangle")
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

    static func message(for failure: MermaidRenderFailure) -> String {
        switch failure {
        case .invalid: String(localized: "Diagram could not be rendered")
        case .tooLarge: String(localized: "Diagram too large – shown as code")
        case .timedOut: String(localized: "Diagram took too long – shown as code")
        }
    }

    private func render() async {
        image = nil
        failure = nil
        switch await MermaidRenderer.shared.render(source: source, colorScheme: colorScheme) {
        case .success(let uiImage):
            image = uiImage
        case .failure(let reason):
            failure = reason
        }
    }
}
