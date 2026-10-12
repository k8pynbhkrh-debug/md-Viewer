import MarkdownUI
import SwiftUI
import UIKit

// View wiring for "keep my place when the view changes" (T-2026-345) and for
// "the line being typed stays visible above the keyboard" (T-2026-337). The
// position arithmetic is in `ReadingPosition.swift`.
//
// Every view of a document registers with its `DocumentSession` as the
// "position source"; the session asks it for the place right before the view
// is swapped, and the next view scrolls to that place once it is on screen.

/// Delays (seconds after the view appeared) at which a restore is applied.
/// More than one, because the layout is not final at once: text views refine
/// their height estimates, the keyboard slides in, images load.
private let restoreDelays: [TimeInterval] = [0, 0.12, 0.4, 0.9]

private extension UIScrollView {
    var minOffsetY: CGFloat { -adjustedContentInset.top }
    var maxOffsetY: CGFloat {
        max(minOffsetY, contentSize.height + adjustedContentInset.bottom - bounds.height)
    }
    var isUserScrolling: Bool { isTracking || isDragging || isDecelerating }

    /// - Postcondition: `minOffsetY ≤ contentOffset.y ≤ maxOffsetY`.
    func scrollVertically(to y: CGFloat) {
        let clamped = min(maxOffsetY, max(minOffsetY, y))
        guard abs(clamped - contentOffset.y) > 0.5 else { return }
        setContentOffset(CGPoint(x: contentOffset.x, y: clamped), animated: false)
    }
}

// MARK: - Text views (editor, "Select Text", Mac selectable preview)

/// Remembers and restores the reading position of one `UITextView`.
///
/// ## Contract
/// - Precondition: `appeared()` once the text view is in a window,
///   `disappearing()` before it leaves.
/// - Postcondition (restore): the passage of `session.readingAnchor` is the
///   first line under the top edge (start / end stay start / end); in the
///   editor the caret is placed there too.
/// - Invariant: never changes the text. Nothing is captured before the
///   restore has run, so a half-built view cannot overwrite the remembered
///   place with "top of document".
@MainActor
final class TextViewPositionKeeper {
    private weak var textView: UITextView?
    private weak var session: DocumentSession?
    private let kind: ReadingAnchor.ViewKind
    private var didRestore = false
    /// Bumped on every appearance, so restore passes of an earlier one stop.
    private var generation = 0
    /// Editor: the selection the restore set — a different one means the user
    /// moved the caret, and later passes must not pull the view back.
    private var restoredSelection: NSRange?
    private var restoredTextLength = 0

    init(textView: UITextView, session: DocumentSession, kind: ReadingAnchor.ViewKind) {
        self.textView = textView
        self.session = session
        self.kind = kind
    }

