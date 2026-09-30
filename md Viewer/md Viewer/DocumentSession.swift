import Foundation
import Observation

/// Everything that belongs to one open document (one tab): its backing file,
/// loaded content, editing state and undo history.
///
/// Lives outside `DocumentView` so switching tabs never loses state — only the
/// active tab has a view (and with it the rendered Markdown); inactive tabs keep
/// just this model. `OpenDocumentsStore` owns the sessions.
///
/// ## Contract
///
/// - Invariant: `isEditing == false` ⟹ `hasUnsavedChanges == false`. The only
///   ways out of the editor are `discardEditing()` and a successful save; both
///   leave `savedText` as what is on disk.
/// - Invariant: `isDraft == (fileURL == nil)`; a draft stays in the editor
///   until it is saved (becomes a file) or discarded (its tab closes).
/// - Invariant: `undoHistory` only ever holds snapshots of the current editing
///   pass — it is reset whenever the editor is entered or left.
/// - Invariant: `findRequest == .findAndReplace` ⟹ `isEditing`. Search never
///   changes text; replacing only ever edits `editedText` (undoable, unsaved
///   until the user saves).
@MainActor
@Observable
final class DocumentSession: Identifiable {
    let id = UUID()

    /// The file this document writes to, or `nil` while it is still an unsaved
    /// draft. Once set (opened file, or first "save as"), the red checkmark
    /// writes in place.
    private(set) var fileURL: URL?

    /// `nil` until `loadIfNeeded()` ran (restored tabs load lazily when first
    /// shown).
    private(set) var content: Result<String, DocumentError>?

    /// While `isEditing`, `editedText` is the working copy. Leaving the editor —
    /// via discard or a successful save — is the only way it affects the
    /// document; the preview always renders `savedText`.
    private(set) var isEditing = false
    var editedText = "" {
        didSet {
            // Every change of the working copy is an undo checkpoint (coalesced
            // into typing bursts by `EditorUndoHistory`).
            if isEditing, oldValue != editedText {
                undoHistory.record(before: oldValue)
            }
        }
    }
    private(set) var isSaving = false
    /// Set when a save failed; the view shows it and clears it.
    var saveError: String?

    /// While true the reader shows the plain-text, natively selectable view
    /// instead of the rendered Markdown. Never true together with `isEditing`.
    /// iOS/iPadOS only — on the Mac `showFormattedPreview` does this job.
    var isSelectingText = false
    /// Mac only: rendered MarkdownUI preview (default) vs. the mouse-selectable
    /// `MarkdownAttributedText`.
    var showFormattedPreview = true

    /// Own undo history for the "Rückgängig" button — see `EditorUndoHistory`.
    private var undoHistory = EditorUndoHistory()

    /// A search the user asked for (⌘F, ⌥⌘F, magnifier) that the visible text
    /// view has not presented yet. Set by `requestFind(replace:)`, cleared by
    /// the view via `findRequestPresented()` once the find bar is up.
    private(set) var findRequest: FindRequest?

    /// The last search term used in this tab — pre-filled into the find bar the
    /// next time it opens here. Tabs do not share it.
    var lastSearchText = ""

    /// - Precondition: an `.existing` source is a file URL.
    /// - Postcondition: `.existing(url)` ⟹ `fileURL == url`, `content == nil`
    ///   (loaded on demand); `.draft(text)` ⟹ `isDraft`, `isEditing`,
    ///   `editedText == savedText == text`, undo history empty.
    init(source: DocumentSource) {
        switch source {
        case .existing(let url):
            precondition(url.isFileURL, "DocumentSession requires a file URL")
            fileURL = url
        case .draft(let initialText):
            fileURL = nil
            content = .success(initialText)
            editedText = initialText
            isEditing = true
            undoHistory.reset()
            assert(isDraft && isEditing && savedText == initialText && !canUndo)
        }
    }

    // MARK: - Derived state

    /// True while there is no backing file yet — the document has never been
    /// written to disk.
    var isDraft: Bool { fileURL == nil }

    /// The open document's folder — where relative image paths resolve
    /// against. `nil` for an unsaved draft.
    var documentFolderURL: URL? { fileURL?.deletingLastPathComponent() }

    /// The text currently "on disk" — for a draft, the text it was started with.
    var savedText: String { (try? content?.get()) ?? "" }

    var isLoaded: Bool {
        if case .success = content { return true }
        return false
    }

    /// Tab / navigation-bar title.
    var title: String { fileURL?.lastPathComponent ?? String(localized: "New Document") }

    var canUndo: Bool { undoHistory.canUndo }

