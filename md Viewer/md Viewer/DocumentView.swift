import Highlightr
import MarkdownUI
import SwiftUI
import UIKit
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
    /// Drives the brief "Copied" toast after the "Copy All" toolbar button.
    @State private var showCopyConfirmation = false
    /// While true the reader shows the plain-text, natively selectable view
    /// instead of the rendered Markdown, so a passage can be selected and
    /// copied. Never true together with `isEditing`. iOS/iPadOS only — on the
    /// Mac the default preview is already selectable (see `showFormattedPreview`).
    @State private var isSelectingText = false
    #if targetEnvironment(macCatalyst)
    /// Mac only. The Mac's default preview is `MarkdownAttributedText` — one
    /// continuous, mouse-selectable string (⌘A / ⌘C work there), at the cost of
    /// tables rendering as tab-separated rows and no images. When this is true
    /// the reader has toggled to the full MarkdownUI rendering instead (bordered
    /// tables, syntax-highlighted code, images) for reading — not selectable
    /// under Catalyst. iOS/iPadOS always use the MarkdownUI `preview`.
    @State private var showFormattedPreview = false
    #endif
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
        fileURL?.lastPathComponent ?? String(localized: "New Document")
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
                .overlay(alignment: .top) { copyConfirmationToast }
        }
        .alert("Error", isPresented: saveErrorBinding) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
        .confirmationDialog(
            "Save Changes?",
            isPresented: $showSaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Save to File", role: .destructive) { confirmSaveInPlace() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The original file \(fileURL?.lastPathComponent ?? "") will be overwritten with the edited text.")
        }
        .confirmationDialog(
            isDraft ? "Discard Document?" : "Discard Changes?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { discardEditing() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(isDraft
                 ? "This document has not been saved yet and will be lost."
                 : "The changes have not been saved and will be lost.")
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
            ProgressView("Loading…")
        case .success:
            if isEditing {
                editor
            } else if isSelectingText {
                SelectableTextView(text: plainText(fromMarkdown: savedText))
            } else {
                #if targetEnvironment(macCatalyst)
                if showFormattedPreview {
                    preview(markdown: savedText)
                } else {
                    // Default Mac preview: selectable in place (mouse, ⌘A, ⌘C)
                    // — MarkdownUI's rendered output is not selectable under
                    // Catalyst. The toolbar toggles to `preview` for the full
                    // rendering.
                    MarkdownAttributedText(
                        markdown: savedText,
                        plainTextForCopyAll: plainText(fromMarkdown: savedText),
                        onCopyAll: { confirmCopied() }
                    )
                }
                #else
                preview(markdown: savedText)
                #endif
            }
        case .failure(let error):
            ContentUnavailableView {
                Label("Error", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.localizedDescription)
            }
        }
    }

    @ViewBuilder
    private var savingOverlay: some View {
        if isSaving {
            ProgressView("Saving…")
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    /// Transient confirmation shown after "Copy All" — the system gives no
    /// feedback for a programmatic pasteboard write, so we do.
    @ViewBuilder
    private var copyConfirmationToast: some View {
        if showCopyConfirmation {
            Label("Copied", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task {
                    try? await Task.sleep(for: .seconds(1.6))
                    withAnimation { showCopyConfirmation = false }
                }
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
                saveError = String(localized: "Saving failed.")
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
                        of: "- [ ] Write release notes",
                        with: "- [x] Write release notes"
                    )
                }
                // Startet direkt in der Text-auswählen-Ansicht (synthetische
                // Taps im Simulator sind unzuverlässig). Nur DEBUG.
                if ProcessInfo.processInfo.arguments.contains("-mdviewerSelectText") {
                    isSelectingText = true
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
                    // `.textSelection(.enabled)` here only gives a whole-block
                    // "Copy" on iOS, not real selection — the "Select Text"
                    // toolbar action switches to `SelectableTextView` for that.
                    // Kept for Mac Catalyst, where inline selection does work.
                    .textSelection(.enabled)
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
                Button("Cancel", systemImage: "xmark") {
                    if hasUnsavedChanges {
                        showDiscardConfirmation = true
                    } else {
                        discardEditing()
                    }
                }
                .disabled(isSaving)
                .accessibilityHint(isDraft
                                   ? "Discards the new document"
                                   : "Returns to the preview without keeping the changes")
            }
            ToolbarItem(placement: .cancellationAction) {
                // Step-by-step undo of individual typing bursts, in addition to
                // "Cancel" (discard everything).
                Button("Undo", systemImage: "arrow.uturn.backward") {
                    if let restored = undoHistory.undo() { editedText = restored }
                }
                .disabled(isSaving || !undoHistory.canUndo)
                .accessibilityHint("Undoes the last change")
            }
            if canSaveAsMarkdown {
                ToolbarItem(placement: .secondaryAction) {
                    Button("Save as Markdown", systemImage: "square.and.arrow.down") {
                        showExporter = true
                    }
                    .disabled(isSaving || editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Save", systemImage: "checkmark") {
                    if isDraft {
                        showExporter = true
                    } else {
                        showSaveConfirmation = true
                    }
                }
                .tint(.red)
                .disabled(!canSave)
                .accessibilityHint(isDraft
                                   ? "Saves the text as a new file"
                                   : "Overwrites the file with the edited text")
            }
        } else if isSelectingText {
            // Text-selection mode: the only way out is "Done" (or the X, which
            // also just returns to the rendered view — it does not close the
            // document from here).
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark") { isSelectingText = false }
                    .accessibilityHint("Returns to the rendered document")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Done") { isSelectingText = false }
            }
        } else {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark") { dismiss() }
                    .accessibilityHint("Closes the document")
            }
            if isLoaded {
                #if targetEnvironment(macCatalyst)
                // The Mac's default preview is already selectable; this toggles
                // to the full MarkdownUI rendering (bordered tables, syntax
                // highlighting, images) for reading, and back.
                ToolbarItem(placement: .primaryAction) {
                    Button(
                        showFormattedPreview ? "Selectable Text" : "Formatted View",
                        systemImage: showFormattedPreview ? "character.cursor.ibeam" : "doc.richtext"
                    ) {
                        showFormattedPreview.toggle()
                    }
                    .disabled(savedText.isEmpty)
                    .accessibilityHint(showFormattedPreview
                                       ? "Switches back to the selectable preview"
                                       : "Switches to the fully rendered preview with tables and images, which cannot be selected")
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("Select Text", systemImage: "character.cursor.ibeam") {
                        isSelectingText = true
                    }
                    .disabled(savedText.isEmpty)
                    .accessibilityHint("Switches to a plain-text view where a passage can be selected and copied")
                }
                #endif
                ToolbarItem(placement: .primaryAction) {
                    Button("Copy All", systemImage: "doc.on.doc") { copyAll() }
                        .disabled(savedText.isEmpty)
                        .accessibilityHint("Copies the whole document as plain text to the clipboard")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit", systemImage: "pencil") { beginEditing() }
                        .accessibilityHint("Edits the Markdown text")
                }
            }
        }
    }

    /// Puts the entire document on the pasteboard as plain text (Markdown
    /// syntax removed), matching what a reader would get by selecting all of
    /// the rendered text. Shows a brief confirmation because a programmatic
    /// pasteboard write is otherwise silent.
    ///
    /// - Precondition: `savedText` is non-empty (the button is disabled
    ///   otherwise).
    /// - Postcondition: `UIPasteboard.general.string` holds the plain-text
    ///   rendering of `savedText`.
    private func copyAll() {
        assert(!savedText.isEmpty, "copyAll precondition violated: nothing to copy")
        UIPasteboard.general.string = plainText(fromMarkdown: savedText)
        confirmCopied()
    }

    /// Shows the brief "Copied" toast and posts the VoiceOver announcement — a
    /// programmatic pasteboard write is otherwise silent. Shared by the "Copy
    /// All" button and, on the Mac, a ⌘C with no active selection in the
    /// selectable preview.
    private func confirmCopied() {
        withAnimation { showCopyConfirmation = true }
        UIAccessibility.post(notification: .announcement,
                             argument: String(localized: "Copied"))
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
            saveError = (error as? DocumentError)?.errorDescription ?? String(localized: "Saving failed.")
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

/// The document's text with Markdown syntax removed — headings lose their
/// `#`, emphasis and code markers are stripped, links collapse to their text.
/// It reads like the rendered text a reader sees and backs both "Copy All" and
/// the "Select Text" view.
///
/// `cmark`'s plain-text renderer handles inline markup and headings but leaves
/// two GFM constructs looking like source, so they are cleaned up here:
///   - task-list items keep their `[ ]` / `[x]` box — dropped, leaving a plain
///     `- ` bullet;
///   - tables come through as raw `|`-delimited rows including the `|---|`
///     divider — the divider is removed and the remaining rows are re-joined
///     with tabs so they still read as columns and paste into a spreadsheet.
///
/// Unit-tested in `PlainTextFromMarkdownTests`.
func plainText(fromMarkdown markdown: String) -> String {
    var text = MarkdownContent(flattenedMarkdownTables(in: markdown)).renderPlainText()
    text = text.replacingOccurrences(
        of: #"(?m)^(\s*[-*]\s+)\[[ xX]\]\s+"#,
        with: "$1",
        options: .regularExpression
    )
    return text
}

/// Rewrites GFM table blocks in `markdown` to tab-separated rows so `cmark`'s
/// plain-text renderer (which does not understand tables) does not emit them
/// verbatim with their pipes and `|---|` divider. A row is any line outside a
/// fenced code block that, trimmed, both starts and ends with `|`; the
/// alignment/divider row (cells containing only `-`, `:` and spaces) is
/// dropped. A trailing hard break keeps each row on its own line.
func flattenedMarkdownTables(in markdown: String) -> String {
    var inFence = false
    return markdown
        .components(separatedBy: "\n")
        .map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFence.toggle()
                return line
            }
            guard !inFence, trimmed.count > 1, trimmed.hasPrefix("|"), trimmed.hasSuffix("|") else {
                return line
            }
            let cells = trimmed.dropFirst().dropLast().components(separatedBy: "|")
            let isDivider = cells.allSatisfy { cell in
                let c = cell.trimmingCharacters(in: .whitespaces)
                return !c.isEmpty && c.allSatisfy { $0 == "-" || $0 == ":" }
            }
            if isDivider { return "" }
            return cells
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\t") + "  "
        }
        .joined(separator: "\n")
}

/// `.fileExporter` reports a user-cancelled dialog as a `CocoaError` on some
/// iOS versions even with an `onCancellation:` handler; treat that as a no-op.
private func isUserCancelled(_ error: Error) -> Bool {
    (error as? CocoaError)?.code == .userCancelled
}
