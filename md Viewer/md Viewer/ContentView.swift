//
//  ContentView.swift
//  md Viewer
//
//  Created by Eric Bertrand on 20.08.26.
//

import SwiftUI
import UIKit

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

                    Text("Open a Markdown file via Share or the Files app to view it here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    VStack(spacing: 12) {
                        #if targetEnvironment(macCatalyst)
                        // SwiftUI's `PasteButton` does not render under Mac
                        // Catalyst, so the empty state would otherwise have no
                        // way to start from clipboard text. This plain button
                        // reads the pasteboard only on an explicit tap, matching
                        // `PasteButton`'s privacy semantics.
                        Button {
                            onNewDocument(UIPasteboard.general.string ?? "")
                        } label: {
                            Label("Paste", systemImage: "doc.on.clipboard")
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .accessibilityHint("Creates a new document from the text on the clipboard")
                        #else
                        PasteButton(payloadType: String.self) { strings in
                            onNewDocument(strings.first ?? "")
                        }
                        .buttonBorderShape(.capsule)
                        .accessibilityHint("Creates a new document from the text on the clipboard")
                        #endif

                        Button {
                            onNewDocument("")
                        } label: {
                            Label("Blank Document", systemImage: "square.and.pencil")
                        }
                        .font(.subheadline)
                    }
                    .padding(.top, 4)

                    #if targetEnvironment(macCatalyst)
                    defaultAppRow
                        .padding(.top, 4)
                    #endif

                    Link("Privacy & Legal Notice", destination: privacyPolicyURL)
                        .font(.footnote)
                        .padding(.top, 8)
                }
                .padding()
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
        #if targetEnvironment(macCatalyst)
        .alert("Default App for .md Files", isPresented: defaultAppErrorBinding) {
            Button("OK", role: .cancel) { defaultAppError = nil }
        } message: {
            Text("\(defaultAppError ?? "")\n\n\(String(localized: "Alternatively, in the Finder: select a .md file, open Get Info (⌘I), choose md Viewer under Open with, and click Change All."))")
        }
        #endif
    }

    #if targetEnvironment(macCatalyst)
    @ViewBuilder
    private var defaultAppRow: some View {
        if isDefaultMarkdownApp {
            Label("md Viewer is the default for .md files", systemImage: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Button {
                do {
                    try DefaultMarkdownAppRegistration.makeDefault()
                    isDefaultMarkdownApp = true
                } catch {
                    defaultAppError = (error as? LocalizedError)?.errorDescription
                        ?? String(localized: "The file association could not be changed.")
                }
            } label: {
                Label("Set md Viewer as the default for .md", systemImage: "doc.badge.gearshape")
            }
            .font(.subheadline)
            .accessibilityHint("Opens .md files in md Viewer on double-click from now on")
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
