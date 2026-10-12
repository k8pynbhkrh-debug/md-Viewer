import XCTest

/// Drives the Share extension the way a user does: Files app → long-press a
/// file → Share → md Viewer. The fixture files come from the app's DEBUG
/// hook `-mdviewerShareFixtures` (Documents/UITest/Share, visible in Files
/// under "On My iPhone › md Viewer"). Expects the simulator's system
/// language to be English (the extension doesn't get launch arguments).
final class ShareExtensionUITests: XCTestCase {
    private let files = XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")

    override class func setUp() {
        super.setUp()
        let app = XCUIApplication()
        app.launchArguments = ["-mdviewerUITestReset", "-mdviewerShareFixtures"]
        app.launch()
        _ = app.buttons["Folder Access"].waitForExistence(timeout: 15)
        app.terminate()
    }

    override func setUp() {
        continueAfterFailure = false
    }

    private func cell(_ prefix: String) -> XCUIElement {
        files.cells.matching(NSPredicate(format: "label BEGINSWITH %@", prefix + ",")).firstMatch
    }

    private func tapCell(_ prefix: String) {
        let target = cell(prefix)
        XCTAssertTrue(target.waitForExistence(timeout: 10), "no \(prefix) in Files")
        // The icon, not the name — tapping the name starts renaming.
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
    }

    /// Navigates Files to Documents/UITest/Share — unless it is already
    /// there (Files remembers the last folder across launches).
    private func goToFixtures() {
        files.launch()
        if cell("Normal").waitForExistence(timeout: 5) { return }
        let browse = files.tabBars.buttons["Browse"]
        XCTAssertTrue(browse.waitForExistence(timeout: 10))
        browse.tap()
        browse.tap() // back to the root of "Browse"
        let onPhone = files.staticTexts["On My iPhone"].firstMatch
        XCTAssertTrue(onPhone.waitForExistence(timeout: 10))
        onPhone.tap()
        tapCell("md Viewer")
        tapCell("UITest")
        tapCell("Share")
    }

    /// Opens `fileName` (without extension) in the Share extension.
    private func share(_ fileName: String) {
        goToFixtures()
        let file = cell(fileName)
        XCTAssertTrue(file.waitForExistence(timeout: 10), "no \(fileName) in Files")
        let target = files.cells["md Viewer"].firstMatch
        for _ in 1...3 {
            file.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).press(forDuration: 1.5)
            let shareItem = files.buttons["Share"].firstMatch
            guard shareItem.waitForExistence(timeout: 5) else { continue }
            shareItem.tap()
            if target.waitForExistence(timeout: 20) { break }
            // Share sheet came up without the app row yet — close and retry.
            files.swipeDown()
        }
        XCTAssertTrue(target.exists, "md Viewer missing in the share sheet")
        target.tap()
    }

    private func expectText(containing text: String, timeout: TimeInterval = 15,
                            file: StaticString = #filePath, line: UInt = #line) {
        let match = files.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)).firstMatch
        let found = match.waitForExistence(timeout: timeout)
        if !found { print("SHARE-DUMP-START\n\(files.debugDescription)\nSHARE-DUMP-END") }
        XCTAssertTrue(found, "not shown: \(text)", file: file, line: line)
    }

    private func closeExtension() {
        let done = files.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 5) { done.tap() }
        files.terminate()
    }

    func testNormalFileIsShown() {
        share("Normal")
        expectText(containing: "Hello from the share test.")
        closeExtension()
    }

    func testEmptyFileShowsError() {
        share("Empty")
        expectText(containing: "The file is empty.")
        closeExtension()
    }

    func testNonUTF8FileShowsError() {
        share("Latin1")
        expectText(containing: "Only UTF-8 encoded files are supported.")
        closeExtension()
    }

    func testTooLargeFileShowsError() {
        share("TooLarge")
        expectText(containing: "The maximum supported size is 5 MB.")
        closeExtension()
    }

    /// T-2026-328: a file above `LargeDocument.shareExtensionThreshold` is
    /// shown as plain text with a notice instead of being formatted (a 4.5 MB
    /// file used to leave the sheet blank). Large.md is twice the threshold;
    /// the 4.5 MB Long.md is for checking by hand — XCUITest's snapshot of a
    /// text view that long never finishes.
    func testLargeFileIsShownAsText() {
        share("Large")
        let notice = files.staticTexts["Large document – shown as text"].firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 15), "no large-document notice")
        let text = files.textViews["largeDocumentText"].firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 5), "no text view for the large document")
        sleep(3)
        // Still there (not killed for memory) and still responsive.
        XCTAssertTrue(notice.exists)
        let done = files.buttons["Done"].firstMatch
        XCTAssertTrue(done.isHittable, "Done is not reachable")
        done.tap()
        XCTAssertTrue(notice.waitForNonExistence(timeout: 5), "sheet did not close")
        files.terminate()
    }

    func testRemoteImageIsNotLoaded() {
        share("Remote")
        expectText(containing: "Text after the image.")
        // Also what VoiceOver announces (the placeholder's accessibility value).
        expectText(containing: "External image – not loaded")
        closeExtension()
    }
}
