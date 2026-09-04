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

    #if targetEnvironment(macCatalyst)
    /// Ob md Viewer beim Erscheinen die Standard-App für `.md` ist. Wird nach
    /// einem erfolgreichen „Als Standard festlegen" auf `true` gesetzt.
    @State private var isDefaultMarkdownApp = DefaultMarkdownAppRegistration.isDefault
    /// Fehlertext des letzten „Als Standard festlegen"-Versuchs, treibt den Alert.
    @State private var defaultAppError: String?
    #endif

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

                    #if targetEnvironment(macCatalyst)
                    defaultAppRow
                        .padding(.top, 4)
                    #endif

                    Link("Datenschutz & Impressum", destination: privacyPolicyURL)
                        .font(.footnote)
                        .padding(.top, 8)
                }
                .padding()
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
        #if targetEnvironment(macCatalyst)
        .alert("Standard-App für .md", isPresented: defaultAppErrorBinding) {
            Button("OK", role: .cancel) { defaultAppError = nil }
        } message: {
            Text("""
            \(defaultAppError ?? "")

            Alternativ im Finder: eine .md-Datei auswählen, „Informationen“ (⌘I) \
            öffnen, unter „Öffnen mit“ md Viewer wählen und „Alle ändern …“.
            """)
        }
        #endif
    }

    #if targetEnvironment(macCatalyst)
    @ViewBuilder
    private var defaultAppRow: some View {
        if isDefaultMarkdownApp {
            Label("md Viewer ist Standard für .md-Dateien", systemImage: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Button {
                do {
                    try DefaultMarkdownAppRegistration.makeDefault()
                    isDefaultMarkdownApp = true
                } catch {
                    defaultAppError = (error as? LocalizedError)?.errorDescription
                        ?? "Die Zuordnung konnte nicht geändert werden."
                }
            } label: {
                Label("md Viewer als Standard für .md festlegen", systemImage: "doc.badge.gearshape")
            }
            .font(.subheadline)
            .accessibilityHint("Öffnet .md-Dateien künftig per Doppelklick in md Viewer")
        }
    }

    private var defaultAppErrorBinding: Binding<Bool> {
        Binding(get: { defaultAppError != nil }, set: { if !$0 { defaultAppError = nil } })
    }
    #endif
}

#Preview {
    ContentView()
}
