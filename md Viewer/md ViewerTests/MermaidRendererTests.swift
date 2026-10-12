import Testing
import SwiftUI
import WebKit
@testable import md_Viewer

/// Exercises `MermaidRenderer`'s contract against the real bundled
/// Mermaid.js in a real (off-screen) `WKWebView`. Each test uses its own
/// renderer instance, so the shared one and its cache stay untouched.
@MainActor
@Suite("MermaidRenderer", .serialized)
struct MermaidRendererTests {
    private let simpleDiagram = "flowchart LR\n  A[Start] --> B[Ende]"

    /// A renderer with a generous page-load limit: in a busy simulator (the
    /// whole test target running in parallel) WebKit's cold start plus the
    /// ~3 MB Mermaid bundle can exceed the app's 20 s. What these tests
    /// check is the per-diagram behaviour, not the cold start.
    private func makeRenderer(renderTimeout: Duration = .seconds(5)) -> MermaidRenderer {
        MermaidRenderer(renderTimeout: renderTimeout, pageLoadTimeout: .seconds(60))
    }

    private func isSuccess(_ result: MermaidRenderResult) -> Bool {
        if case .success = result { return true }
        return false
    }

    @Test("a valid diagram renders within the size cap")
    func validDiagramRenders() async throws {
        let renderer = makeRenderer()
        let result = await renderer.render(source: simpleDiagram, colorScheme: .light)
        guard case .success(let image) = result else {
            Issue.record("expected success, got \(result)")
            return
        }
        #expect(image.size.width > 0 && image.size.height > 0)
        #expect(max(image.size.width, image.size.height) <= MermaidRenderer.maxDiagramDimension)
        let pixels = try #require(image.cgImage)
        #expect(max(pixels.width, pixels.height) <= Int(MermaidRenderer.maxDiagramDimension))
    }

    @Test("a malformed diagram fails as invalid")
    func malformedDiagramFails() async {
        let renderer = makeRenderer()
        let result = await renderer.render(source: "flowchart LR\n  A -->> -->", colorScheme: .light)
        #expect(result == .failure(.invalid))
    }

    // Precondition-free input: oversized source is rejected before any
    // JavaScript runs.
    @Test("source over the length limit is rejected as too large")
    func oversizedSourceIsRejected() async {
        let renderer = makeRenderer()
        let source = "flowchart LR\n" + String(repeating: "A-->B\n", count: MermaidRenderer.maxSourceLength / 6 + 1)
        #expect(source.utf16.count > MermaidRenderer.maxSourceLength)
        #expect(await renderer.render(source: source, colorScheme: .light) == .failure(.tooLarge))
    }

    @Test("a diagram wider than the dimension cap falls back as too large")
    func oversizedOutputIsRejected() async {
        let renderer = makeRenderer(renderTimeout: .seconds(20))
        let chain = (0..<120).map { "N\($0)[Knoten \($0)]" }.joined(separator: " --> ")
        let source = "flowchart LR\n  " + chain
        #expect(source.utf16.count <= MermaidRenderer.maxSourceLength)
        #expect(await renderer.render(source: source, colorScheme: .light) == .failure(.tooLarge))
    }

    // Invariant — a page that never answers times out, releases the lock,
    // and the next diagram renders normally.
    @Test("a missing JavaScript answer times out and the next diagram still renders")
    func missingAnswerTimesOutAndRecovers() async {
        // Production render timeout: a fresh page's first Mermaid call can
        // take a few seconds in the simulator, and the recovery render below
        // runs on a freshly rebuilt page.
        let renderTimeout: Duration = .seconds(5)
        let renderer = makeRenderer(renderTimeout: renderTimeout)
        let defaultScript = renderer.makeRenderScript

        // Warm up so the timing below measures only the missing answer, not
        // the page load.
        #expect(isSuccess(await renderer.render(source: "flowchart TD\n  W --> U", colorScheme: .light)))

        renderer.makeRenderScript = { _, _, _ in "void 0;" }
        let start = ContinuousClock.now
        let first = await renderer.render(source: simpleDiagram, colorScheme: .light)
        #expect(first == .failure(.timedOut))
        #expect(ContinuousClock.now - start < renderTimeout + .seconds(3))

        renderer.makeRenderScript = defaultScript
        let second = await renderer.render(source: simpleDiagram, colorScheme: .dark)
        #expect(isSuccess(second))
    }

    @Test("concurrent renders are serialized and all complete")
    func concurrentRendersComplete() async {
        let renderer = makeRenderer()
        async let a = renderer.render(source: simpleDiagram, colorScheme: .light)
        async let b = renderer.render(source: "flowchart TD\n  X --> Y", colorScheme: .light)
        async let c = renderer.render(source: "not a diagram %%%", colorScheme: .light)
        let results = await [a, b, c]
        #expect(isSuccess(results[0]))
        #expect(isSuccess(results[1]))
        #expect(results[2] == .failure(.invalid))
    }

