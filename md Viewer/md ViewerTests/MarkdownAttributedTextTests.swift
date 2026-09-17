import Testing
import Foundation
import UIKit
@testable import md_Viewer

@Suite("attributedString(fromMarkdown:)")
struct MarkdownAttributedStringTests {

    private let base = UIFont.preferredFont(forTextStyle: .body)

    private func font(in string: NSAttributedString, at substring: String) -> UIFont? {
        let range = (string.string as NSString).range(of: substring)
        guard range.location != NSNotFound else { return nil }
        return string.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont
    }

    // Contract — empty in, empty out.
    @Test("empty input yields an empty string")
    func empty() {
        #expect(attributedString(fromMarkdown: "", baseFont: base).string.isEmpty)
    }

    // Contract — plain text passes through unchanged.
    @Test("text without any Markdown is returned as-is")
    func plainPassthrough() {
        #expect(attributedString(fromMarkdown: "Just a sentence.", baseFont: base).string
                == "Just a sentence.")
    }

    // Contract — the visible characters carry no Markdown syntax markers.
    @Test("strips heading, emphasis and code markers")
    func stripsSyntax() {
        let out = attributedString(fromMarkdown: "# Title\n\nSome **bold** and `code` text.",
                                   baseFont: base).string
        #expect(!out.contains("#"))
        #expect(!out.contains("*"))
        #expect(!out.contains("`"))
        #expect(out.contains("Title"))
        #expect(out.contains("bold"))
        #expect(out.contains("code"))
    }

    @Test("a heading is rendered larger and bold")
    func headingStyle() {
        let out = attributedString(fromMarkdown: "# Big Title", baseFont: base)
        let headingFont = font(in: out, at: "Big Title")
        #expect((headingFont?.pointSize ?? 0) > base.pointSize)
        #expect(headingFont?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }

    @Test("bold text gets the bold trait, italic the italic trait")
    func emphasisTraits() {
        let out = attributedString(fromMarkdown: "a **strong** and *slanted* word", baseFont: base)
        #expect(font(in: out, at: "strong")?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        #expect(font(in: out, at: "slanted")?.fontDescriptor.symbolicTraits.contains(.traitItalic) == true)
    }

    @Test("inline code is monospaced")
    func inlineCode() {
        let out = attributedString(fromMarkdown: "run `swift build` now", baseFont: base)
        #expect(font(in: out, at: "swift build")?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true)
    }

    // Contract — a link keeps its visible text, drops the URL, carries `.link`.
    @Test("a link keeps its text, drops the URL, carries a link attribute")
    func link() {
        let out = attributedString(fromMarkdown: "See [the spec](https://example.com/spec) here.",
                                   baseFont: base)
        #expect(out.string.contains("the spec"))
        #expect(!out.string.contains("https://example.com"))
        let range = (out.string as NSString).range(of: "the spec")
        #expect(out.attribute(.link, at: range.location, effectiveRange: nil) != nil)
    }

    // Contract — task-list checkboxes are dropped (shared with plainText).
    @Test("task-list checkboxes are stripped")
    func taskListCheckboxes() {
        let out = attributedString(fromMarkdown: "- [ ] open item\n- [x] done item", baseFont: base).string
        #expect(!out.contains("["))
        #expect(!out.contains("]"))
        #expect(out.contains("open item"))
        #expect(out.contains("done item"))
    }

    // Contract — a GFM table comes through without pipes or the |---| divider.
    @Test("tables are flattened, divider row removed")
    func tablesFlattened() {
        let md = """
        | Name | Date |
        | --- | --- |
        | Beta | 02.09. |
        | GA | 16.09. |
        """
        let out = attributedString(fromMarkdown: md, baseFont: base).string
        #expect(!out.contains("---"))
        #expect(!out.contains("|"))
        #expect(out.contains("Name"))
        #expect(out.contains("Beta"))
        #expect(out.contains("16.09."))
    }

    @Test("unordered list items keep their text and get a bullet marker")
    func bulletList() {
        let out = attributedString(fromMarkdown: "- one\n- two\n- three", baseFont: base).string
        #expect(out.contains("•"))
        #expect(out.contains("one"))
        #expect(out.contains("two"))
        #expect(out.contains("three"))
    }

    @Test("ordered list items are numbered")
    func numberedList() {
        let out = attributedString(fromMarkdown: "1. first\n2. second", baseFont: base).string
        #expect(out.contains("first"))
        #expect(out.contains("second"))
        #expect(out.contains("1."))
        #expect(out.contains("2."))
    }

    @Test("a fenced code block keeps its lines in a monospaced font")
    func codeBlock() {
        let md = """
        Intro.

        ```
        let x = 1
        let y = 2
        ```
        """
        let out = attributedString(fromMarkdown: md, baseFont: base)
        #expect(out.string.contains("let x = 1"))
        #expect(out.string.contains("let y = 2"))
        #expect(!out.string.contains("```"))
        #expect(font(in: out, at: "let x = 1")?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true)
    }

    @Test("multiple paragraphs are separated by newlines")
    func paragraphSeparation() {
        let out = attributedString(fromMarkdown: "First paragraph.\n\nSecond paragraph.",
                                   baseFont: base).string
        #expect(out.contains("First paragraph."))
        #expect(out.contains("Second paragraph."))
        #expect(out.contains("\n"))
    }

    // Contract — the paragraph gap must be real text (`\n\n`), not just a
    // `paragraphSpacing` attribute: selecting a range and ⌘C only copies
    // characters, so a visual-only gap silently disappears once pasted
    // elsewhere. A plain-text destination needs a genuine blank line to
    // still show paragraphs as separate.
    @Test("the gap between paragraphs is a real blank line, not only visual spacing")
    func paragraphGapSurvivesPlainTextCopy() {
        let out = attributedString(fromMarkdown: "First paragraph.\n\nSecond paragraph.",
                                   baseFont: base).string
        #expect(out.contains("First paragraph.\n\nSecond paragraph."))
    }
}

