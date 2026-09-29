import Testing
import Foundation
@testable import md_Viewer

/// Temp files + an isolated `UserDefaults` suite per test.
@MainActor
private final class Fixture {
    let directory: URL
    let suiteName = "OpenDocumentsStoreTests.\(UUID().uuidString)"
    let defaults: UserDefaults

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenDocumentsStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defaults = UserDefaults(suiteName: suiteName)!
    }

    func file(_ name: String, _ text: String = "# Text") throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        return url
    }

    func makeStore() -> OpenDocumentsStore { OpenDocumentsStore(defaults: defaults) }

    deinit {
        try? FileManager.default.removeItem(at: directory)
        UserDefaults().removePersistentDomain(forName: suiteName)
    }
}

@MainActor
@Suite("OpenDocumentsStore")
struct OpenDocumentsStoreTests {

    // MARK: Opening

    @Test("starts empty — no active tab")
    func startsEmpty() throws {
        let fx = try Fixture()
        let store = fx.makeStore()
        #expect(store.documents.isEmpty)
        #expect(store.activeID == nil)
        #expect(store.active == nil)
    }

    // Contract — postcondition open: the new session is active.
    @Test("opening a file adds an active tab")
    func openAddsActiveTab() throws {
        let fx = try Fixture()
        let store = fx.makeStore()
        let url = try fx.file("a.md")

        let session = store.open(url)

        #expect(store.documents.map(\.id) == [session.id])
        #expect(store.activeID == session.id)
        #expect(session.refersTo(url))
    }

    // Contract — postcondition open: all other tabs unchanged, order kept.
    @Test("opening another file keeps the first tab as it was")
    func openSecondKeepsFirst() throws {
        let fx = try Fixture()
        let store = fx.makeStore()
        let a = store.open(try fx.file("a.md", "# A"))
        a.loadIfNeeded()
        a.beginEditing()
        a.editedText = "# A geändert"

        let b = store.open(try fx.file("b.md", "# B"))

        #expect(store.documents.map(\.id) == [a.id, b.id])
        #expect(store.activeID == b.id)
        #expect(a.isEditing)
        #expect(a.editedText == "# A geändert")
    }

    // Decision: the same file again jumps to its tab instead of a duplicate.
    @Test("opening an already open file activates its tab, no duplicate")
    func openDuplicateJumps() throws {
        let fx = try Fixture()
        let store = fx.makeStore()
        let url = try fx.file("a.md")
        let a = store.open(url)
        let b = store.open(try fx.file("b.md"))
        #expect(store.activeID == b.id)

        // A differently spelled path to the same file.
        let respelled = url.deletingLastPathComponent()
            .appendingPathComponent(".")
            .appendingPathComponent(url.lastPathComponent)
        let again = store.open(respelled)

        #expect(again === a)
        #expect(store.documents.count == 2)
        #expect(store.activeID == a.id)
    }

    @Test("re-opening a file that is not being edited reloads it from disk")
    func openDuplicateReloads() throws {
        let fx = try Fixture()
        let store = fx.makeStore()
        let url = try fx.file("a.md", "# Alt")
        let a = store.open(url)
        a.loadIfNeeded()
        try Data("# Neu".utf8).write(to: url)

        store.open(url)

        #expect(a.savedText == "# Neu")
    }

    // Invariant: re-opening never overwrites a working copy.
    @Test("re-opening a file that is being edited keeps the working copy")
    func openDuplicateKeepsWorkingCopy() throws {
        let fx = try Fixture()
        let store = fx.makeStore()
        let url = try fx.file("a.md", "# Alt")
        let a = store.open(url)
        a.loadIfNeeded()
        a.beginEditing()
        a.editedText = "# Meine Änderung"
        try Data("# Von außen".utf8).write(to: url)

        store.open(url)

        #expect(a.isEditing)
        #expect(a.editedText == "# Meine Änderung")
        #expect(a.savedText == "# Alt")
    }

    // Re-opening takes over the freshly handed-over URL — heals a load error.
    @Test("re-opening a file whose tab shows a load error loads it again via the new URL")
    func openDuplicateHealsLoadError() throws {
        let fx = try Fixture()
        let store = fx.makeStore()
        let url = try fx.file("a.md", "")          // empty → load fails
        let a = store.open(url)
        a.loadIfNeeded()
        guard case .failure = a.content else {
            Issue.record("expected a load failure first, got \(String(describing: a.content))")
            return
        }
        try Data("# Jetzt lesbar".utf8).write(to: url)
        let respelled = url.deletingLastPathComponent()
            .appendingPathComponent(".")
            .appendingPathComponent(url.lastPathComponent)

        let again = store.open(respelled)

        #expect(again === a)
        #expect(store.documents.count == 1)
        #expect(a.fileURL == respelled)
        #expect(a.savedText == "# Jetzt lesbar")
    }

