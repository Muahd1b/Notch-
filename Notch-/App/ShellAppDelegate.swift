import AppKit
import Combine

@MainActor
final class ShellAppDelegate: NSObject, NSApplicationDelegate {
    private let coreRuntimeServices: CoreRuntimeServices
    private let shellCoordinator: ShellCoordinator
    private let isUITestMode: Bool
    private let viewModel: ShellViewModel
    private let menuBarController: ShellMenuBarController

    override init() {
        isUITestMode = ProcessInfo.processInfo.arguments.contains("-uitest-mode")
        let startOpen = ProcessInfo.processInfo.arguments.contains("-uitest-open-shell")
        let settingsStore = AppSettingsStore.shared
        if isUITestMode {
            settingsStore.settingsIconInSymbolBar = true
        }
        let hapticsService = HapticsService(settingsStore: settingsStore)
        let viewModel = ShellViewModel(
            statusSnapshot: .phaseZero,
            initialPresentationState: startOpen ? .open(.pinned) : .closed,
            settingsStore: settingsStore,
            hapticsService: hapticsService
        )
        self.viewModel = viewModel
        coreRuntimeServices = CoreRuntimeServices()
        shellCoordinator = ShellCoordinator(
            viewModel: viewModel,
            geometryResolver: ShellGeometryResolver(),
            hapticsService: hapticsService,
            displayProvider: DefaultShellDisplayProvider(settingsStore: settingsStore)
        )
        menuBarController = ShellMenuBarController(
            settingsStore: settingsStore,
            viewModel: viewModel
        )
        super.init()

        coreRuntimeServices.bindShellSnapshotConsumer { [weak self] snapshot in
            self?.viewModel.updateStatusSnapshot(snapshot)
        }

        viewModel.configurePageActions(
            onCalendarPageAppeared: { [weak coreRuntimeServices] in
                await coreRuntimeServices?.refreshCalendar()
            },
            onCreateCalendarEvent: { [weak coreRuntimeServices] title in
                await coreRuntimeServices?.createCalendarEvent(title: title) ?? false
            },
            onCreateReminder: { [weak coreRuntimeServices] title in
                await coreRuntimeServices?.createReminder(title: title) ?? false
            },
            onCreateFocusBlock: { [weak coreRuntimeServices] in
                await coreRuntimeServices?.createFocusBlock() ?? false
            },
            onLocalhostPageAppeared: { [weak coreRuntimeServices] in
                await coreRuntimeServices?.refreshLocalhost()
            },
            onHabitsPageAppeared: { [weak coreRuntimeServices] in
                await coreRuntimeServices?.refreshHabitsLearning()
            },
            onToggleHabit: { [weak coreRuntimeServices] habitID in
                await coreRuntimeServices?.toggleHabitCompletion(id: habitID)
            },
            onCaptureLearningSignal: { [weak coreRuntimeServices] in
                await coreRuntimeServices?.captureLearningSignal()
            }
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(isUITestMode ? .regular : .accessory)
        menuBarController.start()
        shellCoordinator.start()
        Task {
            await coreRuntimeServices.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController.stop()
        Task {
            await coreRuntimeServices.stop()
        }
    }
}

@MainActor
private final class ShellMenuBarController: NSObject {
    private let settingsStore: AppSettingsStore
    private weak var viewModel: ShellViewModel?
    private let statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()

    init(settingsStore: AppSettingsStore, viewModel: ShellViewModel) {
        self.settingsStore = settingsStore
        self.viewModel = viewModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        statusItem.menu = buildMenu()
    }

    func start() {
        configureButton()
        statusItem.isVisible = settingsStore.menubarIcon

        settingsStore.$menubarIcon
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in
                self?.statusItem.isVisible = visible
            }
            .store(in: &cancellables)
    }

    func stop() {
        cancellables.removeAll()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = Self.buildMenuBarIcon()
        button.imagePosition = .imageOnly
        button.toolTip = "Controll Notch"
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: "Toggle Notch",
            action: #selector(toggleNotch),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Controll Notch",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc
    private func toggleNotch() {
        viewModel?.toggleOpen()
    }

    @objc
    private func openSettings() {
        SettingsWindowController.shared.showWindow()
    }

    @objc
    private func quitApp() {
        NSApp.terminate(nil)
    }

    private static func buildMenuBarIcon() -> NSImage {
        if let symbol = NSImage(systemSymbolName: "yin.yang", accessibilityDescription: "Controll Notch") {
            symbol.isTemplate = true
            return symbol
        }

        // Fallback for older symbol catalogs.
        let fallback = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: "Controll Notch") ?? NSImage()
        fallback.isTemplate = true
        return fallback
    }
}
