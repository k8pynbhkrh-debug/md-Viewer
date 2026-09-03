import Testing
import Foundation
@testable import md_Viewer

@Suite("loadMarkdown")
struct LoadMarkdownTests {

    private func makeTempFile(contents: Data, extension ext: String = "md") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try contents.write(to: url)
        return url
    }

    @Test("returns the file content on success")
    func validMarkdown() throws {
        let markdown = "# Hello\n\nSome **bold** text."
        let url = try makeTempFile(contents: Data(markdown.utf8))
        defer { try? FileManager.default.removeItem(at: url) }

        let result = loadMarkdown(from: url)

        switch result {
        case .success(let content):
            #expect(content == markdown)
        case .failure(let error):
            Issue.record("Expected success, got \(error)")
        }
    }

    @Test("fails with .empty for a zero-byte file")
    func emptyFile() throws {
        let url = try makeTempFile(contents: Data())
        defer { try? FileManager.default.removeItem(at: url) }

        let result = loadMarkdown(from: url)

        guard case .failure(.empty) = result else {
            Issue.record("Expected .failure(.empty), got \(result)")
            return
        }
    }

    @Test("fails with .empty for whitespace-only content")
    func whitespaceOnlyFile() throws {
        let url = try makeTempFile(contents: Data("   \n\t\n  ".utf8))
        defer { try? FileManager.default.removeItem(at: url) }

        let result = loadMarkdown(from: url)

        guard case .failure(.empty) = result else {
            Issue.record("Expected .failure(.empty), got \(result)")
            return
        }
    }

    @Test("fails with .invalidEncoding for non-UTF-8 content")
    func invalidEncoding() throws {
        // 0xFF 0xFE is not valid UTF-8 on its own.
        let url = try makeTempFile(contents: Data([0xFF, 0xFE, 0x00, 0x01]))
        defer { try? FileManager.default.removeItem(at: url) }

        let result = loadMarkdown(from: url)

        guard case .failure(.invalidEncoding) = result else {
            Issue.record("Expected .failure(.invalidEncoding), got \(result)")
            return
        }
    }

    @Test("fails with .notReadable for a missing file")
    func missingFile() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")

        let result = loadMarkdown(from: url)

        guard case .failure(.notReadable) = result else {
            Issue.record("Expected .failure(.notReadable), got \(result)")
            return
        }
    }

    @Test("fails with .tooLarge for a file over the size limit")
    func tooLarge() throws {
        let oversized = Data(repeating: UInt8(ascii: "a"), count: Int(maxFileSize) + 1)
        let url = try makeTempFile(contents: oversized)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = loadMarkdown(from: url)

        guard case .failure(.tooLarge(let size)) = result else {
            Issue.record("Expected .failure(.tooLarge), got \(result)")
            return
        }
        #expect(size == UInt64(oversized.count))
    }

    @Test("succeeds for a file exactly at the size limit")
    func exactlyAtSizeLimit() throws {
        let atLimit = Data(repeating: UInt8(ascii: "a"), count: Int(maxFileSize))
        let url = try makeTempFile(contents: atLimit)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = loadMarkdown(from: url)

        guard case .success = result else {
            Issue.record("Expected .success at exactly maxFileSize, got \(result)")
            return
        }
    }
}

@Suite("saveMarkdown")
struct SaveMarkdownTests {

