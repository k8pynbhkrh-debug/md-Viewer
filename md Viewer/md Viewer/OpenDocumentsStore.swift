import Foundation
import Observation

/// The open documents (tabs) of the app's single window, and which one is
/// active.
///
/// Opening a file the OS hands us (Files app, Share, Finder double-click,
/// "Open…") adds a tab instead of replacing the open document; opening a file
/// that already has a tab jumps to it. Open *files* survive a relaunch via
/// bookmarks; drafts and unsaved edits do not.
///
/// ## Contract
///
/// - Invariant: `activeID == nil ⟺ documents.isEmpty`; otherwise `activeID`
///   names an element of `documents`.
/// - Invariant: `open(_:)` never creates a second tab for a file that already
///   has one (`refersTo`). Only "save as" onto a file that is open elsewhere
///   *with unsaved changes* can leave two tabs on one file — see
///   `sessionDidAdoptFile(_:)`.
/// - Invariant: a tab switch never touches any session's state — editing
///   state, working copy and undo history stay with the session.
/// - `open(_:)` / `newDraft(text:)` postcondition: the new or found session is
///   active; every other session is unchanged and keeps its position.
/// - `close(_:discardingChanges:)` precondition: the session is not saving, and
///   has no unsaved changes unless `discardingChanges` — callers go through
///   `requestClose(_:)`, which asks for confirmation instead.
@MainActor
@Observable
final class OpenDocumentsStore {
    private(set) var documents: [DocumentSession] = []
    private(set) var activeID: DocumentSession.ID?

    /// Drives the "Open…" file dialog (menu ⌘O, "+" in the tab bar, the
    /// iPhone document list).
    var isPresentingOpenDialog = false

    @ObservationIgnored private let defaults: UserDefaults?
    /// Bookmark per file-backed session, created when the file is first seen
    /// so persisting does not have to touch the file system again.
    @ObservationIgnored private var bookmarks: [DocumentSession.ID: Data] = [:]

    static let persistenceKey = "openDocuments"

