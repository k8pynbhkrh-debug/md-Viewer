import Highlightr
import MarkdownUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// `DocumentError`, `maxFileSize`, `loadMarkdown(from:)` and `saveMarkdown(text:to:)`
// live in Shared/MarkdownDocument.swift so the Share extension can reuse them.
// `DocumentSource`, `MarkdownFileDocument` and `suggestedFilename(from:)` are in
// MarkdownDraft.swift. Per-document state lives in `DocumentSession`, the tabs
// in `OpenDocumentsStore`.

struct DocumentView: View {
    /// The document shown — its content, editing state and undo history live
    /// there so they survive tab switches. This view only exists for the
    /// active tab; it is recreated (`.id(session.id)`) when the tab changes.
    let session: DocumentSession
    let store: OpenDocumentsStore
    /// Security-scoped bookmarks for folders granted access to, so relative
    /// image paths in the preview can resolve — see `ImageFolderAccess.swift`.
    /// Shared by all tabs.
    let imageAccessStore: ImageFolderAccessStore
    /// iPhone (compact width): shows the list of open documents. Presented by
    /// `DocumentWorkspaceView`, so it survives the active tab changing.
    var onShowDocumentList: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var highlightr = Highlightr()

    @State private var showSaveConfirmation = false
    @State private var showDiscardConfirmation = false
    @State private var showExporter = false
    /// Drives the brief "Copied" toast after the "Copy All" toolbar button.
    @State private var showCopyConfirmation = false
    @FocusState private var editorFocused: Bool

    /// Mac/iPad (regular width) show a tab bar once there is more than one
    /// document; the iPhone gets the document-list button instead.
    private var showsTabBar: Bool {
        horizontalSizeClass == .regular && store.documents.count > 1
    }

    private var showsDocumentListButton: Bool {
        horizontalSizeClass != .regular
    }

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

    private var savedText: String { session.savedText }
    private var documentFolderURL: URL? { session.documentFolderURL }

