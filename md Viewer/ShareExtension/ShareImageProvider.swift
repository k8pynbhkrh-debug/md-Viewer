import MarkdownUI
import SwiftUI

/// Markdown images in the share sheet. Replaces MarkdownUI's default
/// providers, which would fetch `http(s)` images over the network — the
/// extension must stay as offline as the app. Uses the app's
/// `MarkdownImageLoader`, so `data:` URIs render with the same limits and
/// `http(s)` images get the same "not loaded" placeholder.
///
/// Relative images can't be shown here: the extension only receives a copy
/// of the file, not access to its folder, so they fall back to "Image
/// unavailable" without any file access.
struct ShareImageProvider: ImageProvider {
    func makeImage(url: URL?) -> some View {
        ShareImageView(url: url)
    }
}

/// The inline counterpart (an image inside a line of text). Never throws —
/// MarkdownUI drops a paragraph's inline images as a group if one load
/// throws.
struct ShareInlineImageProvider: InlineImageProvider {
    func image(with url: URL, label: String) async throws -> Image {
        switch await MarkdownImageLoader.shared.load(url: url, accessibleFolderURL: nil) {
        case .image(let uiImage):
            guard let cgImage = uiImage.cgImage else { return Image(systemName: "photo") }
            return Image(cgImage, scale: 1, label: Text(label))
        case .remoteBlocked:
            return Image(systemName: "network.slash")
        case .needsFolderAccess, .unavailable:
            return Image(systemName: "photo")
        }
    }
}

private struct ShareImageView: View {
    let url: URL?

    @State private var result: ImageLoadResult?

    var body: some View {
        content
            .task(id: url) {
                result = await MarkdownImageLoader.shared.load(url: url, accessibleFolderURL: nil)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch result {
        case .none:
            Color.clear.frame(width: 0, height: 0)
        case .image(let uiImage):
            FitWidthLayout {
                Image(uiImage: uiImage)
                    .resizable()
            }
        case .remoteBlocked:
            ImagePlaceholder(
                systemImage: "network.slash",
                text: String(localized: "External image – not loaded"),
                actionTitle: nil,
                action: nil
            )
        case .needsFolderAccess, .unavailable:
            ImagePlaceholder(
                systemImage: "photo",
                text: String(localized: "Image unavailable"),
                actionTitle: nil,
                action: nil
            )
        }
    }
}
