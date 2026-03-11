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

        #expect(windowController.refreshGeometryCallCount == 2)
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

    @Test
    func startCreatesWindowForEachTargetDisplay() {
        let displayProvider = TestDisplayProvider(displays: [.notchedPrimary, .externalFallback])
        var controllersByDisplay: [String: TestWindowController] = [:]
        let coordinator = ShellCoordinator(
            viewModel: ShellViewModel(),
            geometryResolver: ShellGeometryResolver(),
            hapticsService: HapticsService(),
            displayProvider: displayProvider,
            applicationNotificationCenter: NotificationCenter(),
            workspaceNotificationCenter: NotificationCenter(),
            dispatchToMainActor: runSynchronouslyOnMainActor,
            windowControllerFactory: { display, _, _, _ in
                let controller = TestWindowController()
                controller.createdDisplay = display
                controllersByDisplay[display.id] = controller
                return controller
            }
        )

        coordinator.start()

        #expect(controllersByDisplay.keys.sorted() == ["external", "primary"])
        #expect(controllersByDisplay["primary"]?.showWindowCallCount == 1)
        #expect(controllersByDisplay["external"]?.showWindowCallCount == 1)
    }

    @Test
    func screenParameterChangesCloseRemovedDisplayWindows() {
        let appCenter = NotificationCenter()
        let displayProvider = TestDisplayProvider(displays: [.notchedPrimary, .externalFallback])
        var controllersByDisplay: [String: TestWindowController] = [:]
        let coordinator = ShellCoordinator(
            viewModel: ShellViewModel(),
            geometryResolver: ShellGeometryResolver(),
            hapticsService: HapticsService(),
            displayProvider: displayProvider,
            applicationNotificationCenter: appCenter,
            workspaceNotificationCenter: NotificationCenter(),
            dispatchToMainActor: runSynchronouslyOnMainActor,
            windowControllerFactory: { display, _, _, _ in
                let controller = TestWindowController()
                controller.createdDisplay = display
                controllersByDisplay[display.id] = controller
                return controller
            }
        )

        coordinator.start()
        displayProvider.displays = [.notchedPrimary]
        appCenter.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        pumpMainRunLoop()

        #expect(controllersByDisplay["external"]?.closeWindowCallCount == 1)
        #expect(controllersByDisplay["primary"]?.closeWindowCallCount == 0)
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
    var displays: [ShellDisplay]?

    init(display: ShellDisplay?) {
        self.display = display
    }

    init(displays: [ShellDisplay]) {
        self.displays = displays
        self.display = displays.first
    }

    func preferredDisplay() -> ShellDisplay? {
        display
    }

    func targetDisplays() -> [ShellDisplay] {
        if let displays {
            return displays
        }

        guard let display else {
            return []
        }

        return [display]
    }
}

@MainActor
private final class TestWindowController: ShellWindowControlling {
    var createdDisplay: ShellDisplay?
    var updatedDisplays: [ShellDisplay] = []
    var showWindowCallCount = 0
    var refreshGeometryCallCount = 0
    var closeWindowCallCount = 0

    func showWindow() {
        showWindowCallCount += 1
    }

    func updateTargetDisplay(_ display: ShellDisplay) {
        updatedDisplays.append(display)
    }

    func refreshGeometry() {
        refreshGeometryCallCount += 1
    }

    func closeWindow() {
        closeWindowCallCount += 1
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

    static let externalFallback = ShellDisplay(
        id: "external",
        cgDisplayID: 2,
        geometry: ScreenGeometry(
            frame: CGRect(x: 1728, y: 0, width: 1728, height: 1117),
            visibleFrame: CGRect(x: 1728, y: 24, width: 1728, height: 1093),
            safeAreaInsets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftWidth: nil,
            auxiliaryTopRightWidth: nil
        )
    )
}
