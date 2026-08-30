import Highlightr
import MarkdownUI
import SwiftUI

// `DocumentError`, `maxFileSize` and `loadMarkdown(from:)` live in
// Shared/MarkdownDocument.swift so the Share extension can reuse them.

struct DocumentView: View {
    let fileURL: URL

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var content: Result<String, DocumentError>?
    @State private var highlightr = Highlightr()

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

    var body: some View {
        NavigationStack {
            Group {
                switch content {
                case .none:
                    ProgressView("Laden …")
                case .success(let markdown):
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
                        dismiss()
                    }
                    .accessibilityHint("Schließt das Dokument")
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
}
