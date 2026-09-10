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
}
