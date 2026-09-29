//
//  md_ViewerApp.swift
//  md Viewer
//
//  Created by Eric Bertrand on 20.08.26.
//

import SwiftUI
import UniformTypeIdentifiers

@main
struct md_ViewerApp: App {
    /// The document currently presented over the empty state — either a file
    /// handed to us by the OS, or a new draft started from the empty state.
    @State private var document: DocumentSource?

    /// App-wide folder grants for relative images — one instance, so revoking
    /// a folder in "Folder Access" also affects an open document.
    @State private var folderAccessStore = ImageFolderAccessStore()
    @State private var showFolderAccess = false

    #if targetEnvironment(macCatalyst)
    /// Drives the "Öffnen …" menu command's file dialog (Mac only — on iOS the
    /// system opens files via the Files app / "Teilen" instead).
    @State private var showOpenDialog = false
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView(
                onNewDocument: { initialText in
                    document = .draft(initialText: initialText)
                },
                onManageFolderAccess: { showFolderAccess = true }
            )
            .environment(folderAccessStore)
            // Two presentation anchors for the same sheet: the start screen,
            // or — Mac menu while a document is open — the document cover,
            // since the root can't present while the cover is up.
            .sheet(isPresented: folderAccessBinding(whileDocumentOpen: false)) {
                FolderAccessView().environment(folderAccessStore)
            }
            .onOpenURL { url in
                document = .existing(url)
            }
            #if targetEnvironment(macCatalyst)
            .fileImporter(
                isPresented: $showOpenDialog,
                allowedContentTypes: [markdownUTType, .plainText]
            ) { result in
                if case .success(let url) = result {
                    document = .existing(url)
                }
            }
            #endif
            .fullScreenCover(item: $document) { source in
                DocumentView(source: source)
                    .id(source.id)
                    .environment(folderAccessStore)
                    .sheet(isPresented: folderAccessBinding(whileDocumentOpen: true)) {
                        FolderAccessView().environment(folderAccessStore)
                    }
            }
            #if targetEnvironment(macCatalyst)
            // Fenster frei skalierbar machen. Ohne das `.frame` leitet SwiftUI
            // die Maximalgröße aus der „idealen" Größe des Inhalts ab (der
            // GeometryReader im Empty State meldet eine kleine feste Größe) —
            // das Fenster ließ sich dann nur verkleinern und nie über ~924×662
            // hinaus vergrößern. `.windowResizability` und `.defaultSize` dürfen
            // NICHT gesetzt sein: beide reaktivieren unter Mac Catalyst genau
            // diese Deckelung. Die Startgröße bestimmt macOS und merkt sie sich.
            .frame(minWidth: 480, idealWidth: 1080, maxWidth: .infinity,
                   minHeight: 400, idealHeight: 760, maxHeight: .infinity)
            #endif
            #if DEBUG
            // Screenshot-/Smoke-Test-Hook: „-mdviewerDraft <text>" öffnet beim
            // Start direkt einen Entwurf (die Zwischenablage lässt sich im
            // Simulator nicht zuverlässig per Skript in den PasteButton bringen),
            // „-mdviewerFolderAccess" die Ordnerzugriffe. Nur DEBUG.
            .task {
                let args = ProcessInfo.processInfo.arguments
                if let i = args.firstIndex(of: "-mdviewerDraft") {
                    document = .draft(initialText: i + 1 < args.count ? args[i + 1] : "")
                }
                if args.contains("-mdviewerFolderAccess") {
                    showFolderAccess = true
                }
            }
            #endif
        }
        #if targetEnvironment(macCatalyst)
        .commands {
            // Ersetzt das Standard-„Ablage → Neu": md Viewer hat genau ein
            // Fenster, „Neu" startet einen Entwurf, „Öffnen …" einen Dateidialog.
            CommandGroup(replacing: .newItem) {
                Button("New Document") {
                    document = .draft(initialText: "")
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Open…") {
                    showOpenDialog = true
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .appSettings) {
                Button("Folder Access…") {
                    showFolderAccess = true
                }
            }
        }
        #endif
    }

    private func folderAccessBinding(whileDocumentOpen: Bool) -> Binding<Bool> {
        Binding(
            get: { showFolderAccess && (document != nil) == whileDocumentOpen },
            set: { showFolderAccess = $0 }
        )
    }
}
