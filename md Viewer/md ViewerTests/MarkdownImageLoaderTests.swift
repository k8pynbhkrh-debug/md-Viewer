import Testing
import Foundation
import UIKit
import SwiftUI
@testable import md_Viewer

/// Counts every request the URL loading system sees while registered — the
/// proof, in the tests below, that loading a remote image reference makes
/// no network call at all (rather than a failed one).
private final class CountingURLProtocol: URLProtocol {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _count = 0

    static var requestCount: Int { lock.withLock { _count } }
    static func reset() { lock.withLock { _count = 0 } }

    override class func canInit(with request: URLRequest) -> Bool {
        lock.withLock { _count += 1 }
        return false
    }
}

// Contract — see `MarkdownImageLoader`: no network, bounded pixel size,
// oversized `data:` URIs rejected before decoding.
@Suite("MarkdownImageLoader", .serialized)
struct MarkdownImageLoaderTests {

    private static let tinyPNGDataURI =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="

    private func png(width: Int, height: Int) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return renderer.pngData { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    private func pixelSize(_ result: ImageLoadResult) -> CGSize? {
        guard case .image(let image) = result, let cg = image.cgImage else { return nil }
        return CGSize(width: cg.width, height: cg.height)
    }

    // MARK: Invariant — never touches the network

    @Test("http(s) images are blocked without any request being made",
          arguments: ["https://example.com/a.png", "http://example.com/a.png", "HTTPS://example.com/a.png"])
    func remoteImagesAreBlocked(source: String) async {
        URLProtocol.registerClass(CountingURLProtocol.self)
        defer { URLProtocol.unregisterClass(CountingURLProtocol.self) }
        CountingURLProtocol.reset()

        let result = await MarkdownImageLoader.shared.load(url: URL(string: source), accessibleFolderURL: nil)

        #expect(result == .remoteBlocked)
        #expect(CountingURLProtocol.requestCount == 0)
    }

    @Test("a remote image in the selectable preview becomes a placeholder attachment")
    func remoteImageInAttributedTextGetsPlaceholder() async {
        let store = ImageFolderAccessStore(defaults: UserDefaults(suiteName: #function)!)
        let out = await attributedString(
            fromMarkdown: "before ![x](https://example.com/a.png) after",
            baseFont: .preferredFont(forTextStyle: .body),
            documentFolderURL: nil,
            accessStore: store
        )
        var images: [UIImage] = []
        out.enumerateAttribute(.attachment, in: NSRange(location: 0, length: out.length)) { value, _, _ in
            if let image = (value as? NSTextAttachment)?.image { images.append(image) }
        }
        #expect(images.count == 1)
        #expect(out.string.contains("before"))
        #expect(out.string.contains("after"))
    }

    @Test("an inline (in-a-line-of-text) remote image yields a symbol without any request")
    func inlineRemoteImageIsBlocked() async throws {
        URLProtocol.registerClass(CountingURLProtocol.self)
        defer { URLProtocol.unregisterClass(CountingURLProtocol.self) }
        CountingURLProtocol.reset()

        let provider = AppInlineImageProvider(accessStore: ImageFolderAccessStore(defaults: UserDefaults(suiteName: #function)!))
        let image = try await provider.image(with: URL(string: "https://example.com/badge.png")!, label: "badge")

        #expect(image == Image(systemName: "network.slash"))
        #expect(CountingURLProtocol.requestCount == 0)
    }

    @Test("an inline data: image is decoded, not replaced by a symbol")
    func inlineDataImageDecodes() async throws {
        let provider = AppInlineImageProvider(accessStore: ImageFolderAccessStore(defaults: UserDefaults(suiteName: #function)!))
        let image = try await provider.image(with: URL(string: Self.tinyPNGDataURI)!, label: "pixel")
        #expect(image != Image(systemName: "network.slash"))
        #expect(image != Image(systemName: "photo"))
    }

    // MARK: data: URIs

    @Test("a small data: URI decodes at its natural size")
    func dataURIDecodes() async {
        let result = await MarkdownImageLoader.shared.load(url: URL(string: Self.tinyPNGDataURI), accessibleFolderURL: nil)
        #expect(pixelSize(result) == CGSize(width: 1, height: 1))
    }

    /// A 2×2 PNG followed by zero bytes, sized so its Base64 payload is
    /// exactly `base64Length` characters (ImageIO ignores bytes after the
    /// PNG's end chunk, so it still decodes).
    private func paddedPNGDataURI(base64Length: Int) -> URL {
        precondition(base64Length % 4 == 0)
        var data = png(width: 2, height: 2)
        data.append(Data(count: base64Length / 4 * 3 - data.count))
        let payload = data.base64EncodedString()
        precondition(payload.utf8.count == base64Length)
        return URL(string: "data:image/png;base64," + payload)!
    }

    @Test("a data: URI exactly at the byte limit is still decoded")
    func dataURIAtLimitDecodes() async {
        let url = paddedPNGDataURI(base64Length: MarkdownImageLoader.maxDataURIBytes)
        let result = await MarkdownImageLoader.shared.load(url: url, accessibleFolderURL: nil)
        #expect(pixelSize(result) == CGSize(width: 2, height: 2))
    }

    @Test("a data: URI just over the byte limit is rejected")
    func oversizedDataURIIsRejected() async {
        let url = paddedPNGDataURI(base64Length: MarkdownImageLoader.maxDataURIBytes + 4)
        let result = await MarkdownImageLoader.shared.load(url: url, accessibleFolderURL: nil)
        #expect(result == .unavailable)
    }

    @Test("a data: URI without a comma or with garbage is unavailable, not a crash",
          arguments: ["data:image/png;base64", "data:image/png;base64,!!!notbase64!!!", "data:,"])
    func malformedDataURI(source: String) async {
        let result = await MarkdownImageLoader.shared.load(url: URL(string: source), accessibleFolderURL: nil)
        #expect(result == .unavailable)
    }

    // MARK: Postcondition — bounded pixel size

    @Test("an image wider than the pixel limit is downsampled, aspect ratio kept")
    func hugeImageIsDownsampled() {
        let result = MarkdownImageLoader.decodeImage(png(width: 5000, height: 100))
        let size = pixelSize(result)
        #expect(size?.width == CGFloat(MarkdownImageLoader.maxPixelDimension))
        #expect(size.map { abs($0.height - 82) <= 1 } == true)
    }

    @Test("an image within the pixel limit keeps its size (no upscaling)")
    func smallImageKeepsSize() {
        #expect(pixelSize(MarkdownImageLoader.decodeImage(png(width: 300, height: 200)))
                == CGSize(width: 300, height: 200))
    }

    @Test("non-image data is unavailable")
    func nonImageData() {
        #expect(MarkdownImageLoader.decodeImage(Data("hello".utf8)) == .unavailable)
    }

    // MARK: Local files

    @Test("a local image needs folder access until a folder is granted, then loads")
    func localFile() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("md-viewer-loader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("bild.png")
        try png(width: 5000, height: 10).write(to: file)

        #expect(await MarkdownImageLoader.shared.load(url: file, accessibleFolderURL: nil) == .needsFolderAccess)

        let granted = await MarkdownImageLoader.shared.load(url: file, accessibleFolderURL: folder)
        #expect(pixelSize(granted)?.width == CGFloat(MarkdownImageLoader.maxPixelDimension))

        let missing = folder.appendingPathComponent("fehlt.png")
        #expect(await MarkdownImageLoader.shared.load(url: missing, accessibleFolderURL: folder) == .unavailable)
    }

    @Test("a nil URL (unparseable source) is unavailable")
    func nilURL() async {
        #expect(await MarkdownImageLoader.shared.load(url: nil, accessibleFolderURL: nil) == .unavailable)
    }
}

@Suite("Privacy manifest")
struct PrivacyManifestTests {
    @Test("the app bundle declares UserDefaults access with reason CA92.1")
    func declaresUserDefaults() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try #require(
            PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any]
        )
        #expect(plist["NSPrivacyTracking"] as? Bool == false)
        let types = try #require(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let userDefaults = types.first { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults" }
        #expect(userDefaults?["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
    }
}
