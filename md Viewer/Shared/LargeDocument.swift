import SwiftUI
import UIKit

/// When a document is too large for the formatted (MarkdownUI) rendering and
/// is shown as plain text instead.
///
/// MarkdownUI lays out the whole document at once; time and memory grow
/// faster than the file. Measured for T-2026-328 (iPhone 17 simulator,
/// iOS 26.4, time until the first frame / additional memory):
///
/// | Size   | Prose only      | Tables, lists, code |
/// |--------|-----------------|---------------------|
/// | 25 KB  | 0.2 s / 25 MB   | 0.5 s / 55 MB       |
/// | 50 KB  | 0.4 s / 35 MB   | 1.2 s / 115 MB      |
/// | 100 KB | 0.9 s / 75 MB   | 2.8 s / 280 MB      |
/// | 200 KB | 2.4 s / 170 MB  | 7.3 s / 400 MB      |
/// | 1 MB   | 31 s / 900 MB   | —                   |
///
/// The plain-text view opens the 5 MB maximum in under half a second.
///
/// - `appThreshold`: the largest size that still opens in about a second.
/// - `shareExtensionThreshold`: lower, because the system ends an extension
///   that uses much more than ~100 MB — the sheet then simply stays blank.
enum LargeDocument {
    static let appThreshold = 50 * 1024
    static let shareExtensionThreshold = 25 * 1024

    /// Whether `text` is shown as plain text for the given threshold.
    ///
    /// - Precondition: `threshold > 0`.
    /// - Postcondition: `true` ⟺ the UTF-8 size of `text` is greater than
    ///   `threshold` bytes; a document of exactly `threshold` bytes is still
    ///   formatted.
    nonisolated static func exceeds(_ text: String, threshold: Int) -> Bool {
        precondition(threshold > 0, "LargeDocument.exceeds requires a positive threshold")
        return text.utf8.count > threshold
    }
}

/// The line above a large document's text: why it is not formatted — and, if
/// `showFormatted` is given, the way to format it anyway.
struct LargeDocumentNotice: View {
    var showFormatted: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Label("Large document – shown as text", systemImage: "doc.plaintext")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let showFormatted {
                    Button("Show Formatted", action: showFormatted)
                        .font(.footnote)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            Divider()
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

/// The raw text of a large document: read-only, selectable, and fast for the
/// full 5 MB — `UITextView` only lays out what is on screen.
struct LargeDocumentTextView: UIViewRepresentable {
    static let accessibilityIdentifier = "largeDocumentText"

    let text: String
    /// The app passes a text view with a find bar; the default is a plain one.
    var makeTextView: @MainActor () -> UITextView = { UITextView() }
    /// Runs on every SwiftUI update, after the text is in place.
    var update: @MainActor (UITextView) -> Void = { _ in }

    final class Coordinator {
        /// What the text view shows — compared instead of `view.text`, which
        /// would copy megabytes out of the text storage on every update.
        var shownText = ""
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UITextView {
        let view = makeTextView()
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = true
        view.alwaysBounceVertical = true
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 16, left: 20, bottom: 24, right: 20)
        view.adjustsFontForContentSizeCategory = true
        view.textColor = .label
        view.dataDetectorTypes = []
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.accessibilityIdentifier = Self.accessibilityIdentifier
        view.text = text
        context.coordinator.shownText = text
        update(view)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if context.coordinator.shownText != text {
            view.text = text
            context.coordinator.shownText = text
        }
        update(view)
    }
}
