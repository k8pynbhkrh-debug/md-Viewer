import Highlightr
import MarkdownUI
import SwiftUI
import UniformTypeIdentifiers

// `DocumentError`, `maxFileSize`, `loadMarkdown(from:)` and `saveMarkdown(text:to:)`
// live in Shared/MarkdownDocument.swift so the Share extension can reuse them.
// `DocumentSource`, `MarkdownFileDocument` and `suggestedFilename(from:)` are in
// MarkdownDraft.swift.

struct DocumentView: View {
    /// What we were opened with. The backing file (`fileURL`) is resolved from
    /// this in `.task`; for a draft it stays `nil` until the first save.
    let source: DocumentSource

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var content: Result<String, DocumentError>?
    @State private var highlightr = Highlightr()

    /// The file this document writes to, or `nil` while it is still an unsaved
    /// draft. Once set (opened file, or first "save as"), the red checkmark
    /// writes in place.
    @State private var fileURL: URL?

    /// While `isEditing`, `editedText` is the working copy. Leaving the editor —
    /// via the X (discard) or a successful save — is the only way it affects the
    /// document; the preview always renders `savedText`.
    @State private var isEditing = false
    @State private var editedText = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showSaveConfirmation = false
    @State private var showDiscardConfirmation = false
    @State private var showExporter = false
    @FocusState private var editorFocused: Bool

    /// Own undo history for the "Rückgängig" button — see `EditorUndoHistory`.
    @State private var undoHistory = EditorUndoHistory()

    /// True while there is no backing file yet — the document has never been
    /// written to disk.
    private var isDraft: Bool { fileURL == nil }

    /// highlight.js theme names (bundled with Highlightr) for each appearance.
    private func syntaxTheme(for scheme: ColorScheme) -> String {
        scheme == .dark ? "atom-one-dark" : "atom-one-light"
    }

