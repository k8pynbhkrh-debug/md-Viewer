import SwiftUI
import UIKit

/// The document rendered as a styled, read-only, natively selectable text view
/// — the Mac (Catalyst) preview.
///
/// On the Mac the reader expects to sweep the rendered text with the mouse and
/// copy it with ⌘C. SwiftUI's `.textSelection(.enabled)` on MarkdownUI's output
/// does not deliver that under Catalyst (same UIKit text engine as iOS, where it
/// only offers a whole-block "Copy"). A read-only `UITextView` in selectable
/// mode does: mouse drag-selection, plus "Look Up" / share on the selection.
/// `CopyAllTextView` takes first responder on its own so the Edit menu's ⌘A and
/// ⌘C reach it, and defines what those do (highlight all / copy all).
///
/// The text is an `NSAttributedString` rendered from the Markdown by
/// `attributedString(fromMarkdown:baseFont:)` (Foundation's parser), so headings,
/// emphasis, inline code, links and lists keep their look while staying one
/// continuous, selectable string. iOS/iPadOS keep the richer MarkdownUI preview
/// (`DocumentView.preview(markdown:)`) with its images and syntax highlighting.
struct MarkdownAttributedText: UIViewRepresentable {
    /// The document's Markdown source.
    let markdown: String

    /// Plain-text rendering (Markdown syntax removed) put on the pasteboard when
    /// the reader presses ⌘C with nothing selected — the whole document, exactly
    /// like the "Copy All" toolbar button. With a selection, ⌘C copies that.
    let plainTextForCopyAll: String

    /// Called after a ⌘C-with-no-selection "copy all", so the caller can show
    /// the same confirmation toast the "Copy All" button uses (a programmatic
    /// pasteboard write is otherwise silent).
    var onCopyAll: () -> Void = {}

    func makeUIView(context: Context) -> UITextView {
        let view = CopyAllTextView()
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = true
        view.alwaysBounceVertical = true
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 16, left: 20, bottom: 24, right: 20)
        view.adjustsFontForContentSizeCategory = true
        view.textColor = .label
        // Prose the reader is copying — not a place to launch Maps.
        view.dataDetectorTypes = []
        view.attributedText = attributedString(fromMarkdown: markdown, baseFont: Self.baseFont)
        view.copyAllProvider = { plainTextForCopyAll }
        view.onCopyAll = onCopyAll
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        let rendered = attributedString(fromMarkdown: markdown, baseFont: Self.baseFont)
        if view.attributedText != rendered {
            view.attributedText = rendered
        }
        if let view = view as? CopyAllTextView {
            view.copyAllProvider = { plainTextForCopyAll }
            view.onCopyAll = onCopyAll
        }
    }

    private static var baseFont: UIFont { UIFont.preferredFont(forTextStyle: .body) }
}

/// A read-only, selectable text view for the Mac preview.
///
/// - Becomes first responder as soon as it is in a window, so the Edit menu's
///   Select All (⌘A) and Copy (⌘C) reach it without the reader clicking in
///   first — a non-editable `UITextView` does not take first responder on its
///   own under Catalyst, which is why ⌘A otherwise did nothing.
/// - `selectAll(_:)` selects the whole document and shows the selection.
/// - `copy(_:)` with no selection copies the entire document as plain text
///   (matching the "Copy All" button); with a selection it copies that.
///
/// - Precondition (`copy(_:)` copy-all branch): `copyAllProvider` returns the
///   document's plain text.
/// - Postcondition (copy-all branch): `UIPasteboard.general.string` holds that
///   text and `onCopyAll` has run.
final class CopyAllTextView: UITextView {
    /// Supplies the whole-document plain text for a no-selection ⌘C.
    var copyAllProvider: () -> String = { "" }
    /// Run after a successful no-selection "copy all".
    var onCopyAll: () -> Void = {}

    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, !isFirstResponder {
            becomeFirstResponder()
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // Keep Select All and Copy available with no selection, so ⌘A can
        // highlight the whole document and ⌘C can copy it; everything else
        // keeps UITextView's own rules.
        if action == #selector(selectAll(_:)) || action == #selector(copy(_:)) {
            return !text.isEmpty
        }
        return super.canPerformAction(action, withSender: sender)
    }

    override func selectAll(_ sender: Any?) {
        guard !text.isEmpty else { return }
        if !isFirstResponder { becomeFirstResponder() }
        selectedTextRange = textRange(from: beginningOfDocument, to: endOfDocument)
    }

    override func copy(_ sender: Any?) {
        guard selectedRange.length == 0 else {
            super.copy(sender)
            return
        }
        let all = copyAllProvider()
        guard !all.isEmpty else { return }
        UIPasteboard.general.string = all
        onCopyAll()
    }
}

// MARK: - Markdown → NSAttributedString