    var body: some View {
        @Bindable var session = session
        // No own NavigationStack: `DocumentWorkspaceView` hosts one for all
        // tabs, so a tab switch swaps only this content instead of building a
        // new navigation controller each time.
        documentContent
            .environment(imageAccessStore)
            .navigationTitle(session.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .overlay { savingOverlay }
            .overlay(alignment: .top) { copyConfirmationToast }
            .safeAreaInset(edge: .top, spacing: 0) {
                if showsTabBar {
                    DocumentTabBar(store: store)
                }
            }
        .alert("Error", isPresented: saveErrorBinding) {
            Button("OK", role: .cancel) { session.saveError = nil }
        } message: {
            Text(session.saveError ?? "")
        }
        .confirmationDialog(
            "Save Changes?",
            isPresented: $showSaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Save to File", role: .destructive) { Task { await session.saveInPlace() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The original file \(session.fileURL?.lastPathComponent ?? "") will be overwritten with the edited text.")
        }
        .confirmationDialog(
            session.isDraft ? "Discard Document?" : "Discard Changes?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { discardEditing() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(session.isDraft
                 ? "This document has not been saved yet and will be lost."
                 : "The changes have not been saved and will be lost.")
        }
        .fileExporter(
            isPresented: $showExporter,
            document: MarkdownFileDocument(text: session.editedText),
            contentType: markdownUTType,
            defaultFilename: suggestedFilename(from: session.editedText),
            onCompletion: handleExportResult
        )
        .onChange(of: colorScheme) { _, _ in applySyntaxTheme() }
        .task { load() }
    }

    @ViewBuilder
    private var documentContent: some View {
        switch session.content {
        case .none:
            ProgressView("Loading…")
        case .success:
            if session.isEditing {
                editor
            } else if session.isSelectingText {
                SelectableTextView(text: plainText(fromMarkdown: savedText))
            } else {
                #if targetEnvironment(macCatalyst)
                if session.showFormattedPreview {
                    preview(markdown: savedText)
                } else {
                    // Selectable Mac preview (mouse, ⌘A, ⌘C) — MarkdownUI's
                    // rendered output is not selectable under Catalyst. Reached
                    // via the toolbar toggle; the default is `preview`.
                    MarkdownAttributedText(
                        markdown: savedText,
                        plainTextForCopyAll: plainText(fromMarkdown: savedText),
                        documentFolderURL: documentFolderURL,
                        accessStore: imageAccessStore,
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
        if session.isSaving {
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
        Binding(get: { session.saveError != nil }, set: { if !$0 { session.saveError = nil } })
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            session.adoptSavedFile(at: url)
            store.sessionDidAdoptFile(session)
        case .failure(let error):
            if !isUserCancelled(error) {
                session.saveError = String(localized: "Saving failed.")
            }
        }
    }

    /// Loads the document on first display (restored tabs load lazily) and
    /// announces it to VoiceOver.
    private func load() {
        applySyntaxTheme()
        let wasLoaded = session.content != nil
        session.loadIfNeeded()
        guard !wasLoaded else { return }
        switch session.content {
        case .success:
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        case .failure(let error):
            UIAccessibility.post(notification: .announcement, argument: error.localizedDescription)
        case .none:
            break
        }
    }

    private var editor: some View {
        @Bindable var session = session
        return TextEditor(text: $session.editedText)
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
    }

    private func preview(markdown: String) -> some View {
        GeometryReader { geometry in
            ScrollView {
                Markdown(markdown, imageBaseURL: documentFolderURL)
                    .markdownImageProvider(AppImageProvider(documentFolderURL: documentFolderURL))
                    .markdownInlineImageProvider(AppInlineImageProvider(accessStore: imageAccessStore))
                    // Inline images load once per view identity and don't
                    // observe the store — re-create the rendering when folder
                    // grants change so a revoked folder's images disappear
                    // immediately (block images reload via their own task).
                    .id(imageAccessStore.revision)
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
                        Group {
                            if configuration.language?.lowercased() == "mermaid" {
                                MermaidDiagramView(
                                    source: configuration.content,
                                    fallback: AnyView(codeBlockContainer(configuration))
                                )
                            } else {
                                codeBlockContainer(configuration)
                            }
                        }
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

    /// The normal (non-Mermaid) fenced-code-block rendering: syntax-
    /// highlighted, horizontally scrollable, tinted panel. Shared between the
    /// default `codeBlock` style and Mermaid's fallback when a diagram fails
    /// to render.
    private func codeBlockContainer(_ configuration: CodeBlockConfiguration) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
        }
        .background(codeBlockBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// iPhone: opens the list of open documents (switch, close, new, open).
    @ToolbarContentBuilder
    private var documentListItem: some ToolbarContent {
        if showsDocumentListButton {
            ToolbarItem(placement: .cancellationAction) {
                Button("Open Documents", systemImage: "square.on.square") {
                    onShowDocumentList()
                }
                .accessibilityValue(Text("\(store.documents.count) open"))
                .accessibilityHint("Shows all open documents")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if session.isEditing {
            // Leading X = leave the editor WITHOUT keeping changes (confirmed if
            // any were made). For a draft this closes the document; for a file
            // it returns to the preview. Keeping changes is only ever the red
            // checkmark.
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", systemImage: "xmark") {
                    if session.hasUnsavedChanges {
                        showDiscardConfirmation = true
                    } else {
                        discardEditing()
                    }
                }
                .disabled(session.isSaving)
                .accessibilityHint(session.isDraft
                                   ? "Discards the new document"
                                   : "Returns to the preview without keeping the changes")
            }
            documentListItem
            ToolbarItem(placement: .cancellationAction) {
                // Step-by-step undo of individual typing bursts, in addition to
                // "Cancel" (discard everything).
                Button("Undo", systemImage: "arrow.uturn.backward") {
                    session.undo()
                }
                .disabled(session.isSaving || !session.canUndo)
                .accessibilityHint("Undoes the last change")
            }
            if session.canSaveAsMarkdown {
                ToolbarItem(placement: .secondaryAction) {
                    Button("Save as Markdown", systemImage: "square.and.arrow.down") {
                        showExporter = true
                    }
                    .disabled(session.isSaving || session.editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Save", systemImage: "checkmark") {
                    if session.isDraft {
                        showExporter = true
                    } else {
                        showSaveConfirmation = true
                    }
                }
                .tint(.red)
                .disabled(!session.canSave)
                .accessibilityHint(session.isDraft
                                   ? "Saves the text as a new file"
                                   : "Overwrites the file with the edited text")
            }
        } else if session.isSelectingText {
            // Text-selection mode: the only way out is "Done" (or the X, which
            // also just returns to the rendered view — it does not close the
            // document from here).
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark") { session.isSelectingText = false }
                    .accessibilityHint("Returns to the rendered document")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Done") { session.isSelectingText = false }
            }
        } else {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark") { store.userClose(session.id) }
                    .accessibilityHint("Closes the document")
            }
            documentListItem
            if session.isLoaded {
                #if targetEnvironment(macCatalyst)
                // The Mac opens in the full MarkdownUI rendering (bordered
                // tables, syntax highlighting, images); this toggles to the
                // selectable text preview for copying, and back.
                ToolbarItem(placement: .primaryAction) {
                    Button(
                        session.showFormattedPreview ? "Selectable Text" : "Formatted View",
                        systemImage: session.showFormattedPreview ? "character.cursor.ibeam" : "doc.richtext"
                    ) {
                        session.showFormattedPreview.toggle()
                    }
                    .disabled(savedText.isEmpty)
                    .accessibilityHint(session.showFormattedPreview
                                       ? "Switches to the selectable preview"
                                       : "Switches to the fully rendered preview with tables and images, which cannot be selected")
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("Select Text", systemImage: "character.cursor.ibeam") {
                        session.isSelectingText = true
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
                    Button("Edit", systemImage: "pencil") { session.beginEditing() }
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

    /// Leaves the editor without keeping the working copy (already confirmed
    /// by the user if there were changes). A discarded draft closes its tab.
    private func discardEditing() {
        if session.discardEditing() == .closeDocument {
            store.close(session.id, discardingChanges: true)
        }
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