    /// Applies the theme that matches the current appearance and a system
    /// monospaced font (Highlightr defaults to Courier otherwise).
    private func applySyntaxTheme() {
        highlightr?.setTheme(to: syntaxTheme(for: colorScheme))
        highlightr?.theme.setCodeFont(
            .monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .callout).pointSize,
                                  weight: .regular)
        )
    }

    private var codeBlockBackground: Color {
        highlightr.map { Color(uiColor: $0.theme.themeBackgroundColor) }
            ?? Color(uiColor: .secondarySystemBackground)
    }

    /// The text currently "on disk" — for a draft, the last value handed to the
    /// editor.
    private var savedText: String {
        (try? content?.get()) ?? ""
    }

    private var isLoaded: Bool {
        if case .success = content { return true }
        return false
    }

    /// Title shown in the navigation bar.
    private var navigationTitle: String {
        fileURL?.lastPathComponent ?? "Neues Dokument"
    }

    /// True while editing and the working copy is worth keeping. Drives the
    /// discard confirmation: for a draft, any text at all counts; for a file,
    /// only a difference from disk.
    private var hasUnsavedChanges: Bool {
        guard isEditing else { return false }
        if isDraft {
            return !editedText.isEmpty
        }
        return editedText != savedText
    }

    /// True when there is something a save could actually write — a non-empty
    /// draft, or a changed file.
    private var canSave: Bool {
        guard isEditing, !isSaving else { return false }
        if isDraft {
            return !editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return editedText != savedText
    }

    /// Offer "als Markdown speichern" while editing a text file that is not
    /// already a `.md` (e.g. an opened `.txt`).
    private var canSaveAsMarkdown: Bool {
        guard isEditing, let ext = fileURL?.pathExtension.lowercased() else { return false }
        return ext != "md" && ext != "markdown"
    }

    var body: some View {
        NavigationStack {
            documentContent
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .overlay { savingOverlay }
        }
        .alert("Fehler", isPresented: saveErrorBinding) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
        .confirmationDialog(
            "Änderungen speichern?",
            isPresented: $showSaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("In Datei speichern", role: .destructive) { confirmSaveInPlace() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Originaldatei „\(fileURL?.lastPathComponent ?? "")“ wird mit dem bearbeiteten Text überschrieben.")
        }
        .confirmationDialog(
            isDraft ? "Dokument verwerfen?" : "Änderungen verwerfen?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Verwerfen", role: .destructive) { discardEditing() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text(isDraft
                 ? "Dieses Dokument wurde noch nicht gespeichert und geht verloren."
                 : "Die Änderungen wurden nicht gespeichert und gehen verloren.")
        }
        .fileExporter(
            isPresented: $showExporter,
            document: MarkdownFileDocument(text: editedText),
            contentType: markdownUTType,
            defaultFilename: suggestedFilename(from: editedText),
            onCompletion: handleExportResult
        )
        .onChange(of: colorScheme) { _, _ in applySyntaxTheme() }
        .task { await load() }
    }

    @ViewBuilder
    private var documentContent: some View {
        switch content {
        case .none:
            ProgressView("Laden …")
        case .success:
            if isEditing {
                editor
            } else {
                preview(markdown: savedText)
            }
        case .failure(let error):
            ContentUnavailableView {
                Label("Fehler", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.localizedDescription)
            }
        }
    }

    @ViewBuilder
    private var savingOverlay: some View {
        if isSaving {
            ProgressView("Speichern …")
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    }

    private func confirmSaveInPlace() {
        guard let url = fileURL else { return }
        Task { await saveInPlace(to: url) }
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            adoptSavedFile(at: url)
        case .failure(let error):
            if !isUserCancelled(error) {
                saveError = "Speichern fehlgeschlagen."
            }
        }
    }

    /// Resolves `source` into a backing file (or a draft) and loads its content.
    private func load() async {
        applySyntaxTheme()
        switch source {
        case .existing(let url):
            fileURL = url
            content = loadMarkdown(from: url)
            switch content {
            case .success:
                UIAccessibility.post(notification: .screenChanged, argument: nil)
                #if DEBUG
                // App-Store-Screenshot-Lauf: mit diesem Startargument direkt in
                // den Editor (Tastatur per Cmd+K) und mit einer sichtbaren
                // Änderung, damit der rote Speichern-Haken aktiv ist.
                // Synthetische Taps im Simulator sind hier unzuverlässig.
                // Nur DEBUG.
                if ProcessInfo.processInfo.arguments.contains("-mdviewerScreenshotEdit"),
                   case .success(let text) = content {
                    beginEditing()
                    editedText = text.replacingOccurrences(
                        of: "- [ ] Release-Notes schreiben",
                        with: "- [x] Release-Notes schreiben"
                    )
                }
                #endif
            case .failure(let error):
                UIAccessibility.post(notification: .announcement, argument: error.localizedDescription)
            case .none:
                break
            }
        case .draft(let initialText):
            fileURL = nil
            beginDraft(text: initialText)
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }

    private var editor: some View {
        TextEditor(text: $editedText)
            .font(.system(.body, design: .monospaced))
            .focused($editorFocused)
            // Dismiss the keyboard by dragging down over the text, the way the
            // message list works in chat apps — no explicit "hide keyboard"
            // button. Leaving the editor also drops it.
            .scrollDismissesKeyboard(.interactively)
            .padding(.horizontal, 24)
            .padding(.vertical)
            // Requesting focus only once the editor is actually in the hierarchy;
            // setting it before this view mounts is dropped by SwiftUI and
            // leaves the keyboard down.
            .onAppear { editorFocused = true }
            .onChange(of: editedText) { oldValue, _ in undoHistory.record(before: oldValue) }
    }

    private func preview(markdown: String) -> some View {
        GeometryReader { geometry in
            ScrollView {
                Markdown(markdown)
                    .markdownCodeSyntaxHighlighter(
                        HighlightrSyntaxHighlighter(highlightr: highlightr)
                    )
                    .markdownBlockStyle(\.table) { configuration in
                        ScrollView(.horizontal, showsIndicators: true) {
                            configuration.label
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .markdownMargin(top: 0, bottom: 16)
                    }
                    .markdownBlockStyle(\.codeBlock) { configuration in
                        ScrollView(.horizontal, showsIndicators: false) {
                            configuration.label
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(12)
                        }
                        .background(codeBlockBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .markdownMargin(top: 0, bottom: 16)
                    }
                    // Fill the available width (MarkdownUI otherwise sizes
                    // to the content's natural width and pins it leading,
                    // which looks broken on iPad). ~24pt side margins.
                    .frame(width: max(0, geometry.size.width - 48), alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isEditing {
            // Leading X = leave the editor WITHOUT keeping changes (confirmed if
            // any were made). For a draft this closes the document; for a file
            // it returns to the preview. Keeping changes is only ever the red
            // checkmark.
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen", systemImage: "xmark") {
                    if hasUnsavedChanges {
                        showDiscardConfirmation = true
                    } else {
                        discardEditing()
                    }
                }
                .disabled(isSaving)
                .accessibilityHint(isDraft
                                   ? "Verwirft das neue Dokument"
                                   : "Zurück zur Vorschau, ohne die Änderungen zu übernehmen")
            }
            ToolbarItem(placement: .cancellationAction) {
                // Step-by-step undo of individual typing bursts, in addition to
                // "Abbrechen" (discard everything).
                Button("Rückgängig", systemImage: "arrow.uturn.backward") {
                    if let restored = undoHistory.undo() { editedText = restored }
                }
                .disabled(isSaving || !undoHistory.canUndo)
                .accessibilityHint("Macht die letzte Änderung rückgängig")
            }
            if canSaveAsMarkdown {
                ToolbarItem(placement: .secondaryAction) {
                    Button("Als Markdown speichern", systemImage: "square.and.arrow.down") {
                        showExporter = true
                    }
                    .disabled(isSaving || editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Speichern", systemImage: "checkmark") {
                    if isDraft {
                        showExporter = true
                    } else {
                        showSaveConfirmation = true
                    }
                }
                .tint(.red)
                .disabled(!canSave)
                .accessibilityHint(isDraft
                                   ? "Speichert den Text als neue Datei"
                                   : "Überschreibt die Datei mit dem bearbeiteten Text")
            }
        } else {
            ToolbarItem(placement: .cancellationAction) {
                Button("Schließen", systemImage: "xmark") { dismiss() }
                    .accessibilityHint("Schließt das Dokument")
            }
            if isLoaded {
                ToolbarItem(placement: .primaryAction) {
                    Button("Bearbeiten", systemImage: "pencil") { beginEditing() }
                        .accessibilityHint("Bearbeitet den Markdown-Text")
                }
            }
        }
    }

    /// Enters the editor with a fresh working copy of the saved text.
    ///
    /// - Precondition: the document loaded successfully.
    /// - Postcondition: `isEditing && editedText == savedText` and the undo
    ///   history is empty.
    private func beginEditing() {
        undoHistory.reset()
        editedText = savedText
        isEditing = true
        assert(isEditing && editedText == savedText && !undoHistory.canUndo)
    }

    /// Enters the editor with an unsaved draft — no backing file yet.
    ///
    /// - Precondition: `fileURL == nil`.
    /// - Postcondition: `content == .success(text)`, `editedText == text`,
    ///   `isEditing`, and the undo history is empty.
    private func beginDraft(text: String) {
        precondition(fileURL == nil, "beginDraft called with a backing file present")
        undoHistory.reset()
        content = .success(text)
        editedText = text
        isEditing = true
        assert(isEditing && editedText == text && savedText == text && !undoHistory.canUndo)
    }

    /// Leaves the editor without keeping the working copy. A draft has nothing
    /// to fall back to, so the whole document closes; a file returns to its
    /// preview.
    ///
    /// - Postcondition: `isDraft` ⟹ the cover is dismissed; otherwise
    ///   `!isEditing` and the preview shows `savedText` again.
    private func discardEditing() {
        undoHistory.reset()
        if isDraft {
            dismiss()
        } else {
            isEditing = false
            assert(!isEditing)
        }
    }

    /// Writes the working copy to `url` in place and returns to the preview.
    ///
    /// - Precondition: `url` is a file URL and `canSave` (the button is disabled
    ///   otherwise).
    /// - Postcondition (success): `savedText == <written text> && !isEditing` —
    ///   disk and in-memory content agree and the editor is closed.
    /// - Postcondition (failure): `saveError` is set and the editor stays open
    ///   with the working copy intact, so the user can retry.
    ///
    /// The file I/O runs off the main actor because `NSFileCoordinator` can
    /// block for seconds on an iCloud / Files document that other presenters
    /// hold; `isSaving` drives the progress overlay for that window.
    @MainActor
    private func saveInPlace(to url: URL) async {
        precondition(url.isFileURL, "saveInPlace requires a file URL")
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
            undoHistory.reset()
            assert(savedText == text && !isEditing)
        } catch {
            saveError = (error as? DocumentError)?.errorDescription ?? "Speichern fehlgeschlagen."
        }
    }

    /// Adopts `url` (just written by the `.fileExporter`) as the document's
    /// backing file.
    ///
    /// - Precondition: `content` is `.success` — there was text to write.
    /// - Postcondition: `fileURL == url`, `content == .success(editedText)`,
    ///   `!isEditing`, undo history empty; the next save writes in place.
    private func adoptSavedFile(at url: URL) {
        assert(isLoaded, "adoptSavedFile precondition violated: nothing was written")
        let text = editedText
        fileURL = url
        content = .success(text)
        isEditing = false
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

/// `.fileExporter` reports a user-cancelled dialog as a `CocoaError` on some
/// iOS versions even with an `onCancellation:` handler; treat that as a no-op.
private func isUserCancelled(_ error: Error) -> Bool {
    (error as? CocoaError)?.code == .userCancelled
}
