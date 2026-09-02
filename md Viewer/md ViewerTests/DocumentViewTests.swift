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
}
