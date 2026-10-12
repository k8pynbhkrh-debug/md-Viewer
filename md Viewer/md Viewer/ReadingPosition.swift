import CoreGraphics
import Foundation

// Keeping the reader's place when the view changes (T-2026-345).
//
// The four views of a document show *different text* at *different heights*:
// the rendered Markdown, the plain-text "Select Text" view, the Mac's
// selectable preview and the raw Markdown in the editor. A pixel offset means
// nothing across them, so the place is remembered as a **text passage**:
// every view reduces what it shows to its letters and digits (`TextSkeleton`
// — Markdown syntax, whitespace and punctuation drop out, so the same prose
// reads the same in all four), and a `ReadingPosition` names a spot in that
// skeleton. This file is the pure part; the views are wired up in
// `ReadingPositionViews.swift`.

/// A spot in a document, independent of how the document is displayed.
///
/// - Invariant: `0 ≤ fraction ≤ 1`.
struct ReadingPosition: Equatable {
    enum Edge: Equatable {
        /// The very beginning — stays the beginning in every view.
        case start
        /// The very end — stays the end in every view.
        case end
    }

    /// Set when the view was scrolled all the way to one end.
    var edge: Edge?
    /// How far into the text's letters and digits the spot is.
    var fraction: Double
    /// The letters and digits that follow the spot (at most `snippetLength`).
    var snippet: [Unicode.Scalar]

    static let snippetLength = 32

    static let start = ReadingPosition(edge: .start, fraction: 0, snippet: [])
    static let end = ReadingPosition(edge: .end, fraction: 1, snippet: [])
}

/// The letters and digits of a text, each with its UTF-16 offset in that text.
///
/// - Invariant: `scalars.count == offsets.count`, `offsets` strictly ascending,
///   every offset `< utf16Length`.
struct TextSkeleton {
    private(set) var scalars: [Unicode.Scalar] = []
    private(set) var offsets: [Int] = []
    /// UTF-16 length of the text the skeleton was built from.
    private(set) var utf16Length = 0

    var count: Int { scalars.count }

    init(_ text: String) {
        scalars.reserveCapacity(text.utf8.count / 2)
        offsets.reserveCapacity(text.utf8.count / 2)
        var offset = 0
        for scalar in text.unicodeScalars {
            if Self.isSignificant(scalar) {
                scalars.append(scalar)
                offsets.append(offset)
            }
            offset += UTF16.width(scalar)
        }
        utf16Length = offset
    }

    static func isSignificant(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.isASCII {
            let v = scalar.value
            return (v >= 48 && v <= 57) || (v >= 65 && v <= 90) || (v >= 97 && v <= 122)
        }
        return scalar.properties.isAlphabetic || scalar.properties.numericType != nil
    }

    /// The first skeleton index whose character sits at or after `utf16Offset`
    /// (`count` if there is none).
    ///
    /// - Postcondition: `0 ≤ result ≤ count`.
    func index(atOrAfterUTF16Offset utf16Offset: Int) -> Int {
        var low = 0
        var high = offsets.count
        while low < high {
            let mid = (low + high) / 2
            if offsets[mid] < utf16Offset { low = mid + 1 } else { high = mid }
        }
        return low
    }

    /// The UTF-16 offset of skeleton index `index`; `utf16Length` for `count`.
    ///
    /// - Precondition: `0 ≤ index ≤ count`.
    func utf16Offset(atIndex index: Int) -> Int {
        precondition(index >= 0 && index <= count, "skeleton index out of range")
        return index < count ? offsets[index] : utf16Length
    }

    /// The position that names skeleton index `index`.
    ///
    /// - Precondition: `0 ≤ index ≤ count`.
    /// - Postcondition: `self.index(of: result) == index` whenever at least
    ///   `ReadingPosition.minimumMatchLength` characters follow `index`
    ///   (round trip in the same text); otherwise within rounding of it.
    func position(atIndex index: Int) -> ReadingPosition {
        precondition(index >= 0 && index <= count, "skeleton index out of range")
        guard count > 0 else { return .start }
        let end = min(count, index + ReadingPosition.snippetLength)
        return ReadingPosition(
            edge: nil,
            fraction: Double(index) / Double(count),
            snippet: Array(scalars[index..<end])
        )
    }

    /// Finds `position` in this text: the occurrence of its snippet nearest to
    /// where its `fraction` points; without a usable match, the `fraction`
    /// alone.
    ///
    /// The snippet may come from a *different rendering* of the document, so
    /// it is also tried shortened and with its first characters dropped (a
    /// list number or link target that exists in one rendering only). A match
    /// far from the expected spot is ignored — a repeated phrase elsewhere in
    /// the document must not win over the proportional guess.
    ///
    /// - Postcondition: `0 ≤ result ≤ count`; `.start` ⟹ `0`, `.end` ⟹ `count`.
    func index(of position: ReadingPosition) -> Int {
        switch position.edge {
        case .start: return 0
        case .end: return count
        case nil: break
        }
        guard count > 0 else { return 0 }
        let fraction = min(1, max(0, position.fraction))
        let expected = min(count, Int((fraction * Double(count)).rounded()))
        let snippet = position.snippet
        let minimum = ReadingPosition.minimumMatchLength
        guard snippet.count >= minimum else { return expected }

        let window = max(2_000, count / 10)
        var candidates: [ArraySlice<Unicode.Scalar>] = [snippet[...]]
        if snippet.count > 12 { candidates.append(snippet.prefix(12)) }
        for dropped in 1...3 where snippet.count - dropped >= minimum {
            candidates.append(snippet.dropFirst(dropped).prefix(12))
        }
        for candidate in candidates {
            if let match = nearestOccurrence(of: candidate, to: expected, within: window) {
                return match
            }
        }
        return expected
    }

