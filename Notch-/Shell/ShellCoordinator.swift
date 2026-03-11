import AppKit

@MainActor
final class ShellCoordinator {
    private let dispatchToMainActor: (@escaping @MainActor () -> Void) -> Void
    private let viewModel: ShellViewModel
    private let geometryResolver: ShellGeometryResolver
    private let hapticsService: HapticsService
    private let displayProvider: any ShellDisplayProviding
    private let windowControllerFactory: @MainActor (ShellDisplay, ShellViewModel, ShellGeometryResolver, HapticsService) -> any ShellWindowControlling
    private let applicationNotificationCenter: NotificationCenter
    private let workspaceNotificationCenter: NotificationCenter
    private var windowController: (any ShellWindowControlling)?
    private var applicationObservers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []

    init(
        viewModel: ShellViewModel,
        geometryResolver: ShellGeometryResolver,
        hapticsService: HapticsService,
        displayProvider: any ShellDisplayProviding,
        applicationNotificationCenter: NotificationCenter = .default,
        workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        dispatchToMainActor: @escaping (@escaping @MainActor () -> Void) -> Void = { operation in
            Task { @MainActor in
                operation()
            }
        },
        windowControllerFactory: @escaping @MainActor (ShellDisplay, ShellViewModel, ShellGeometryResolver, HapticsService) -> any ShellWindowControlling = { display, viewModel, geometryResolver, hapticsService in
            ShellWindowController(
                display: display,
                viewModel: viewModel,
                geometryResolver: geometryResolver,
                hapticsService: hapticsService
            )
        }
    ) {
        self.viewModel = viewModel
        self.geometryResolver = geometryResolver
        self.hapticsService = hapticsService
        self.displayProvider = displayProvider
        self.applicationNotificationCenter = applicationNotificationCenter
        self.workspaceNotificationCenter = workspaceNotificationCenter
        self.dispatchToMainActor = dispatchToMainActor
        self.windowControllerFactory = windowControllerFactory
    }

    convenience init() {
        self.init(
            viewModel: ShellViewModel(),
            geometryResolver: ShellGeometryResolver(),
            hapticsService: HapticsService(),
            displayProvider: DefaultShellDisplayProvider()
        )
    }

    func start() {
        if let windowController {
            windowController.refreshGeometry()
            return
        }

        guard let display = displayProvider.preferredDisplay() else { return }
        let controller = windowControllerFactory(display, viewModel, geometryResolver, hapticsService)

        windowController = controller
        controller.showWindow()
        installObservers()
    }

    private func installObservers() {
        let screenParamsObserver = applicationNotificationCenter.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.dispatchToMainActor { [weak self] in
                self?.handleScreenEnvironmentChange()
            }
        }

        let activeSpaceObserver = workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.dispatchToMainActor { [weak self] in
                self?.windowController?.refreshGeometry()
            }
        }

        applicationObservers = [screenParamsObserver]
        workspaceObservers = [activeSpaceObserver]
    }

    private func handleScreenEnvironmentChange() {
        guard let display = displayProvider.preferredDisplay() else { return }
        windowController?.updateTargetDisplay(display)
    }

    deinit {
        for observer in applicationObservers {
            applicationNotificationCenter.removeObserver(observer)
        }

        for observer in workspaceObservers {
            workspaceNotificationCenter.removeObserver(observer)
        }
    }
}
