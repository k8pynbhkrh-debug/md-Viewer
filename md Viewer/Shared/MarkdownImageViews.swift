import SwiftUI

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
struct ImagePlaceholder: View {
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
                // MarkdownUI puts `.accessibilityLabel(alt)` on the whole
                // image slot, which replaces this text's label — with nothing
                // for `![](…)` without alt text, so VoiceOver stayed silent.
                // The value is not overridden: VoiceOver reads "alt, text".
                .accessibilityValue(text)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.footnote)
                    .buttonStyle(.bordered)
                    // Same override as above: the label becomes the alt text.
                    .accessibilityValue(actionTitle)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
