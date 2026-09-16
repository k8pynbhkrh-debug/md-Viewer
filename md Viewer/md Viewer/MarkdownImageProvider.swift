import MarkdownUI
import SwiftUI

/// Loads and displays Markdown images for the MarkdownUI preview
/// (`DocumentView.preview(markdown:)`): relative paths resolved against the
/// document's folder (via `ImageFolderAccessStore`), `data:` URIs, and plain
/// `http(s)` URLs. Replaces MarkdownUI's network-only `DefaultImageProvider`.
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

/// Sizes its (resizable) content down to fit the proposed width, preserving
/// aspect ratio, but never upscales beyond its natural size — the same
/// policy MarkdownUI's own default image provider uses, reimplemented here
/// since that type is internal to the package. Also used by
/// `MermaidDiagramView` for rendered diagrams.
struct FitWidthLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let view = subviews.first else { return .zero }
        var size = view.sizeThatFits(.unspecified)
        if let width = proposal.width, size.width > width, size.width > 0 {
            let aspectRatio = size.width / size.height
            size.width = width
            size.height = width / aspectRatio
        }
        return size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

/// A visible placeholder for an image the preview couldn't show — used
/// instead of silently leaving a gap, so the reader knows why and, when
/// there's something to do about it, how to fix it.
private struct ImagePlaceholder: View {
    let systemImage: String
    let text: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.footnote)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
