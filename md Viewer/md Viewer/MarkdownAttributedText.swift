import SwiftUI
import UIKit

/// The document rendered as a styled, read-only, natively selectable text view
/// — the Mac (Catalyst) default preview.
///
/// On the Mac the reader expects to sweep the rendered text with the mouse and
/// copy it with ⌘C. SwiftUI's `.textSelection(.enabled)` on MarkdownUI's output
/// does not deliver that under Catalyst — it does nothing there (verified on a
/// real Mac). A read-only `UITextView` in selectable mode does: mouse
/// drag-selection, plus "Look Up" / share on the selection. `CopyAllTextView`
/// takes first responder on its own so the Edit menu's ⌘A and ⌘C reach it, and
/// defines what those do (highlight all / copy all).
///
/// The text is an `NSAttributedString` rendered from the Markdown by
/// `attributedString(fromMarkdown:baseFont:)` (Foundation's parser), so headings,
/// emphasis, inline code, fenced code blocks, links and lists keep their look
/// while staying one continuous, selectable string. Tables come through as
/// tab-separated rows (no borders) and images are dropped; the reader can toggle
/// to the full MarkdownUI rendering (`DocumentView.preview(markdown:)`) from the
/// toolbar for those. iOS/iPadOS always use the MarkdownUI preview.
struct MarkdownAttributedText: UIViewRepresentable {
    /// The document's Markdown source.
    let markdown: String

    /// Plain-text rendering (Markdown syntax removed) put on the pasteboard when
    /// the reader presses ⌘C with nothing selected — the whole document, exactly
    /// like the "Copy All" toolbar button. With a selection, ⌘C copies that.
    let plainTextForCopyAll: String

    /// The open document's folder, for resolving relative image paths. `nil`
    /// for an unsaved draft.
    let documentFolderURL: URL?

    /// Shared with the MarkdownUI preview — tracks which folders the reader
    /// has granted access to for relative images.
    let accessStore: ImageFolderAccessStore

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
        loadImages(into: view)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        let rendered = attributedString(fromMarkdown: markdown, baseFont: Self.baseFont)
        if view.attributedText != rendered {
            view.attributedText = rendered
            loadImages(into: view)
        }
        if let view = view as? CopyAllTextView {
            view.copyAllProvider = { plainTextForCopyAll }
            view.onCopyAll = onCopyAll
        }
    }

    /// Upgrades `view.attributedText` in place once any images referenced by
    /// `markdown` have loaded — the text itself is already showing (set
    /// synchronously above), so the reader never sees a blank state while
    /// images resolve off the main thread. A previous, now-superseded pass
    /// (the markdown changed again before it finished) is cancelled via
    /// `CopyAllTextView.pendingImageTask`.
    private func loadImages(into view: UITextView) {
        guard let view = view as? CopyAllTextView else { return }
        // Cheap pre-check: a document with no `![` at all has no images to
        // resolve, so skip the async pass (and the `attributedText`
        // reassignment it ends in) entirely. Reassigning `attributedText` —
        // even to an equal-content string — clears the view's current mouse
        // selection, which otherwise silently broke drag-to-select on every
        // image-free document (the common case) shortly after it opened.
        guard markdown.contains("![") else { return }
        let markdown = self.markdown
        let baseFont = Self.baseFont
        let documentFolderURL = self.documentFolderURL
        let accessStore = self.accessStore
        view.pendingImageTask = Task {
            let withImages = await attributedString(
                fromMarkdown: markdown,
                baseFont: baseFont,
                documentFolderURL: documentFolderURL,
                accessStore: accessStore
            )
            guard !Task.isCancelled else { return }
            view.attributedText = withImages
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
///   (matching the "Copy All" button); with a selection it copies that
///   range's text, run through `sanitizedForPlainTextCopy` to strip the
///   display-only stand-ins (see that function) so the paste is clean.
///
/// - Precondition (`copy(_:)` copy-all branch): `copyAllProvider` returns the
///   document's plain text.
/// - Postcondition (copy-all branch): `UIPasteboard.general.string` holds that
///   text and `onCopyAll` has run.
/// - Postcondition (selection branch): `UIPasteboard.general.string` holds
///   the selected range's text with no `\u{2028}` or `\u{FFFC}` markers.
final class CopyAllTextView: UITextView {
    /// Supplies the whole-document plain text for a no-selection ⌘C.
    var copyAllProvider: () -> String = { "" }
    /// Run after a successful no-selection "copy all".
    var onCopyAll: () -> Void = {}

    /// The in-flight "load this markdown's images" pass. Assigning a new
    /// value cancels whichever one was running — the markdown changed again
    /// before images resolved, so that pass's result no longer applies.
    var pendingImageTask: Task<Void, Never>? {
        didSet { oldValue?.cancel() }
    }

    deinit { pendingImageTask?.cancel() }

    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Deferred to the next run loop turn: called synchronously, this can
        // land before the window has become key, in which case
        // `becomeFirstResponder()` silently no-ops — the view never actually
        // gains first-responder status, and with it never installs the text
        // interaction that makes mouse drag-to-select work at all (not just
        // ⌘A/⌘C, which was this method's original motivation).
        guard window != nil, !isFirstResponder else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window != nil, !self.isFirstResponder else { return }
            self.becomeFirstResponder()
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
            let selected = (attributedText.string as NSString).substring(with: selectedRange)
            UIPasteboard.general.string = sanitizedForPlainTextCopy(selected)
            return
        }
        let all = copyAllProvider()
        guard !all.isEmpty else { return }
        UIPasteboard.general.string = all
        onCopyAll()
    }
}