/// Renders `markdown` to a styled `NSAttributedString` for a read-only text
/// view: one continuous, selectable string that still reads as formatted text.
///
/// Built on `AttributedString(markdown:)`, so it shares the GFM gaps of
/// `plainText(fromMarkdown:)`, which are pre-handled here: tables are flattened
/// to tab-separated rows and task-list checkboxes are dropped. Handled:
/// headings (scaled + bold), bold / italic / strikethrough, inline code and
/// fenced code blocks (monospaced, tinted background), block quotes (indented,
/// secondary colour), ordered / unordered lists (marker + hanging indent),
/// links (`.link` attribute, tint colour) and thematic breaks. Not shown:
/// images — on the Mac this view is about selecting and copying prose, and the
/// reader still has the rendered preview on iOS/iPadOS.
///
/// Font sizes derive from `baseFont` so Dynamic Type is respected. On a parse
/// failure the raw (table-flattened) source is returned in `baseFont`.
///
/// This is display glue — light contract only: non-empty in ⟹ non-empty out,
/// and the visible characters carry no Markdown syntax markers.
func attributedString(fromMarkdown markdown: String, baseFont: UIFont) -> NSAttributedString {
    let source = markdownForAttributedString(markdown)
    guard !source.isEmpty else { return NSAttributedString() }

    let plainFallback = {
        NSAttributedString(string: source,
                           attributes: [.font: baseFont, .foregroundColor: UIColor.label])
    }

    guard let parsed = try? AttributedString(
        markdown: source,
        options: AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
    ) else {
        return plainFallback()
    }

    let blocks = markdownBlocks(in: parsed)
    guard !blocks.isEmpty else { return plainFallback() }

    let result = NSMutableAttributedString()
    for block in blocks {
        let rendered = renderBlock(block, from: parsed, baseFont: baseFont)
        guard rendered.length > 0 else { continue }
        if result.length > 0 {
            result.append(NSAttributedString(string: "\n"))
        }
        result.append(rendered)
    }

    return result.length > 0 ? result : plainFallback()
}

/// Pre-processes the Markdown so Foundation's parser (no GFM tables, literal
/// task-list boxes) does not leak source into the rendered text — the same two
/// clean-ups `plainText(fromMarkdown:)` applies.
private func markdownForAttributedString(_ markdown: String) -> String {
    var text = flattenedMarkdownTables(in: markdown)
    text = text.replacingOccurrences(
        of: #"(?m)^(\s*[-*]\s+)\[[ xX]\]\s+"#,
        with: "$1",
        options: .regularExpression
    )
    return text
}

/// One rendered Markdown block: the span of a paragraph, heading, list item,
/// code block or block quote line, plus the presentation intent that describes
/// its nesting.
private struct MarkdownBlock {
    let range: Range<AttributedString.Index>
    let intent: PresentationIntent?
}

/// Groups the parsed string's runs into blocks by the identity of their
/// innermost presentation-intent component. Runs without an intent each form
/// their own block.
private func markdownBlocks(in parsed: AttributedString) -> [MarkdownBlock] {
    var blocks: [MarkdownBlock] = []
    var currentIdentity: Int?
    var currentLower: AttributedString.Index?
    var currentUpper: AttributedString.Index?
    var currentIntent: PresentationIntent?

    func flush() {
        if let lower = currentLower, let upper = currentUpper {
            blocks.append(MarkdownBlock(range: lower..<upper, intent: currentIntent))
        }
    }

    for run in parsed.runs {
        let intent = run.presentationIntent
        let identity = intent?.components.first?.identity
        if identity != nil, identity == currentIdentity {
            currentUpper = run.range.upperBound
        } else {
            flush()
            currentIdentity = identity
            currentIntent = intent
            currentLower = run.range.lowerBound
            currentUpper = run.range.upperBound
        }
    }
    flush()
    return blocks
}

private enum MarkdownListKind { case ordered, unordered }