    func appeared() {
        guard let session, textView != nil else { return }
        generation += 1
        didRestore = false
        session.registerPositionSource(owner: self) { [weak self] in self?.capture() }
        guard let anchor = session.readingAnchor else {
            didRestore = true
            return
        }
        let generation = generation
        for (pass, delay) in restoreDelays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.generation == generation else { return }
                self.restore(anchor, isFirstPass: pass == 0)
            }
        }
    }

    func disappearing() {
        generation += 1
        session?.unregisterPositionSource(owner: self)
    }

    private func capture() -> ReadingAnchor? {
        guard didRestore, let textView, textView.window != nil else { return nil }
        let length = (textView.text as NSString).length
        let position: ReadingPosition
        if textView.contentOffset.y <= textView.minOffsetY + 1 {
            position = .start
        } else if textView.contentOffset.y >= textView.maxOffsetY - 1 {
            position = .end
        } else {
            // A text view's coordinates are its content coordinates.
            let top = CGPoint(x: textView.textContainerInset.left + 2,
                              y: textView.contentOffset.y + textView.adjustedContentInset.top + 2)
            guard let textPosition = textView.closestPosition(to: top) else { return nil }
            let offset = textView.offset(from: textView.beginningOfDocument, to: textPosition)
            let skeleton = TextSkeleton(textView.text)
            position = skeleton.position(atIndex: skeleton.index(atOrAfterUTF16Offset: offset))
        }
        return ReadingAnchor(
            position: position,
            view: kind,
            contentOffsetY: textView.contentOffset.y,
            textLength: length,
            selection: kind == .editor ? textView.selectedRange : nil
        )
    }

    private func restore(_ anchor: ReadingAnchor, isFirstPass: Bool) {
        guard let textView, textView.window != nil else { return }
        defer { didRestore = true }
        let length = (textView.text as NSString).length
        if !isFirstPass {
            // The reader took over — scrolling, typing or moving the caret.
            guard !textView.isUserScrolling, length == restoredTextLength else { return }
            if kind == .editor, textView.selectedRange != restoredSelection { return }
        }
        textView.layoutIfNeeded()

        let sameView = anchor.view == kind && anchor.textLength == length
        var caret: NSRange?
        var targetY: CGFloat
        switch anchor.position.edge {
        case .start:
            targetY = textView.minOffsetY
            caret = NSRange(location: 0, length: 0)
        case .end:
            targetY = textView.maxOffsetY
            caret = NSRange(location: length, length: 0)
        case nil:
            let skeleton = TextSkeleton(textView.text)
            let offset = skeleton.utf16Offset(atIndex: skeleton.index(of: anchor.position))
            guard let textPosition = textView.position(from: textView.beginningOfDocument, offset: offset) else {
                return
            }
            targetY = textView.caretRect(for: textPosition).minY - textView.adjustedContentInset.top - 4
            // The caret goes to the start of that (wrapped) line, not into a
            // word — and not to the paragraph start, which may be off screen.
            let lineStart = textView.tokenizer.position(
                from: textPosition, toBoundary: .line,
                inDirection: UITextDirection(rawValue: UITextStorageDirection.backward.rawValue))
            let caretOffset = lineStart.map { textView.offset(from: textView.beginningOfDocument, to: $0) } ?? offset
            caret = NSRange(location: min(offset, max(0, caretOffset)), length: 0)
        }
        if sameView {
            targetY = anchor.contentOffsetY
            caret = anchor.selection
        }
        if kind == .editor, isFirstPass, let caret, caret.location + caret.length <= length {
            textView.selectedRange = caret
        }
        if isFirstPass {
            restoredSelection = textView.selectedRange
            restoredTextLength = length
        }
        textView.scrollVertically(to: targetY)
    }
}

// MARK: - Editor: caret stays above the keyboard (T-2026-337)

/// Keeps the line being typed visible above the on-screen keyboard.
///
/// SwiftUI's `TextEditor` normally shrinks with the keyboard and its text view
/// follows the caret — but that rests on the system's own keyboard avoidance,
/// and the caret line then sits flush against the keyboard. This does it
/// explicitly: whatever part of the text view the keyboard covers becomes
/// bottom inset, and after every change of the text the caret is scrolled
/// into the free area with a line of air below it.
///
/// ## Contract
/// - Precondition: `textView` is the editor's text view.
/// - Postcondition (after each text change while it has focus): the caret
///   rectangle lies inside the part of the text view not covered by the
///   keyboard.
/// - Invariant: never changes text or selection.
@MainActor
final class CaretVisibilityKeeper {
    private weak var textView: UITextView?
    private var observers: [NSObjectProtocol] = []
    /// The keyboard's frame in screen coordinates, `.null` while hidden.
    private var keyboardFrame = CGRect.null
    /// Air between the last line and the keyboard / bottom edge.
    private static let bottomGap: CGFloat = 12