    /// The start of the occurrence of `needle` closest to `expected`, looking
    /// no further than `window` characters away.
    private func nearestOccurrence(of needle: ArraySlice<Unicode.Scalar>,
                                   to expected: Int,
                                   within window: Int) -> Int? {
        guard let first = needle.first, needle.count <= count else { return nil }
        let lastStart = count - needle.count
        let low = max(0, expected - window)
        let high = min(lastStart, expected + window)
        guard low <= high else { return nil }
        var best: Int?
        var bestDistance = Int.max
        var start = low
        while start <= high {
            defer { start += 1 }
            guard scalars[start] == first else { continue }
            let distance = abs(start - expected)
            // Past the expected spot the distance only grows.
            if distance >= bestDistance, start > expected { break }
            guard distance < bestDistance else { continue }
            if scalars[start..<(start + needle.count)].elementsEqual(needle) {
                best = start
                bestDistance = distance
            }
        }
        return best
    }
}

extension ReadingPosition {
    /// Shorter snippets (the last few characters of a document) are too
    /// ambiguous to search for; the `fraction` decides alone.
    static let minimumMatchLength = 6
}

// MARK: - Rendered preview

/// One block of the rendered Markdown preview (paragraph, heading, code block,
/// table) as laid out on screen: its text and its vertical extent in the
/// scroll content.
struct RenderedBlock: Equatable {
    var text: String
    var minY: CGFloat
    var height: CGFloat
}

/// Translates between a vertical offset in the rendered preview and a
/// `ReadingPosition`, treating the blocks' texts — top to bottom — as one
/// text and interpolating linearly inside a block.
///
/// - Invariant: blocks are ordered by `minY`; `starts[i]` is the skeleton
///   index at which block `i` begins.
struct RenderedBlockMap {
    private let blocks: [RenderedBlock]
    private let starts: [Int]
    private let counts: [Int]
    private let skeleton: TextSkeleton

    init(blocks unsorted: [RenderedBlock]) {
        let blocks = unsorted
            .filter { $0.height > 0 }
            .sorted { $0.minY < $1.minY }
        var starts: [Int] = []
        var counts: [Int] = []
        var joined = ""
        var total = 0
        for block in blocks {
            let count = block.text.unicodeScalars.reduce(into: 0) { sum, scalar in
                if TextSkeleton.isSignificant(scalar) { sum += 1 }
            }
            starts.append(total)
            counts.append(count)
            total += count
            joined += block.text
            joined += "\n"
        }
        self.blocks = blocks
        self.starts = starts
        self.counts = counts
        self.skeleton = TextSkeleton(joined)
        assert(skeleton.count == total)
    }

    var isEmpty: Bool { skeleton.count == 0 }

    /// The position shown at vertical content offset `y`.
    ///
    /// - Postcondition: `y(for: result)` is within one line of `y` when `y`
    ///   lies inside a text block; above the first block ⟹ its start, below
    ///   the last ⟹ `.end`.
    func position(atY y: CGFloat) -> ReadingPosition {
        guard !isEmpty else { return .start }
        guard let i = blocks.firstIndex(where: { $0.minY + $0.height > y }) else {
            return .end
        }
        // Skip blocks without text (they cannot be named) to the next one.
        var blockIndex = i
        var t = min(1, max(0, (y - blocks[i].minY) / blocks[i].height))
        while counts[blockIndex] == 0 {
            blockIndex += 1
            t = 0
            if blockIndex == blocks.count { return .end }
        }
        let within = min(counts[blockIndex] - 1, Int(t * CGFloat(counts[blockIndex])))
        return skeleton.position(atIndex: starts[blockIndex] + max(0, within))
    }

    /// The vertical content offset at which `position` is shown, or `nil`
    /// when there is no text to place it in.
    func y(for position: ReadingPosition) -> CGFloat? {
        guard !isEmpty, let last = blocks.last else { return nil }
        switch position.edge {
        case .start: return 0
        case .end: return last.minY + last.height
        case nil: break
        }
        let index = skeleton.index(of: position)
        guard index < skeleton.count else { return last.minY + last.height }
        // The last text block starting at or before `index`.
        var low = 0
        var high = starts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if starts[mid] <= index { low = mid } else { high = mid - 1 }
        }
        var blockIndex = low
        while blockIndex > 0, counts[blockIndex] == 0 { blockIndex -= 1 }
        guard counts[blockIndex] > 0 else { return blocks[blockIndex].minY }
        let t = CGFloat(index - starts[blockIndex]) / CGFloat(counts[blockIndex])
        return blocks[blockIndex].minY + min(1, max(0, t)) * blocks[blockIndex].height
    }
}

// MARK: - What a session remembers

/// The place a document was last seen at, as captured by the view that showed
/// it.
struct ReadingAnchor: Equatable {
    enum ViewKind: Equatable {
        case preview, selectableText, attributedText, editor
    }

    /// The passage at the top of the screen.
    var position: ReadingPosition
    /// The view that captured it. Returning to the *same* kind of view (tab
    /// switch) restores `contentOffsetY` exactly instead of re-deriving it.
    var view: ViewKind
    var contentOffsetY: CGFloat
    /// Size of what the view showed (UTF-16 length of its text; for the
    /// rendered preview its content height) — the exact offset is only reused
    /// while it still matches.
    var textLength: Int
    /// Editor only: the caret / selection, restored with a tab switch.
    var selection: NSRange?
}
