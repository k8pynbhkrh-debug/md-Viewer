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
}
