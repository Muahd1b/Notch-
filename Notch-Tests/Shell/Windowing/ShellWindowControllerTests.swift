import AppKit
import Testing
@testable import Notch_

@MainActor
struct ShellWindowControllerTests {
    @Test
    func closedStateTracksNotchAlignedHoverBand() throws {
        let defaults = UserDefaults(suiteName: "ShellWindowControllerTests-\(UUID().uuidString)")!
        let settingsStore = AppSettingsStore(defaults: defaults)
        let viewModel = ShellViewModel(statusSnapshot: .phaseZero, settingsStore: settingsStore)
        let controller = ShellWindowController(
            display: .notchedPrimary,
            viewModel: viewModel,
            geometryResolver: ShellGeometryResolver(),
            hapticsService: HapticsService(settingsStore: settingsStore),
            settingsStore: settingsStore
        )

        controller.showWindow()

        let panel = try #require(controller.window as? ShellPanel)
        #expect(panel.currentTrackingRect == CGRect(x: 202, y: 178, width: 276, height: 32))
    }
}

private extension ShellDisplay {
    static let notchedPrimary = ShellDisplay(
        id: "primary",
        cgDisplayID: 1,
        geometry: ScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: CGRect(x: 0, y: 28, width: 1512, height: 954),
            safeAreaInsets: NSEdgeInsets(top: 32, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftWidth: 620,
            auxiliaryTopRightWidth: 620
        )
    )
}
