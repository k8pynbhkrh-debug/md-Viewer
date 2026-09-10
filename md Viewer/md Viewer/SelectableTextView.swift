import SwiftUI
import UIKit

/// Read-only, fully selectable text.
///
/// SwiftUI's `.textSelection(.enabled)` does not produce the native selection UI
/// (drag handles, "Select All", "Copy", "Look Up", share) on top of MarkdownUI's
/// rendered output on iOS — a long press there only offers a whole-block "Copy".
/// A plain `UITextView` in non-editable / selectable mode gives the reader the
/// real system selection experience for an arbitrary passage.
///
/// The text handed in is the document's plain-text rendering (Markdown syntax
/// removed), so what the reader selects matches what they see.
struct SelectableTextView: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = true
        view.alwaysBounceVertical = true
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 16, left: 20, bottom: 24, right: 20)
        view.adjustsFontForContentSizeCategory = true
        view.textColor = .label
        // No link/date/address detection — this is prose the user is copying,
        // not a place to launch Maps.
        view.dataDetectorTypes = []
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.text = text
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if view.text != text {
            view.text = text
        }
        // Keep up with a Dynamic Type change made while the view is on screen.
        view.font = UIFont.preferredFont(forTextStyle: .body)
    }
}
