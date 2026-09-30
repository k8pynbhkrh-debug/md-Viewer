import Testing
import Foundation
import UIKit
@testable import md_Viewer

// Contract of search / replace (T-2026-325): `DocumentSession.requestFind`,
// `EditorUndoHistory.breakCoalescing`, and the system search of the
// `UITextView`s the find bar runs on.

@Suite("EditorUndoHistory.breakCoalescing")
struct EditorUndoBreakCoalescingTests {

    private func time(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSinceReferenceDate: seconds)
    }

    // Postcondition — the next change is its own step even inside the interval.
    @Test("the change after a break is its own undo step")
    func breakStartsNewStep() {
        var history = EditorUndoHistory()
        history.record(before: "typed", at: time(0))
        history.breakCoalescing()
        history.record(before: "typed more", at: time(0.1))
        #expect(history.stack == ["typed", "typed more"])
    }

    // Postcondition — the stack itself is unchanged.
    @Test("a break alone does not change the history")
    func breakKeepsStack() {
        var history = EditorUndoHistory()
        history.record(before: "a", at: time(0))
        history.breakCoalescing()
        #expect(history.stack == ["a"])
    }

    // Postcondition — a pending skip from undo() survives the break.
    @Test("the change caused by undo is still skipped after a break")
    func breakKeepsPendingSkip() {
        var history = EditorUndoHistory()
        history.record(before: "v1", at: time(0))
        #expect(history.undo() == "v1")
        history.breakCoalescing()
        history.record(before: "v2", at: time(0.1)) // the undo's own change
        #expect(history.canUndo == false)
    }
}

@MainActor
@Suite("DocumentSession find")
struct DocumentSessionFindTests {

    private func loadedFile(_ text: String) throws -> (DocumentSession, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("find-\(UUID().uuidString).md")
        try Data(text.utf8).write(to: url)
        let session = DocumentSession(source: .existing(url))
        session.loadIfNeeded()
        return (session, url)
    }

    /// Whether the searchable (non-MarkdownUI) text view is the one shown.
    private func showsSearchableText(_ session: DocumentSession) -> Bool {
        #if targetEnvironment(macCatalyst)
        !session.showFormattedPreview
        #else
        session.isSelectingText
        #endif
    }

    @Test("no pending request and no search term initially")
    func initialState() throws {
        let (session, url) = try loadedFile("# Titel")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(session.findRequest == nil)
        #expect(session.lastSearchText.isEmpty)
        #expect(session.canFind)
    }

    // Precondition side — nothing to search before loading.
    @Test("an unloaded document cannot be searched")
    func unloadedCannotFind() {
        let session = DocumentSession(source: .existing(URL(fileURLWithPath: "/nonexistent.md")))
        #expect(session.canFind == false)
    }

    // Postcondition (reading) — switches to the searchable text view.
    @Test("find in the reader switches to the searchable text view")
    func findInReaderSwitchesView() throws {
        let (session, url) = try loadedFile("Über uns")
        defer { try? FileManager.default.removeItem(at: url) }
        session.requestFind(replace: false)
        #expect(session.findRequest == .find)
        #expect(showsSearchableText(session))
        #expect(session.isEditing == false)
    }

    // Invariant — no replace outside the editor; the text is never touched.
    @Test("replace in the reader degrades to a plain search")
    func replaceOutsideEditorIsFind() throws {
        let (session, url) = try loadedFile("Über uns")
        defer { try? FileManager.default.removeItem(at: url) }
        session.requestFind(replace: true)
        #expect(session.findRequest == .find)
        #expect(session.isEditing == false)
        #expect(session.savedText == "Über uns")
        #expect(session.hasUnsavedChanges == false)
    }

    @Test("replace in the editor offers the replace field")
    func replaceInEditor() throws {
        let (session, url) = try loadedFile("Über uns")
        defer { try? FileManager.default.removeItem(at: url) }
        session.beginEditing()
        session.requestFind(replace: true)
        #expect(session.findRequest == .findAndReplace)
        session.requestFind(replace: false)
        #expect(session.findRequest == .find)
    }

    @Test("presenting clears the request, the search term stays")
    func presentedClearsRequest() throws {
        let (session, url) = try loadedFile("Über uns")
        defer { try? FileManager.default.removeItem(at: url) }
        session.lastSearchText = "über"
        session.requestFind(replace: false)
        session.findRequestPresented()
        #expect(session.findRequest == nil)
        #expect(session.lastSearchText == "über")
    }

    @Test("entering or leaving the editor drops a pending request")
    func modeChangeDropsRequest() throws {
        let (session, url) = try loadedFile("Über uns")
        defer { try? FileManager.default.removeItem(at: url) }
        session.requestFind(replace: false)
        session.beginEditing()
        #expect(session.findRequest == nil)
        session.requestFind(replace: true)
        session.discardEditing()
        #expect(session.findRequest == nil)
    }

    // Contract — "Replace All" is one undo step, marks the document unsaved
    // and never writes the file. The find bar applies it as a burst of
    // `editedText` changes (one per match) right after the user typed.
    @Test("replace all is one undo step, unsaved, file untouched")
    func replaceAllIsOneUndoStep() throws {
        let original = "über, Über, ÜBER"
        let (session, url) = try loadedFile(original)
        defer { try? FileManager.default.removeItem(at: url) }
        session.beginEditing()
        session.editedText = original + "!"            // typing just before
        session.requestFind(replace: true)             // find bar opens
        session.editedText = "unter, Über, ÜBER!"      // replace all, match 1…
        session.editedText = "unter, unter, ÜBER!"
        session.editedText = "unter, unter, unter!"    // …match 3

        #expect(session.hasUnsavedChanges)
        #expect(try String(contentsOf: url, encoding: .utf8) == original)

        session.undo()
        #expect(session.editedText == original + "!")  // typing kept
        session.undo()
        #expect(session.editedText == original)
        #expect(session.canUndo == false)
    }
}

/// Matching (case, umlauts) and replacing are done by the system find bar
/// itself (`UITextSearching` of `UITextView`), which only runs inside a live,
/// on-screen find session — checked in the simulator, not here. What the app
/// owns is that the find interaction is switched on.
@MainActor
@Suite("Find interaction")
struct FindInteractionTests {

    @Test("the read-only views have the find interaction enabled")
    func findEnabled() {
        #expect(FindableTextView().isFindInteractionEnabled)
        #expect(CopyAllTextView().isFindInteractionEnabled)
    }
}
