import Testing
import Foundation
@testable import md_Viewer

// Contract of the plain-text fallback for large documents (T-2026-328):
// `LargeDocument.exceeds` and `DocumentSession.showsLargeDocumentAsText` /
// `formatLargeDocumentAnyway()` / `requestFind` on a large document.

@Suite("LargeDocument.exceeds")
struct LargeDocumentThresholdTests {

    // Postcondition — exactly at the threshold is still formatted.
    @Test("a document of exactly the threshold is not large")
    func atThreshold() {
        #expect(LargeDocument.exceeds(String(repeating: "a", count: 100), threshold: 100) == false)
    }

    // Postcondition — one byte more is large.
    @Test("one byte above the threshold is large")
    func aboveThreshold() {
        #expect(LargeDocument.exceeds(String(repeating: "a", count: 101), threshold: 100))
    }

    // Postcondition — the size is UTF-8 bytes (what the file weighs), not characters.
    @Test("size is counted in UTF-8 bytes")
    func countsBytes() {
        let umlauts = String(repeating: "ä", count: 60) // 60 characters, 120 bytes
        #expect(LargeDocument.exceeds(umlauts, threshold: 100))
        #expect(LargeDocument.exceeds(umlauts, threshold: 120) == false)
    }

    @Test("an empty text is never large")
    func empty() {
        #expect(LargeDocument.exceeds("", threshold: 1) == false)
    }

    // The extension has the tighter memory budget; both stay below what may be opened at all.
    @Test("share extension ≤ app < maximum file size")
    func thresholdOrder() {
        #expect(LargeDocument.shareExtensionThreshold <= LargeDocument.appThreshold)
        #expect(UInt64(LargeDocument.appThreshold) < maxFileSize)
    }
}

@MainActor
@Suite("DocumentSession large document")
struct DocumentSessionLargeDocumentTests {

    private func loadedFile(bytes: Int) throws -> (DocumentSession, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("large-\(UUID().uuidString).md")
        try Data(repeating: UInt8(ascii: "a"), count: bytes).write(to: url)
        let session = DocumentSession(source: .existing(url))
        session.loadIfNeeded()
        return (session, url)
    }

    private func switchedToSearchableText(_ session: DocumentSession) -> Bool {
        #if targetEnvironment(macCatalyst)
        !session.showFormattedPreview
        #else
        session.isSelectingText
        #endif
    }

    @Test("a document at the threshold is formatted")
    func atThresholdIsFormatted() throws {
        let (session, url) = try loadedFile(bytes: LargeDocument.appThreshold)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(session.isLargeDocument == false)
        #expect(session.showsLargeDocumentAsText == false)
    }

    @Test("a document above the threshold is shown as text")
    func aboveThresholdIsText() throws {
        let (session, url) = try loadedFile(bytes: LargeDocument.appThreshold + 1)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(session.isLargeDocument)
        #expect(session.showsLargeDocumentAsText)
    }

    @Test("the largest file that can be opened is shown as text")
    func maximumSizeIsText() throws {
        let (session, url) = try loadedFile(bytes: Int(maxFileSize))
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(session.showsLargeDocumentAsText)
    }

    @Test("a document that is not loaded is not large")
    func unloadedIsNotLarge() {
        let session = DocumentSession(source: .existing(URL(fileURLWithPath: "/nonexistent.md")))
        #expect(session.isLargeDocument == false)
        #expect(session.showsLargeDocumentAsText == false)
    }

    // Invariant — the fallback only ever replaces the reader, never the editor.
    @Test("the editor is not replaced by the text fallback")
    func editorUnaffected() throws {
        let (session, url) = try loadedFile(bytes: LargeDocument.appThreshold + 1)
        defer { try? FileManager.default.removeItem(at: url) }
        session.beginEditing()
        #expect(session.showsLargeDocumentAsText == false)
        #expect(session.editedText == session.savedText)
        session.discardEditing()
        #expect(session.showsLargeDocumentAsText)
    }

    @Test("a large draft stays in the editor")
    func largeDraft() {
        let session = DocumentSession(source: .draft(initialText: String(repeating: "a", count: LargeDocument.appThreshold + 1)))
        #expect(session.isEditing)
        #expect(session.showsLargeDocumentAsText == false)
    }

    // Postcondition of formatLargeDocumentAnyway — formatted from then on, text untouched.
    @Test("\"show formatted anyway\" switches this document to the rendering")
    func formatAnyway() throws {
        let (session, url) = try loadedFile(bytes: LargeDocument.appThreshold + 1)
        defer { try? FileManager.default.removeItem(at: url) }
        let before = session.savedText
        session.formatLargeDocumentAnyway()
        #expect(session.showsLargeDocumentAsText == false)
        #expect(session.isLargeDocument)
        #expect(session.savedText == before)
        // Stays that way across an editing pass.
        session.beginEditing()
        session.discardEditing()
        #expect(session.showsLargeDocumentAsText == false)
    }

    // Follows the saved text — saving a shortened document formats it again.
    @Test("a document saved below the threshold is formatted again")
    func shrinkingFormatsAgain() async throws {
        let (session, url) = try loadedFile(bytes: LargeDocument.appThreshold + 1)
        defer { try? FileManager.default.removeItem(at: url) }
        session.beginEditing()
        session.editedText = "# Kurz"
        await session.saveInPlace()
        #expect(session.isEditing == false)
        #expect(session.isLargeDocument == false)
        #expect(session.showsLargeDocumentAsText == false)
    }

    // requestFind postcondition — the text fallback is searchable as it is.
    @Test("find in the text fallback does not switch views")
    func findStaysInFallback() throws {
        let (session, url) = try loadedFile(bytes: LargeDocument.appThreshold + 1)
        defer { try? FileManager.default.removeItem(at: url) }
        session.requestFind(replace: true)
        #expect(session.findRequest == .find)
        #expect(session.showsLargeDocumentAsText)
        #expect(switchedToSearchableText(session) == false)
    }

    @Test("find after \"show formatted anyway\" switches to the searchable text view")
    func findAfterFormatAnyway() throws {
        let (session, url) = try loadedFile(bytes: LargeDocument.appThreshold + 1)
        defer { try? FileManager.default.removeItem(at: url) }
        session.formatLargeDocumentAnyway()
        session.requestFind(replace: false)
        #expect(session.findRequest == .find)
        #expect(switchedToSearchableText(session))
    }
}
