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
    @State private var isSaving = false
    @State private var saveError: String? = nil
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

    /// The last saved text, used to detect unsaved edits.
    private var savedText: String {
        (try? content?.get()) ?? ""
    }

    private var hasUnsavedChanges: Bool {
        isEditing && editedText != savedText
    }

    var body: some View {
        NavigationStack {
            Group {
                switch content {
                case .none:
                    ProgressView("Laden …")
                case .success(let markdown):
                    if isEditing {
                        TextEditor(text: $editedText)
                            .font(.system(.body, design: .monospaced))
                            .focused($editorFocused)
                            .scrollDismissesKeyboard(.interactively)
                            .padding(.horizontal, 24)
                            .padding(.vertical)
                    } else {
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
            .toolbar {
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

                if isEditing {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Vorschau", systemImage: "eye") {
                            isEditing = false
                        }
                        .accessibilityHint("Zeigt die Markdown-Vorschau")
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Speichern", systemImage: "checkmark") {
                            save()
                        }
                        .disabled(isSaving)
                        .accessibilityHint("Speichert die Änderungen in der Datei")
                    }
                    ToolbarItem(placement: .keyboard) {
                        Spacer()
                    }
                    ToolbarItem(placement: .keyboard) {
                        Button("Fertig") { editorFocused = false }
                    }
                } else if case .success(let markdown) = content {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Bearbeiten", systemImage: "pencil") {
                            editedText = markdown
                            isEditing = true
                            editorFocused = true
                        }
                        .accessibilityHint("Bearbeitet den Markdown-Text")
                    }
                }
            }
            .alert("Fehler", isPresented: .constant(saveError != nil)) {
                Button("OK") { saveError = nil }
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

    /// Writes the edited text back to the file and returns to the preview.
    private func save() {
        isSaving = true
        do {
            try saveMarkdown(text: editedText, to: fileURL)
            content = .success(editedText)
            isEditing = false
        } catch {
            saveError = (error as? DocumentError)?.errorDescription ?? "Speichern fehlgeschlagen."
        }
        isSaving = false
    }
}