    /// - Parameter defaults: where open files are remembered across launches;
    ///   `nil` disables persistence (previews). The tabs stored there are
    ///   restored right away — see `restore()`.
    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
        restore()
        checkInvariants()
    }

    var active: DocumentSession? {
        documents.first { $0.id == activeID }
    }

    // MARK: - Opening

    /// Opens `url` as a new, active tab — or, if a tab for that file exists,
    /// activates it (taking over `url` and re-reading the file unless it is
    /// being edited).
    ///
    /// - Precondition: `url.isFileURL`.
    /// - Postcondition: the returned session refers to `url` and is active;
    ///   `documents.count` grew by at most one; all other sessions unchanged.
    @discardableResult
    func open(_ url: URL) -> DocumentSession {
        precondition(url.isFileURL, "open(_:) requires a file URL")
        let before = documents.map(\.id)
        defer { checkInvariants() }

        if let existing = documents.first(where: { $0.refersTo(url) }) {
            // Not being edited: take over the freshly handed-over URL (it
            // carries current access rights) and re-read the file — this also
            // heals a tab that showed a load error. A working copy is never
            // touched.
            if !existing.isEditing {
                existing.retarget(to: url)
                bookmarks[existing.id] = Self.makeBookmark(for: url) ?? bookmarks[existing.id]
            }
            activeID = existing.id
            persist()
            assert(documents.map(\.id) == before)
            return existing
        }

        let session = DocumentSession(source: .existing(url))
        bookmarks[session.id] = Self.makeBookmark(for: url)
        documents.append(session)
        activeID = session.id
        persist()
        assert(documents.map(\.id) == before + [session.id])
        return session
    }

    /// Starts a new unsaved draft in a new, active tab.
    ///
    /// - Postcondition: the returned session is a draft with `text`, is active,
    ///   and was appended; all other sessions unchanged.
    @discardableResult
    func newDraft(text: String) -> DocumentSession {
        let session = DocumentSession(source: .draft(initialText: text))
        documents.append(session)
        activeID = session.id
        checkInvariants()
        return session
    }

    /// Records that a session was just saved to a new file ("save as"), so it
    /// is restored on the next launch. Another tab showing that same file is
    /// now outdated and is closed — unless it holds unsaved changes of its
    /// own, which are never dropped silently.
    ///
    /// - Precondition: `session` is open and file-backed.
    /// - Postcondition: `session` is still open and active-state unchanged
    ///   for it; no tab without unsaved changes shares its file.
    func sessionDidAdoptFile(_ session: DocumentSession) {
        precondition(documents.contains { $0 === session }, "unknown session")
        guard let url = session.fileURL else {
            preconditionFailure("sessionDidAdoptFile on a draft")
        }
        bookmarks[session.id] = Self.makeBookmark(for: url)
        let outdated = documents.filter {
            $0 !== session && $0.refersTo(url) && !$0.hasUnsavedChanges && !$0.isSaving
        }
        for other in outdated { close(other.id) }
        persist()
        checkInvariants()
    }

    // MARK: - Switching

    /// - Precondition: `id` names an open session.
    /// - Postcondition: `activeID == id`; no session changed.
    func activate(_ id: DocumentSession.ID) {
        precondition(documents.contains { $0.id == id }, "activate: unknown session")
        activeID = id
        persist()
        checkInvariants()
    }

    /// Activates the tab after (`offset: 1`) or before (`-1`) the active one,
    /// wrapping around. No-op with fewer than two tabs.
    func activateNeighbor(offset: Int) {
        guard documents.count > 1, let index = documents.firstIndex(where: { $0.id == activeID }) else { return }
        let count = documents.count
        activate(documents[((index + offset) % count + count) % count].id)
    }

    // MARK: - Closing

    enum CloseRequest: Equatable {
        case closed
        /// The session has unsaved changes; nothing happened. Ask the user,
        /// then call `close(_:discardingChanges: true)`.
        case needsConfirmation
        /// A save is running; nothing happened.
        case busy
    }

    /// Closes the tab unless that would lose work.
    ///
    /// - Precondition: `id` names an open session.
    /// - Postcondition: `.closed` ⟹ the session is gone (see `close`);
    ///   otherwise no state changed.
    @discardableResult
    func requestClose(_ id: DocumentSession.ID) -> CloseRequest {
        guard let session = documents.first(where: { $0.id == id }) else {
            preconditionFailure("requestClose: unknown session")
        }
        if session.isSaving { return .busy }
        if session.hasUnsavedChanges { return .needsConfirmation }
        close(id)
        return .closed
    }

    /// The tab the user asked to close although it has unsaved changes —
    /// drives the "Discard Changes?" confirmation at the window root.
    var pendingCloseID: DocumentSession.ID?

    /// A close initiated by the user (tab ×, ⌘W, X button): closes right away
    /// or, if that would lose work, sets `pendingCloseID` for the root view to
    /// confirm.
    ///
    /// - Postcondition: the session is closed, or `pendingCloseID == id`, or
    ///   (while saving) nothing changed.
    func userClose(_ id: DocumentSession.ID) {
        if requestClose(id) == .needsConfirmation {
            pendingCloseID = id
        }
    }

    /// The user confirmed discarding the pending tab's changes.
    func confirmPendingClose() {
        defer { pendingCloseID = nil }
        guard let id = pendingCloseID,
              let session = documents.first(where: { $0.id == id }),
              !session.isSaving else { return }
        close(id, discardingChanges: true)
    }

    /// Removes the tab. If it was active, its right neighbor (else the left
    /// one) becomes active; closing the last tab leads to the empty state.
    ///
    /// - Precondition: `id` names an open session that is not saving and —
    ///   unless `discardingChanges` — has no unsaved changes.
    /// - Postcondition: the session is removed; the order of the others is
    ///   unchanged; if it was not active, `activeID` is unchanged.
    func close(_ id: DocumentSession.ID, discardingChanges: Bool = false) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else {
            preconditionFailure("close: unknown session")
        }
        let session = documents[index]
        precondition(!session.isSaving, "close during a save")
        precondition(discardingChanges || !session.hasUnsavedChanges,
                     "close would lose unsaved changes — use requestClose")
        let wasActive = activeID == id
        let othersBefore = documents.map(\.id).filter { $0 != id }
        let activeBefore = activeID

        documents.remove(at: index)
        bookmarks[id] = nil
        if wasActive {
            activeID = documents.isEmpty ? nil : documents[min(index, documents.count - 1)].id
        }
        persist()

        assert(documents.map(\.id) == othersBefore)
        assert(wasActive || activeID == activeBefore)
        checkInvariants()
    }

    // MARK: - Persistence

    /// What is stored in `UserDefaults`: bookmarks of the open files in tab
    /// order, and which of them was active.
    struct PersistedTabs: Codable, Equatable {
        var bookmarks: [Data]
        var activeIndex: Int?
    }

    /// Writes the open *files* (drafts are skipped) in tab order.
    private func persist() {
        guard let defaults else { return }
        var stored: [Data] = []
        var activeIndex: Int?
        for session in documents {
            guard let bookmark = bookmarks[session.id] else { continue }
            if session.id == activeID { activeIndex = stored.count }
            stored.append(bookmark)
        }
        let value = PersistedTabs(bookmarks: stored, activeIndex: activeIndex)
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: Self.persistenceKey)
        }
    }

    /// Reopens the files remembered by `persist()`. Files that were deleted,
    /// moved out of reach, or whose bookmark no longer resolves are skipped
    /// silently; duplicates collapse into one tab.
    ///
    /// - Postcondition: every restored session is file-backed and not yet
    ///   loaded (`content == nil` — tabs load when first shown).
    private func restore() {
        guard let defaults,
              let data = defaults.data(forKey: Self.persistenceKey),
              let stored = try? JSONDecoder().decode(PersistedTabs.self, from: data) else {
            return
        }
        var activeCandidate: DocumentSession.ID?
        for (index, bookmark) in stored.bookmarks.enumerated() {
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: bookmark, relativeTo: nil,
                                     bookmarkDataIsStale: &isStale),
                  Self.fileExists(at: url),
                  !documents.contains(where: { $0.refersTo(url) }) else {
                continue
            }
            let session = DocumentSession(source: .existing(url))
            bookmarks[session.id] = isStale ? (Self.makeBookmark(for: url) ?? bookmark) : bookmark
            documents.append(session)
            if index == stored.activeIndex { activeCandidate = session.id }
        }
        activeID = activeCandidate ?? documents.last?.id
        persist()
        assert(documents.allSatisfy { !$0.isDraft && $0.content == nil })
    }

    private static func makeBookmark(for url: URL) -> Data? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try? url.bookmarkData()
    }

    private static func fileExists(at url: URL) -> Bool {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - Invariants

    private func checkInvariants() {
        assert((activeID == nil) == documents.isEmpty, "activeID must be nil exactly when there are no tabs")
        assert(activeID == nil || documents.contains { $0.id == activeID }, "activeID names no open tab")
        assert(Set(documents.map(\.id)).count == documents.count, "duplicate session")
    }
}
