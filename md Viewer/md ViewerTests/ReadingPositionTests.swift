import Testing
import Foundation
import CoreGraphics
@testable import md_Viewer

// Contract of "keep my place when the view changes" (T-2026-345):
// `TextSkeleton`, `ReadingPosition`, `RenderedBlockMap` and the session's
// position source.

private let markdown = """
# Projektplan

Dies ist der **erste** Absatz mit einem [Link](https://example.com/pfad).

## Zweiter Abschnitt

1. Erster Punkt der Liste
2. Zweiter Punkt der Liste

```swift
let antwort = 42
```

Der letzte Absatz schliesst das Dokument mit einigen Worten ab.
"""

@Suite("TextSkeleton")
struct TextSkeletonTests {

    // Invariant — only letters and digits, offsets ascending and in range.
    @Test("keeps letters and digits with their UTF-16 offsets")
    func skeletonContents() {
        let skeleton = TextSkeleton("# Ä b!\n1. 😀c")
        #expect(String(String.UnicodeScalarView(skeleton.scalars)) == "Äb1c")
        #expect(skeleton.offsets == [2, 4, 7, 12])
        #expect(skeleton.utf16Length == 13)
        #expect(zip(skeleton.offsets, skeleton.offsets.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test("an empty or symbol-only text has an empty skeleton")
    func emptySkeleton() {
        #expect(TextSkeleton("").count == 0)
        #expect(TextSkeleton("--- *** \n").count == 0)
        #expect(TextSkeleton("").index(of: .end) == 0)
        #expect(TextSkeleton("***").position(atIndex: 0) == .start)
    }

    // Postcondition of index(atOrAfterUTF16Offset:) — 0 … count.
    @Test("maps a UTF-16 offset to the next letter")
    func indexAtOffset() {
        let skeleton = TextSkeleton("ab  cd")
        #expect(skeleton.index(atOrAfterUTF16Offset: 0) == 0)
        #expect(skeleton.index(atOrAfterUTF16Offset: 2) == 2)
        #expect(skeleton.index(atOrAfterUTF16Offset: 5) == 3)
        #expect(skeleton.index(atOrAfterUTF16Offset: 99) == 4)
        #expect(skeleton.utf16Offset(atIndex: 4) == 6)
    }

    // Postcondition of position(atIndex:) — round trip in the same text.
    @Test("a position resolves to the index it was taken at")
    func roundTrip() {
        let skeleton = TextSkeleton(markdown)
        for index in stride(from: 0, to: skeleton.count - ReadingPosition.minimumMatchLength, by: 7) {
            #expect(skeleton.index(of: skeleton.position(atIndex: index)) == index)
        }
    }

    // Postcondition — start stays start, end stays end, in any text.
    @Test("the edges map to the edges")
    func edges() {
        let skeleton = TextSkeleton(markdown)
        #expect(skeleton.index(of: .start) == 0)
        #expect(skeleton.index(of: .end) == skeleton.count)
    }

    // The point of the skeleton: the same passage is found in a different
    // rendering of the document (Markdown source ↔ plain text).
    @Test("a passage from the Markdown source is found in the plain text and back")
    func acrossRenderings() throws {
        let plain = plainText(fromMarkdown: markdown)
        let source = TextSkeleton(markdown)
        let rendered = TextSkeleton(plain)

        let sourceOffset = try #require((markdown as NSString).range(of: "Zweiter Punkt").location as Int?)
        let position = source.position(atIndex: source.index(atOrAfterUTF16Offset: sourceOffset))
        let found = rendered.utf16Offset(atIndex: rendered.index(of: position))
        #expect((plain as NSString).substring(from: found).hasPrefix("Zweiter Punkt"))

        let plainOffset = (plain as NSString).range(of: "Der letzte Absatz").location
        let back = rendered.position(atIndex: rendered.index(atOrAfterUTF16Offset: plainOffset))
        let inSource = source.utf16Offset(atIndex: source.index(of: back))
        #expect((markdown as NSString).substring(from: inSource).hasPrefix("Der letzte Absatz"))
    }

    // A list number that only one rendering has must not defeat the match.
    @Test("leading characters missing in the other rendering are tolerated")
    func droppedPrefix() {
        let source = TextSkeleton("Einleitung hier.\n\n7. Wichtiger Punkt im Text")
        let other = TextSkeleton("Einleitung hier.\n\nWichtiger Punkt im Text")
        let position = source.position(atIndex: source.index(atOrAfterUTF16Offset: 18))
        let found = other.utf16Offset(atIndex: other.index(of: position))
        #expect(found == 18)
    }

    // A repeated phrase: the occurrence near the expected spot wins.
    @Test("of several occurrences the one nearest the expected spot is taken")
    func nearestOccurrence() {
        let line = "Wiederholte Zeile mit gleichem Inhalt\n"
        let text = String(repeating: line, count: 50)
        let skeleton = TextSkeleton(text)
        let perLine = skeleton.count / 50
        let index = perLine * 30
        #expect(skeleton.index(of: skeleton.position(atIndex: index)) == index)
    }

    // Without a usable snippet the proportion decides.
    @Test("an unknown snippet falls back to the fraction")
    func fractionFallback() {
        let skeleton = TextSkeleton(String(repeating: "abcdefghij", count: 10))
        let position = ReadingPosition(edge: nil, fraction: 0.5,
                                       snippet: Array("zzzzzzzzzzzz".unicodeScalars))
        #expect(skeleton.index(of: position) == 50)
        let short = ReadingPosition(edge: nil, fraction: 0.25, snippet: Array("ab".unicodeScalars))
        #expect(skeleton.index(of: short) == 25)
    }

    // Invariant — out-of-range fractions are clamped, never trap.
    @Test("a fraction outside 0…1 is clamped")
    func clampedFraction() {
        let skeleton = TextSkeleton("abcdefghij")
        #expect(skeleton.index(of: ReadingPosition(edge: nil, fraction: 7, snippet: [])) == 10)
        #expect(skeleton.index(of: ReadingPosition(edge: nil, fraction: -1, snippet: [])) == 0)
    }
}

@Suite("RenderedBlockMap")
struct RenderedBlockMapTests {