    // Invariant — the page can't navigate away; the render still succeeds
    // because the harness stays loaded.
    @Test("navigation attempts from the page are cancelled")
    func navigationAttemptsAreCancelled() async {
        let renderer = makeRenderer()
        let defaultScript = renderer.makeRenderScript
        renderer.makeRenderScript = { id, source, theme in
            "window.location.href = 'https://example.com/'; window.location.href = 'file:///etc/hosts'; "
                + defaultScript(id, source, theme)
        }
        let result = await renderer.render(source: simpleDiagram, colorScheme: .light)
        #expect(isSuccess(result))
    }

    // Invariant — the page can't load anything from the network. Since the
    // Mac build carries `network.client` (WebKit needs it to start), the
    // page's Content-Security-Policy is what blocks requests, so check it
    // at runtime: fetch, XHR and an <img> to a remote URL must all fail
    // *and* raise a CSP violation (so an offline machine can't make this
    // pass by accident). The probe reports back through the renderer's
    // own message channel: "success" only if everything was blocked.
    @Test("the diagram page blocks fetch, XHR and remote images")
    func networkRequestsAreBlocked() async {
        let renderer = makeRenderer()
        renderer.makeRenderScript = { id, _, _ in
            let jsID = MermaidRenderer.jsString(id)
            return """
            (function() {
              var violations = 0;
              document.addEventListener('securitypolicyviolation', function() { violations++; });
              var probes = [
                fetch('https://example.com/probe').then(function() { return 'loaded'; }, function() { return 'blocked'; }),
                new Promise(function(resolve) {
                  try {
                    var xhr = new XMLHttpRequest();
                    xhr.open('GET', 'https://example.com/xhr');
                    xhr.onload = function() { resolve('loaded'); };
                    xhr.onerror = function() { resolve('blocked'); };
                    xhr.send();
                  } catch (e) { resolve('blocked'); }
                }),
                new Promise(function(resolve) {
                  var img = new Image();
                  img.onload = function() { resolve('loaded'); };
                  img.onerror = function() { resolve('blocked'); };
                  img.src = 'https://example.com/probe.png';
                })
              ];
              Promise.all(probes).then(function(results) {
                setTimeout(function() {
                  var allBlocked = results.every(function(r) { return r === 'blocked'; });
                  window.webkit.messageHandlers.mermaid.postMessage(
                    allBlocked && violations > 0
                      ? { id: \(jsID), status: 'success', width: 10, height: 10 }
                      : { id: \(jsID), status: 'error' });
                }, 300);
              });
            })();
            """
        }
        let result = await renderer.render(source: simpleDiagram, colorScheme: .light)
        #expect(isSuccess(result), "a remote request was not blocked by the page's CSP")
    }

    @Test("navigation policy allows only the initial harness load")
    func navigationPolicy() {
        let harness = Bundle.main.resourceURL
        #expect(MermaidRenderer.navigationPolicy(for: harness, harnessURL: harness, harnessLoadPending: true) == .allow)
        #expect(MermaidRenderer.navigationPolicy(for: harness, harnessURL: harness, harnessLoadPending: false) == .cancel)
        #expect(MermaidRenderer.navigationPolicy(for: URL(string: "https://example.com/"), harnessURL: harness, harnessLoadPending: true) == .cancel)
        #expect(MermaidRenderer.navigationPolicy(for: URL(fileURLWithPath: "/etc/hosts"), harnessURL: harness, harnessLoadPending: true) == .cancel)
        #expect(MermaidRenderer.navigationPolicy(for: URL(string: "about:blank"), harnessURL: harness, harnessLoadPending: true) == .cancel)
        #expect(MermaidRenderer.navigationPolicy(for: nil, harnessURL: harness, harnessLoadPending: true) == .cancel)
    }

    @Test("the harness uses strict security and never posts error text")
    func harnessConfiguration() {
        let html = MermaidRenderer.harnessHTML
        #expect(html.contains("securityLevel: 'strict'"))
        #expect(html.contains("maxTextSize: \(MermaidRenderer.maxSourceLength)"))
        #expect(!html.contains("String(error)"))
        #expect(html.contains("default-src 'none'"))
    }

    @Test("failure messages are fixed, localized strings")
    func failureMessages() {
        let messages = [MermaidRenderFailure.invalid, .tooLarge, .timedOut].map(MermaidDiagramView.message(for:))
        #expect(Set(messages).count == 3)
        #expect(messages.allSatisfy { !$0.isEmpty })
    }
}
