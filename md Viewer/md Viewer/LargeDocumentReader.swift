import SwiftUI

/// The reader for a document above `LargeDocument.appThreshold`: its raw text
/// with the notice on top (see `DocumentSession.showsLargeDocumentAsText`).
/// Searchable like the "Select Text" view; "Show Formatted" switches this tab
/// to the normal rendering after a warning.
struct LargeDocumentReader: View {
    let session: DocumentSession
    let find: TextFindHooks

    @State private var confirmsFormatting = false

    var body: some View {
        VStack(spacing: 0) {
            LargeDocumentNotice { confirmsFormatting = true }
            LargeDocumentTextView(
                text: session.savedText,
                makeTextView: { FindableTextView() },
                update: { ($0 as? FindableTextView)?.findHooks = find }
            )
        }
        .confirmationDialog(
            "Show Formatted?",
            isPresented: $confirmsFormatting,
            titleVisibility: .visible
        ) {
            Button("Show Formatted Anyway") { session.formatLargeDocumentAnyway() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Formatting a document this large can take a long time. The app does not respond until it is done.")
        }
    }
}
