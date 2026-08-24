//
//  md_ViewerApp.swift
//  md Viewer
//
//  Created by Eric Bertrand on 20.08.26.
//

import SwiftUI

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

@main
struct md_ViewerApp: App {
    @State private var fileURL: URL?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    fileURL = url
                }
                .fullScreenCover(item: $fileURL) { url in
                    DocumentView(fileURL: url)
                }
        }
    }
}
