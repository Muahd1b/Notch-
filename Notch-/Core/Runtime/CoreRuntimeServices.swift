import AppKit
import EventKit
import Foundation

@MainActor
final class CoreRuntimeServices {
    static weak var shared: CoreRuntimeServices?

    let eventBus: NotchEventBus
    let persistenceStore: PersistenceStore
    let diagnostics: RuntimeDiagnostics
    let adapterRegistry: AdapterRegistry
    let permissionsManager: PermissionsManager
    let pageRegistry: PageRegistry
    let focusSessionHistory: FocusSessionHistoryService
    private let agentObserverAdapter: AgentObserverAdapter
    private let settings: AppSettingsStore
    private let opsAdapter: OpsAdapter
    private let calendarService: CalendarEventKitService
    private let localhostService: LocalhostProbeService
    private let habitsLearningService: HabitsLearningStoreService
    private let notionSyncService: NotionSyncService
    private let eventDecoder: JSONDecoder
    private let externalIntegrationsEnabled: Bool
    private var hasRegisteredAdapters = false
    private var eventSubscriptionTask: Task<Void, Never>?
    private var shellSnapshotConsumer: ((ShellStatusSnapshot) -> Void)?
    private var currentSnapshot: ShellStatusSnapshot
    private var calendarStoreChangedObserver: NSObjectProtocol?

    init(
        defaults: UserDefaults = .standard,
        externalIntegrationsEnabled: Bool? = nil,
        settings: AppSettingsStore = .shared
    ) {
        let eventBus = NotchEventBus()
        let diagnostics = RuntimeDiagnostics(eventBus: eventBus)
        let integrationEnabled = externalIntegrationsEnabled ?? {
            let args = ProcessInfo.processInfo.arguments
            let env = ProcessInfo.processInfo.environment
            return !args.contains("-uitest-mode") && env["XCTestConfigurationFilePath"] == nil
        }()

        self.settings = settings
        self.eventBus = eventBus
        self.persistenceStore = PersistenceStore(defaults: defaults)
        self.diagnostics = diagnostics
        self.adapterRegistry = AdapterRegistry(eventBus: eventBus, diagnostics: diagnostics)
        self.permissionsManager = PermissionsManager(eventBus: eventBus)
        self.pageRegistry = PageRegistry()
        self.focusSessionHistory = FocusSessionHistoryService(
            persistenceStore: self.persistenceStore,
            diagnostics: diagnostics
        )
        self.agentObserverAdapter = AgentObserverAdapter(eventBus: eventBus, diagnostics: diagnostics, settings: settings)
        self.opsAdapter = OpsAdapter(eventBus: eventBus, diagnostics: diagnostics)
        self.calendarService = CalendarEventKitService(eventBus: eventBus, diagnostics: diagnostics)
        self.localhostService = LocalhostProbeService(eventBus: eventBus, diagnostics: diagnostics)
        self.habitsLearningService = HabitsLearningStoreService(
            persistenceStore: self.persistenceStore,
            eventBus: eventBus,
            diagnostics: diagnostics
        )
        self.notionSyncService = NotionSyncService(eventBus: eventBus, diagnostics: diagnostics)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.eventDecoder = decoder
        self.externalIntegrationsEnabled = integrationEnabled
        self.currentSnapshot = .phaseZero
        Self.shared = self
    }

    func bindShellSnapshotConsumer(_ consumer: @escaping (ShellStatusSnapshot) -> Void) {
        shellSnapshotConsumer = consumer
        consumer(currentSnapshot)
    }

    func start() async {
        await diagnostics.record(
            level: .info,
            message: "Core runtime services started.",
            source: "core.runtime"
        )
        await registerAdaptersIfNeeded()
        startEventSubscriptionIfNeeded()
        await adapterRegistry.startAll()
        await habitsLearningService.start(dailyResetHour: settings.habitsDailyResetHour)
        await refreshHabitsLearning()
        if externalIntegrationsEnabled {
            configureCalendarStoreChangedObserverIfNeeded()
            await refreshCalendar()
            await refreshLocalhost()
        }
    }

    func stop() async {
        if let calendarStoreChangedObserver {
            NotificationCenter.default.removeObserver(calendarStoreChangedObserver)
            self.calendarStoreChangedObserver = nil
        }
        eventSubscriptionTask?.cancel()
        eventSubscriptionTask = nil
        await adapterRegistry.stopAll()
        await diagnostics.record(
            level: .info,
            message: "Core runtime services stopped.",
            source: "core.runtime"
        )
    }

    private func registerAdaptersIfNeeded() async {
        guard !hasRegisteredAdapters else { return }
        do {
            try await adapterRegistry.register(agentObserverAdapter)
            try await adapterRegistry.register(opsAdapter)
            hasRegisteredAdapters = true
        } catch {
            await diagnostics.record(
                level: .warning,
                message: "Failed to register one or more adapters.",
                source: "core.runtime",
                metadata: ["error": String(describing: error)]
            )
        }
    }

