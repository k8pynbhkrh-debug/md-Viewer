import Testing
import Foundation
@testable import md_Viewer

/// Exercises `ImageFolderAccessStore`'s contract directly against a real
/// temporary folder — no `UIDocumentPickerViewController` interaction needed
/// for the storage/resolution logic itself (`FolderPicker` is a thin system
/// wrapper, not covered here).
@Suite("ImageFolderAccessStore")
struct ImageFolderAccessStoreTests {
    private func freshStore(_ name: String = #function) -> ImageFolderAccessStore {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return ImageFolderAccessStore(defaults: defaults)
    }

    private func makeTempFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("md-viewer-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    // Contract — no bookmark granted yet, nothing resolves.
    @Test("no bookmarks granted resolves nothing")
    func noBookmarks() throws {
        let store = freshStore()
        let file = try makeTempFolder().appendingPathComponent("foto.jpg")
        #expect(store.accessibleFolderURL(forFileAt: file) == nil)
    }

    // Contract (postcondition) — granting a folder resolves a file directly
    // inside it.
    @Test("granting a folder resolves a file directly inside it")
    func grantsDirectFile() throws {
        let store = freshStore()
        let folder = try makeTempFolder()
        try store.grantAccess(to: folder)
        let file = folder.appendingPathComponent("foto.jpg")
        let resolved = store.accessibleFolderURL(forFileAt: file)
        #expect(resolved?.standardized.path == folder.standardized.path)
    }

    // Contract — "or an ancestor of it": a descendant subfolder also resolves.
    @Test("granting a folder also resolves a file in a descendant subfolder")
    func grantsDescendantSubfolder() throws {
        let store = freshStore()
        let folder = try makeTempFolder()
        try store.grantAccess(to: folder)
        let subfolder = folder.appendingPathComponent("chat-medien", isDirectory: true)
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        let file = subfolder.appendingPathComponent("foto.jpg")
        #expect(store.accessibleFolderURL(forFileAt: file) != nil)
    }

    @Test("a file outside any granted folder resolves to nil")
    func fileOutsideGrantedFolderIsNil() throws {
        let store = freshStore()
        try store.grantAccess(to: try makeTempFolder())
        let elsewhere = try makeTempFolder().appendingPathComponent("foto.jpg")
        #expect(store.accessibleFolderURL(forFileAt: elsewhere) == nil)
    }

    // Contract (postcondition) — `revision` changes so observers reload.
    @Test("granting access bumps revision")
    func grantingBumpsRevision() throws {
        let store = freshStore()
        let before = store.revision
        try store.grantAccess(to: try makeTempFolder())
        #expect(store.revision == before + 1)
    }

    @Test("bookmarks persist across store instances sharing the same defaults")
    func persistsAcrossInstances() throws {
        let suiteName = #function
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let folder = try makeTempFolder()

        let first = ImageFolderAccessStore(defaults: defaults)
        try first.grantAccess(to: folder)

        let second = ImageFolderAccessStore(defaults: defaults)
        let file = folder.appendingPathComponent("foto.jpg")
        #expect(second.accessibleFolderURL(forFileAt: file) != nil)
    }

    // Invariant — at most one entry per folder.
    @Test("granting the same folder twice keeps a single entry")
    func duplicateGrantIsDeduplicated() throws {
        let store = freshStore()
        let folder = try makeTempFolder()
        try store.grantAccess(to: folder)
        let firstID = try #require(store.folders.first?.id)
        try store.grantAccess(to: folder)
        #expect(store.folders.count == 1)
        #expect(store.folders.first?.id == firstID)
    }

    @Test("the list shows only the folder name, not its path")
    func listShowsOnlyFolderName() throws {
        let store = freshStore()
        let folder = try makeTempFolder()
        try store.grantAccess(to: folder)
        #expect(store.folders.map(\.displayName) == [folder.lastPathComponent])
        let stored = try #require(UserDefaults(suiteName: #function)!.data(forKey: ImageFolderAccessStore.defaultsKey))
        let json = try #require(String(data: stored, encoding: .utf8))
        #expect(!json.contains("displayPath"))
    }

    // Postcondition (`removeAccess`) — local image access is gone.
    @Test("removing a folder revokes resolution and persists")
    func removeRevokesAccess() throws {
        let suiteName = #function
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = ImageFolderAccessStore(defaults: defaults)
        let folder = try makeTempFolder()
        let other = try makeTempFolder()
        try store.grantAccess(to: folder)
        try store.grantAccess(to: other)
        let file = folder.appendingPathComponent("foto.jpg")
        let id = try #require(store.folders.first?.id)
        let before = store.revision

        store.removeAccess(id: id)

        #expect(store.accessibleFolderURL(forFileAt: file) == nil)
        #expect(store.folders.count == 1)
        #expect(store.revision == before + 1)
        let reloaded = ImageFolderAccessStore(defaults: defaults)
        #expect(reloaded.accessibleFolderURL(forFileAt: file) == nil)
        #expect(reloaded.accessibleFolderURL(forFileAt: other.appendingPathComponent("a.png")) != nil)
    }

    @Test("removing an unknown id changes nothing")
    func removeUnknownIsNoOp() throws {
        let store = freshStore()
        try store.grantAccess(to: try makeTempFolder())
        let before = store.revision
        store.removeAccess(id: UUID())
        #expect(store.folders.count == 1)
        #expect(store.revision == before)
    }

    // Postcondition (`removeAll`) — nothing resolves, nothing stored.
    @Test("remove all clears every folder and the stored data")
    func removeAllClearsEverything() throws {
        let suiteName = #function
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = ImageFolderAccessStore(defaults: defaults)
        let folder = try makeTempFolder()
        try store.grantAccess(to: folder)
        try store.grantAccess(to: try makeTempFolder())
        let before = store.revision

        store.removeAll()

        #expect(store.folders.isEmpty)
        #expect(store.revision == before + 1)
        #expect(defaults.data(forKey: ImageFolderAccessStore.defaultsKey) == nil)
        #expect(store.accessibleFolderURL(forFileAt: folder.appendingPathComponent("foto.jpg")) == nil)
    }

    // Stale bookmarks (folder deleted) are cleaned up.
    @Test("a bookmark to a deleted folder is dropped")
    func deletedFolderIsDropped() throws {
        let store = freshStore()
        let gone = try makeTempFolder()
        let kept = try makeTempFolder()
        try store.grantAccess(to: gone)
        try store.grantAccess(to: kept)
        try FileManager.default.removeItem(at: gone)

        store.removeUnresolvableBookmarks()

        #expect(store.folders.map(\.displayName) == [kept.lastPathComponent])
    }

    // Migration — pre-1.5 entries stored the full path; they keep working
    // and are rewritten with only the folder name.
    @Test("legacy entries with displayPath are migrated to a folder name")
    func legacyEntriesAreMigrated() throws {
        let suiteName = #function
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let folder = try makeTempFolder()
        let legacy: [[String: Any]] = [[
            "bookmarkData": try folder.bookmarkData().base64EncodedString(),
            "displayPath": folder.path,
        ]]
        defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: ImageFolderAccessStore.defaultsKey)

        let store = ImageFolderAccessStore(defaults: defaults)

        #expect(store.folders.map(\.displayName) == [folder.lastPathComponent])
        #expect(store.accessibleFolderURL(forFileAt: folder.appendingPathComponent("foto.jpg")) != nil)
        let json = try #require(String(data: defaults.data(forKey: ImageFolderAccessStore.defaultsKey)!, encoding: .utf8))
        #expect(!json.contains("displayPath"))
    }
}