/// Undoes the display-only stand-ins `attributedString(fromMarkdown:baseFont:)`
/// puts in the rendered text, so a partial-selection copy pastes as clean
/// plain text elsewhere instead of leaking internal markers:
/// - `\u{2028}` (Unicode line separator) — used to collapse a fenced code
///   block into one paragraph on screen — becomes a real `\n` again, so a
///   pasted multi-line code block doesn't collapse onto one line.
/// - `\u{FFFC}` (object replacement character, left behind by an inline
///   image `NSTextAttachment`) is dropped — an image has nothing sensible to
///   contribute to a plain-text paste.
///
/// - Precondition: `text` is a substring of `attributedText.string` from
///   `attributedString(fromMarkdown:baseFont:)`.
/// - Postcondition: the result contains neither marker character.
func sanitizedForPlainTextCopy(_ text: String) -> String {
    text.replacingOccurrences(of: "\u{2028}", with: "\n")
        .replacingOccurrences(of: "\u{FFFC}", with: "")
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
/// links (`.link` attribute, tint colour) and thematic breaks. Images are
/// **not** handled here — `AttributedString(markdown:)` itself drops `![]()`
/// entirely (verified empirically: it leaves only the alt text, with no
/// attribute marking it as having been an image). The image-aware overload
/// below pre-processes them separately before calling this function.
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
            // A real blank line, not just one `\n` — the visible gap between
            // paragraphs must live in the *text* (`\n\n`), not only in the
            // `paragraphSpacing` attribute below. Attribute-only spacing
            // looks identical on screen but is invisible to a plain-text
            // copy: selecting a range and ⌘C only carries the characters,
            // so a reader pasting elsewhere saw paragraphs merge into a
            // single run-on line. Explicit `.font` keeps this blank line's
            // height in step with Dynamic Type, matching the surrounding text.
            result.append(NSAttributedString(string: "\n\n", attributes: [.font: baseFont]))
        }
        result.append(rendered)
    }

    return result.length > 0 ? result : plainFallback()
}

// MARK: - Images

/// The image-aware sibling of `attributedString(fromMarkdown:baseFont:)`:
/// same text rendering, plus every `![alt](src)` resolved and spliced in as
/// an inline `NSTextAttachment`. Runs the (potentially slow — folder access,
/// disk I/O, Base64 decode) image resolution off the main actor via
/// `MarkdownImageLoader`; only the final, cheap splice-into-the-string step
/// touches the (already-displayed) text.
///
/// A reference that can't be shown gets a static placeholder glyph rather
/// than vanishing silently — matching the MarkdownUI preview's placeholders,
/// minus the interactive "choose folder" button: an `NSTextAttachment` can't
/// host a SwiftUI button, and the reader can switch to "Formatted View" for
/// that. See `MarkdownImageProvider.swift` for the interactive version.
func attributedString(
    fromMarkdown markdown: String,
    baseFont: UIFont,
    documentFolderURL: URL?,
    accessStore: ImageFolderAccessStore
) async -> NSAttributedString {
    let (sanitized, references) = extractImageReferences(from: markdown)
    let base = attributedString(fromMarkdown: sanitized, baseFont: baseFont)
    guard !references.isEmpty else { return base }

    let result = NSMutableAttributedString(attributedString: base)
    await insertImageAttachments(into: result, references: references, documentFolderURL: documentFolderURL, accessStore: accessStore)
    return result
}