    private func startEventSubscriptionIfNeeded() {
        guard eventSubscriptionTask == nil else { return }

        eventSubscriptionTask = Task { [weak self] in
            guard let self else { return }
            let subscription = await eventBus.subscribe()
            for await event in subscription.stream {
                await self.handleRuntimeEvent(event)
            }
        }
    }

    private func handleRuntimeEvent(_ event: NotchEvent) async {
        switch event.source {
        case "adapter.agents.observer":
            await handleAgentPayload(event)
        case "adapter.ops.observer":
            await handleOpsPayload(event)
        default:
            return
        }
    }

    private func handleOpsPayload(_ event: NotchEvent) async {
        guard case .text(let payload) = event.payload else { return }
        guard let data = payload.data(using: .utf8) else { return }

        do {
            let decoded = try eventDecoder.decode(OpsObserverPayload.self, from: data)
            let ops = ShellOpsSnapshot(
                automations: decoded.automations,
                needsYou: decoded.needsYou,
                repos: decoded.repos,
                updatedAt: decoded.updatedAt
            )
            var nextSnapshot = currentSnapshot
            nextSnapshot.ops = ops
            currentSnapshot = nextSnapshot
            shellSnapshotConsumer?(nextSnapshot)
        } catch {
            await diagnostics.record(
                level: .warning,
                message: "Failed to decode ops payload.",
                source: "core.runtime",
                metadata: ["error": String(describing: error)]
            )
        }
    }

    private func handleAgentPayload(_ event: NotchEvent) async {
        guard case .text(let payload) = event.payload else { return }
        guard let data = payload.data(using: .utf8) else { return }

        do {
            let decoded = try eventDecoder.decode(AgentObserverPayload.self, from: data)
            let sessions = decoded.sessions.map(mapObservedAgentSession)
            var nextSnapshot = currentSnapshot
            nextSnapshot = nextSnapshot.updatingAgents(sessions)
            currentSnapshot = nextSnapshot
            shellSnapshotConsumer?(nextSnapshot)
        } catch {
            await diagnostics.record(
                level: .warning,
                message: "Failed to decode agent observer payload.",
                source: "core.runtime",
                metadata: ["error": String(describing: error)]
            )
        }
    }

