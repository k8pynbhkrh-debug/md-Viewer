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
    /// The open documents (tabs). Files handed to us by the OS, "Open…" and
    /// new drafts all land here as tabs; open files are restored on launch.
    @State private var store = OpenDocumentsStore()
    /// Folder access grants for relative images — shared by all tabs.
    @State private var imageAccessStore = ImageFolderAccessStore()

    var body: some Scene {
        WindowGroup {
            DocumentWorkspaceView(store: store, imageAccessStore: imageAccessStore)
            .onOpenURL { url in
                // A new tab — or the existing one if that file is already
                // open. Never replaces the document being worked on.
                store.open(url)
            }
            .fileImporter(
                isPresented: $store.isPresentingOpenDialog,
                allowedContentTypes: [markdownUTType, .plainText],
                allowsMultipleSelection: true
            ) { result in
                if case .success(let urls) = result {
                    for url in urls { store.open(url) }
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
            // Simulator nicht zuverlässig per Skript in den PasteButton bringen).
            // Nur DEBUG.
            .task {
                let args = ProcessInfo.processInfo.arguments
                if let i = args.firstIndex(of: "-mdviewerDraft") {
                    store.newDraft(text: i + 1 < args.count ? args[i + 1] : "")
                }
            }
            #endif
        }
        .commands {
            // Ersetzt das Standard-„Ablage → Neu": md Viewer hat genau ein
            // Fenster mit Tabs; „Neu" startet einen Entwurf, „Öffnen …" einen
            // Dateidialog — beides als neuer Tab. Auf dem iPad greifen die
            // Kurzbefehle mit Hardware-Tastatur.
            CommandGroup(replacing: .newItem) {
                Button("New Document") {
                    store.newDraft(text: "")
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Open…") {
                    store.isPresentingOpenDialog = true
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("Close Tab") {
                    if let id = store.activeID { store.userClose(id) }
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(store.activeID == nil)
            }
            CommandGroup(after: .windowArrangement) {
                Button("Show Next Tab") { store.activateNeighbor(offset: 1) }
                    .keyboardShortcut(.tab, modifiers: .control)
                    .disabled(store.documents.count < 2)
                Button("Show Previous Tab") { store.activateNeighbor(offset: -1) }
                    .keyboardShortcut(.tab, modifiers: [.control, .shift])
                    .disabled(store.documents.count < 2)
            }
        }
    }
}
