import SwiftUI
import MarkdownUI

/// The maximum file size the app will attempt to open (5 MB).
private let maxFileSize: UInt64 = 5 * 1024 * 1024

/// Errors that can occur when loading a Markdown file.
enum DocumentError: LocalizedError {
    case notReadable
    case tooLarge(UInt64)
    case invalidEncoding
    case empty

    var errorDescription: String? {
        switch self {
        case .notReadable:
            "Die Datei konnte nicht gelesen werden."
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
private func loadMarkdown(from url: URL) -> Result<String, DocumentError> {
    let isSecurityScoped = url.startAccessingSecurityScopedResource()
    defer {
        if isSecurityScoped {
            url.stopAccessingSecurityScopedResource()
        }
    }

    // Check file attributes
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
          let fileSize = attributes[.size] as? UInt64 else {
        return .failure(.notReadable)
    }

    // Check file size
    if fileSize > maxFileSize {
        return .failure(.tooLarge(fileSize))
    }

    // Check for empty file
    if fileSize == 0 {
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

struct DocumentView: View {
    let fileURL: URL

    @Environment(\.dismiss) private var dismiss
    @State private var content: Result<String, DocumentError>?

    var body: some View {
        NavigationStack {
            Group {
                switch content {
                case .none:
                    ProgressView("Laden …")
                case .success(let markdown):
                    ScrollView {
                        Markdown(markdown)
                            .padding()
                    }
                case .failure(let error):
                    ContentUnavailableView {
                        Label("Fehler", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error.localizedDescription)
                    }
                }
            }
            .navigationTitle(fileURL.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            content = loadMarkdown(from: fileURL)
        }
    }
}
