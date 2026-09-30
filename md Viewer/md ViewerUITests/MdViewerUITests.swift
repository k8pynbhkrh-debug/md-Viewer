import XCTest

/// End-to-end checks that need real taps: "Folder Access" (list, swipe to
/// remove, remove all, reachable from the start screen and — on the iPhone —
/// from the open-documents list) and the visible save paths (success, and a
/// failure that must show an error and keep the edit).
///
/// The app sets up its own fixtures via DEBUG launch arguments (see
/// `UITestSupport.swift`), because the system folder/file pickers can't be
/// driven reliably. UI language is forced to English so labels are stable.
final class MdViewerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(reset: Bool = true, extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
            + (reset ? ["-mdviewerUITestReset"] : []) + extra
        app.launch()
    }

    private func waitFor(_ element: XCUIElement, _ timeout: TimeInterval = 10,
                         file: StaticString = #filePath, line: UInt = #line) {
        let found = element.waitForExistence(timeout: timeout)
        if !found { print("UI-DUMP-START\n\(app.debugDescription)\nUI-DUMP-END") }
        XCTAssertTrue(found, "missing: \(element)", file: file, line: line)
    }

    /// The confirmation-dialog button, not the list row with the same label.
    private func confirm(_ label: String) {
        let inSheet = app.sheets.buttons[label]
        if inSheet.waitForExistence(timeout: 3) {
            inSheet.tap()
        } else {
            let all = app.buttons.matching(identifier: label)
            waitFor(all.element(boundBy: max(all.count - 1, 0)))
            all.element(boundBy: all.count - 1).tap()
        }
    }

    // MARK: - Folder Access

    /// Taps "Folder Access" until its sheet is up. Records how many taps it
    /// took — more than one would mean the first tap was swallowed.
    @discardableResult
    private func openFolderAccess(file: StaticString = #filePath, line: UInt = #line) -> Int {
        let button = app.buttons["Folder Access"]
        waitFor(button, file: file, line: line)
        let title = app.navigationBars["Folder Access"]
        for attempt in 1...3 {
            button.tap()
            if title.waitForExistence(timeout: 4) {
                print("FOLDER-ACCESS-TAPS \(attempt)")
                return attempt
            }
        }
        waitFor(title, 1, file: file, line: line)
        return 0
    }


    func testFolderAccessListsOnlyFolderNames() {
        launch(extra: ["-mdviewerSeedFolders", "Alpha,Beta"])
        openFolderAccess()
        waitFor(app.staticTexts["Alpha"])
        XCTAssertTrue(app.staticTexts["Beta"].exists)
        let pathLike = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '/'"))
        XCTAssertEqual(pathLike.count, 0, "a folder path is shown instead of just the name")
    }

    func testSwipeRemovesOneFolder() {
        launch(extra: ["-mdviewerSeedFolders", "Alpha,Beta"])
        openFolderAccess()
        let alpha = app.staticTexts["Alpha"]
        waitFor(alpha)
        alpha.swipeLeft()
        let delete = app.buttons["Delete"]
        waitFor(delete, 3)
        delete.tap()
        XCTAssertTrue(alpha.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Beta"].exists)
    }

    func testRemoveAllAsksFirstAndPersistsAcrossRelaunch() {
        launch(extra: ["-mdviewerSeedFolders", "Alpha,Beta"])
        openFolderAccess()
        waitFor(app.staticTexts["Alpha"])

        app.buttons["Remove All"].tap()
        waitFor(app.staticTexts["Remove access to all folders?"], 3)
        confirm("Remove All")

        waitFor(app.staticTexts["No Folders Shared"])
        XCTAssertFalse(app.staticTexts["Alpha"].exists)

        // Revocation is stored, not just hidden.
        app.terminate()
        launch(reset: false)
        openFolderAccess()
        waitFor(app.staticTexts["No Folders Shared"])
    }

    func testFolderAccessReachableFromDocumentListWhileDocumentOpen() throws {
        launch(extra: ["-mdviewerSeedFolders", "Alpha", "-mdviewerOpenFixture", "plain"])
        let listButton = app.buttons["Open Documents"]
        guard listButton.waitForExistence(timeout: 10) else {
            throw XCTSkip("no document-list button (regular width) — Mac/iPad use the menu")
        }
        let listTitle = app.navigationBars["Open Documents"]
        var taps = 0
        repeat {
            taps += 1
            listButton.tap()
        } while !listTitle.waitForExistence(timeout: 4) && taps < 3
        print("OPEN-DOCUMENTS-TAPS \(taps)")
        waitFor(listTitle, 1)
        let entry = app.buttons["Folder Access"]
        waitFor(entry)
        entry.tap()
        waitFor(app.staticTexts["Alpha"])
    }

    // MARK: - Images

    /// Revoking the folder while its document is open replaces the image by
    /// the "Choose Folder" placeholder right away.
    func testRevokingFolderHidesItsImageImmediately() throws {
        launch(extra: ["-mdviewerSeedFolders", "doc-image", "-mdviewerOpenFixture", "image"])
        waitFor(app.images["Testbild"], 15)
        // The real image, not the "folder access needed" placeholder.
        XCTAssertFalse(app.images["folder.badge.questionmark"].exists)

        let listButton = app.buttons["Open Documents"]
        guard listButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("no document-list button (regular width)")
        }
        listButton.tap()
        waitFor(app.navigationBars["Open Documents"])
        app.buttons["Folder Access"].tap()
        waitFor(app.staticTexts["doc-image"])
        app.buttons["Remove All"].tap()
        confirm("Remove All")
        waitFor(app.staticTexts["No Folders Shared"])
        app.buttons["Done"].tap()

        // Placeholder instead of the image. MarkdownUI labels the whole image
        // slot with the alt text, so the button is found by its value.
        waitFor(app.buttons.matching(NSPredicate(format: "value == %@", "Choose Folder")).firstMatch)
        XCTAssertTrue(app.images["folder.badge.questionmark"].exists)
    }

    /// A remote image shows the "not loaded" placeholder, and VoiceOver
    /// announces it (MarkdownUI would otherwise blank the label for an image
    /// without alt text).
    func testRemoteImagePlaceholderIsShownAndAnnounced() {
        launch(extra: ["-mdviewerOpenFixture", "remote"])
        waitFor(app.staticTexts["Original text."])
        let placeholder = app.staticTexts.matching(
            NSPredicate(format: "value == %@", "External image – not loaded")).firstMatch
        waitFor(placeholder)
    }

    // MARK: - Saving

    private func editAndSave(appending text: String) {
        let edit = app.buttons["Edit"]
        waitFor(edit)
        edit.tap()
        let editor = app.textViews.firstMatch
        waitFor(editor)
        editor.tap()
        editor.typeText(text)
        app.buttons["Save"].tap()
        confirm("Save to File")
    }

    func testSaveWritesTheFile() {
        launch(extra: ["-mdviewerOpenFixture", "plain"])
        waitFor(app.staticTexts["Original text."])
        editAndSave(appending: " Added line.")
        // Back in the preview, showing the saved text; no error.
        waitFor(app.buttons["Edit"])
        XCTAssertFalse(app.alerts["Error"].exists)
        let saved = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Added line.'"))
        XCTAssertGreaterThan(saved.count, 0)
    }

    func testSaveFailureShowsErrorAndKeepsTheEdit() {
        launch(extra: ["-mdviewerOpenFixture", "readonly"])
        waitFor(app.staticTexts["Original text."])
        editAndSave(appending: " Unsaved words.")

        let alert = app.alerts["Error"]
        waitFor(alert)
        alert.buttons["OK"].tap()

        // Still editing, the typed text is not lost.
        waitFor(app.buttons["Save"])
        let editor = app.textViews.firstMatch
        XCTAssertTrue((editor.value as? String ?? "").contains("Unsaved words."))
    }
}