/// Finds every `![alt](src)` in `markdown` and replaces it with a single
/// `\u{FFFC}` (object replacement character) placeholder, so the reference
/// survives — as one inert character, at a known position — through
/// `markdownForAttributedString`'s table/checkbox clean-up and the Foundation
/// Markdown parser, both of which would otherwise drop it. Nested
/// constructs (an image inside a link, `[![alt](img)](url)`) are not
/// matched — same "light contract" scope as the rest of this file.
///
/// - Postcondition: the returned references are in the same left-to-right
///   order as their `\u{FFFC}` placeholders in `sanitized`, so a positional
///   walk (`insertImageAttachments`) can pair them up correctly.
func extractImageReferences(from markdown: String) -> (sanitized: String, references: [(alt: String, source: String)]) {
    guard let regex = try? NSRegularExpression(pattern: #"!\[([^\]]*)\]\(([^)\s]+)\)"#) else {
        return (markdown, [])
    }
    let ns = markdown as NSString
    let matches = regex.matches(in: markdown, range: NSRange(location: 0, length: ns.length))
    guard !matches.isEmpty else { return (markdown, []) }

    var references: [(alt: String, source: String)] = []
    let sanitized = NSMutableString()
    var cursor = 0
    for match in matches {
        guard match.numberOfRanges == 3 else { continue }
        sanitized.append(ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
        sanitized.append("\u{FFFC}")
        references.append((
            alt: ns.substring(with: match.range(at: 1)),
            source: ns.substring(with: match.range(at: 2))
        ))
        cursor = match.range.location + match.range.length
    }
    sanitized.append(ns.substring(from: cursor))
    return (sanitized as String, references)
}

/// Replaces each `\u{FFFC}` placeholder in `text`, in order, with the
/// corresponding `references` entry resolved to an image attachment.
///
/// - Precondition: `references.count` matches the number of `\u{FFFC}`
///   characters in `text` (guaranteed by `extractImageReferences`, which
///   produces both together).
private func insertImageAttachments(
    into text: NSMutableAttributedString,
    references: [(alt: String, source: String)],
    documentFolderURL: URL?,
    accessStore: ImageFolderAccessStore
) async {
    var searchStart = 0
    for reference in references {
        let ns = text.string as NSString
        let placeholderRange = ns.range(
            of: "\u{FFFC}",
            range: NSRange(location: searchStart, length: ns.length - searchStart)
        )
        guard placeholderRange.location != NSNotFound else { break }

        let url = URL(string: reference.source, relativeTo: documentFolderURL)
        let accessibleFolder = url.flatMap { accessStore.accessibleFolderURL(forFileAt: $0) }
        let result = await MarkdownImageLoader.shared.load(url: url, accessibleFolderURL: accessibleFolder)

        let attachment: NSTextAttachment
        switch result {
        case .image(let uiImage):
            let fitting = FitWidthTextAttachment()
            fitting.image = uiImage
            attachment = fitting
        case .needsFolderAccess:
            attachment = NSTextAttachment()
            attachment.image = UIImage(systemName: "folder.badge.questionmark")?
                .withTintColor(.secondaryLabel, renderingMode: .alwaysOriginal)
        case .unavailable:
            attachment = NSTextAttachment()
            attachment.image = UIImage(systemName: "photo")?
                .withTintColor(.secondaryLabel, renderingMode: .alwaysOriginal)
        }

        let replacement = NSAttributedString(attachment: attachment)
        text.replaceCharacters(in: placeholderRange, with: replacement)
        searchStart = placeholderRange.location + replacement.length
    }
}

/// An `NSTextAttachment` that scales its image down to fit the text
/// container's width, preserving aspect ratio, but never upscales past the
/// image's own pixel size — the `NSTextAttachment` counterpart to
/// `FitWidthLayout` (`MarkdownImageProvider.swift`), needed because a plain
/// `NSTextAttachment` renders at the image's native pixel size regardless of
/// the container width.
private final class FitWidthTextAttachment: NSTextAttachment {
    override func attachmentBounds(
        for textContainer: NSTextContainer?,
        proposedLineFragment lineFrag: CGRect,
        glyphPosition position: CGPoint,
        characterIndex charIndex: Int
    ) -> CGRect {
        guard let image, image.size.width > 0, image.size.height > 0, lineFrag.width > 0 else {
            return super.attachmentBounds(
                for: textContainer, proposedLineFragment: lineFrag,
                glyphPosition: position, characterIndex: charIndex
            )
        }
        let width = min(image.size.width, lineFrag.width)
        let height = width * (image.size.height / image.size.width)
        return CGRect(x: 0, y: 0, width: width, height: height)
    }
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
    // The gap between blocks now comes from a real blank line (`"\n\n"` in
    // the join above), not this attribute — attribute-only spacing doesn't
    // survive a plain-text copy of a partial selection.
    paragraph.lineBreakMode = .byWordWrapping
    if headerLevel != nil {
        paragraph.paragraphSpacingBefore = baseFont.pointSize * 0.7
    }
    if isCodeBlock {
        // The whole block is rendered as one paragraph (interior line breaks are
        // U+2028, not U+000A — see below), so this spacing lands once, after the
        // block, and the tinted background reads as one continuous panel.
        paragraph.lineSpacing = 2
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
        if isCodeBlock { paragraph.tailIndent = -12 }
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

    if isCodeBlock {
        // Collapse the interior newlines to U+2028 so the block is a single
        // paragraph: one paragraph style, one uninterrupted background panel,
        // no per-line gaps. `CopyAllTextView.copy(_:)` converts U+2028 back to
        // `\n` for a partial-selection copy (see `sanitizedForPlainTextCopy`);
        // `plainText(fromMarkdown:)` backs "Copy All" with real newlines.
        let body = styled.mutableString
        body.replaceOccurrences(of: "\n", with: "\u{2028}",
                                options: [], range: NSRange(location: 0, length: body.length))
    }

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