    // Contract — invariant: a tab switch never loses unsaved changes.
    @Test("switching tabs keeps editing state and undo history")
    func switchKeepsEditingState() throws {
        let fx = try Fixture()
        let store = fx.makeStore()
        let a = store.open(try fx.file("a.md", "# A"))
        a.loadIfNeeded()
        a.beginEditing()
        a.editedText = "# A plus"
        let b = store.open(try fx.file("b.md"))

        store.activate(b.id)
        store.activate(a.id)

        #expect(store.activeID == a.id)
        #expect(a.isEditing)
        #expect(a.editedText == "# A plus")
        #expect(a.hasUnsavedChanges)
        #expect(a.canUndo)
    }

    @Test("next / previous tab wrap around")
    func neighborWraps() throws {
        let fx = try Fixture()
        let store = fx.makeStore()
        let a = store.open(try fx.file("a.md"))
        let b = store.open(try fx.file("b.md"))
        let c = store.open(try fx.file("c.md"))

        store.activateNeighbor(offset: 1)
        #expect(store.activeID == a.id)
        store.activateNeighbor(offset: -1)
        #expect(store.activeID == c.id)
        store.activateNeighbor(offset: -1)
        #expect(store.activeID == b.id)
    }

    // MARK: Drafts

    // Edge case from the ticket: a draft without a file is a tab of its own.
    @Test("a new draft is its own active tab")
    func draftIsTab() throws {
        let fx = try Fixture()
        let store = fx.makeStore()
        let a = store.open(try fx.file("a.md"))

        let draft = store.newDraft(text: "# Entwurf")

        #expect(store.documents.map(\.id) == [a.id, draft.id])
        #expect(store.activeID == draft.id)
        #expect(draft.isDraft)
        #expect(draft.isEditing)
        #expect(draft.editedText == "# Entwurf")
    }

    @Test("two drafts are two tabs")
    func twoDrafts() throws {
        let fx = try Fixture()
        let store = fx.makeStore()
        store.newDraft(text: "")
        store.newDraft(text: "")
        #expect(store.documents.count == 2)
    }

    // MARK: Closing

    // Contract — precondition close: unsaved changes need confirmation.
    @Test("closing a tab with unsaved changes asks first and changes nothing")
    func closeUnsavedNeedsConfirmation() throws {
        let fx = try Fixture()
        let store = fx.makeStore()
        let a = store.open(try fx.file("a.md", "# A"))
        a.loadIfNeeded()
        a.beginEditing()
        a.editedText = "# A geändert"

        #expect(store.requestClose(a.id) == .needsConfirmation)
        #expect(store.documents.map(\.id) == [a.id])
        #expect(a.editedText == "# A geändert")
    }

    @Test("a draft with text needs confirmation, an empty draft does not")
    func closeDraft() throws {
        let fx = try Fixture()
        let store = fx.makeStore()
        let withText = store.newDraft(text: "Notiz")
        let empty = store.newDraft(text: "")

        #expect(store.requestClose(withText.id) == .needsConfirmation)
        #expect(store.requestClose(empty.id) == .closed)
        #expect(store.documents.map(\.id) == [withText.id])
    }

    @Test("editing without changes closes without asking")
    func closeEditingUnchanged() throws {
        let fx = try Fixture()
        let store = fx.makeStore()
        let a = store.open(try fx.file("a.md"))
        a.loadIfNeeded()
        a.beginEditing()
        #expect(store.requestClose(a.id) == .closed)
        #expect(store.documents.isEmpty)
    }

    @Test("userClose on unsaved changes sets the pending tab; confirming closes it")
    func userCloseConfirmFlow() throws {
        let fx = try Fixture()
        let store = fx.makeStore()
        let a = store.open(try fx.file("a.md", "# A"))
        a.loadIfNeeded()
        a.beginEditing()
        a.editedText = "# anders"

        store.userClose(a.id)
        #expect(store.pendingCloseID == a.id)
        #expect(store.documents.count == 1)

        store.confirmPendingClose()
        #expect(store.pendingCloseID == nil)
        #expect(store.documents.isEmpty)
    }

    // Contract — close postcondition: the right neighbor becomes active.
    @Test("closing the active middle tab activates its right neighbor")
    func closeActivatesRightNeighbor() throws {
        let fx = try Fixture()
        let store = fx.makeStore()
        let a = store.open(try fx.file("a.md"))
        let b = store.open(try fx.file("b.md"))
        let c = store.open(try fx.file("c.md"))
        store.activate(b.id)

        store.close(b.id)

        #expect(store.documents.map(\.id) == [a.id, c.id])
        #expect(store.activeID == c.id)
    }

