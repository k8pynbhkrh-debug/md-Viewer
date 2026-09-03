//
//  ContentView.swift
//  md Viewer
//
//  Created by Eric Bertrand on 20.08.26.
//

import SwiftUI

/// Public URL of the privacy policy / Impressum page (hosted via GitHub Pages).
private let privacyPolicyURL = URL(string: "https://k8pynbhkrh-debug.github.io/md-Viewer/")!

struct ContentView: View {
    /// Called when the user starts a new document from the empty state — with
    /// pasted clipboard text, or `""` for an empty document.
    let onNewDocument: (String) -> Void

    init(onNewDocument: @escaping (String) -> Void = { _ in }) {
        self.onNewDocument = onNewDocument
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .imageScale(.large)
                        .font(.system(size: 44))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)

                    Text("md Viewer")
                        .font(.title2)
                        .bold()

                    Text("Öffne eine Markdown-Datei über „Teilen“ oder die Dateien-App, um sie hier anzuzeigen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    VStack(spacing: 12) {
                        PasteButton(payloadType: String.self) { strings in
                            onNewDocument(strings.first ?? "")
                        }
                        .buttonBorderShape(.capsule)
                        .accessibilityHint("Legt aus dem Text in der Zwischenablage ein neues Dokument an")

                        Button {
                            onNewDocument("")
                        } label: {
                            Label("Leeres Dokument", systemImage: "square.and.pencil")
                        }
                        .font(.subheadline)
                    }
                    .padding(.top, 4)

                    Link("Datenschutz & Impressum", destination: privacyPolicyURL)
                        .font(.footnote)
                        .padding(.top, 8)
                }
                .padding()
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
    }
}

#Preview {
    ContentView()
}