    private let blocks = [
        RenderedBlock(text: "Projektplan", minY: 16, height: 40),
        RenderedBlock(text: "Dies ist der erste Absatz mit einem Link.", minY: 72, height: 60),
        RenderedBlock(text: "---", minY: 140, height: 10),
        RenderedBlock(text: "Der letzte Absatz schliesst das Dokument mit einigen Worten ab.", minY: 160, height: 90),
    ]

    @Test("an offset inside a block names that block's text")
    func positionInBlock() {
        let map = RenderedBlockMap(blocks: blocks)
        let position = map.position(atY: 72)
        #expect(String(String.UnicodeScalarView(position.snippet)).hasPrefix("Diesistdererste"))
    }

    // Postcondition — y → position → y lands within the block, close to y.
    @Test("round trip stays within a line")
    func roundTrip() throws {
        let map = RenderedBlockMap(blocks: blocks)
        for y in [CGFloat(16), 80, 100, 170, 200, 230] {
            let back = try #require(map.y(for: map.position(atY: y)))
            #expect(abs(back - y) <= 12, "y \(y) came back as \(back)")
        }
    }

    @Test("a block without text hands over to the next text block")
    func textlessBlock() throws {
        let map = RenderedBlockMap(blocks: blocks)
        let y = try #require(map.y(for: map.position(atY: 142)))
        #expect(y == 160)
    }

    @Test("below the last block is the end; the edges map to the extent")
    func edges() {
        let map = RenderedBlockMap(blocks: blocks)
        #expect(map.position(atY: 400) == .end)
        #expect(map.y(for: .start) == 0)
        #expect(map.y(for: .end) == 250)
    }

    @Test("blocks reported out of order are sorted; no text means no mapping")
    func orderAndEmpty() {
        let shuffled = RenderedBlockMap(blocks: blocks.reversed())
        #expect(shuffled.position(atY: 72) == RenderedBlockMap(blocks: blocks).position(atY: 72))
        let empty = RenderedBlockMap(blocks: [RenderedBlock(text: "***", minY: 0, height: 10)])
        #expect(empty.isEmpty)
        #expect(empty.y(for: .end) == nil)
        #expect(empty.position(atY: 5) == .start)
    }