    private func makeTempFile(contents: Data, extension ext: String = "md") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try contents.write(to: url)
        return url
    }

    @Test("overwrites the file and the new content reads back")
    func roundTrip() throws {
        let url = try makeTempFile(contents: Data("# Alt".utf8))
        defer { try? FileManager.default.removeItem(at: url) }

        let updated = "# Neu\n\nMit **fettem** Text."
        try saveMarkdown(text: updated, to: url)

        let readBack = try String(contentsOf: url, encoding: .utf8)
        #expect(readBack == updated)
    }

    @Test("creates the file if it does not exist yet")
    func createsFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        defer { try? FileManager.default.removeItem(at: url) }

        try saveMarkdown(text: "# Hallo", to: url)

        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(try String(contentsOf: url, encoding: .utf8) == "# Hallo")
    }

    @Test("throws .notWritable for an unwritable location")
    func notWritable() {
        let url = URL(fileURLWithPath: "/this/path/does/not/exist/file.md")

        #expect {
            try saveMarkdown(text: "x", to: url)
        } throws: { error in
            guard case DocumentError.notWritable = error else { return false }
            return true
        }
    }

    // Contract — postcondition on failure: a throwing save leaves the file
    // byte-for-byte as it was.
    @Test("leaves an existing file untouched when the write itself fails")
    func atomicOnWriteFailure() throws {
        let original = "# Wichtig\n\nDarf nicht kaputtgehen."
        let url = try makeTempFile(contents: Data(original.utf8))
        defer {
            try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: url.path)
            try? FileManager.default.removeItem(at: url)
        }

        // Make the file (and its directory entry) unreplaceable.
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: url.path)

        #expect {
            try saveMarkdown(text: "# Ersetzt", to: url)
        } throws: { error in
            guard case DocumentError.notWritable = error else { return false }
            return true
        }
        #expect(try String(contentsOf: url, encoding: .utf8) == original)
    }

    // Contract — postcondition on success: an existing file's metadata is
    // carried over to the replacement rather than reset to defaults.
    @Test("carries over the existing file's POSIX permissions")
    func preservesFileMetadata() throws {
        let url = try makeTempFile(contents: Data("# Alt".utf8))
        defer { try? FileManager.default.removeItem(at: url) }

        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)

        try saveMarkdown(text: "# Neu", to: url)

        let permissions = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        #expect(permissions == 0o600)
    }

    @Test("throws .empty for whitespace-only text and leaves the file untouched")
    func rejectsEmpty() throws {
        let url = try makeTempFile(contents: Data("# Original".utf8))
        defer { try? FileManager.default.removeItem(at: url) }

        #expect {
            try saveMarkdown(text: "   \n\t\n", to: url)
        } throws: { error in
            guard case DocumentError.empty = error else { return false }
            return true
        }
        #expect(try String(contentsOf: url, encoding: .utf8) == "# Original")
    }

    @Test("throws .tooLarge for content over the size limit")
    func rejectsTooLarge() throws {
        let url = try makeTempFile(contents: Data("# Original".utf8))
        defer { try? FileManager.default.removeItem(at: url) }

        let oversized = String(repeating: "a", count: Int(maxFileSize) + 1)
        #expect {
            try saveMarkdown(text: oversized, to: url)
        } throws: { error in
            guard case DocumentError.tooLarge = error else { return false }
            return true
        }
        #expect(try String(contentsOf: url, encoding: .utf8) == "# Original")
    }

    @Test("preserves the file when replacing existing content (round-trips via loadMarkdown)")
    func roundTripsThroughLoad() throws {
        let url = try makeTempFile(contents: Data("# Alt".utf8))
        defer { try? FileManager.default.removeItem(at: url) }

        let updated = "# Neu\n\nGeänderter Inhalt."
        try saveMarkdown(text: updated, to: url)

        guard case .success(let reloaded) = loadMarkdown(from: url) else {
            Issue.record("Expected loadMarkdown to succeed after saveMarkdown")
            return
        }
        #expect(reloaded == updated)
    }
}

@Suite("EditorUndoHistory")
struct EditorUndoHistoryTests {

    /// A clock that advances only when the test says so, so coalescing is
    /// deterministic.
    private func time(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSinceReferenceDate: seconds)
    }

    @Test("empty history has nothing to undo")
    func emptyHistory() {
        var history = EditorUndoHistory()
        #expect(history.canUndo == false)
        #expect(history.undo() == nil)
    }

    // Contract — record then undo restores the recorded snapshot.
    @Test("undo restores the text from before the change")
    func recordThenUndo() {
        var history = EditorUndoHistory()
        history.record(before: "Hallo", at: time(0))
        #expect(history.canUndo)
        #expect(history.undo() == "Hallo")
        #expect(history.canUndo == false)
    }

    // Contract — changes within coalesceInterval collapse into one step.
    @Test("keystrokes within the coalesce interval are one undo step")
    func coalescesRapidTyping() {
        var history = EditorUndoHistory()
        history.record(before: "a", at: time(0))
        history.record(before: "ab", at: time(0.1))
        history.record(before: "abc", at: time(0.2))
        #expect(history.stack == ["a"])
        #expect(history.undo() == "a")
        #expect(history.canUndo == false)
    }

    // Contract — a pause longer than coalesceInterval starts a new step.
    @Test("a pause starts a new undo step")
    func pauseSplitsSteps() {
        var history = EditorUndoHistory()
        history.record(before: "start", at: time(0))
        history.record(before: "start typing burst one", at: time(1.0))
        #expect(history.stack == ["start", "start typing burst one"])
        #expect(history.undo() == "start typing burst one")
        #expect(history.undo() == "start")
        #expect(history.undo() == nil)
    }

    // Contract — the single change caused by undo() itself is not recorded.
    @Test("the change from undo is not itself recorded")
    func undoDoesNotRecordItself() {
        var history = EditorUndoHistory()
        history.record(before: "v1", at: time(0))
        history.record(before: "v2", at: time(1.0))
        #expect(history.undo() == "v2")           // caller now sets editedText = "v2"
        history.record(before: "v3", at: time(2.0)) // the resulting onChange — must be skipped
        #expect(history.stack == ["v1"])
        #expect(history.undo() == "v1")
        #expect(history.undo() == nil)
    }

    // Contract — invariant stack.count <= maxSteps.
    @Test("history is capped at maxSteps, dropping the oldest")
    func capsAtMaxSteps() {
        var history = EditorUndoHistory()
        history.maxSteps = 3
        for i in 0..<10 {
            history.record(before: "step\(i)", at: time(Double(i) * 2))
        }
        #expect(history.stack.count == 3)
        #expect(history.stack == ["step7", "step8", "step9"])
    }

    @Test("reset clears the history")
    func resetClears() {
        var history = EditorUndoHistory()
        history.record(before: "x", at: time(0))
        history.reset()
        #expect(history.canUndo == false)
    }
}

