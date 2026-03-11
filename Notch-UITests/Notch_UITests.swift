//
//  Notch_UITests.swift
//  Notch-UITests
//
//  Created by Jonas Knüppel on 09.03.26.
//

import XCTest

final class Notch_UITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testShellLaunchesAndCanOpen() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.otherElements["shell-root"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["shell-open-button"].waitForExistence(timeout: 2))

        app.buttons["shell-open-button"].click()

        XCTAssertTrue(app.staticTexts["shell-open-title"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
