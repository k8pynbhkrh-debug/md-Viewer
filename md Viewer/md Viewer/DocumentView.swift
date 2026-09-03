import Highlightr
import MarkdownUI
import SwiftUI

// `DocumentError`, `maxFileSize`, `loadMarkdown(from:)` and `saveMarkdown(text:to:)`
// live in Shared/MarkdownDocument.swift so the Share extension can reuse them.

struct DocumentView: View {
    let fileURL: URL

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var content: Result<String, DocumentError>?
    @State private var highlightr = Highlightr()

    /// While `isEditing`, `editedText` is the working copy. Leaving the editor —
    /// via the back button (discard) or a successful save — is the only way it
    /// affects the document; the preview always renders the on-disk text.
    @State private var isEditing = false
    @State private var editedText = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showSaveConfirmation = false
    @State private var showDiscardConfirmation = false
    @FocusState private var editorFocused: Bool

    /// Own undo history for the "Rückgängig" button — see `EditorUndoHistory`.
    @State private var undoHistory = EditorUndoHistory()

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

    /// The text currently on disk.
    private var savedText: String {
        (try? content?.get()) ?? ""
    }

    /// True only while editing and the working copy differs from disk. Outside
    /// the editor there is nothing unsaved: leaving always either saves or
    /// discards.
    private var hasUnsavedChanges: Bool {
        isEditing && editedText != savedText
    }

    var body: some View {
        NavigationStack {
            Group {
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
            .navigationTitle(fileURL.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert(
                "Fehler",
                isPresented: Binding(get: { saveError != nil },
                                     set: { if !$0 { saveError = nil } })
            ) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
            .confirmationDialog(
                "Änderungen speichern?",
                isPresented: $showSaveConfirmation,
                titleVisibility: .visible
            ) {
                Button("In Datei speichern", role: .destructive) { Task { await save() } }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Die Originaldatei „\(fileURL.lastPathComponent)“ wird mit dem bearbeiteten Text überschrieben.")
            }
            .confirmationDialog(
                "Änderungen verwerfen?",
                isPresented: $showDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Verwerfen", role: .destructive) { discardEditing() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Die Änderungen wurden nicht gespeichert und gehen verloren.")
            }
            .overlay {
                if isSaving {
                    ProgressView("Speichern …")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .onChange(of: colorScheme) { _, _ in
            applySyntaxTheme()
        }
        .task {
            applySyntaxTheme()
            content = loadMarkdown(from: fileURL)
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
            // setting it in the "Bearbeiten" action (before this view mounts) is
            // dropped by SwiftUI and leaves the keyboard down.
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
            // any were made). Keeping changes is only ever the red checkmark.
            // In the preview the same X position closes the document instead.
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen", systemImage: "xmark") {
                    if hasUnsavedChanges {
                        showDiscardConfirmation = true
                    } else {
                        discardEditing()
                    }
                }
                .disabled(isSaving)
                .accessibilityHint("Zurück zur Vorschau, ohne die Änderungen zu übernehmen")
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
            ToolbarItem(placement: .primaryAction) {
                Button("Speichern", systemImage: "checkmark") {
                    showSaveConfirmation = true
                }
                .tint(.red)
                .disabled(isSaving || !hasUnsavedChanges)
                .accessibilityHint("Überschreibt die Datei mit dem bearbeiteten Text")
            }
        } else {
            ToolbarItem(placement: .cancellationAction) {
                Button("Schließen", systemImage: "xmark") { dismiss() }
                    .accessibilityHint("Schließt das Dokument")
            }
            if case .success = content {
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

    /// Leaves the editor and drops the working copy. The next `beginEditing()`
    /// re-seeds it from disk.
    ///
    /// - Postcondition: `!isEditing`.
    private func discardEditing() {
        isEditing = false
        undoHistory.reset()
        assert(!isEditing)
    }

    /// Writes the working copy back to the file and returns to the preview.
    ///
    /// - Precondition: called only with unsaved changes present (the button is
    ///   disabled otherwise).
    /// - Postcondition (success): `savedText == <written text> && !isEditing` —
    ///   disk and in-memory content agree and the editor is closed.
    /// - Postcondition (failure): `saveError` is set and the editor stays open
    ///   with the working copy intact, so the user can retry.
    ///
    /// The file I/O runs off the main actor because `NSFileCoordinator` can
    /// block for seconds on an iCloud / Files document that other presenters
    /// hold; `isSaving` drives the progress overlay for that window.
    @MainActor
    private func save() async {
        assert(hasUnsavedChanges, "save() precondition violated: nothing to save")
        let text = editedText
        let url = fileURL
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
}