    /// True while editing and the working copy is worth keeping. Drives the
    /// discard / close confirmation: for a draft, any text at all counts; for a
    /// file, only a difference from disk.
    var hasUnsavedChanges: Bool {
        guard isEditing else { return false }
        if isDraft { return !editedText.isEmpty }
        return editedText != savedText
    }

    /// True when there is something a save could actually write — a non-empty
    /// draft, or a changed file.
    var canSave: Bool {
        guard isEditing, !isSaving else { return false }
        if isDraft {
            return !editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return editedText != savedText
    }

    /// Offer "als Markdown speichern" while editing a text file that is not
    /// already a `.md` (e.g. an opened `.txt`).
    var canSaveAsMarkdown: Bool {
        guard isEditing, let ext = fileURL?.pathExtension.lowercased() else { return false }
        return ext != "md" && ext != "markdown"
    }

    /// Whether this session is backed by the same file as `url` — symlinks and
    /// `.`/`..` components resolved. Used to jump to an already open tab
    /// instead of opening a duplicate.
    func refersTo(_ url: URL) -> Bool {
        guard let fileURL else { return false }
        return Self.canonicalPath(of: fileURL) == Self.canonicalPath(of: url)
    }

    nonisolated static func canonicalPath(of url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    // MARK: - Loading

    /// Loads the backing file once; later calls are no-ops.
    ///
    /// - Postcondition: `content != nil`.
    func loadIfNeeded() {
        guard content == nil, let fileURL else { return }
        content = loadMarkdown(from: fileURL)
        #if DEBUG
        // App-Store-Screenshot-Lauf: mit diesem Startargument direkt in den
        // Editor (Tastatur per Cmd+K) und mit einer sichtbaren Änderung, damit
        // der rote Speichern-Haken aktiv ist. Synthetische Taps im Simulator
        // sind hier unzuverlässig. Nur DEBUG.
        if ProcessInfo.processInfo.arguments.contains("-mdviewerScreenshotEdit"),
           case .success(let text) = content {
            beginEditing()
            editedText = text.replacingOccurrences(
                of: "- [ ] Write release notes",
                with: "- [x] Write release notes"
            )
        }
        // Startet direkt in der Text-auswählen-Ansicht. Nur DEBUG.
        if ProcessInfo.processInfo.arguments.contains("-mdviewerSelectText") {
            isSelectingText = true
        }
        // Öffnet direkt die Suchleiste (im Editor mit Ersetzen), optional mit
        // vorbelegtem Begriff: „-mdviewerFind <begriff>". Nur DEBUG.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-mdviewerFind"), canFind {
            if i + 1 < args.count { lastSearchText = args[i + 1] }
            requestFind(replace: isEditing)
        }
        #endif
        assert(content != nil)
    }

    /// Points the session at `url` — the same file, handed over again by the
    /// system (Files app, Finder, "Open…") with fresh access rights — and
    /// re-reads it. Lets a tab that failed to load (e.g. access lost after a
    /// relaunch) recover by opening the file again.
    ///
    /// - Precondition: `!isEditing`, `refersTo(url)`.
    /// - Postcondition: `fileURL == url` and `content` reflects the file now.
    func retarget(to url: URL) {
        precondition(!isEditing, "retarget would discard the working copy")
        precondition(refersTo(url), "retarget to a different file")
        fileURL = url
        content = loadMarkdown(from: url)
        assert(fileURL == url && content != nil)
    }

    // MARK: - Editing

    /// Enters the editor with a fresh working copy of the saved text.
    ///
    /// - Precondition: the document loaded successfully.
    /// - Postcondition: `isEditing && editedText == savedText` and the undo
    ///   history is empty.
    func beginEditing() {
        assert(isLoaded, "beginEditing precondition violated: document not loaded")
        isSelectingText = false
        findRequest = nil
        isEditing = true
        editedText = savedText
        undoHistory.reset()
        assert(isEditing && editedText == savedText && !canUndo)
    }

    /// Steps back one typing burst.
    ///
    /// - Postcondition: `editedText` is the most recent checkpoint, if any.
    func undo() {
        if let restored = undoHistory.undo() { editedText = restored }
    }

    // MARK: - Find

    enum FindRequest: Equatable {
        /// Find bar only.
        case find
        /// Find bar with the replace field — only ever while editing.
        case findAndReplace
    }

    /// Whether search is possible at all — there is loaded, non-empty text.
    var canFind: Bool {
        isEditing || (isLoaded && !savedText.isEmpty)
    }

    /// Asks the visible text view to open the system find bar.
    ///
    /// The rendered MarkdownUI preview cannot be searched, so outside the
    /// editor this switches to the plain-text view that can ("Select Text" on
    /// iOS, the selectable preview on the Mac). Replacing is only offered in
    /// the editor; outside it a replace request degrades to a plain search.
    ///
    /// - Precondition: `canFind`.
    /// - Postcondition: `findRequest != nil`; `findRequest == .findAndReplace`
    ///   ⟹ `isEditing`; `!isEditing` ⟹ the searchable text view is selected
    ///   (`isSelectingText` on iOS, `!showFormattedPreview` on the Mac). No
    ///   text changes.
    func requestFind(replace: Bool) {
        precondition(canFind, "requestFind without searchable text")
        if isEditing {
            // A following "Replace All" is its own undo step.
            undoHistory.breakCoalescing()
            findRequest = replace ? .findAndReplace : .find
        } else {
            #if targetEnvironment(macCatalyst)
            showFormattedPreview = false
            #else
            isSelectingText = true
            #endif
            findRequest = .find
        }
        assert(findRequest != nil && (findRequest != .findAndReplace || isEditing))
    }

    /// Called by the text view once it presented the find bar for
    /// `findRequest`.
    ///
    /// - Postcondition: `findRequest == nil`.
    func findRequestPresented() {
        findRequest = nil
    }

    enum DiscardOutcome: Equatable {
        /// A file returned to its preview.
        case returnedToPreview
        /// A draft has nothing to fall back to — the caller closes its tab.
        case closeDocument
    }

    /// Leaves the editor without keeping the working copy.
    ///
    /// - Precondition: `isEditing`, `!isSaving`.
    /// - Postcondition: `!isEditing`, undo history empty; a file shows
    ///   `savedText` again (`.returnedToPreview`), a draft asks its owner to
    ///   close it (`.closeDocument`).
    @discardableResult
    func discardEditing() -> DiscardOutcome {
        precondition(isEditing, "discardEditing called outside the editor")
        precondition(!isSaving, "discardEditing during a save")
        undoHistory.reset()
        findRequest = nil
        isEditing = false
        editedText = ""
        assert(!isEditing && !hasUnsavedChanges)
        return isDraft ? .closeDocument : .returnedToPreview
    }

    /// Writes the working copy to the backing file in place and returns to the
    /// preview.
    ///
    /// - Precondition: `!isDraft` and `canSave` (the button is disabled
    ///   otherwise).
    /// - Postcondition (success): `savedText == <written text> && !isEditing` —
    ///   disk and in-memory content agree and the editor is closed.
    /// - Postcondition (failure): `saveError` is set and the editor stays open
    ///   with the working copy intact, so the user can retry.
    ///
    /// The file I/O runs off the main actor because `NSFileCoordinator` can
    /// block for seconds on an iCloud / Files document that other presenters
    /// hold; `isSaving` drives the progress overlay for that window.
    func saveInPlace() async {
        guard let url = fileURL else {
            preconditionFailure("saveInPlace on a draft — use the exporter")
        }
        assert(canSave, "saveInPlace precondition violated: nothing to save")
        let text = editedText
        isSaving = true
        defer { isSaving = false }
        do {
            try await Task.detached(priority: .userInitiated) {
                try saveMarkdown(text: text, to: url)
            }.value
            content = .success(text)
            isEditing = false
            findRequest = nil
            undoHistory.reset()
            assert(savedText == text && !isEditing)
        } catch {
            saveError = (error as? DocumentError)?.errorDescription ?? String(localized: "Saving failed.")
        }
    }

    /// Adopts `url` (just written by the `.fileExporter`) as the backing file.
    ///
    /// - Precondition: `isEditing` — there was a working copy to write.
    /// - Postcondition: `fileURL == url`, `savedText == <working copy>`,
    ///   `!isEditing`, undo history empty; the next save writes in place.
    func adoptSavedFile(at url: URL) {
        precondition(isEditing, "adoptSavedFile precondition violated: nothing was written")
        precondition(url.isFileURL, "adoptSavedFile requires a file URL")
        let text = editedText
        fileURL = url
        content = .success(text)
        isEditing = false
        findRequest = nil
        undoHistory.reset()
        assert(fileURL == url && !isEditing && savedText == text)
        #if DEBUG
        // The exporter wrote the file, not us — confirm it landed as our text.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        assert((try? String(contentsOf: url, encoding: .utf8)) == text,
               "adoptSavedFile postcondition violated: file on disk differs from editedText")
        #endif
    }
}
