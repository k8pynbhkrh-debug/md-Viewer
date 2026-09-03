import SwiftUI
import UniformTypeIdentifiers

// Types for the "new document from text" path (v1.2). `DocumentError` and the
// file read/write helpers live in Shared/MarkdownDocument.swift.

/// The Markdown UTI declared in the app's Info.plist; falls back to plain text
/// if it cannot be resolved at runtime.
nonisolated let markdownUTType: UTType = UTType("net.daringfireball.markdown") ?? .plainText

/// What `DocumentView` was opened with: an existing file on disk, or a new
/// draft that has no backing file yet.
enum DocumentSource: Identifiable {
    case existing(URL)
    /// `initialText == ""` means an empty new document.
    case draft(initialText: String)

    var id: String {
        switch self {
        case .existing(let url): url.absoluteString
        case .draft: "draft"
        }
    }
}

/// A plain UTF-8 text file, used by `DocumentView`'s `.fileExporter` to write a
/// brand-new `.md` file to a location the user picks.
///
/// ## Contract
///
/// - `init(text:)` stores the text verbatim; `data` is exactly `Data(text.utf8)`.
/// - `init(data:)` throws `DocumentError.invalidEncoding` for non-UTF-8 input;
///   otherwise `text` equals the decoded bytes.
/// - `fileWrapper(configuration:)` postcondition: the returned wrapper is a
///   regular-file wrapper whose contents are exactly `data`.
nonisolated struct MarkdownFileDocument: FileDocument {
    static let readableContentTypes: [UTType] = [markdownUTType, .plainText]
    static let writableContentTypes: [UTType] = [markdownUTType]

    var text: String

    init(text: String) {
        self.text = text
    }

    /// Decodes UTF-8 file bytes. The testable seam behind `init(configuration:)`.
    init(data: Data) throws {
        guard let string = String(data: data, encoding: .utf8) else {
            throw DocumentError.invalidEncoding
        }
        text = string
    }

    /// The bytes this document writes. The testable seam behind `fileWrapper`.
    var data: Data { Data(text.utf8) }

    init(configuration: ReadConfiguration) throws {
        guard let raw = configuration.file.regularFileContents else {
            throw DocumentError.invalidEncoding
        }
        try self.init(data: raw)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let wrapper = FileWrapper(regularFileWithContents: data)
        assert(wrapper.regularFileContents == data,
               "MarkdownFileDocument.fileWrapper postcondition violated")
        return wrapper
    }
}

/// A filesystem-safe default name for saving `text` as a new file.
///
/// Uses the first Markdown ATX heading (`# …`) if it yields a usable name,
/// otherwise `"Dokument"`. The exporter appends the `.md` extension.
///
/// - Postcondition: the result is non-empty, trimmed, at most 60 characters,
///   and contains no path separators, colons or control characters.
nonisolated func suggestedFilename(from text: String) -> String {
    let fallback = "Dokument"

    let heading = text
        .split(separator: "\n", omittingEmptySubsequences: false)
        .lazy
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .first { $0.hasPrefix("#") }?
        .drop { $0 == "#" }
        .trimmingCharacters(in: .whitespaces) ?? ""

    let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.controlCharacters)
    let cleaned = String(String.UnicodeScalarView(heading.unicodeScalars.filter { !forbidden.contains($0) }))
        .trimmingCharacters(in: .whitespacesAndNewlines)

    let name = cleaned.isEmpty ? fallback : cleaned
    let result = String(name.prefix(60)).trimmingCharacters(in: .whitespacesAndNewlines)

    let safe = result.isEmpty ? fallback : result
    assert(!safe.isEmpty && !safe.contains("/") && !safe.contains(":"),
           "suggestedFilename postcondition violated: \(safe)")
    return safe
}
