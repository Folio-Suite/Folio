// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import XCTest

@MainActor final class WriteUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchDocument() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        app.typeKey("n", modifierFlags: .command)
        return app
    }

    private func attach(_ name: String, from app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testAboutPanelReportsSuiteIdentity() throws {
        let bundle = Bundle(for: Self.self)
        let version = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        let build = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        defer { app.terminate() }
        app.menuBars.menuBarItems["Write"].click()
        app.menuItems["About Write"].click()
        XCTAssertTrue(app.staticTexts["Version \(version) (\(build))"].firstMatch.waitForExistence(timeout: 5))
    }

    func testSemanticFormattingToolbarAndHelp() {
        let app = launchDocument()
        defer { app.terminate() }
        let text = app.textViews["manuscriptText"].firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.click()
        text.typeText("Formatting sample")
        text.typeKey("a", modifierFlags: .command)
        let emphasis = app.checkBoxes["Emphasis"].firstMatch
        XCTAssertTrue(emphasis.exists)
        emphasis.click()
        let semanticOn = String(describing: emphasis.value)
        XCUIElement.perform(withKeyModifiers: .option) { emphasis.click() }
        XCTAssertEqual(String(describing: emphasis.value), semanticOn)
        emphasis.click()
        XCTAssertNotEqual(String(describing: emphasis.value), semanticOn)
        app.toolbars.buttons["Appearance"].firstMatch.click()
        XCTAssertTrue(app.popovers.firstMatch.waitForExistence(timeout: 3))
        for label in ["Bold", "Italic", "Underline", "Strikethrough"] {
            let checkbox = app.popovers.checkBoxes[label].firstMatch
            XCTAssertTrue(checkbox.exists)
            let before = String(describing: checkbox.value)
            checkbox.click()
            XCTAssertNotEqual(String(describing: checkbox.value), before)
            XCTAssertTrue(app.popovers.firstMatch.exists)
        }
        attach("Appearance formatting popover", from: app)
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        app.toolbars.buttons["Formatting Help"].firstMatch.click()
        XCTAssertTrue(app.popovers.firstMatch.waitForExistence(timeout: 3))
        attach("Semantic formatting help", from: app)
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        text.click()
        text.typeKey("a", modifierFlags: .command)
        text.typeKey(XCUIKeyboardKey.delete, modifierFlags: [])
    }

    func testEditHistoryMenuOpensForForegroundWork() {
        let app = launchDocument()
        defer { app.terminate() }
        let text = app.textViews["manuscriptText"].firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.click()
        app.menuBars.menuBarItems["Edit"].click()
        app.menuItems["History…"].click()
        XCTAssertTrue(app.menuItems["Create Checkpoint…"].firstMatch.waitForExistence(timeout: 5),
            "The foreground Work must receive Edit > History")
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
    }

    func testFormattingConflictOffersConversionWithoutChangingWords() {
        let app = launchDocument()
        defer { app.terminate() }
        let text = app.textViews["manuscriptText"].firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.click()
        text.typeText("Keep these words")
        text.typeKey("a", modifierFlags: .command)
        text.typeKey("b", modifierFlags: [.command, .option])
        app.checkBoxes["Emphasis"].firstMatch.click()
        let marker = app.buttons["formattingConflictMarker"].firstMatch
        XCTAssertTrue(marker.waitForExistence(timeout: 3))
        XCTAssertEqual(text.value as? String, "Keep these words")
        text.typeKey(XCUIKeyboardKey.rightArrow, modifierFlags: [])
        attach("Inline semantic diagnostic", from: app)
        marker.click()
        let convert = app.buttons["Convert to Semantic Emphasis"].firstMatch
        XCTAssertTrue(convert.waitForExistence(timeout: 3))
        attach("Semantic presentation conflict", from: app)
        convert.click()
        XCTAssertFalse(convert.exists)
        XCTAssertFalse(marker.exists)
        XCTAssertEqual(text.value as? String, "Keep these words")
        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(marker.waitForExistence(timeout: 3))
        XCTAssertEqual(text.value as? String, "Keep these words")
        app.typeKey("z", modifierFlags: [.command, .shift])
        XCTAssertFalse(marker.exists)
        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(marker.waitForExistence(timeout: 3))
        marker.click()
        app.buttons["Keep Presentation / Dismiss"].firstMatch.click()
        XCTAssertFalse(marker.exists)
        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(marker.waitForExistence(timeout: 3))
        app.typeKey("z", modifierFlags: [.command, .shift])
        XCTAssertFalse(marker.exists)
        XCTAssertEqual(text.value as? String, "Keep these words")
        text.click()
        text.typeKey("a", modifierFlags: .command)
        text.typeKey(XCUIKeyboardKey.delete, modifierFlags: [])
    }

    func testNativeUndoRedoRestoresTypingDeletionAndSemanticControls() {
        let app = launchDocument()
        defer { app.terminate() }
        let text = app.textViews["manuscriptText"].firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.click()
        text.typeText("Undo these words")
        app.typeKey("z", modifierFlags: .command)
        XCTAssertEqual(text.value as? String, "")
        app.typeKey("z", modifierFlags: [.command, .shift])
        XCTAssertEqual(text.value as? String, "Undo these words")
        text.typeKey("a", modifierFlags: .command)
        let emphasis = app.checkBoxes["Emphasis"].firstMatch
        let off = String(describing: emphasis.value)
        emphasis.click()
        let enabledValue = String(describing: emphasis.value)
        XCTAssertNotEqual(enabledValue, off)
        app.typeKey("z", modifierFlags: .command)
        XCTAssertEqual(String(describing: emphasis.value), off)
        app.typeKey("z", modifierFlags: [.command, .shift])
        XCTAssertEqual(String(describing: emphasis.value), enabledValue)
        text.typeKey(XCUIKeyboardKey.delete, modifierFlags: [])
        XCTAssertEqual(text.value as? String, "")
        app.typeKey("z", modifierFlags: .command)
        XCTAssertEqual(text.value as? String, "Undo these words")
        app.typeKey("z", modifierFlags: [.command, .shift])
        XCTAssertEqual(text.value as? String, "")
    }

    func testManuscriptSidebarAddsRenamesSwitchesAndReordersUnits() {
        let app = launchDocument()
        defer { app.terminate() }
        let text = app.textViews["manuscriptText"].firstMatch
        let table = app.tables["manuscriptUnits"].firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertTrue(table.exists)
        text.click()
        text.typeText("First unit words")
        app.buttons["Add Content Unit"].firstMatch.click()
        let title = app.textFields["contentUnitTitle"].firstMatch
        title.typeText("Second Unit")
        title.typeKey(XCUIKeyboardKey.return, modifierFlags: [])
        XCTAssertEqual(table.tableRows.count, 2)
        XCTAssertEqual(text.value as? String, "")
        text.typeText("Second unit words")
        table.tableRows.element(boundBy: 0).click()
        XCTAssertEqual(text.value as? String, "First unit words")
        app.typeKey("z", modifierFlags: .command)
        XCTAssertEqual(text.value as? String, "")
        XCTAssertEqual(title.value as? String, "Second Unit")
        app.typeKey("z", modifierFlags: [.command, .shift])
        XCTAssertEqual(text.value as? String, "Second unit words")
        app.buttons["Move Content Unit Up"].firstMatch.click()
        XCTAssertFalse(app.buttons["Move Content Unit Up"].firstMatch.isEnabled)
        XCTAssertEqual(text.value as? String, "Second unit words")
        table.tableRows.element(boundBy: 1).click()
        XCTAssertEqual(text.value as? String, "First unit words")
        title.click()
        title.typeKey("a", modifierFlags: .command)
        title.typeText("First Unit")
        table.tableRows.element(boundBy: 0).click()
        XCTAssertEqual(text.value as? String, "Second unit words")
        XCTAssertEqual(title.value as? String, "Second Unit")
        table.tableRows.element(boundBy: 1).click()
        XCTAssertEqual(title.value as? String, "First Unit")
        attach("Manuscript sidebar with two Content Units", from: app)
        text.typeKey("a", modifierFlags: .command)
        text.typeKey(XCUIKeyboardKey.delete, modifierFlags: [])
        table.tableRows.element(boundBy: 0).click()
        text.typeKey("a", modifierFlags: .command)
        text.typeKey(XCUIKeyboardKey.delete, modifierFlags: [])
    }

    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) { XCUIApplication().launch() }
    }
}
