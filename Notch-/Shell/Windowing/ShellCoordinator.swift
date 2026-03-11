import AppKit
import Combine

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
    private let settingsStore: AppSettingsStore
    private var windowControllers: [String: any ShellWindowControlling] = [:]
    private var applicationObservers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()

    init(
        viewModel: ShellViewModel,
        geometryResolver: ShellGeometryResolver,
        hapticsService: HapticsService,
        displayProvider: any ShellDisplayProviding,
        settingsStore: AppSettingsStore? = nil,
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
                hapticsService: hapticsService,
                settingsStore: AppSettingsStore.shared
            )
        }
    ) {
        self.viewModel = viewModel
        self.geometryResolver = geometryResolver
        self.hapticsService = hapticsService
        self.displayProvider = displayProvider
        self.settingsStore = settingsStore ?? AppSettingsStore.shared
        self.applicationNotificationCenter = applicationNotificationCenter
        self.workspaceNotificationCenter = workspaceNotificationCenter
        self.dispatchToMainActor = dispatchToMainActor
        self.windowControllerFactory = windowControllerFactory
        bindSettingsChanges()
    }

    convenience init() {
        self.init(
            viewModel: ShellViewModel(),
            geometryResolver: ShellGeometryResolver(),
            hapticsService: HapticsService(),
            displayProvider: DefaultShellDisplayProvider(settingsStore: AppSettingsStore.shared),
            settingsStore: AppSettingsStore.shared
        )
    }

    func start() {
        reconcileDisplayControllers()
        for controller in windowControllers.values {
            controller.refreshGeometry()
        }
        installObservers()
    }

    private func installObservers() {
        guard applicationObservers.isEmpty, workspaceObservers.isEmpty else { return }

        let dispatchToMainActor = self.dispatchToMainActor

        let screenParamsObserver = applicationNotificationCenter.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            dispatchToMainActor { [weak self] in
                self?.handleScreenEnvironmentChange()
            }
        }

        let activeSpaceObserver = workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            dispatchToMainActor { [weak self] in
                guard let self else { return }
                for controller in self.windowControllers.values {
                    controller.refreshGeometry()
                }
            }
        }

        applicationObservers = [screenParamsObserver]
        workspaceObservers = [activeSpaceObserver]
    }

    private func handleScreenEnvironmentChange() {
        reconcileDisplayControllers()
    }

    private func bindSettingsChanges() {
        Publishers.MergeMany(
            settingsStore.$showOnAllDisplays.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settingsStore.$preferredDisplayID.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settingsStore.$automaticallySwitchDisplay.dropFirst().map { _ in () }.eraseToAnyPublisher()
        )
        .sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reconcileDisplayControllers()
            }
        }
        .store(in: &cancellables)
    }

    private func reconcileDisplayControllers() {
        let targetDisplays = displayProvider.targetDisplays()
        let targetIDs = Set(targetDisplays.map(\.id))

        for existingID in Array(windowControllers.keys) where !targetIDs.contains(existingID) {
            windowControllers[existingID]?.closeWindow()
            windowControllers.removeValue(forKey: existingID)
        }

        for display in targetDisplays {
            if let controller = windowControllers[display.id] {
                controller.updateTargetDisplay(display)
                continue
            }

            let controller = windowControllerFactory(display, viewModel, geometryResolver, hapticsService)
            windowControllers[display.id] = controller
            controller.showWindow()
        }
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