    @Test("closing the active last tab activates its left neighbor")
    func closeLastPositionActivatesLeft() throws {
        let fx = try Fixture()
        let store = fx.makeStore()
        let a = store.open(try fx.file("a.md"))
        let b = store.open(try fx.file("b.md"))

        store.close(b.id)

        #expect(store.activeID == a.id)
    }

    // Contract — close postcondition: closing an inactive tab keeps the active one.
    @Test("closing an inactive tab leaves the active tab alone")
    func closeInactiveKeepsActive() throws {
        let fx = try Fixture()
        let store = fx.makeStore()
        let a = store.open(try fx.file("a.md"))
        let b = store.open(try fx.file("b.md"))

        store.close(a.id)

        #expect(store.documents.map(\.id) == [b.id])
        #expect(store.activeID == b.id)
    }

    // Edge case from the ticket: last tab closed → empty state.
    @Test("closing the last tab returns to the empty state")
    func closeLastTab() throws {
        let fx = try Fixture()
        let store = fx.makeStore()
        let a = store.open(try fx.file("a.md"))

        store.close(a.id)

        #expect(store.documents.isEmpty)
        #expect(store.activeID == nil)
    }

    @Test("close(discardingChanges:) drops a working copy on purpose")
    func closeDiscarding() throws {
        let fx = try Fixture()
        let store = fx.makeStore()
        let a = store.open(try fx.file("a.md", "# A"))
        a.loadIfNeeded()
        a.beginEditing()
        a.editedText = "# weg damit"

        store.close(a.id, discardingChanges: true)

        #expect(store.documents.isEmpty)
    }

    // MARK: Save as

    @Test("saving a draft onto a file open in a clean tab closes the outdated tab")
    func saveAsReplacesOutdatedTab() throws {
        let fx = try Fixture()
        let store = fx.makeStore()
        let url = try fx.file("a.md", "# Alt")
        let old = store.open(url)
        let draft = store.newDraft(text: "# Neu")
        try Data("# Neu".utf8).write(to: url)   // what the exporter would write

        draft.adoptSavedFile(at: url)
        store.sessionDidAdoptFile(draft)

        #expect(store.documents.map(\.id) == [draft.id])
        #expect(store.activeID == draft.id)
        #expect(!store.documents.contains { $0 === old })
    }

    // MARK: Restore after relaunch

    @Test("open files, their order and the active tab survive a relaunch")
    func restoresFiles() throws {
        let fx = try Fixture()
        let first = fx.makeStore()
        let a = first.open(try fx.file("a.md"))
        first.open(try fx.file("b.md"))
        first.activate(a.id)

        let second = fx.makeStore()

        #expect(second.documents.map(\.title) == ["a.md", "b.md"])
        #expect(second.active?.title == "a.md")
        // Restored tabs load lazily.
        #expect(second.documents.allSatisfy { $0.content == nil && !$0.isEditing })
    }

    @Test("drafts are not restored")
    func draftsNotRestored() throws {
        let fx = try Fixture()
        let first = fx.makeStore()
        first.open(try fx.file("a.md"))
        first.newDraft(text: "# Entwurf")

        let second = fx.makeStore()

        #expect(second.documents.map(\.title) == ["a.md"])
        #expect(second.active?.title == "a.md")
    }

    @Test("a deleted file is skipped silently on relaunch")
    func restoreSkipsDeleted() throws {
        let fx = try Fixture()
        let first = fx.makeStore()
        let gone = try fx.file("gone.md")
        first.open(try fx.file("a.md"))
        first.open(gone)
        try FileManager.default.removeItem(at: gone)

        let second = fx.makeStore()

        #expect(second.documents.map(\.title) == ["a.md"])
        #expect(second.active?.title == "a.md")
    }

    @Test("closed tabs are not restored")
    func closedNotRestored() throws {
        let fx = try Fixture()
        let first = fx.makeStore()
        let a = first.open(try fx.file("a.md"))
        first.close(a.id)

        #expect(fx.makeStore().documents.isEmpty)
    }

    @Test("garbage in UserDefaults starts empty instead of failing")
    func restoreIgnoresGarbage() throws {
        let fx = try Fixture()
        fx.defaults.set(Data("kein JSON".utf8), forKey: OpenDocumentsStore.persistenceKey)
        #expect(fx.makeStore().documents.isEmpty)
    }
}

@MainActor
@Suite("DocumentSession")
struct DocumentSessionTests {

    private func tempFile(_ text: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        try Data(text.utf8).write(to: url)
        return url
    }

    // Contract — init(.draft) postcondition.
    @Test("a draft starts in the editor with its text and no undo")
    func draftInit() {
        let session = DocumentSession(source: .draft(initialText: "# Hallo"))
        #expect(session.isDraft)
        #expect(session.isEditing)
        #expect(session.editedText == "# Hallo")
        #expect(session.savedText == "# Hallo")
        #expect(!session.canUndo)
    }