    // The passage found in the editor's Markdown is found in the preview.
    @Test("a position from the Markdown source maps into the rendered blocks")
    func fromSource() throws {
        let source = "# Projektplan\n\nDies ist der **erste** Absatz mit einem [Link](https://example.com).\n\n---\n\nDer letzte Absatz schliesst das Dokument mit einigen Worten ab."
        let skeleton = TextSkeleton(source)
        let offset = (source as NSString).range(of: "Der letzte").location
        let position = skeleton.position(atIndex: skeleton.index(atOrAfterUTF16Offset: offset))
        let y = try #require(RenderedBlockMap(blocks: blocks).y(for: position))
        #expect(y == 160)
    }
}

@Suite("DocumentSession reading position")
@MainActor
struct DocumentSessionReadingPositionTests {

    private final class Owner {}

    private func anchor(_ fraction: Double) -> ReadingAnchor {
        ReadingAnchor(position: ReadingPosition(edge: nil, fraction: fraction, snippet: []),
                      view: .editor, contentOffsetY: 120, textLength: 10, selection: nil)
    }

    // Postcondition of captureReadingPosition — anchor taken, source gone.
    @Test("capturing asks the source once and disconnects it")
    func captureOnce() {
        let session = DocumentSession(source: .draft(initialText: "Text"))
        let owner = Owner()
        var asked = 0
        session.registerPositionSource(owner: owner) { asked += 1; return self.anchor(0.4) }
        session.captureReadingPosition()
        session.captureReadingPosition()
        #expect(asked == 1)
        #expect(session.readingAnchor == anchor(0.4))
    }

    // A view that cannot tell yet must not erase the remembered place.
    @Test("a source without an answer leaves the anchor unchanged")
    func nilKeepsAnchor() {
        let session = DocumentSession(source: .draft(initialText: "Text"))
        let first = Owner(), second = Owner()
        session.registerPositionSource(owner: first) { self.anchor(0.4) }
        session.captureReadingPosition()
        session.registerPositionSource(owner: second) { () -> ReadingAnchor? in nil }
        session.captureReadingPosition()
        #expect(session.readingAnchor == anchor(0.4))
    }

    // Postcondition of unregisterPositionSource — only the current source.
    @Test("a view that is no longer the source is not asked when it goes away")
    func staleOwner() {
        let session = DocumentSession(source: .draft(initialText: "Text"))
        let old = Owner(), new = Owner()
        session.registerPositionSource(owner: old) { self.anchor(0.1) }
        session.registerPositionSource(owner: new) { self.anchor(0.9) }
        session.unregisterPositionSource(owner: old)
        #expect(session.readingAnchor == nil)
        session.unregisterPositionSource(owner: new)
        #expect(session.readingAnchor == anchor(0.9))
    }

    // Leaving the editor captures while the working copy is still there.
    @Test("discarding captures before the working copy is cleared")
    func discardCapturesFirst() {
        let session = DocumentSession(source: .draft(initialText: "Arbeitskopie"))
        let owner = Owner()
        var seenText = ""
        session.registerPositionSource(owner: owner) {
            seenText = session.editedText
            return self.anchor(0.5)
        }
        session.discardEditing()
        #expect(seenText == "Arbeitskopie")
        #expect(session.readingAnchor == anchor(0.5))
    }

    // Invariant — remembering the place changes neither text nor undo.
    @Test("capturing changes neither text nor undo history")
    func capturingIsReadOnly() {
        let session = DocumentSession(source: .draft(initialText: "Start"))
        session.editedText = "Start und mehr"
        let couldUndo = session.canUndo
        session.registerPositionSource(owner: Owner()) { self.anchor(0.3) }
        session.captureReadingPosition()
        #expect(session.editedText == "Start und mehr")
        #expect(session.canUndo == couldUndo)
        #expect(session.hasUnsavedChanges)
    }

    @Test("switching to the text selection view captures the place")
    func selectingTextCaptures() {
        let session = DocumentSession(source: .draft(initialText: "Text"))
        session.registerPositionSource(owner: Owner()) { self.anchor(0.7) }
        session.isSelectingText = true
        #expect(session.readingAnchor == anchor(0.7))
    }
}
