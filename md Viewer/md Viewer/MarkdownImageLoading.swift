import Foundation
import ImageIO
import UIKit

/// The outcome of resolving one Markdown image reference.
enum ImageLoadResult: Equatable {
    case image(UIImage)
    /// A relative path inside a folder the app has not (yet) been granted
    /// access to.
    case needsFolderAccess
    /// An `http(s)` image. md Viewer works fully offline and deliberately
    /// never fetches remote images — the image host would otherwise learn
    /// that (and when, and from which IP) the document was opened.
    case remoteBlocked
    /// Anything else that didn't produce an image — missing file, decode
    /// failure, oversized `data:` URI, unsupported scheme.
    case unavailable
}

/// Resolves and decodes Markdown image references off the main thread:
/// `data:` URIs (Base64) and local files under a folder the user has granted
/// access to. Actor isolation keeps every decode off the main actor without
/// extra bookkeeping — large embedded images no longer stall or abort the
/// preview (the originally reported bug).
///
/// Contract:
/// - Invariant: never touches the network. `http(s)` URLs yield
///   `.remoteBlocked` without any request being made.
/// - Postcondition: an `.image` result is never larger than
///   `maxPixelDimension` on its longer side (bigger sources are downsampled
///   while decoding, so a huge image can't exhaust memory).
/// - Postcondition: a `data:` URI whose payload exceeds `maxDataURIBytes` is
///   rejected as `.unavailable` before any Base64 or image decoding happens.
actor MarkdownImageLoader {
    static let shared = MarkdownImageLoader()

    /// Longest side, in pixels, of any image this loader hands out.
    static let maxPixelDimension = 4096
    /// Largest `data:` URI payload (the Base64 text after the comma) that is
    /// decoded at all.
    static let maxDataURIBytes = 10 * 1024 * 1024

    /// - Parameters:
    ///   - url: the already-resolved image URL, as produced by MarkdownUI
    ///     joining the Markdown source against `imageBaseURL`; `nil` if the
    ///     source string didn't even parse as a URL (e.g. an unescaped space
    ///     in the destination — invalid per CommonMark).
    ///   - accessibleFolderURL: the security-scoped folder — resolved by
    ///     `ImageFolderAccessStore` on the main actor by the caller — that
    ///     covers `url`, or `nil` if none has been granted yet. Which folder
    ///     covers a given file stays the caller's job; this actor only does
    ///     the (potentially slow) I/O and decoding.
    func load(url: URL?, accessibleFolderURL: URL?) async -> ImageLoadResult {
        guard let url else { return .unavailable }
        switch url.scheme?.lowercased() {
        case "data":
            return decodeDataURI(url)
        case "http", "https":
            return .remoteBlocked
        case "file", .none:
            return loadLocalFile(url: url, accessibleFolderURL: accessibleFolderURL)
        default:
            return .unavailable
        }
    }

    /// Decoded by hand: `data:` is no scheme any loader API here fetches.
    private func decodeDataURI(_ url: URL) -> ImageLoadResult {
        let string = url.absoluteString
        guard let commaIndex = string.firstIndex(of: ",") else { return .unavailable }
        let payload = string[string.index(after: commaIndex)...]
        guard payload.utf8.count <= Self.maxDataURIBytes,
              let data = Data(base64Encoded: String(payload), options: .ignoreUnknownCharacters) else {
            return .unavailable
        }
        return Self.decodeImage(data)
    }

    private func loadLocalFile(url: URL, accessibleFolderURL: URL?) -> ImageLoadResult {
        guard let folder = accessibleFolderURL else { return .needsFolderAccess }
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return .unavailable }
        return Self.decodeImage(data)
    }

    /// Decodes any ImageIO format (JPEG, PNG, HEIC, WebP, GIF, …) straight to
    /// at most `maxPixelDimension` on the longer side — never materialising
    /// the full-size bitmap — and applies the EXIF orientation. Smaller
    /// images come out at their natural size (the thumbnail API never
    /// upscales).
    static func decodeImage(_ data: Data) -> ImageLoadResult {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return .unavailable
        }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension,
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return .unavailable
        }
        assert(max(cgImage.width, cgImage.height) <= maxPixelDimension)
        return .image(UIImage(cgImage: cgImage))
    }
}
