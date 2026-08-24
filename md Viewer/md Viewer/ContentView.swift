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
    var body: some View {
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

            Link("Datenschutz & Impressum", destination: privacyPolicyURL)
                .font(.footnote)
                .padding(.top, 8)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
