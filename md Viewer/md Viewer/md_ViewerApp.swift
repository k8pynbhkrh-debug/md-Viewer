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

    #if targetEnvironment(macCatalyst)
    /// Drives the "Öffnen …" menu command's file dialog (Mac only — on iOS the
    /// system opens files via the Files app / "Teilen" instead).
    @State private var showOpenDialog = false
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView { initialText in
                document = .draft(initialText: initialText)
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
            }
            #if DEBUG
            // Screenshot-/Smoke-Test-Hook: „-mdviewerDraft <text>" öffnet beim
            // Start direkt einen Entwurf (die Zwischenablage lässt sich im
            // Simulator nicht zuverlässig per Skript in den PasteButton bringen).
            // Nur DEBUG.
            .task {
                let args = ProcessInfo.processInfo.arguments
                if let i = args.firstIndex(of: "-mdviewerDraft") {
                    document = .draft(initialText: i + 1 < args.count ? args[i + 1] : "")
                }
            }
            #endif
        }
        #if targetEnvironment(macCatalyst)
        .defaultSize(width: 1200, height: 820)
        .windowResizability(.contentMinSize)
        .commands {
            // Ersetzt das Standard-„Ablage → Neu": md Viewer hat genau ein
            // Fenster, „Neu" startet einen Entwurf, „Öffnen …" einen Dateidialog.
            CommandGroup(replacing: .newItem) {
                Button("Neues Dokument") {
                    document = .draft(initialText: "")
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Öffnen …") {
                    showOpenDialog = true
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
        #endif
    }
}
