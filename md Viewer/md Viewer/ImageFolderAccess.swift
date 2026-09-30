import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// One folder the user has granted access to, as shown in "Folder Access"
/// — only the folder's own name, never its full path.
struct GrantedFolder: Identifiable, Equatable {
    let id: UUID
    let displayName: String
}

/// A persisted security-scoped bookmark to a folder the user has granted
/// md Viewer read access to, so relative image paths inside a `.md` file in
/// that folder (or a descendant of it) can be resolved.
///
/// Opening a single file via the Files picker only grants the sandbox access
/// to that file, not its siblings (`DocumentView.swift` handles that
/// per-file scope already, in `load()`). Relative images need the
/// *containing folder* on top of that — this is that additional grant.
///
/// Stored: an id, the bookmark data and the folder's last path component
/// (for the "Folder Access" list). Entries written before 1.5 carried the
/// full `displayPath` instead; decoding reduces that to its last component
/// and flags the entry so the store rewrites it without the path.
private struct FolderBookmark: Codable {
    let id: UUID
    let bookmarkData: Data
    let displayName: String
    /// Not persisted — true when decoded from the pre-1.5 format.
    private(set) var needsRewrite = false

    private enum CodingKeys: String, CodingKey { case id, bookmarkData, displayName }
    private enum LegacyKeys: String, CodingKey { case displayPath }

    init(id: UUID = UUID(), bookmarkData: Data, displayName: String) {
        self.id = id
        self.bookmarkData = bookmarkData
        self.displayName = displayName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bookmarkData = try container.decode(Data.self, forKey: .bookmarkData)
        let storedID = try container.decodeIfPresent(UUID.self, forKey: .id)
        let storedName = try container.decodeIfPresent(String.self, forKey: .displayName)
        id = storedID ?? UUID()
        if let storedName {
            displayName = storedName
        } else {
            let legacyPath = try decoder.container(keyedBy: LegacyKeys.self)
                .decodeIfPresent(String.self, forKey: .displayPath) ?? ""
            displayName = URL(fileURLWithPath: legacyPath).lastPathComponent
        }
        needsRewrite = storedID == nil || storedName == nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(bookmarkData, forKey: .bookmarkData)
        try container.encode(displayName, forKey: .displayName)
    }
}

/// Tracks which folders the user has granted md Viewer access to for
/// resolving relative image paths in Markdown previews, drives the
/// on-demand "grant access" flow and lets the user revoke grants again
/// ("Folder Access"). One app-wide instance is created in `md_ViewerApp`
/// and handed down via the SwiftUI environment (or passed explicitly to
/// `MarkdownAttributedText`), so a revoke takes effect in an open document
/// immediately.
///
/// ## Contract
/// - Invariant: at most one entry per folder (compared by resolved,
///   symlink-free path); `folders` mirrors the persisted entries in order.
/// - `accessibleFolderURL(forFileAt:)`: accepts any URL; a non-file URL
///   always yields `nil`.
/// - Postcondition: returns a folder URL that is `fileURL`'s directory or an
///   ancestor of it, valid to call `startAccessingSecurityScopedResource()`
///   on — or `nil` if no such folder has been granted (or it was revoked).
///   Bookmarks that no longer resolve are dropped as a side effect.
/// - Precondition (`grantAccess(to:)`): `folderURL` is a file URL that is
///   currently security-scope-accessible (freshly returned by a
///   `UIDocumentPickerViewController` folder pick).
/// - Postcondition: exactly one bookmark for `folderURL` is persisted (an
///   existing one for the same folder is replaced, keeping its id),
///   `accessibleFolderURL(forFileAt:)` subsequently resolves it (and any
///   descendant file) to it, and `revision` has changed — views doing
///   `.task(id: revision)` reload and pick up the newly accessible image.
/// - Postcondition (`removeAccess(id:)` / `removeAll()`): the entry (all
///   entries) is gone from `folders` and from `UserDefaults`,
///   `accessibleFolderURL` no longer resolves to it, and `revision` has
///   changed so visible images fall back to "folder access needed".
///   Removing an unknown id is a no-op (no revision change).
@Observable
final class ImageFolderAccessStore {
    static let defaultsKey = "imageFolderBookmarks"

    private let defaults: UserDefaults
    private var bookmarks: [FolderBookmark]

    /// Bumped on every change to the granted set — views key their
    /// `.task(id:)` on this so image loads are retried after a grant and
    /// dropped after a revoke.
    private(set) var revision = 0

