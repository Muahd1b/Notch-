import AppKit
import Foundation
import Testing
@testable import Notch_

@MainActor
struct ShellCoordinatorTests {
    @Test
    func startCreatesWindowForPreferredDisplay() {
        let displayProvider = TestDisplayProvider(display: .notchedPrimary)
        let windowController = TestWindowController()
        let coordinator = ShellCoordinator(
            viewModel: ShellViewModel(),
            geometryResolver: ShellGeometryResolver(),
            hapticsService: HapticsService(),
            displayProvider: displayProvider,
            applicationNotificationCenter: NotificationCenter(),
            workspaceNotificationCenter: NotificationCenter(),
            dispatchToMainActor: runSynchronouslyOnMainActor,
            windowControllerFactory: { display, _, _, _ in
                windowController.createdDisplay = display
                return windowController
            }
        )

        coordinator.start()

        #expect(windowController.showWindowCallCount == 1)
        #expect(windowController.createdDisplay == .notchedPrimary)
    }

    @Test
    func screenParameterChangesUpdateTargetDisplay() {
        let appCenter = NotificationCenter()
        let displayProvider = TestDisplayProvider(display: .notchedPrimary)
        let windowController = TestWindowController()
        let coordinator = ShellCoordinator(
            viewModel: ShellViewModel(),
            geometryResolver: ShellGeometryResolver(),
            hapticsService: HapticsService(),
            displayProvider: displayProvider,
            applicationNotificationCenter: appCenter,
            workspaceNotificationCenter: NotificationCenter(),
            dispatchToMainActor: runSynchronouslyOnMainActor,
            windowControllerFactory: { display, _, _, _ in
                windowController.createdDisplay = display
                return windowController
            }
        )

        coordinator.start()
        displayProvider.display = .externalFallback
        appCenter.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        pumpMainRunLoop()

        #expect(windowController.updatedDisplays == [.externalFallback])
    }

    @Test
    func activeSpaceChangesRefreshShellGeometry() {
        let workspaceCenter = NotificationCenter()
        let displayProvider = TestDisplayProvider(display: .notchedPrimary)
        let windowController = TestWindowController()
        let coordinator = ShellCoordinator(
            viewModel: ShellViewModel(),
            geometryResolver: ShellGeometryResolver(),
            hapticsService: HapticsService(),
            displayProvider: displayProvider,
            applicationNotificationCenter: NotificationCenter(),
            workspaceNotificationCenter: workspaceCenter,
            dispatchToMainActor: runSynchronouslyOnMainActor,
            windowControllerFactory: { display, _, _, _ in
                windowController.createdDisplay = display
                return windowController
            }
        )

        coordinator.start()
        workspaceCenter.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        pumpMainRunLoop()

        #expect(windowController.refreshGeometryCallCount == 1)
    }

    @Test
    func startDoesNothingWithoutAvailableDisplay() {
        let windowController = TestWindowController()
        let coordinator = ShellCoordinator(
            viewModel: ShellViewModel(),
            geometryResolver: ShellGeometryResolver(),
            hapticsService: HapticsService(),
            displayProvider: TestDisplayProvider(display: nil),
            applicationNotificationCenter: NotificationCenter(),
            workspaceNotificationCenter: NotificationCenter(),
            dispatchToMainActor: runSynchronouslyOnMainActor,
            windowControllerFactory: { _, _, _, _ in
                windowController
            }
        )

        coordinator.start()

        #expect(windowController.showWindowCallCount == 0)
        #expect(windowController.createdDisplay == nil)
    }

    private func pumpMainRunLoop() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }

    private func runSynchronouslyOnMainActor(_ operation: @escaping @MainActor () -> Void) {
        MainActor.assumeIsolated {
            operation()
        }
    }
}

@MainActor
private final class TestDisplayProvider: ShellDisplayProviding {
    var display: ShellDisplay?

    init(display: ShellDisplay?) {
        self.display = display
    }

    func preferredDisplay() -> ShellDisplay? {
        display
    }
}

@MainActor
private final class TestWindowController: ShellWindowControlling {
    var createdDisplay: ShellDisplay?
    var updatedDisplays: [ShellDisplay] = []
    var showWindowCallCount = 0
    var refreshGeometryCallCount = 0

    func showWindow() {
        showWindowCallCount += 1
    }

    func updateTargetDisplay(_ display: ShellDisplay) {
        updatedDisplays.append(display)
    }

    func refreshGeometry() {
        refreshGeometryCallCount += 1
    }
}

private extension ShellDisplay {
    static let notchedPrimary = ShellDisplay(
        id: "primary",
        geometry: ScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: CGRect(x: 0, y: 28, width: 1512, height: 954),
            safeAreaInsets: NSEdgeInsets(top: 32, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftWidth: 620,
            auxiliaryTopRightWidth: 620
        )
    )

    static let externalFallback = ShellDisplay(
        id: "external",
        geometry: ScreenGeometry(
            frame: CGRect(x: 1728, y: 0, width: 1728, height: 1117),
            visibleFrame: CGRect(x: 1728, y: 24, width: 1728, height: 1093),
            safeAreaInsets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftWidth: nil,
            auxiliaryTopRightWidth: nil
        )
    )
}