    init(textView: UITextView) {
        self.textView = textView
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: UITextView.textDidChangeNotification, object: textView, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.textChanged() }
        })
        for name in [UIResponder.keyboardWillChangeFrameNotification,
                     UIResponder.keyboardDidChangeFrameNotification,
                     UIResponder.keyboardWillHideNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
                let hides = note.name == UIResponder.keyboardWillHideNotification
                MainActor.assumeIsolated {
                    self?.keyboardChanged(to: hides ? .null : (frame ?? .null))
                }
            })
        }
        applyBottomInset()
    }

    isolated deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    private func keyboardChanged(to frame: CGRect) {
        keyboardFrame = frame
        applyBottomInset()
        // After the keyboard's own animation settled the frame.
        DispatchQueue.main.async { [weak self] in
            self?.applyBottomInset()
            self?.revealCaret()
        }
    }

    private func textChanged() {
        // The text view lays out the new line in this turn; look afterwards.
        DispatchQueue.main.async { [weak self] in self?.revealCaret() }
    }

    /// How much of the text view's bottom the keyboard covers.
    private func keyboardOverlap(in textView: UITextView) -> CGFloat {
        guard !keyboardFrame.isNull, let window = textView.window else { return 0 }
        let keyboardInWindow = window.convert(keyboardFrame, from: window.screen.coordinateSpace)
        let visibleFrame = textView.convert(textView.bounds, to: window)
        return max(0, min(visibleFrame.height, visibleFrame.maxY - keyboardInWindow.minY))
    }

    private func applyBottomInset() {
        guard let textView else { return }
        let inset = keyboardOverlap(in: textView) + Self.bottomGap
        guard abs(textView.contentInset.bottom - inset) > 0.5 else { return }
        textView.contentInset.bottom = inset
        textView.verticalScrollIndicatorInsets.bottom = max(0, inset - Self.bottomGap)
    }

    /// Scrolls just far enough that the caret line is inside the free area.
    func revealCaret() {
        guard let textView, textView.isFirstResponder, textView.window != nil,
              !textView.isUserScrolling, let selection = textView.selectedTextRange else { return }
        applyBottomInset()
        textView.layoutIfNeeded()
        let caret = textView.caretRect(for: selection.end)
        guard !caret.isNull, !caret.isInfinite else { return }
        let top = textView.contentOffset.y + textView.adjustedContentInset.top
        let bottom = textView.contentOffset.y + textView.bounds.height - textView.adjustedContentInset.bottom
        if caret.maxY > bottom {
            textView.scrollVertically(to: textView.contentOffset.y + caret.maxY - bottom)
        } else if caret.minY < top {
            textView.scrollVertically(to: textView.contentOffset.y - (top - caret.minY))
        }
    }
}

// MARK: - Rendered preview (MarkdownUI in a SwiftUI ScrollView)

private let previewContentSpace = "mdPreviewContent"

struct RenderedBlocksKey: PreferenceKey {
    static let defaultValue: [RenderedBlock] = []
    static func reduce(value: inout [RenderedBlock], nextValue: () -> [RenderedBlock]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    /// Reports this rendered block's text and vertical extent, so the preview
    /// can tell which passage is at the top of the screen.
    func reportsRenderedBlock(text: String) -> some View {
        background {
            GeometryReader { proxy in
                let frame = proxy.frame(in: .named(previewContentSpace))
                Color.clear.preference(
                    key: RenderedBlocksKey.self,
                    value: [RenderedBlock(text: text, minY: frame.minY, height: frame.height)]
                )
            }
        }
    }

    /// Makes the scroll content of the rendered preview keep its reading
    /// position through `controller`. Apply to the outermost view inside the
    /// `ScrollView`.
    func keepsReadingPosition(with controller: PreviewPositionController, session: DocumentSession) -> some View {
        coordinateSpace(name: previewContentSpace)
            .onPreferenceChange(RenderedBlocksKey.self) { blocks in
                controller.blocks = blocks
            }
            .background { PreviewScrollProbe(controller: controller, session: session) }
    }
}

/// Remembers and restores the reading position of the rendered preview.
///
/// ## Contract
/// - Postcondition (restore): the block containing the remembered passage is
///   at the top edge, interpolated inside the block; re-applied for a moment
///   while the layout still grows (images, diagrams), unless the reader
///   scrolls.
/// - Invariant: nothing is captured before the restore has been applied to a
///   laid-out document.
@MainActor
final class PreviewPositionController {
    var blocks: [RenderedBlock] = [] {
        didSet { if blocks != oldValue { layoutChanged() } }
    }
    private weak var scrollView: UIScrollView?
    private weak var session: DocumentSession?
    private var pending: ReadingAnchor?
    private var pendingUntil = Date.distantPast
    private var didRestore = false
    private var generation = 0

