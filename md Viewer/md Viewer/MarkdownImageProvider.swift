import MarkdownUI
import SwiftUI

/// Loads and displays Markdown images for the MarkdownUI preview
/// (`DocumentView.preview(markdown:)`): relative paths resolved against the
/// document's folder (via `ImageFolderAccessStore`) and `data:` URIs;
/// `http(s)` images get a "not loaded" placeholder — md Viewer never fetches
/// from the network. Replaces MarkdownUI's network-only `DefaultImageProvider`.
struct AppImageProvider: ImageProvider {
    /// The open document's folder — where a "grant access" picker for a
    /// missing relative image should start browsing. `nil` for an unsaved
    /// draft (which has no folder; relative images simply won't resolve
    /// there).
    let documentFolderURL: URL?

    func makeImage(url: URL?) -> some View {
        MarkdownImageView(url: url, documentFolderURL: documentFolderURL)
    }
}

/// Loads images that sit *inside* a line of text (`Status: ![](badge.png) ok`)
/// — MarkdownUI routes those through a separate inline provider, whose
/// default fetches over the network. Same sources and limits as
/// `AppImageProvider`; anything that can't be shown (remote, missing, folder
/// not yet granted) becomes a text-sized SF Symbol instead, since an inline
/// slot can only hold an `Image`, not a placeholder view.
///
/// Never throws: MarkdownUI loads a paragraph's inline images as one group
/// and drops *all* of them if any single load throws.
struct AppInlineImageProvider: InlineImageProvider {
    let accessStore: ImageFolderAccessStore

    func image(with url: URL, label: String) async throws -> Image {
        let accessibleFolder = accessStore.accessibleFolderURL(forFileAt: url)
        switch await MarkdownImageLoader.shared.load(url: url, accessibleFolderURL: accessibleFolder) {
        case .image(let uiImage):
            guard let cgImage = uiImage.cgImage else { return Image(systemName: "photo") }
            return Image(cgImage, scale: 1, label: Text(label))
        case .remoteBlocked:
            return Image(systemName: "network.slash")
        case .needsFolderAccess:
            return Image(systemName: "folder.badge.questionmark")
        case .unavailable:
            return Image(systemName: "photo")
        }
    }
}

/// One Markdown image: loads it off the main thread via `MarkdownImageLoader`
/// and shows a visible, actionable placeholder rather than a silent gap when
/// it can't — either because the containing folder needs to be granted
/// access, or because it just isn't available.
private struct MarkdownImageView: View {
    let url: URL?
    let documentFolderURL: URL?

    @Environment(ImageFolderAccessStore.self) private var accessStore
    @State private var result: ImageLoadResult?
    @State private var showFolderPicker = false

    var body: some View {
        content
            .task(id: taskID) { await load() }
            .sheet(isPresented: $showFolderPicker) {
                FolderPicker(directoryURL: documentFolderURL) { picked in
                    try? accessStore.grantAccess(to: picked)
                }
            }
    }

    /// Re-runs `load()` whenever the image URL changes, or the reader grants
    /// folder access (bumping `accessStore.revision`) after a previous
    /// `.needsFolderAccess` result.
    private var taskID: String {
        "\(url?.absoluteString ?? "")#\(accessStore.revision)"
    }

    private func load() async {
        guard let url else {
            result = .unavailable
            return
        }
        let accessibleFolder = accessStore.accessibleFolderURL(forFileAt: url)
        result = await MarkdownImageLoader.shared.load(url: url, accessibleFolderURL: accessibleFolder)
    }

    @ViewBuilder
    private var content: some View {
        switch result {
        case .none:
            // Still loading — no placeholder flash for the common case (a
            // local, already-accessible file resolves almost instantly).
            Color.clear.frame(width: 0, height: 0)
        case .image(let uiImage):
            FitWidthLayout {
                Image(uiImage: uiImage)
                    .resizable()
            }
        case .needsFolderAccess:
            ImagePlaceholder(
                systemImage: "folder.badge.questionmark",
                text: String(localized: "Image – folder access needed"),
                actionTitle: String(localized: "Choose Folder"),
                action: { showFolderPicker = true }
            )
        case .remoteBlocked:
            ImagePlaceholder(
                systemImage: "network.slash",
                text: String(localized: "External image – not loaded"),
                actionTitle: nil,
                action: nil
            )
        case .unavailable:
            ImagePlaceholder(
                systemImage: "photo",
                text: String(localized: "Image unavailable"),
                actionTitle: nil,
                action: nil
            )
        }
    }
}