@Suite("sanitizedForPlainTextCopy(_:)")
struct SanitizedForPlainTextCopyTests {

    // Contract — text with no markers passes through unchanged.
    @Test("plain text is untouched")
    func plainPassthrough() {
        #expect(sanitizedForPlainTextCopy("Just a sentence.") == "Just a sentence.")
    }

    // Contract — a code block's U+2028 line separators (used on screen to
    // keep the block one paragraph) become real newlines again, so a partial
    // copy of a code block doesn't collapse onto one line elsewhere.
    @Test("U+2028 line separators become real newlines")
    func lineSeparatorsBecomeNewlines() {
        let out = sanitizedForPlainTextCopy("let x = 1\u{2028}let y = 2")
        #expect(out == "let x = 1\nlet y = 2")
    }

    // Contract — an image's leftover object-replacement character is dropped
    // rather than pasted as a stray glyph.
    @Test("U+FFFC object-replacement characters are dropped")
    func objectReplacementCharactersAreDropped() {
        let out = sanitizedForPlainTextCopy("before\u{FFFC}after")
        #expect(out == "beforeafter")
    }
}

@Suite("extractImageReferences(from:)")
struct ExtractImageReferencesTests {
    @Test("no images: markdown and empty references pass through unchanged")
    func noImages() {
        let (sanitized, references) = extractImageReferences(from: "Just **text**, no pictures.")
        #expect(sanitized == "Just **text**, no pictures.")
        #expect(references.isEmpty)
    }

    @Test("a single image is replaced by one placeholder, surrounding text kept")
    func singleImage() {
        let (sanitized, references) = extractImageReferences(from: "before ![a photo](chat-medien/foto.jpg) after")
        #expect(sanitized == "before \u{FFFC} after")
        #expect(references.count == 1)
        #expect(references[0].alt == "a photo")
        #expect(references[0].source == "chat-medien/foto.jpg")
    }

    @Test("multiple images are extracted in left-to-right order")
    func multipleImagesInOrder() {
        let (sanitized, references) = extractImageReferences(
            from: "![one](a.jpg) between ![two](b.jpg)"
        )
        #expect(sanitized == "\u{FFFC} between \u{FFFC}")
        #expect(references.map(\.source) == ["a.jpg", "b.jpg"])
    }

