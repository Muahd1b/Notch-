import XCTest

final class ShellUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testShellLaunchesAndOpensSettingsFromSymbolBar() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-mode", "-uitest-open-shell"]
        app.launch()

        let shellRoot = app.descendants(matching: .any)["shell-root"]
        let settingsButton = app.descendants(matching: .any)["shell-settings-button"]
        let settingsRoot = app.descendants(matching: .any)["settings-root"]

        XCTAssertTrue(shellRoot.waitForExistence(timeout: 10))
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))

        settingsButton.click()

        XCTAssertTrue(settingsRoot.waitForExistence(timeout: 10))
    }

    @MainActor
    func testOpenShellRendersCalendarLocalhostAndHabitsPages() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-mode", "-uitest-open-shell"]
        app.launch()

        let calendarTab = app.descendants(matching: .any)["shell-calendar-tab"]
        let focusTab = app.descendants(matching: .any)["shell-focus-tab"]
        let localhostTab = app.descendants(matching: .any)["shell-localhost-tab"]
        let habitsTab = app.descendants(matching: .any)["shell-habits-tab"]

        XCTAssertTrue(calendarTab.waitForExistence(timeout: 10))
        XCTAssertTrue(focusTab.waitForExistence(timeout: 10))
        XCTAssertTrue(localhostTab.waitForExistence(timeout: 10))
        XCTAssertTrue(habitsTab.waitForExistence(timeout: 10))

        calendarTab.click()
        XCTAssertTrue(app.descendants(matching: .any)["shell-calendar-page"].waitForExistence(timeout: 5))

        focusTab.click()
        XCTAssertTrue(app.descendants(matching: .any)["shell-focus-page"].waitForExistence(timeout: 5))

        localhostTab.click()
        XCTAssertTrue(app.descendants(matching: .any)["shell-localhost-page"].waitForExistence(timeout: 5))

        habitsTab.click()
        XCTAssertTrue(app.descendants(matching: .any)["shell-habits-page"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        throw XCTSkip("Launch performance testing is disabled during notch-shell UI iteration.")
    }
}
