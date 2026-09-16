import Foundation
import UIKit

/// The outcome of resolving one Markdown image reference.
enum ImageLoadResult: Equatable {
    case image(UIImage)
    /// A relative path inside a folder the app has not (yet) been granted
    /// access to.
    case needsFolderAccess
    /// Anything else that didn't produce an image — missing file, decode
    /// failure, unsupported scheme, network error.
    case unavailable
}

/// Resolves and decodes Markdown image references off the main thread:
/// `data:` URIs (Base64), local files under a folder the user has granted
/// access to, and plain `http(s)` URLs. Actor isolation keeps every decode
/// off the main actor without extra bookkeeping — large embedded images no
/// longer stall or abort the preview (the originally reported bug).
actor MarkdownImageLoader {
    static let shared = MarkdownImageLoader()

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
            return await fetchRemote(url)
        case "file", .none:
            return loadLocalFile(url: url, accessibleFolderURL: accessibleFolderURL)
        default:
            return .unavailable
        }
    }

    /// `URLSession` does not support the `data:` scheme, so this is decoded
    /// by hand rather than fetched.
    private func decodeDataURI(_ url: URL) -> ImageLoadResult {
        guard let commaIndex = url.absoluteString.firstIndex(of: ",") else { return .unavailable }
        let base64 = String(url.absoluteString[url.absoluteString.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
              let image = UIImage(data: data) else {
            return .unavailable
        }
        return .image(image)
    }

    private func fetchRemote(_ url: URL) async -> ImageLoadResult {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else {
            return .unavailable
        }
        return .image(image)
    }

    /// `UIImage(data:)` decodes JPEG, PNG, HEIC, WebP and GIF alike via
    /// ImageIO — no per-format handling needed.
    private func loadLocalFile(url: URL, accessibleFolderURL: URL?) -> ImageLoadResult {
        guard let folder = accessibleFolderURL else { return .needsFolderAccess }
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
            return .unavailable
        }
        return .image(image)
    }
}
