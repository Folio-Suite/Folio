// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import XCTest

@MainActor
final class ResearchUITests: XCTestCase {
    func testAboutPanelReportsSuiteIdentity() {
        let testBundle = Bundle(for: Self.self)
        let version = testBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = testBundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        XCTAssertNotNil(version)
        XCTAssertNotNil(build)

        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.menuBars.menuBarItems["Research"].click()
        app.menuItems["About Research"].click()
        if let version, let build {
            XCTAssertTrue(app.staticTexts["Version \(version) (\(build))"].firstMatch.waitForExistence(timeout: 5))
        }
        app.terminate()
    }

    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
