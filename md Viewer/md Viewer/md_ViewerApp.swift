//
//  md_ViewerApp.swift
//  md Viewer
//
//  Created by Eric Bertrand on 20.08.26.
//

import SwiftUI

@main
struct md_ViewerApp: App {
    /// The document currently presented over the empty state — either a file
    /// handed to us by the OS, or a new draft started from the empty state.
    @State private var document: DocumentSource?

    var body: some Scene {
        WindowGroup {
            ContentView { initialText in
                document = .draft(initialText: initialText)
            }
            .onOpenURL { url in
                document = .existing(url)
            }
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
    }
}