    private func mapObservedAgentSession(_ session: ObservedAgentSession) -> ShellAgentSession {
        let provider: ShellAgentProvider
        switch session.provider {
        case .codex:
            provider = .codex
        case .claudeCode:
            provider = .claudeCode
        case .openCode:
            provider = .openCode
        case .ollama:
            provider = .ollama
        }

        let status: ShellAgentSessionStatus
        switch session.status {
        case .ongoing:
            status = .ongoing
        case .needsReview:
            status = .needsReview
        case .failed:
            status = .failed
        case .idle:
            status = .idle
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let lastActivityLabel = formatter.localizedString(for: session.lastActivityAt, relativeTo: Date())

        return ShellAgentSession(
            id: session.id,
            provider: provider,
            title: session.title,
            workspacePath: session.workspacePath,
            status: status,
            confidence: session.confidence,
            lastActivityAt: session.lastActivityAt,
            lastActivityLabel: lastActivityLabel,
            model: session.model,
            summary: session.summary,
            branch: session.branch,
            tokensUsed: session.tokensUsed,
            tokenLimit: session.tokenLimit,
            planUsagePercent: session.planUsagePercent
        )
    }

    func refreshCalendar() async {
        guard externalIntegrationsEnabled else { return }
        guard settings.calendarEnabled else {
            var nextSnapshot = currentSnapshot
            nextSnapshot = nextSnapshot.updatingCalendar([])
            currentSnapshot = nextSnapshot
            shellSnapshotConsumer?(nextSnapshot)
            return
        }
        let lookahead = settings.calendarLookaheadHours
        let includeAllDay = settings.calendarShowAllDayEvents
        let selectedCalendarSourceIDs = settings.selectedCalendarSourceIDs
        let selectedReminderSourceIDs = settings.selectedReminderSourceIDs

        let events = await calendarService.refresh(
            lookaheadHours: lookahead,
            includeAllDay: includeAllDay,
            selectedCalendarSourceIDs: selectedCalendarSourceIDs,
            selectedReminderSourceIDs: selectedReminderSourceIDs
        )

        let permissionStatus = mapPermissionStatus(await calendarService.eventsAuthorizationStatus())
        permissionsManager.updateStatus(permissionStatus, for: .calendar)

        var nextSnapshot = currentSnapshot
        nextSnapshot = nextSnapshot.updatingCalendar(events)
        currentSnapshot = nextSnapshot
        shellSnapshotConsumer?(nextSnapshot)
    }

    private func configureCalendarStoreChangedObserverIfNeeded() {
        guard calendarStoreChangedObserver == nil else { return }

        calendarStoreChangedObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                await self?.refreshCalendar()
            }
        }
    }

    func createCalendarEvent(title: String = "New Event") async -> Bool {
        guard externalIntegrationsEnabled else { return false }
        let opened = await openExternalApp(bundleIdentifier: "com.apple.iCal")
        if opened {
            await diagnostics.record(
                level: .info,
                message: "Opened Calendar app for event creation.",
                source: "calendar.launcher",
                metadata: ["titleHint": title]
            )
        }
        return opened
    }

    func createReminder(title: String = "New Reminder") async -> Bool {
        guard externalIntegrationsEnabled else { return false }
        let opened = await openExternalApp(bundleIdentifier: "com.apple.reminders")
        if opened {
            await diagnostics.record(
                level: .info,
                message: "Opened Reminders app for reminder creation.",
                source: "calendar.launcher",
                metadata: ["titleHint": title]
            )
        }
        return opened
    }

    func createFocusBlock() async -> Bool {
        guard externalIntegrationsEnabled else { return false }
        let selectedCalendarSourceIDs = settings.selectedCalendarSourceIDs
        let created = await calendarService.createQuickEvent(
            title: "Focus Block",
            durationMinutes: 25,
            preferredSourceIDs: selectedCalendarSourceIDs
        )
        if created {
            await refreshCalendar()
        }
        return created
    }

    func refreshLocalhost() async {
        guard externalIntegrationsEnabled else { return }
        guard settings.localhostMonitoringEnabled else { return }

        let showHealthy = settings.localhostShowHealthyServices
        let services = await localhostService.refresh(showHealthyServices: showHealthy)

        var nextSnapshot = currentSnapshot
        nextSnapshot = nextSnapshot.updatingLocalhost(services)
        currentSnapshot = nextSnapshot
        shellSnapshotConsumer?(nextSnapshot)
    }

    func refreshHabitsLearning() async {
        let dailyResetHour = settings.habitsDailyResetHour
        await habitsLearningService.refresh(dailyResetHour: dailyResetHour)
        var habits = await habitsLearningService.habits()
        var learnings = await habitsLearningService.learnings()

        let habitsEnabled = settings.habitsEnabled
        let learningsEnabled = settings.learningsEnabled

        if !habitsEnabled {
            habits = []
        }
        if !learningsEnabled {
            learnings = []
        }

        let notionSyncEnabled = settings.notionSyncEnabled
        _ = await notionSyncService.syncIfConfigured(
            habits: habits,
            learnings: learnings,
            enabled: notionSyncEnabled
        )

        var nextSnapshot = currentSnapshot
        nextSnapshot = nextSnapshot.updatingHabitsLearning(habits: habits, learnings: learnings)
        currentSnapshot = nextSnapshot
        shellSnapshotConsumer?(nextSnapshot)
    }

    func toggleHabitCompletion(id: String) async {
        let dailyResetHour = settings.habitsDailyResetHour
        await habitsLearningService.refresh(dailyResetHour: dailyResetHour)
        await habitsLearningService.toggleHabit(id: id)
        await refreshHabitsLearning()
    }

    func habitsForSettings() async -> [ShellHabitProgress] {
        let dailyResetHour = settings.habitsDailyResetHour
        await habitsLearningService.refresh(dailyResetHour: dailyResetHour)
        return await habitsLearningService.habits()
    }

    func createHabit(title: String, targetUnits: Int) async -> Bool {
        let created = await habitsLearningService.createHabit(title: title, targetUnits: targetUnits)
        if created {
            await refreshHabitsLearning()
        }
        return created
    }

    func reorderHabits(fromOffsets source: IndexSet, toOffset destination: Int) async -> Bool {
        let reordered = await habitsLearningService.reorderHabits(fromOffsets: source, toOffset: destination)
        if reordered {
            await refreshHabitsLearning()
        }
        return reordered
    }

    func deleteHabit(id: String) async -> Bool {
        let deleted = await habitsLearningService.deleteHabit(id: id)
        if deleted {
            await refreshHabitsLearning()
        }
        return deleted
    }

    func deleteLegacyMockHabitsLearningData() async -> Bool {
        let deleted = await habitsLearningService.deleteLegacyMockData()
        if deleted {
            await refreshHabitsLearning()
        }
        return deleted
    }

    func captureLearningSignal() async {
        await habitsLearningService.captureLearningSignal()
        await refreshHabitsLearning()
    }

    private func mapPermissionStatus(_ status: EKAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .fullAccess, .writeOnly, .authorized:
            return .ready
        case .notDetermined:
            return .needsSetup
        case .restricted:
            return .unavailable
        case .denied:
            return .denied
        @unknown default:
            return .needsSetup
        }
    }

    private func openExternalApp(bundleIdentifier: String) async -> Bool {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return false
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        return await withCheckedContinuation { continuation in
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { app, error in
                continuation.resume(returning: app != nil && error == nil)
            }
        }
    }
}
