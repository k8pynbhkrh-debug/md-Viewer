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