/// Styles a single block: paragraph style (indent, spacing, hanging list
/// marker), block font (heading scale, monospaced code) and inline runs.
private func renderBlock(_ block: MarkdownBlock,
                         from parsed: AttributedString,
                         baseFont: UIFont) -> NSAttributedString {
    var headerLevel: Int?
    var isCodeBlock = false
    var blockQuoteDepth = 0
    var listItemOrdinal: Int?
    var listKind: MarkdownListKind?
    var isThematicBreak = false

    for component in block.intent?.components ?? [] {
        switch component.kind {
        case .header(level: let level): headerLevel = level
        case .codeBlock: isCodeBlock = true
        case .blockQuote: blockQuoteDepth += 1
        case .listItem(ordinal: let ordinal): listItemOrdinal = ordinal
        case .orderedList: listKind = .ordered
        case .unorderedList: listKind = .unordered
        case .thematicBreak: isThematicBreak = true
        default: break
        }
    }

    let blockFont: UIFont
    if let level = headerLevel {
        blockFont = headerFont(level: level, base: baseFont)
    } else if isCodeBlock {
        blockFont = UIFont.monospacedSystemFont(ofSize: baseFont.pointSize * 0.92, weight: .regular)
    } else {
        blockFont = baseFont
    }
    let blockColor: UIColor = (blockQuoteDepth > 0) ? .secondaryLabel : .label

    let paragraph = NSMutableParagraphStyle()
    paragraph.paragraphSpacing = baseFont.pointSize * 0.5
    paragraph.lineBreakMode = .byWordWrapping
    if headerLevel != nil {
        paragraph.paragraphSpacingBefore = baseFont.pointSize * 0.7
    }

    let quoteIndent = CGFloat(blockQuoteDepth) * 16
    var prefix = ""
    if let kind = listKind {
        let marker = (kind == .ordered) ? "\(listItemOrdinal ?? 1).\t" : "•\t"
        prefix = marker
        let hang = quoteIndent + 22
        paragraph.firstLineHeadIndent = quoteIndent
        paragraph.headIndent = hang
        paragraph.tabStops = [NSTextTab(textAlignment: .left, location: hang)]
    } else {
        paragraph.firstLineHeadIndent = quoteIndent + (isCodeBlock ? 12 : 0)
        paragraph.headIndent = quoteIndent + (isCodeBlock ? 12 : 0)
    }

    let styled = NSMutableAttributedString()
    if !prefix.isEmpty {
        styled.append(NSAttributedString(string: prefix,
                                         attributes: [.font: blockFont, .foregroundColor: blockColor]))
    }
    if isThematicBreak {
        styled.append(NSAttributedString(string: "\u{2014}\u{2014}\u{2014}\u{2014}\u{2014}\u{2014}\u{2014}\u{2014}",
                                         attributes: [.font: baseFont, .foregroundColor: UIColor.separator]))
    } else {
        for run in parsed[block.range].runs {
            let piece = String(parsed[block.range][run.range].characters)
            guard !piece.isEmpty else { continue }
            styled.append(styledInlineRun(piece,
                                          inline: run.inlinePresentationIntent,
                                          link: run.link,
                                          blockFont: blockFont,
                                          blockColor: blockColor,
                                          isCodeBlock: isCodeBlock))
        }
    }

    trimNewlines(styled)
    guard styled.length > 0 else { return NSAttributedString() }

    styled.addAttribute(.paragraphStyle, value: paragraph,
                        range: NSRange(location: 0, length: styled.length))
    if isCodeBlock {
        styled.addAttribute(.backgroundColor, value: UIColor.secondarySystemBackground,
                            range: NSRange(location: 0, length: styled.length))
    }
    return styled
}

/// One inline run with its emphasis / code / link styling applied.
private func styledInlineRun(_ text: String,
                             inline: InlinePresentationIntent?,
                             link: URL?,
                             blockFont: UIFont,
                             blockColor: UIColor,
                             isCodeBlock: Bool) -> NSAttributedString {
    var font = blockFont
    let intent = inline ?? []
    if intent.contains(.stronglyEmphasized) { font = font.addingSymbolicTraits(.traitBold) }
    if intent.contains(.emphasized) { font = font.addingSymbolicTraits(.traitItalic) }
    if intent.contains(.code), !isCodeBlock {
        font = UIFont.monospacedSystemFont(ofSize: font.pointSize * 0.92, weight: .regular)
    }

    var attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: blockColor,
    ]
    if intent.contains(.strikethrough) {
        attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
    }
    if let link {
        attributes[.link] = link
        attributes[.foregroundColor] = UIColor.tintColor
    }
    return NSAttributedString(string: text, attributes: attributes)
}

/// A bold, size-scaled font for an ATX heading level (1 = largest).
private func headerFont(level: Int, base: UIFont) -> UIFont {
    let scale: CGFloat
    switch level {
    case 1: scale = 1.7
    case 2: scale = 1.45
    case 3: scale = 1.25
    case 4: scale = 1.12
    default: scale = 1.0
    }
    let descriptor = base.fontDescriptor.withSymbolicTraits(.traitBold) ?? base.fontDescriptor
    return UIFont(descriptor: descriptor, size: base.pointSize * scale)
}

/// Drops newline characters from both ends of `string` in place, leaving any
/// interior newlines (hard breaks, code-block lines) intact.
private func trimNewlines(_ string: NSMutableAttributedString) {
    let newlines = CharacterSet.newlines
    while string.length > 0,
          let scalar = string.string.unicodeScalars.first,
          newlines.contains(scalar) {
        string.deleteCharacters(in: NSRange(location: 0, length: 1))
    }
    while string.length > 0,
          let scalar = string.string.unicodeScalars.last,
          newlines.contains(scalar) {
        string.deleteCharacters(in: NSRange(location: string.length - 1, length: 1))
    }
}

private extension UIFont {
    /// This font with `traits` added to whatever it already has.
    func addingSymbolicTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let combined = fontDescriptor.symbolicTraits.union(traits)
        guard let descriptor = fontDescriptor.withSymbolicTraits(combined) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