@Suite("MarkdownFileDocument")
struct MarkdownFileDocumentTests {

    // Contract — data is exactly the UTF-8 bytes of text.
    @Test("data is the UTF-8 encoding of the text")
    func dataRoundTrip() {
        #expect(MarkdownFileDocument(text: "# Über\n\nÄäÖöÜü — €").data
                == Data("# Über\n\nÄäÖöÜü — €".utf8))
    }

    @Test("an empty document writes zero bytes")
    func emptyDocument() {
        #expect(MarkdownFileDocument(text: "").data == Data())
    }

    // Contract — init(data:) decodes UTF-8 and text equals the decoded bytes.
    @Test("init(data:) decodes UTF-8 back to the same text")
    func decodesUTF8() throws {
        let text = "# Titel\n\n- eins\n- zwei"
        let doc = try MarkdownFileDocument(data: Data(text.utf8))
        #expect(doc.text == text)
    }

    // Contract — non-UTF-8 input throws .invalidEncoding.
    @Test("init(data:) throws .invalidEncoding for non-UTF-8 bytes")
    func rejectsNonUTF8() {
        #expect {
            _ = try MarkdownFileDocument(data: Data([0xFF, 0xFE, 0x00, 0x01]))
        } throws: { error in
            guard case DocumentError.invalidEncoding = error else { return false }
            return true
        }
    }

    @Test("text -> data -> text is the identity")
    func fullRoundTrip() throws {
        let original = "# Notiz\n\nText mit `code` und **fett**."
        let reloaded = try MarkdownFileDocument(data: MarkdownFileDocument(text: original).data)
        #expect(reloaded.text == original)
    }
}

@Suite("suggestedFilename")
struct SuggestedFilenameTests {

    @Test("uses the first ATX heading")
    func firstHeading() {
        #expect(suggestedFilename(from: "# Besprechung Dienstag\n\nText") == "Besprechung Dienstag")
    }

    @Test("skips non-heading lines before the heading")
    func headingAfterText() {
        #expect(suggestedFilename(from: "\n\nVorwort\n\n## Kapitel eins\n") == "Kapitel eins")
    }

    // Contract — no heading yields the fallback.
    @Test("falls back to \"Dokument\" without a heading")
    func fallback() {
        #expect(suggestedFilename(from: "nur Fließtext, keine Überschrift") == "Dokument")
        #expect(suggestedFilename(from: "") == "Dokument")
        #expect(suggestedFilename(from: "#   \n") == "Dokument")
    }

    // Contract — result contains no path separators or colons.
    @Test("strips path separators and colons")
    func stripsForbiddenCharacters() {
        let name = suggestedFilename(from: "# a/b:c\\d")
        #expect(!name.contains("/"))
        #expect(!name.contains(":"))
        #expect(!name.contains("\\"))
        #expect(name == "abcd")
    }

    // Contract — result is at most 60 characters and non-empty.
    @Test("caps very long headings at 60 characters")
    func capsLength() {
        let long = String(repeating: "wort ", count: 40)
        let name = suggestedFilename(from: "# \(long)")
        #expect(!name.isEmpty)
        #expect(name.count <= 60)
    }

    @Test("handles headings without a space after the hash")
    func noSpaceAfterHash() {
        #expect(suggestedFilename(from: "#Titel") == "Titel")
    }
}
