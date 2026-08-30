import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Principal class of the Share extension.
///
/// When the user picks "md Viewer" from the share sheet for a Markdown file,
/// iOS instantiates this controller. It pulls the shared item out to a local
/// copy, renders it with the same `loadMarkdown(from:)` the app uses, and
/// shows the formatted document in a sheet — no bounce to the main app.
final class ShareViewController: UIViewController {

    /// Types we try to obtain a file representation for, in order of preference.
    private static let acceptedTypes: [UTType] = {
        var types: [UTType] = []
        types.append(UTType(importedAs: "net.daringfireball.markdown"))
        types.append(.plainText)
        types.append(.text)
        types.append(.data)
        return types
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        loadSharedDocument()
    }

    private func loadSharedDocument() {
        guard
            let item = extensionContext?.inputItems.first as? NSExtensionItem,
            let provider = item.attachments?.first,
            let type = Self.acceptedTypes.first(where: {
                provider.hasItemConformingToTypeIdentifier($0.identifier)
            })
        else {
            show(.failure(.notReadable), title: "Dokument")
            return
        }

        provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { [weak self] url, _ in
            let title = url?.lastPathComponent ?? "Dokument"
            let outcome: Result<String, DocumentError> = url.map(loadMarkdown(from:))
                ?? .failure(.notReadable)
            DispatchQueue.main.async {
                self?.show(outcome, title: title)
            }
        }
    }

    private func show(_ result: Result<String, DocumentError>, title: String) {
        let root = ShareMarkdownView(title: title, result: result) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }

        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)
    }
}
