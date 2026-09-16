import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// A persisted security-scoped bookmark to a folder the user has granted
/// md Viewer read access to, so relative image paths inside a `.md` file in
/// that folder (or a descendant of it) can be resolved.
///
/// Opening a single file via the Files picker only grants the sandbox access
/// to that file, not its siblings (`DocumentView.swift` handles that
/// per-file scope already, in `load()`). Relative images need the
/// *containing folder* on top of that — this is that additional grant.
private struct FolderBookmark: Codable {
    let bookmarkData: Data
    /// Kept only for debugging; resolution always goes through
    /// `bookmarkData`, never this path.
    let displayPath: String
}

/// Tracks which folders the user has granted md Viewer access to for
/// resolving relative image paths in Markdown previews, and drives the
/// on-demand "grant access" flow. One instance is owned by `DocumentView`
/// and shared (via the SwiftUI environment, or passed explicitly to
/// `MarkdownAttributedText`) with everything in the preview that resolves
/// images.
///
/// ## Contract
/// - Precondition (`accessibleFolderURL(forFileAt:)`): `fileURL` is a file
///   URL.
/// - Postcondition: returns a folder URL that is `fileURL`'s directory or an
///   ancestor of it, valid to call `startAccessingSecurityScopedResource()`
///   on — or `nil` if no such folder has been granted yet.
/// - Precondition (`grantAccess(to:)`): `folderURL` is currently
///   security-scope-accessible (freshly returned by a
///   `UIDocumentPickerViewController` folder pick).
/// - Postcondition: a bookmark for `folderURL` is persisted,
///   `accessibleFolderURL(forFileAt:)` subsequently resolves it (and any
///   descendant file) to it, and `revision` has changed — views doing
///   `.task(id: revision)` reload and pick up the newly accessible image.
@Observable
final class ImageFolderAccessStore {
    private static let defaultsKey = "imageFolderBookmarks"

    private let defaults: UserDefaults
    private var bookmarks: [FolderBookmark]

    /// Bumped on every successful `grantAccess(to:)` — views key their
    /// `.task(id:)` on this so a previous `.needsFolderAccess` result is
    /// retried once access is granted.
    private(set) var revision = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.bookmarks = Self.loadBookmarks(from: defaults)
    }

    private static func loadBookmarks(from defaults: UserDefaults) -> [FolderBookmark] {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([FolderBookmark].self, from: data) else {
            return []
        }
        return decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(bookmarks) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    /// Resolves a folder — `fileURL`'s directory or an ancestor of it — that
    /// the user has already granted access to, if any. Bookmarks that no
    /// longer resolve (folder moved/deleted) are dropped; a stale-but-valid
    /// one is refreshed.
    func accessibleFolderURL(forFileAt fileURL: URL) -> URL? {
        let target = fileURL.resolvingSymlinksInPath().deletingLastPathComponent().standardized.path
        var staleIndexes: [Int] = []
        var found: URL?
        for (index, bookmark) in bookmarks.enumerated() {
            var isStale = false
            guard let resolved = try? URL(
                resolvingBookmarkData: bookmark.bookmarkData,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                staleIndexes.append(index)
                continue
            }
            let folderPath = resolved.standardized.path
            if target == folderPath || target.hasPrefix(folderPath + "/") {
                if isStale, let refreshed = try? resolved.bookmarkData() {
                    bookmarks[index] = FolderBookmark(bookmarkData: refreshed, displayPath: resolved.path)
                    persist()
                }
                found = resolved
                break
            }
        }
        if !staleIndexes.isEmpty {
            for index in staleIndexes.reversed() { bookmarks.remove(at: index) }
            persist()
        }
        return found
    }

    /// Grants access to `folderURL` (from a folder picker) and remembers it
    /// for future launches.
    func grantAccess(to folderURL: URL) throws {
        let scoped = folderURL.startAccessingSecurityScopedResource()
        defer { if scoped { folderURL.stopAccessingSecurityScopedResource() } }
        let bookmarkData = try folderURL.bookmarkData()
        bookmarks.append(FolderBookmark(bookmarkData: bookmarkData, displayPath: folderURL.path))
        persist()
        revision += 1
    }
}

/// Presents the system folder picker so the user can grant md Viewer access
/// to a folder that contains relative image paths referenced from the open
/// Markdown document.
struct FolderPicker: UIViewControllerRepresentable {
    /// Where the picker should start browsing — typically the document's own
    /// folder, since granting that is what makes its relative images resolve.
    var directoryURL: URL?
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        controller.directoryURL = directoryURL
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
