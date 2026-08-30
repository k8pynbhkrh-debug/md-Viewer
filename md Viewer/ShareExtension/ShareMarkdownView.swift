import MarkdownUI
import SwiftUI

/// Renders the shared Markdown document inside the share sheet.
///
/// A deliberately lean cousin of the app's `DocumentView`: no syntax
/// highlighting engine (keeps the extension well inside its memory budget),
/// but the same wide-table handling and full-width layout.
struct ShareMarkdownView: View {
    let title: String
    let result: Result<String, DocumentError>

    /// Called when the user taps "Fertig"; the controller completes the
    /// extension request.
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch result {
                case .success(let markdown):
                    ScrollView {
                        Markdown(markdown)
                            .markdownBlockStyle(\.table) { configuration in
                                ScrollView(.horizontal, showsIndicators: true) {
                                    configuration.label
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .markdownMargin(top: 0, bottom: 16)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical)
                    }
                case .failure(let error):
                    ContentUnavailableView {
                        Label("Fehler", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error.localizedDescription)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig", action: onDone)
                }
            }
        }
    }
}