    // Contract — init(.existing) postcondition: not loaded until shown.
    @Test("a file session loads lazily")
    func lazyLoad() throws {
        let url = try tempFile("# Datei")
        defer { try? FileManager.default.removeItem(at: url) }
        let session = DocumentSession(source: .existing(url))
        #expect(session.content == nil)
        session.loadIfNeeded()
        #expect(session.savedText == "# Datei")
        #expect(session.title == url.lastPathComponent)
    }

    // Contract — beginEditing postcondition.
    @Test("beginEditing starts with the saved text and empty undo")
    func beginEditing() throws {
        let url = try tempFile("# Datei")
        defer { try? FileManager.default.removeItem(at: url) }
        let session = DocumentSession(source: .existing(url))
        session.loadIfNeeded()
        session.isSelectingText = true

        session.beginEditing()

        #expect(session.isEditing)
        #expect(session.editedText == "# Datei")
        #expect(!session.canUndo)
        #expect(!session.isSelectingText)
        #expect(!session.hasUnsavedChanges)
    }

    @Test("typing records an undo step; undo restores the text before it")
    func undoAfterTyping() throws {
        let url = try tempFile("# Datei")
        defer { try? FileManager.default.removeItem(at: url) }
        let session = DocumentSession(source: .existing(url))
        session.loadIfNeeded()
        session.beginEditing()

        session.editedText = "# Datei!"
        #expect(session.canUndo)
        session.undo()

        #expect(session.editedText == "# Datei")
        #expect(!session.canUndo)
    }

    // Contract — discardEditing postcondition for a file.
    @Test("discarding a file's edits returns to the preview")
    func discardFile() throws {
        let url = try tempFile("# Datei")
        defer { try? FileManager.default.removeItem(at: url) }
        let session = DocumentSession(source: .existing(url))
        session.loadIfNeeded()
        session.beginEditing()
        session.editedText = "# anders"

        #expect(session.discardEditing() == .returnedToPreview)
        #expect(!session.isEditing)
        #expect(!session.hasUnsavedChanges)
        #expect(session.savedText == "# Datei")
    }

    // Contract — discardEditing postcondition for a draft.
    @Test("discarding a draft asks for its tab to close")
    func discardDraft() {
        let session = DocumentSession(source: .draft(initialText: "x"))
        #expect(session.discardEditing() == .closeDocument)
    }

    // Contract — saveInPlace postcondition (success).
    @Test("saving writes the file and leaves the editor")
    func saveInPlace() async throws {
        let url = try tempFile("# Alt")
        defer { try? FileManager.default.removeItem(at: url) }
        let session = DocumentSession(source: .existing(url))
        session.loadIfNeeded()
        session.beginEditing()
        session.editedText = "# Neu"

        await session.saveInPlace()

        #expect(!session.isEditing)
        #expect(session.savedText == "# Neu")
        #expect(session.saveError == nil)
        #expect(try String(contentsOf: url, encoding: .utf8) == "# Neu")
    }

    // Contract — saveInPlace postcondition (failure): working copy intact.
    @Test("a failed save keeps the editor and the working copy")
    func saveFailureKeepsWorkingCopy() async throws {
        let url = try tempFile("# Alt")
        defer {
            try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: url.path)
            try? FileManager.default.removeItem(at: url)
        }
        let session = DocumentSession(source: .existing(url))
        session.loadIfNeeded()
        session.beginEditing()
        session.editedText = "# Neu"
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: url.path)

        await session.saveInPlace()

        #expect(session.isEditing)
        #expect(session.editedText == "# Neu")
        #expect(session.saveError != nil)
    }

    // Contract — retarget postcondition: new URL, content re-read.
    @Test("retarget switches to the new URL of the same file and re-reads it")
    func retarget() throws {
        let url = try tempFile("# Alt")
        defer { try? FileManager.default.removeItem(at: url) }
        let session = DocumentSession(source: .existing(url))
        session.loadIfNeeded()
        try Data("# Neu".utf8).write(to: url)
        let respelled = url.deletingLastPathComponent()
            .appendingPathComponent(".")
            .appendingPathComponent(url.lastPathComponent)

        session.retarget(to: respelled)

        #expect(session.fileURL == respelled)
        #expect(session.savedText == "# Neu")
    }

    @Test("refersTo matches the same file under a different spelling only")
    func refersTo() throws {
        let url = try tempFile("x")
        defer { try? FileManager.default.removeItem(at: url) }
        let session = DocumentSession(source: .existing(url))
        let respelled = url.deletingLastPathComponent()
            .appendingPathComponent("../\(url.deletingLastPathComponent().lastPathComponent)/\(url.lastPathComponent)")
        #expect(session.refersTo(respelled))
        #expect(!session.refersTo(url.appendingPathExtension("other")))
        #expect(!DocumentSession(source: .draft(initialText: "")).refersTo(url))
    }
}