    func attach(scrollView: UIScrollView, session: DocumentSession) {
        self.scrollView = scrollView
        self.session = session
        generation += 1
        didRestore = false
        session.registerPositionSource(owner: self) { [weak self] in self?.capture() }
        guard let anchor = session.readingAnchor else {
            didRestore = true
            return
        }
        pending = anchor
        pendingUntil = Date().addingTimeInterval(1.5)
        let generation = generation
        for delay in restoreDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.generation == generation else { return }
                self.applyPending()
            }
        }
    }

    func detach() {
        generation += 1
        session?.unregisterPositionSource(owner: self)
        pending = nil
        scrollView = nil
    }

    private func layoutChanged() {
        guard pending != nil else { return }
        let generation = generation
        // The scroll view takes over the new content size after this pass.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == generation else { return }
            self.applyPending()
        }
    }

    private func applyPending() {
        guard let anchor = pending, let scrollView, scrollView.window != nil else { return }
        guard Date() < pendingUntil || !didRestore else {
            pending = nil
            return
        }
        if didRestore, scrollView.isUserScrolling {
            pending = nil
            return
        }
        scrollView.layoutIfNeeded()
        let map = RenderedBlockMap(blocks: blocks)
        guard !map.isEmpty else { return }
        let targetY: CGFloat
        if anchor.view == .preview, anchor.textLength == Int(scrollView.contentSize.height) {
            targetY = anchor.contentOffsetY
        } else {
            switch anchor.position.edge {
            case .start: targetY = scrollView.minOffsetY
            case .end: targetY = scrollView.maxOffsetY
            case nil:
                guard let y = map.y(for: anchor.position) else { return }
                targetY = y - scrollView.adjustedContentInset.top
            }
        }
        scrollView.scrollVertically(to: targetY)
        didRestore = true
    }

    private func capture() -> ReadingAnchor? {
        guard didRestore, let scrollView, scrollView.window != nil else { return nil }
        let position: ReadingPosition
        if scrollView.contentOffset.y <= scrollView.minOffsetY + 1 {
            position = .start
        } else if scrollView.contentOffset.y >= scrollView.maxOffsetY - 1 {
            position = .end
        } else {
            let map = RenderedBlockMap(blocks: blocks)
            guard !map.isEmpty else { return nil }
            position = map.position(atY: scrollView.contentOffset.y + scrollView.adjustedContentInset.top)
        }
        return ReadingAnchor(
            position: position,
            view: .preview,
            contentOffsetY: scrollView.contentOffset.y,
            textLength: Int(scrollView.contentSize.height),
            selection: nil
        )
    }
}

/// Finds the `UIScrollView` behind the preview's SwiftUI `ScrollView` and
/// hands it to the controller — iOS 17 has no SwiftUI API to read and set a
/// scroll offset.
private struct PreviewScrollProbe: UIViewRepresentable {
    let controller: PreviewPositionController
    let session: DocumentSession

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.controller = controller
        view.session = session
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {}

    final class ProbeView: UIView {
        var controller: PreviewPositionController?
        weak var session: DocumentSession?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isHidden = true
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        override func willMove(toWindow newWindow: UIWindow?) {
            if newWindow == nil { controller?.detach() }
            super.willMove(toWindow: newWindow)
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil, let session = self.session else { return }
                var ancestor = self.superview
                while let current = ancestor {
                    if let scrollView = current as? UIScrollView {
                        self.controller?.attach(scrollView: scrollView, session: session)
                        return
                    }
                    ancestor = current.superview
                }
                assertionFailure("PreviewScrollProbe: no UIScrollView around the preview")
            }
        }
    }
}

extension View {
    /// Paragraphs and headings report their text and position like tables
    /// and code blocks do. The styles repeat MarkdownUI's default (`.basic`)
    /// theme verbatim — its block styles cannot be wrapped from outside — so
    /// the rendering is unchanged.
    func reportingTextBlocks() -> some View {
        markdownBlockStyle(\.paragraph) { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.15))
                .reportsRenderedBlock(text: configuration.content.renderPlainText())
                .markdownMargin(top: .zero, bottom: .em(1))
        }
        .markdownBlockStyle(\.heading1) { reportingHeading($0, size: 2) }
        .markdownBlockStyle(\.heading2) { reportingHeading($0, size: 1.5) }
        .markdownBlockStyle(\.heading3) { reportingHeading($0, size: 1.17) }
        .markdownBlockStyle(\.heading4) { reportingHeading($0, size: 1) }
        .markdownBlockStyle(\.heading5) { reportingHeading($0, size: 0.83) }
        .markdownBlockStyle(\.heading6) { reportingHeading($0, size: 0.67) }
    }
}

@MainActor
private func reportingHeading(_ configuration: BlockConfiguration, size: CGFloat) -> some View {
    configuration.label
        .reportsRenderedBlock(text: configuration.content.renderPlainText())
        .markdownMargin(top: .rem(1.5), bottom: .rem(1))
        .markdownTextStyle {
            FontWeight(.semibold)
            FontSize(.em(size))
        }
}
