import Foundation

/// The maximum file size the app will attempt to open (5 MB).
let maxFileSize: UInt64 = 5 * 1024 * 1024

/// Errors that can occur when loading a Markdown file.
///
/// Shared by the app and the Share extension, so it must not assume any
/// actor isolation — `nonisolated` keeps `errorDescription` usable from the
/// extension's background item-loading callbacks even though the app target
/// compiles with `MainActor` default isolation.
enum DocumentError: LocalizedError, Sendable {
    case notReadable
    case notWritable
    case tooLarge(UInt64)
    case invalidEncoding
    case empty

    nonisolated var errorDescription: String? {
        switch self {
        case .notReadable:
            "Die Datei konnte nicht gelesen werden."
        case .notWritable:
            "Die Datei konnte nicht gespeichert werden."
        case .tooLarge(let size):
            "Die Datei ist zu groß (\(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))). Maximal 5 MB werden unterstützt."
        case .invalidEncoding:
            "Die Datei konnte nicht als Text gelesen werden. Nur UTF-8-kodierte Dateien werden unterstützt."
        case .empty:
            "Die Datei ist leer."
        }
    }
}

/// Loads the contents of a Markdown file at the given URL with error handling.
///
/// Handles security-scoped resource access for files opened via "Open With".
nonisolated func loadMarkdown(from url: URL) -> Result<String, DocumentError> {
    let isSecurityScoped = url.startAccessingSecurityScopedResource()
    defer {
        if isSecurityScoped {
            url.stopAccessingSecurityScopedResource()
        }
    }

    // Check file size (using resourceValues to avoid file timestamp APIs)
    guard let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
          let fileSize = resourceValues.fileSize else {
        return .failure(.notReadable)
    }

    let size = UInt64(fileSize)
    if size > maxFileSize {
        return .failure(.tooLarge(size))
    }

    if size == 0 {
        return .failure(.empty)
    }

    // Read file data
    guard let data = try? Data(contentsOf: url) else {
        return .failure(.notReadable)
    }

    // Decode as UTF-8
    guard let content = String(data: data, encoding: .utf8) else {
        return .failure(.invalidEncoding)
    }

    // Check for whitespace-only content
    if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return .failure(.empty)
    }

    return .success(content)
}

/// Saves the given text back to the file at `url`, overwriting its current content.
///
/// Handles security-scoped resource access for files opened via "Open With",
/// mirroring `loadMarkdown(from:)`. The write goes through `NSFileCoordinator`
/// so documents opened in place (iCloud Drive, the Files app) are updated
/// safely alongside other processes that may be observing the file.
nonisolated func saveMarkdown(text: String, to url: URL) throws {
    let isSecurityScoped = url.startAccessingSecurityScopedResource()
    defer {
        if isSecurityScoped {
            url.stopAccessingSecurityScopedResource()
        }
    }

    guard let data = text.data(using: .utf8) else {
        throw DocumentError.invalidEncoding
    }

    var coordinatorError: NSError?
    var writeError: Error?
    NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { writeURL in
        do {
            try data.write(to: writeURL, options: .atomic)
        } catch {
            writeError = error
        }
    }

    if coordinatorError != nil || writeError != nil {
        throw DocumentError.notWritable
    }
}
