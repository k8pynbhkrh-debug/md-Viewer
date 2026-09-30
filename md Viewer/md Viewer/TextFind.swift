import SwiftUI
import UIKit

// Search (⌘F, magnifier) and, in the editor, replace — via the system find
// bar (`UIFindInteraction`) of the `UITextView` that shows the text. The
// rendered MarkdownUI preview is not searchable; `DocumentSession.requestFind`
// switches to a text view first. Per tab: the find bar belongs to the active
// tab's view and closes with it, the last search term is kept in the session.

/// What a text view needs to serve `DocumentSession`'s find requests.
struct TextFindHooks {
    /// A pending request to present the find bar, or `nil`.
    var request: DocumentSession.FindRequest?
    /// Pre-filled when the find bar opens with an empty search field.
    var lastSearchText = ""
    /// Called once the find bar is up — the caller clears the request.
    var onPresented: () -> Void = {}
    /// Called with the current search term when the text view leaves the
    /// screen (tab switch, mode change), so the tab can remember it.
    var onSearchTextChange: (String) -> Void = { _ in }

    static let none = TextFindHooks()
}

extension UITextView {
    /// Opens the system find bar, pre-filled with `searchText` unless the bar
    /// already holds a term of its own.
    ///
    /// - Postcondition: the replace field is shown only if `request ==
    ///   .findAndReplace` **and** the view is editable — a read-only view
    ///   never offers replacing.
    func presentFindNavigator(for request: DocumentSession.FindRequest, prefilling searchText: String) {
        isFindInteractionEnabled = true
        guard let interaction = findInteraction else { return }
        if (interaction.searchText ?? "").isEmpty, !searchText.isEmpty {
            interaction.searchText = searchText
        }
        interaction.presentFindNavigator(showingReplace: request == .findAndReplace && isEditable)
    }

    /// The term in the find bar, if the find interaction has one.
    var currentSearchText: String? {
        guard let text = findInteraction?.searchText, !text.isEmpty else { return nil }
        return text
    }
}

/// A read-only `UITextView` whose system find bar is enabled and follows
/// `findHooks`: a pending request is presented as soon as the view is on
/// screen, and the search term is reported back when it leaves.
class FindableTextView: UITextView {
    var findHooks = TextFindHooks.none {
        didSet { presentPendingFindWhenVisible() }
    }
    private var presentationScheduled = false

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        isFindInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isFindInteractionEnabled = true
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        if newWindow == nil, let text = currentSearchText {
            findHooks.onSearchTextChange(text)
        }
        super.willMove(toWindow: newWindow)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        presentPendingFindWhenVisible()
    }

    /// Deferred to the next run-loop turn: right after a mode switch the view
    /// is not in a key window yet, and the find bar would not appear.
    private func presentPendingFindWhenVisible() {
        guard findHooks.request != nil, window != nil, !presentationScheduled else { return }
        presentationScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.presentationScheduled = false
            guard self.window != nil, let request = self.findHooks.request else { return }
            self.presentFindNavigator(for: request, prefilling: self.findHooks.lastSearchText)
            self.findHooks.onPresented()
        }
    }
}

/// Serves find requests for a SwiftUI `TextEditor`, which exposes no find API
/// beyond `.findNavigator` (no pre-filled term, no "show replace"). Placed as
/// the editor's `.background`, it locates the `UITextView` backing the editor
/// and drives its find interaction directly — that also enables the system
/// Find menu (⌘F, ⌥⌘F, ⌘G) while the editor has focus.
///
/// Replacing through the find bar edits the text view, which updates the
/// `editedText` binding like typing does — so it lands in
/// `EditorUndoHistory` and marks the document unsaved.
struct EditorFindBridge: UIViewRepresentable {
    var hooks: TextFindHooks

    func makeUIView(context: Context) -> LocatorView {
        LocatorView()
    }

    func updateUIView(_ view: LocatorView, context: Context) {
        view.hooks = hooks
    }

    static func dismantleUIView(_ view: LocatorView, coordinator: ()) {
        if let text = view.textView?.currentSearchText {
            view.hooks.onSearchTextChange(text)
        }
    }

    final class LocatorView: UIView {
        var hooks = TextFindHooks.none {
            didSet { presentPendingFind() }
        }
        private(set) weak var textView: UITextView?
        private var presentationScheduled = false

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isHidden = true
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            // The editor's own hosting view is laid out in the same pass;
            // look for it on the next turn.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil else { return }
                self.locateTextView()
                self.presentPendingFind()
            }
        }

        private func presentPendingFind() {
            guard hooks.request != nil, textView != nil, !presentationScheduled else { return }
            presentationScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.presentationScheduled = false
                guard let request = self.hooks.request, let textView = self.textView,
                      textView.window != nil else { return }
                textView.presentFindNavigator(for: request, prefilling: self.hooks.lastSearchText)
                self.hooks.onPresented()
            }
        }

        /// The nearest editable `UITextView` around this view — in the editor
        /// that is the `TextEditor`'s, the only editable text view on screen.
        private func locateTextView() {
            var ancestor = superview
            for _ in 0..<8 {
                guard let current = ancestor else { break }
                if let found = Self.firstEditableTextView(in: current) {
                    found.isFindInteractionEnabled = true
                    textView = found
                    return
                }
                ancestor = current.superview
            }
            assertionFailure("EditorFindBridge: no editable UITextView found near the editor")
        }

        private static func firstEditableTextView(in view: UIView) -> UITextView? {
            if let textView = view as? UITextView, textView.isEditable { return textView }
            for subview in view.subviews {
                if let found = firstEditableTextView(in: subview) { return found }
            }
            return nil
        }
    }
}