    /// The granted folders, for the "Folder Access" list.
    var folders: [GrantedFolder] {
        bookmarks.map { GrantedFolder(id: $0.id, displayName: $0.displayName) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let loaded = Self.loadBookmarks(from: defaults)
        self.bookmarks = loaded
        if loaded.contains(where: \.needsRewrite) { persist() }
    }

    private static func loadBookmarks(from defaults: UserDefaults) -> [FolderBookmark] {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([FolderBookmark].self, from: data) else {
            return []
        }
        return decoded
    }

    private func persist() {
        if bookmarks.isEmpty {
            defaults.removeObject(forKey: Self.defaultsKey)
            return
        }
        guard let data = try? JSONEncoder().encode(bookmarks) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    private static func canonicalPath(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardized.path
    }

    private static func resolve(_ bookmark: FolderBookmark) -> (url: URL, isStale: Bool)? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark.bookmarkData,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        return (url, isStale)
    }

    private static func resolvedPath(of bookmark: FolderBookmark) -> String? {
        resolve(bookmark).map { canonicalPath($0.url) }
    }

    /// Resolves a folder — `fileURL`'s directory or an ancestor of it — that
    /// the user has already granted access to, if any. Bookmarks that no
    /// longer resolve (folder moved/deleted) are dropped; a stale-but-valid
    /// one is refreshed.
    func accessibleFolderURL(forFileAt fileURL: URL) -> URL? {
        // Callers pass every image URL they see (remote ones included);
        // only file URLs can live in a granted folder.
        guard fileURL.isFileURL else { return nil }
        let target = Self.canonicalPath(fileURL.deletingLastPathComponent())
        var unresolvable: Set<UUID> = []
        var found: URL?
        for (index, bookmark) in bookmarks.enumerated() {
            guard let resolution = Self.resolve(bookmark) else {
                unresolvable.insert(bookmark.id)
                continue
            }
            let resolved = resolution.url
            let folderPath = Self.canonicalPath(resolved)
            if target == folderPath || target.hasPrefix(folderPath + "/") {
                if resolution.isStale, let refreshed = try? resolved.bookmarkData() {
                    bookmarks[index] = FolderBookmark(
                        id: bookmark.id, bookmarkData: refreshed, displayName: resolved.lastPathComponent
                    )
                    persist()
                }
                found = resolved
                break
            }
        }
        if !unresolvable.isEmpty {
            bookmarks.removeAll { unresolvable.contains($0.id) }
            persist()
        }
        return found
    }

    /// Drops every bookmark that no longer resolves (folder deleted or
    /// moved out of reach). Called when "Folder Access" opens so the list
    /// only shows folders that still exist.
    func removeUnresolvableBookmarks() {
        let before = bookmarks.count
        bookmarks.removeAll { Self.resolve($0) == nil }
        if bookmarks.count != before {
            persist()
            revision += 1
        }
    }

    /// Grants access to `folderURL` (from a folder picker) and remembers it
    /// for future launches. Granting the same folder again replaces its
    /// bookmark instead of adding a duplicate.
    func grantAccess(to folderURL: URL) throws {
        precondition(folderURL.isFileURL, "grantAccess(to:) needs a file URL")
        let scoped = folderURL.startAccessingSecurityScopedResource()
        defer { if scoped { folderURL.stopAccessingSecurityScopedResource() } }
        let bookmarkData = try folderURL.bookmarkData()
        let path = Self.canonicalPath(folderURL)
        let name = folderURL.lastPathComponent
        if let index = bookmarks.firstIndex(where: { Self.resolvedPath(of: $0) == path }) {
            bookmarks[index] = FolderBookmark(id: bookmarks[index].id, bookmarkData: bookmarkData, displayName: name)
        } else {
            bookmarks.append(FolderBookmark(bookmarkData: bookmarkData, displayName: name))
        }
        persist()
        revision += 1
        assert(bookmarks.filter { Self.resolvedPath(of: $0) == path }.count == 1)
    }

    /// Revokes one granted folder. Unknown ids are ignored.
    func removeAccess(id: UUID) {
        guard let index = bookmarks.firstIndex(where: { $0.id == id }) else { return }
        bookmarks.remove(at: index)
        persist()
        revision += 1
    }

    /// Revokes every granted folder and deletes the stored bookmarks.
    func removeAll() {
        bookmarks.removeAll()
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