    @Test("an image with empty alt text is still extracted")
    func emptyAltText() {
        let (_, references) = extractImageReferences(from: "![](data:image/png;base64,AAAA)")
        #expect(references.count == 1)
        #expect(references[0].alt == "")
        #expect(references[0].source == "data:image/png;base64,AAAA")
    }
}

@Suite("attributedString(fromMarkdown:baseFont:documentFolderURL:accessStore:)")
struct MarkdownAttributedTextImageTests {
    private let base = UIFont.preferredFont(forTextStyle: .body)

    /// A well-known minimal 1×1 transparent PNG, self-contained — no disk or
    /// network access needed to resolve it.
    private static let tinyPNGDataURI =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="

    private func attachmentCount(in text: NSAttributedString) -> Int {
        var count = 0
        text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length)) { value, _, _ in
            if value != nil { count += 1 }
        }
        return count
    }

    @Test("markdown without images renders exactly as the sync overload does")
    func noImagesMatchesSync() async {
        let store = ImageFolderAccessStore(defaults: UserDefaults(suiteName: #function)!)
        let markdown = "# Title\n\nSome **bold** text."
        let sync = attributedString(fromMarkdown: markdown, baseFont: base)
        let async_ = await attributedString(
            fromMarkdown: markdown, baseFont: base, documentFolderURL: nil, accessStore: store
        )
        #expect(async_.string == sync.string)
        #expect(attachmentCount(in: async_) == 0)
    }

    @Test("a data: URI image is decoded and spliced in as an attachment, surrounding text intact")
    func dataURIImageBecomesAttachment() async {
        let store = ImageFolderAccessStore(defaults: UserDefaults(suiteName: #function)!)
        let markdown = "before ![pixel](\(Self.tinyPNGDataURI)) after"
        let out = await attributedString(
            fromMarkdown: markdown, baseFont: base, documentFolderURL: nil, accessStore: store
        )
        #expect(out.string.contains("before"))
        #expect(out.string.contains("after"))
        #expect(attachmentCount(in: out) == 1)

        // The attachment's own textual representation *is* U+FFFC (that's how
        // `NSAttributedString(attachment:)` encodes into a string) — so what
        // actually distinguishes "decoded the data: URI" from "fell back to a
        // generic placeholder icon" is the attached image's pixel size, not
        // the presence or absence of that character.
        var attachedImage: UIImage?
        out.enumerateAttribute(.attachment, in: NSRange(location: 0, length: out.length)) { value, _, _ in
            if let attachment = value as? NSTextAttachment { attachedImage = attachment.image }
        }
        #expect(attachedImage?.size == CGSize(width: 1, height: 1))
    }

    @Test("a relative image with no granted folder access still gets a placeholder attachment, not a gap")
    func relativeImageWithoutAccessGetsPlaceholder() async {
        let store = ImageFolderAccessStore(defaults: UserDefaults(suiteName: #function)!)
        let folder = URL(fileURLWithPath: "/tmp/md-viewer-tests-\(UUID().uuidString)/")
        let markdown = "before ![](chat-medien/foto.jpg) after"
        let out = await attributedString(
            fromMarkdown: markdown, baseFont: base, documentFolderURL: folder, accessStore: store
        )
        #expect(out.string.contains("before"))
        #expect(out.string.contains("after"))
        #expect(attachmentCount(in: out) == 1)
    }

    @Test("multiple images each get their own attachment, in order")
    func multipleImagesEachGetAnAttachment() async {
        let store = ImageFolderAccessStore(defaults: UserDefaults(suiteName: #function)!)
        let markdown = "![one](\(Self.tinyPNGDataURI)) and ![two](\(Self.tinyPNGDataURI))"
        let out = await attributedString(
            fromMarkdown: markdown, baseFont: base, documentFolderURL: nil, accessStore: store
        )
        #expect(attachmentCount(in: out) == 2)
        #expect(out.string.contains("and"))
    }
}
