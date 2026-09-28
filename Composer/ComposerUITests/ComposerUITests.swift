// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import XCTest

@MainActor
final class ComposerUITests: XCTestCase {
    func testControlledCompositionPreviewIsVisible() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        defer { app.terminate() }
        let preview = app.groups["compositionPreview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        XCTAssertEqual(preview.label, "Composition preview")
        XCTAssertEqual(preview.value as? String,
            "Folio composes authored text.Source identity stays with the publication.")
        XCTAssertTrue(app.menuBars.menuBarItems["Window"].exists)
    }

    func testAboutPanelReportsSuiteIdentity() throws {
        let bundle = Bundle(for: Self.self)
        let version = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        let build = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        defer { app.terminate() }
        app.menuBars.menuBarItems["Composer"].click()
        app.menuItems["About Composer"].click()
        XCTAssertTrue(app.staticTexts["Version \(version) (\(build))"].firstMatch.waitForExistence(timeout: 5))
    }
}
