#if DEBUG
import Foundation
import UIKit

/// DEBUG-only launch hooks for the UI tests (`md ViewerUITests`). Synthetic
/// taps can't drive the system folder/file pickers reliably, so the tests
/// ask the app to set up its own fixtures instead:
///
/// - `-mdviewerUITestReset` — forget open tabs and folder grants and delete
///   earlier fixtures, before any store reads `UserDefaults`.
/// - `-mdviewerSeedFolders <a,b,…>` — create these folders in the app's
///   Documents/UITest directory and grant image access to each (what the
///   folder picker would do).
/// - `-mdviewerOpenFixture <plain|readonly|remote|image|large>` — write a
///   Markdown file (in UITest/doc-<kind>) and open it as a tab. `large` is
///   just above `LargeDocument.appThreshold` (shown as text); `readonly`
///   puts it in a write-protected folder, so saving must fail with a visible
///   error; `remote` adds an http(s) image without alt text; `image` adds a
///   local image "Testbild" next to it (grant access with
///   `-mdviewerSeedFolders doc-image`).
/// - `-mdviewerShareFixtures` — files for the Share-extension tests.
enum UITestSupport {
    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    private static func value(after flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    static var fixtureRoot: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UITest", isDirectory: true)
    }

    /// Must run before `OpenDocumentsStore` / `ImageFolderAccessStore` are
    /// created — they load their state in `init`.
    static func resetIfRequested() {
        guard arguments.contains("-mdviewerUITestReset") else { return }
        UserDefaults.standard.removeObject(forKey: OpenDocumentsStore.persistenceKey)
        UserDefaults.standard.removeObject(forKey: ImageFolderAccessStore.defaultsKey)
        makeWritable(fixtureRoot)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }

    static func applyFixtures(store: OpenDocumentsStore, imageAccessStore: ImageFolderAccessStore) {
        let fileManager = FileManager.default
        if let names = value(after: "-mdviewerSeedFolders") {
            for name in names.split(separator: ",").map(String.init) {
                let folder = fixtureRoot.appendingPathComponent(name, isDirectory: true)
                try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
                try? imageAccessStore.grantAccess(to: folder)
            }
        }
        if arguments.contains("-mdviewerShareFixtures") {
            writeShareFixtures()
        }
        if let kind = value(after: "-mdviewerOpenFixture") {
            let folder = fixtureRoot.appendingPathComponent("doc-\(kind)", isDirectory: true)
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appendingPathComponent("Fixture.md")
            let text: String
            switch kind {
            case "remote":
                text = "# Fixture\n\n![](https://example.com/x.png)\n\nOriginal text.\n"
            case "image":
                let png = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 80)).pngData { context in
                    UIColor.systemTeal.setFill()
                    context.fill(CGRect(x: 0, y: 0, width: 120, height: 80))
                }
                try? png.write(to: folder.appendingPathComponent("foto.png"))
                text = "# Fixture\n\n![Testbild](foto.png)\n\nOriginal text.\n"
            case "large":
                var large = "# Large fixture\n\n"
                while large.utf8.count <= LargeDocument.appThreshold {
                    large += "Paragraph with **bold** text and more words to fill the page.\n\n"
                }
                text = large
            default:
                text = "# Fixture\n\nOriginal text.\n"
            }
            try? text.write(to: file, atomically: true, encoding: .utf8)
            if kind == "readonly" {
                try? fileManager.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)
            }
            _ = store.open(file)
        }
    }

    /// Files for the Share-extension UI tests, in Documents/UITest/Share —
    /// visible in the Files app under "On My iPhone › md Viewer".
    private static func writeShareFixtures() {
        let folder = fixtureRoot.appendingPathComponent("Share", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        func write(_ name: String, _ data: Data) {
            try? data.write(to: folder.appendingPathComponent(name))
        }
        write("Empty.md", Data())
        // "# Grüße" in Latin-1 (ü = 0xFC, ß = 0xDF) — not valid UTF-8.
        write("Latin1.md", Data([0x23, 0x20, 0x47, 0x72, 0xFC, 0xDF, 0x65, 0x0A]))
        write("TooLarge.md", Data(repeating: UInt8(ascii: "a"), count: Int(maxFileSize) + 1))
        var long = "# Long document\n\n"
        while long.utf8.count < 4_500_000 {
            long += "Paragraph with **bold** text and more words to fill the page.\n\n"
        }
        long += "End of long document.\n"
        // For checking by hand only: XCUITest never finishes its snapshot of
        // a text view with ~70,000 paragraphs. The automated test uses Large.md.
        write("Long.md", Data(long.utf8))
        var large = "# Large document\n\n"
        while large.utf8.count <= 2 * LargeDocument.shareExtensionThreshold {
            large += "Paragraph with **bold** text and more words to fill the page.\n\n"
        }
        write("Large.md", Data(large.utf8))
        write("Remote.md", Data("# Remote image\n\n![](https://example.com/x.png)\n\nText after the image.\n".utf8))
        write("Normal.md", Data("# Shared note\n\nHello from the share test.\n".utf8))
    }

    /// Restores write permission below `url` so a reset can delete a
    /// write-protected fixture folder.
    private static func makeWritable(_ url: URL) {
        guard let enumerator = FileManager.default.enumerator(atPath: url.path) else { return }
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        for case let relative as String in enumerator {
            let path = url.appendingPathComponent(relative).path
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
                try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
            }
        }
    }
}
#endif
