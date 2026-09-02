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

    @State private var isEditing = false
    @State private var editedText = ""
    /// Set once the user has entered the editor for this document and not yet
    /// saved or discarded. While set, `editedText` — not the last saved text —
    /// is the version shown in the preview and checked for unsaved changes.
    @State private var hasDraft = false
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showCloseConfirmation = false
    @FocusState private var editorFocused: Bool

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

    /// The last text written to disk.
    private var savedText: String {
        (try? content?.get()) ?? ""
    }

    /// The version currently on screen: the working draft if one exists,
    /// otherwise the saved file.
    private var displayedText: String {
        hasDraft ? editedText : savedText
    }

    private var hasUnsavedChanges: Bool {
        hasDraft && editedText != savedText
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
                        preview(markdown: displayedText)
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
                "Ungespeicherte Änderungen",
                isPresented: $showCloseConfirmation,
                titleVisibility: .visible
            ) {
                Button("Verwerfen und schließen", role: .destructive) { dismiss() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Die Änderungen wurden noch nicht gespeichert.")
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
            .scrollDismissesKeyboard(.interactively)
            .padding(.horizontal, 24)
            .padding(.vertical)
            // Requesting focus only once the editor is actually in the hierarchy;
            // setting it in the "Bearbeiten" action (before this view mounts) is
            // dropped by SwiftUI and leaves the keyboard down.
            .onAppear { editorFocused = true }
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
        ToolbarItem(placement: .cancellationAction) {
            Button("Schließen", systemImage: "xmark") {
                if hasUnsavedChanges {
                    showCloseConfirmation = true
                } else {
                    dismiss()
                }
            }
            .accessibilityHint("Schließt das Dokument")
        }

        if case .success = content {
            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vorschau", systemImage: "eye") {
                        isEditing = false
                    }
                    .disabled(isSaving)
                    .accessibilityHint("Zeigt die Markdown-Vorschau der Änderungen")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Speichern", systemImage: "checkmark") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                    .accessibilityHint("Speichert die Änderungen in der Datei")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { editorFocused = false }
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Button("Bearbeiten", systemImage: "pencil") {
                        // Keep an in-progress draft; only seed from the saved
                        // text on the first entry into the editor.
                        if !hasDraft {
                            editedText = savedText
                            hasDraft = true
                        }
                        isEditing = true
                    }
                    .accessibilityHint("Bearbeitet den Markdown-Text")
                }
            }
        }
    }

    /// Writes the current draft back to the file and returns to the preview.
    ///
    /// The file I/O runs off the main actor because `NSFileCoordinator` can
    /// block for seconds on an iCloud / Files document that other presenters
    /// hold; `isSaving` drives the progress overlay for that window.
    @MainActor
    private func save() async {
        let text = editedText
        let url = fileURL
        isSaving = true
        defer { isSaving = false }
        do {
            try await Task.detached(priority: .userInitiated) {
                try saveMarkdown(text: text, to: url)
            }.value
            content = .success(text)
            hasDraft = false
            isEditing = false
        } catch {
            saveError = (error as? DocumentError)?.errorDescription ?? "Speichern fehlgeschlagen."
        }
    }
}
