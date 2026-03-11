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
    private let calendarService: CalendarEventKitService
    private let localhostService: LocalhostProbeService
    private let habitsLearningService: HabitsLearningStoreService
    private let notionSyncService: NotionSyncService
    private let externalIntegrationsEnabled: Bool
    private var shellSnapshotConsumer: ((ShellStatusSnapshot) -> Void)?
    private var currentSnapshot: ShellStatusSnapshot
    private var calendarStoreChangedObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard, externalIntegrationsEnabled: Bool? = nil) {
        let eventBus = NotchEventBus()
        let diagnostics = RuntimeDiagnostics(eventBus: eventBus)
        let integrationEnabled = externalIntegrationsEnabled ?? {
            let args = ProcessInfo.processInfo.arguments
            let env = ProcessInfo.processInfo.environment
            return !args.contains("-uitest-mode") && env["XCTestConfigurationFilePath"] == nil
        }()

        self.eventBus = eventBus
        self.persistenceStore = PersistenceStore(defaults: defaults)
        self.diagnostics = diagnostics
        self.adapterRegistry = AdapterRegistry(eventBus: eventBus, diagnostics: diagnostics)
        self.permissionsManager = PermissionsManager(eventBus: eventBus)
        self.pageRegistry = PageRegistry()
        self.calendarService = CalendarEventKitService(eventBus: eventBus, diagnostics: diagnostics)
        self.localhostService = LocalhostProbeService(eventBus: eventBus, diagnostics: diagnostics)
        self.habitsLearningService = HabitsLearningStoreService(
            persistenceStore: self.persistenceStore,
            eventBus: eventBus,
            diagnostics: diagnostics
        )
        self.notionSyncService = NotionSyncService(eventBus: eventBus, diagnostics: diagnostics)
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
        await adapterRegistry.startAll()
        await habitsLearningService.start()
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
        await adapterRegistry.stopAll()
        await diagnostics.record(
            level: .info,
            message: "Core runtime services stopped.",
            source: "core.runtime"
        )
    }

    func refreshCalendar() async {
        guard externalIntegrationsEnabled else { return }
        guard AppSettingsStore.shared.calendarEnabled else {
            var nextSnapshot = currentSnapshot
            nextSnapshot = nextSnapshot.updatingCalendar([])
            currentSnapshot = nextSnapshot
            shellSnapshotConsumer?(nextSnapshot)
            return
        }
        let lookahead = AppSettingsStore.shared.calendarLookaheadHours
        let includeAllDay = AppSettingsStore.shared.calendarShowAllDayEvents
        let selectedCalendarSourceIDs = AppSettingsStore.shared.selectedCalendarSourceIDs
        let selectedReminderSourceIDs = AppSettingsStore.shared.selectedReminderSourceIDs

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
        let selectedCalendarSourceIDs = AppSettingsStore.shared.selectedCalendarSourceIDs
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
        guard AppSettingsStore.shared.localhostMonitoringEnabled else { return }

        let showHealthy = AppSettingsStore.shared.localhostShowHealthyServices
        let services = await localhostService.refresh(showHealthyServices: showHealthy)

        var nextSnapshot = currentSnapshot
        nextSnapshot = nextSnapshot.updatingLocalhost(services)
        currentSnapshot = nextSnapshot
        shellSnapshotConsumer?(nextSnapshot)
    }

    func refreshHabitsLearning() async {
        await habitsLearningService.refresh()
        var habits = await habitsLearningService.habits()
        var learnings = await habitsLearningService.learnings()

        let habitsEnabled = AppSettingsStore.shared.habitsEnabled
        let learningsEnabled = AppSettingsStore.shared.learningsEnabled

        if !habitsEnabled {
            habits = []
        }
        if !learningsEnabled {
            learnings = []
        }

        let notionSyncEnabled = AppSettingsStore.shared.notionSyncEnabled
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
        await habitsLearningService.toggleHabit(id: id)
        await refreshHabitsLearning()
    }

    func habitsForSettings() async -> [ShellHabitProgress] {
        await habitsLearningService.refresh()
        return await habitsLearningService.habits()
    }

    func createHabit(title: String, targetUnits: Int) async -> Bool {
        let created = await habitsLearningService.createHabit(title: title, targetUnits: targetUnits)
        if created {
            await refreshHabitsLearning()
        }
        return created
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

private actor CalendarEventKitService {
    private let eventStore = EKEventStore()
    private let eventBus: NotchEventBus
    private let diagnostics: RuntimeDiagnostics?
    private let timeFormatter: DateFormatter
    private let relativeFormatter: RelativeDateTimeFormatter

    init(eventBus: NotchEventBus, diagnostics: RuntimeDiagnostics?) {
        self.eventBus = eventBus
        self.diagnostics = diagnostics
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.locale = .current
        self.timeFormatter = formatter
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .short
        self.relativeFormatter = relative
    }

    func eventsAuthorizationStatus() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    func refresh(
        lookaheadHours: Double,
        includeAllDay: Bool,
        selectedCalendarSourceIDs: Set<String>,
        selectedReminderSourceIDs: Set<String>
    ) async -> [ShellCalendarEvent] {
        let canReadEvents = await ensureEventsAccess()
        let canReadReminders = await ensureRemindersAccess()

        guard canReadEvents || canReadReminders else {
            await publishRefreshSignal(eventCount: 0)
            return []
        }

        let now = Date()
        let fetchRange = timelineFetchRange(lookaheadHours: lookaheadHours, now: now)
        let start = fetchRange.start
        let end = fetchRange.end
        let allowedEventCalendars = effectiveSelectedCalendars(
            availableCalendars: canReadEvents ? eventStore.calendars(for: .event) : [],
            selectedSourceIDs: selectedCalendarSourceIDs
        )
        let allowedReminderCalendars = effectiveSelectedCalendars(
            availableCalendars: canReadReminders ? eventStore.calendars(for: .reminder) : [],
            selectedSourceIDs: selectedReminderSourceIDs
        )

        let mappedEventItems: [ShellCalendarEvent] = {
            guard canReadEvents else { return [] }
            let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: allowedEventCalendars)
            return eventStore.events(matching: predicate)
                .filter { includeAllDay || !$0.isAllDay }
                .map { event in
                    ShellCalendarEvent(
                        id: "\(event.eventIdentifier ?? UUID().uuidString)-\(event.startDate.timeIntervalSince1970)",
                        startAt: event.startDate,
                        endAt: event.endDate,
                        title: event.title?.isEmpty == false ? event.title! : "Untitled Event",
                        timeLabel: timeLabel(for: event),
                        relativeLabel: relativeLabel(for: event.startDate, now: now),
                        location: event.location?.isEmpty == false ? event.location! : event.calendar.title,
                        sourceID: event.calendar.calendarIdentifier,
                        source: event.calendar.title,
                        sourceColorHex: colorHex(for: event.calendar.cgColor),
                        isAllDay: event.isAllDay
                    )
                }
        }()

        let mappedReminders = await fetchReminderEvents(
            from: start,
            to: end,
            calendars: allowedReminderCalendars,
            includeAllDay: includeAllDay
        )

        let combined = (mappedEventItems + mappedReminders)
            .sorted(by: { $0.startAt < $1.startAt })

        let mappedEvents = Array(combined)
        await publishRefreshSignal(eventCount: mappedEvents.count)
        return mappedEvents
    }

    private func timelineFetchRange(lookaheadHours: Double, now: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        let defaultStart = calendar.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart
        let defaultEnd = calendar.date(byAdding: .day, value: 15, to: todayStart) ?? now
        let lookaheadEnd = now.addingTimeInterval(max(1, lookaheadHours) * 3600)
        return (defaultStart, max(defaultEnd, lookaheadEnd))
    }

    private func effectiveSelectedCalendars(
        availableCalendars: [EKCalendar],
        selectedSourceIDs: Set<String>
    ) -> [EKCalendar] {
        guard !availableCalendars.isEmpty else { return [] }
        guard !selectedSourceIDs.isEmpty else { return availableCalendars }

        let filtered = availableCalendars.filter { selectedSourceIDs.contains($0.calendarIdentifier) }
        // Fall back to all calendars when legacy/static IDs don't match live EventKit IDs.
        // If selections are partially stale, prefer showing all events over hiding calendars silently.
        let hasStaleSelections = filtered.count < selectedSourceIDs.count
        return (filtered.isEmpty || hasStaleSelections) ? availableCalendars : filtered
    }

    private func fetchReminderEvents(
        from start: Date,
        to end: Date,
        calendars: [EKCalendar],
        includeAllDay: Bool
    ) async -> [ShellCalendarEvent] {
        guard !calendars.isEmpty else { return [] }

        let predicate = eventStore.predicateForReminders(in: calendars)
        let reminders: [EKReminder] = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        return reminders.compactMap { reminder in
            guard let dueDateComponents = reminder.dueDateComponents,
                let dueDate = Calendar.current.date(from: dueDateComponents)
            else {
                return nil
            }

            guard dueDate >= start && dueDate <= end else { return nil }

            let isAllDayReminder = dueDateComponents.hour == nil
            guard includeAllDay || !isAllDayReminder else { return nil }

            let endDate = isAllDayReminder
                ? Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: dueDate)) ?? dueDate
                : dueDate.addingTimeInterval(30 * 60)

            let calendar = reminder.calendar
            return ShellCalendarEvent(
                id: reminder.calendarItemIdentifier,
                startAt: dueDate,
                endAt: endDate,
                title: reminder.title?.isEmpty == false ? reminder.title! : "Untitled Reminder",
                timeLabel: isAllDayReminder ? "All Day" : timeFormatter.string(from: dueDate),
                relativeLabel: relativeLabel(for: dueDate, now: Date()),
                location: calendar?.title ?? "Reminders",
                sourceID: calendar?.calendarIdentifier ?? "reminders.default",
                source: calendar?.title ?? "Reminders",
                sourceColorHex: colorHex(for: calendar?.cgColor),
                isAllDay: isAllDayReminder,
                isReminder: true,
                isCompleted: reminder.isCompleted
            )
        }
    }

    func createQuickEvent(
        title: String,
        durationMinutes: Int,
        preferredSourceIDs: Set<String>
    ) async -> Bool {
        guard await ensureEventsAccess() else { return false }
        guard let calendar = preferredCalendar(
            for: .event,
            preferredSourceIDs: preferredSourceIDs
        ) ?? eventStore.defaultCalendarForNewEvents else { return false }

        let now = Date()
        let start = Calendar.current.date(byAdding: .minute, value: 10, to: now) ?? now
        let end = Calendar.current.date(byAdding: .minute, value: max(5, durationMinutes), to: start) ?? start.addingTimeInterval(1800)

        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = title
        event.startDate = start
        event.endDate = end
        event.notes = "Created from Controll Notch"

        do {
            try eventStore.save(event, span: .thisEvent)
            await eventBus.publish(
                NotchEvent(
                    kind: .entityUpserted,
                    source: "calendar.eventkit",
                    payload: .attributes([
                        "type": "event",
                        "title": title,
                    ])
                )
            )
            return true
        } catch {
            if let diagnostics {
                await diagnostics.record(
                    level: .error,
                    message: "Failed to create calendar event.",
                    source: "calendar.eventkit",
                    metadata: ["error": String(describing: error)]
                )
            }
            return false
        }
    }

    func createReminder(title: String, preferredSourceIDs: Set<String>) async -> Bool {
        guard await ensureRemindersAccess() else { return false }
        guard let defaultReminderCalendar = preferredCalendar(
            for: .reminder,
            preferredSourceIDs: preferredSourceIDs
        ) ?? eventStore.defaultCalendarForNewReminders() else { return false }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = defaultReminderCalendar
        reminder.title = title
        reminder.priority = 5
        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: Date().addingTimeInterval(3600)
        )

        do {
            try eventStore.save(reminder, commit: true)
            await eventBus.publish(
                NotchEvent(
                    kind: .entityUpserted,
                    source: "calendar.eventkit",
                    payload: .attributes([
                        "type": "reminder",
                        "title": title,
                    ])
                )
            )
            return true
        } catch {
            if let diagnostics {
                await diagnostics.record(
                    level: .error,
                    message: "Failed to create reminder.",
                    source: "calendar.eventkit",
                    metadata: ["error": String(describing: error)]
                )
            }
            return false
        }
    }

    private func ensureEventsAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess, .authorized:
            return true
        case .writeOnly:
            return false
        case .notDetermined:
            return await requestEventAccess()
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func ensureRemindersAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .fullAccess, .authorized:
            return true
        case .writeOnly:
            return true
        case .notDetermined:
            return await requestReminderAccess()
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func requestEventAccess() async -> Bool {
        if #available(macOS 14.0, *) {
            return await withCheckedContinuation { continuation in
                eventStore.requestFullAccessToEvents { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }

#if swift(>=5.9)
        return await withCheckedContinuation { continuation in
            eventStore.requestAccess(to: .event) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
#else
        return false
#endif
    }

    private func requestReminderAccess() async -> Bool {
        if #available(macOS 14.0, *) {
            return await withCheckedContinuation { continuation in
                eventStore.requestFullAccessToReminders { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }

#if swift(>=5.9)
        return await withCheckedContinuation { continuation in
            eventStore.requestAccess(to: .reminder) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
#else
        return false
#endif
    }

    private func timeLabel(for event: EKEvent) -> String {
        if event.isAllDay {
            return "All Day"
        }

        return "\(timeFormatter.string(from: event.startDate)) - \(timeFormatter.string(from: event.endDate))"
    }

    private func relativeLabel(for date: Date, now: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return relativeFormatter.localizedString(for: date, relativeTo: now)
        }
        if Calendar.current.isDateInTomorrow(date) {
            return "tomorrow"
        }
        return DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
    }

    private func publishRefreshSignal(eventCount: Int) async {
        await eventBus.publish(
            NotchEvent(
                kind: .entityUpserted,
                source: "calendar.eventkit",
                payload: .attributes([
                    "type": "timeline",
                    "count": String(eventCount),
                ])
            )
        )
    }

    private func preferredCalendar(for type: EKEntityType, preferredSourceIDs: Set<String>) -> EKCalendar? {
        guard !preferredSourceIDs.isEmpty else { return nil }
        return eventStore.calendars(for: type).first {
            preferredSourceIDs.contains($0.calendarIdentifier)
        }
    }

    private func colorHex(for cgColor: CGColor?) -> String? {
        guard
            let cgColor,
            let nsColor = NSColor(cgColor: cgColor)?.usingColorSpace(.deviceRGB)
        else { return nil }

        let red = Int(round(nsColor.redComponent * 255))
        let green = Int(round(nsColor.greenComponent * 255))
        let blue = Int(round(nsColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

private struct LocalhostProbeDefinition: Sendable {
    let id: String
    let name: String
    let endpoint: String
    let processHint: String
}

private actor LocalhostProbeService {
    private let eventBus: NotchEventBus
    private let diagnostics: RuntimeDiagnostics?
    private let definitions: [LocalhostProbeDefinition]
    private let urlSession: URLSession

    init(eventBus: NotchEventBus, diagnostics: RuntimeDiagnostics?) {
        self.eventBus = eventBus
        self.diagnostics = diagnostics
        self.urlSession = URLSession(configuration: .ephemeral)
        self.definitions = [
            LocalhostProbeDefinition(id: "svc-1", name: "notch-api", endpoint: "http://localhost:8080", processHint: "8080"),
            LocalhostProbeDefinition(id: "svc-2", name: "notch-web", endpoint: "http://localhost:3000", processHint: "3000"),
            LocalhostProbeDefinition(id: "svc-3", name: "worker-jobs", endpoint: "http://localhost:9091", processHint: "worker"),
        ]
    }

    func refresh(showHealthyServices: Bool) async -> [ShellLocalhostService] {
        var services: [ShellLocalhostService] = []
        services.reserveCapacity(definitions.count)

        for definition in definitions {
            let service = await probeService(definition)
            services.append(service)
        }

        if !showHealthyServices {
            let unhealthy = services.filter { $0.status != .healthy }
            if !unhealthy.isEmpty {
                services = unhealthy
            }
        }

        await eventBus.publish(
            NotchEvent(
                kind: .entityUpserted,
                source: "localhost.probe",
                payload: .attributes([
                    "count": String(services.count),
                    "healthy": String(services.filter { $0.status == .healthy }.count),
                ])
            )
        )

        if let diagnostics {
            let downServices = services.filter { $0.status == .down }.map(\.name)
            if !downServices.isEmpty {
                await diagnostics.record(
                    level: .warning,
                    message: "One or more localhost services are down.",
                    source: "localhost.probe",
                    metadata: ["downServices": downServices.joined(separator: ",")]
                )
            }
        }

        return services
    }

    private func probeService(_ definition: LocalhostProbeDefinition) async -> ShellLocalhostService {
        let status = await requestStatus(for: definition.endpoint)
        let resources = sampleProcessResources(for: definition.processHint)

        return ShellLocalhostService(
            id: definition.id,
            name: definition.name,
            endpoint: definition.endpoint,
            status: status,
            ramUsageMB: resources.ramMB,
            cpuPercent: resources.cpuPercent
        )
    }

    private func requestStatus(for endpoint: String) async -> ShellLocalhostServiceStatus {
        guard let url = URL(string: endpoint) else { return .down }

        var request = URLRequest(url: url)
        request.timeoutInterval = 1.2
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (_, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return .healthy }
            switch httpResponse.statusCode {
            case 200..<400:
                return .healthy
            case 400..<500:
                return .degraded
            default:
                return .down
            }
        } catch {
            return .down
        }
    }

    private func sampleProcessResources(for hint: String) -> (ramMB: Int, cpuPercent: Int) {
        let pids = processIDs(matching: hint)
        guard !pids.isEmpty else { return (0, 0) }

        var ramTotalKB = 0
        var cpuTotal = 0.0

        for pid in pids {
            let rss = readSingleMetric(command: "/bin/ps", arguments: ["-o", "rss=", "-p", String(pid)])
            let cpu = readSingleMetric(command: "/bin/ps", arguments: ["-o", "%cpu=", "-p", String(pid)])
            ramTotalKB += Int(rss) ?? 0
            cpuTotal += Double(cpu) ?? 0
        }

        return (max(0, ramTotalKB / 1024), max(0, Int(cpuTotal.rounded())))
    }

    private func processIDs(matching hint: String) -> [Int] {
        guard let output = runCommand(command: "/usr/bin/pgrep", arguments: ["-f", hint]) else { return [] }
        return output
            .split(separator: "\n")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private func readSingleMetric(command: String, arguments: [String]) -> String {
        runCommand(command: command, arguments: arguments)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
    }

    private func runCommand(command: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}

private actor HabitsLearningStoreService {
    private enum LegacyMockIDs {
        static let habits: Set<String> = ["habit-1", "habit-2", "habit-3"]
        static let learnings: Set<String> = ["learn-1", "learn-2", "learn-3"]
    }

    private enum Keys {
        static let habits = "notch.store.habits"
        static let learnings = "notch.store.learnings"
    }

    private let persistenceStore: PersistenceStore
    private let eventBus: NotchEventBus
    private let diagnostics: RuntimeDiagnostics?

    private var cachedHabits: [ShellHabitProgress] = []
    private var cachedLearnings: [ShellLearningSignal] = []

    init(
        persistenceStore: PersistenceStore,
        eventBus: NotchEventBus,
        diagnostics: RuntimeDiagnostics?
    ) {
        self.persistenceStore = persistenceStore
        self.eventBus = eventBus
        self.diagnostics = diagnostics
    }

    func start() async {
        await loadFromPersistence()
    }

    func refresh() async {
        await loadFromPersistence()
    }

    func habits() -> [ShellHabitProgress] {
        cachedHabits
    }

    func learnings() -> [ShellLearningSignal] {
        cachedLearnings
    }

    func toggleHabit(id: String) async {
        guard let index = cachedHabits.firstIndex(where: { $0.id == id }) else { return }
        var habit = cachedHabits[index]
        let targetUnits = max(1, habit.targetUnits)
        let isCompleted = habit.completedUnits >= targetUnits
        let nextCompletedUnits = isCompleted ? 0 : min(targetUnits, habit.completedUnits + 1)
        habit = ShellHabitProgress(
            id: habit.id,
            title: habit.title,
            completedUnits: nextCompletedUnits,
            targetUnits: targetUnits,
            streakDays: habit.streakDays
        )
        cachedHabits[index] = habit
        await persistHabits()
        await publishMutationSignal(type: "habit", id: id)
    }

    func createHabit(title: String, targetUnits: Int) async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }

        if cachedHabits.contains(where: { $0.title.localizedCaseInsensitiveCompare(trimmedTitle) == .orderedSame }) {
            return false
        }

        let habit = ShellHabitProgress(
            id: "habit-\(UUID().uuidString)",
            title: trimmedTitle,
            completedUnits: 0,
            targetUnits: max(1, targetUnits),
            streakDays: 0
        )

        cachedHabits.append(habit)
        cachedHabits.sort {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        await persistHabits()
        await publishMutationSignal(type: "habit", id: habit.id)
        return true
    }

    func deleteHabit(id: String) async -> Bool {
        guard let index = cachedHabits.firstIndex(where: { $0.id == id }) else { return false }
        cachedHabits.remove(at: index)
        await persistHabits()
        await publishMutationSignal(type: "habit", id: id)
        return true
    }

    func deleteLegacyMockData() async -> Bool {
        let habitsBefore = cachedHabits.count
        let learningsBefore = cachedLearnings.count

        cachedHabits.removeAll(where: { LegacyMockIDs.habits.contains($0.id) })
        cachedLearnings.removeAll(where: { LegacyMockIDs.learnings.contains($0.id) })

        let didChange = habitsBefore != cachedHabits.count || learningsBefore != cachedLearnings.count
        guard didChange else { return false }

        await persistHabits()
        await persistLearnings()
        await publishMutationSignal(type: "mock-cleanup", id: "legacy-phase-zero")
        return true
    }

    func captureLearningSignal() async {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let label = formatter.string(from: Date())

        let entry = ShellLearningSignal(
            id: "learn-\(UUID().uuidString)",
            title: "Learning capture \(label)",
            source: "Local",
            capturedAtLabel: "just now"
        )

        cachedLearnings.insert(entry, at: 0)
        if cachedLearnings.count > 30 {
            cachedLearnings = Array(cachedLearnings.prefix(30))
        }
        await persistLearnings()
        await publishMutationSignal(type: "learning", id: entry.id)
    }

    private func loadFromPersistence() async {
        do {
            cachedHabits = try await persistenceStore.load([ShellHabitProgress].self, for: Keys.habits) ?? []
            cachedLearnings = try await persistenceStore.load([ShellLearningSignal].self, for: Keys.learnings) ?? []
        } catch {
            if let diagnostics {
                await diagnostics.record(
                    level: .error,
                    message: "Failed to load habits/learnings persistence.",
                    source: "habits.local",
                    metadata: ["error": String(describing: error)]
                )
            }
            cachedHabits = []
            cachedLearnings = []
        }
    }

    private func persistHabits() async {
        do {
            try await persistenceStore.save(cachedHabits, for: Keys.habits)
        } catch {
            if let diagnostics {
                await diagnostics.record(
                    level: .error,
                    message: "Failed to persist habits.",
                    source: "habits.local",
                    metadata: ["error": String(describing: error)]
                )
            }
        }
    }

    private func persistLearnings() async {
        do {
            try await persistenceStore.save(cachedLearnings, for: Keys.learnings)
        } catch {
            if let diagnostics {
                await diagnostics.record(
                    level: .error,
                    message: "Failed to persist learnings.",
                    source: "learning.local",
                    metadata: ["error": String(describing: error)]
                )
            }
        }
    }

    private func publishMutationSignal(type: String, id: String) async {
        await eventBus.publish(
            NotchEvent(
                kind: .entityUpserted,
                source: "habits.local",
                payload: .attributes([
                    "type": type,
                    "id": id,
                    "habitsCount": String(cachedHabits.count),
                    "learningsCount": String(cachedLearnings.count),
                ])
            )
        )
    }
}

private enum NotionSyncState: Sendable {
    case skipped
    case configured
    case unavailable
}

private actor NotionSyncService {
    private let eventBus: NotchEventBus
    private let diagnostics: RuntimeDiagnostics?
    private let urlSession: URLSession

    init(eventBus: NotchEventBus, diagnostics: RuntimeDiagnostics?) {
        self.eventBus = eventBus
        self.diagnostics = diagnostics
        self.urlSession = URLSession(configuration: .ephemeral)
    }

    func syncIfConfigured(
        habits: [ShellHabitProgress],
        learnings: [ShellLearningSignal],
        enabled: Bool
    ) async -> NotionSyncState {
        guard enabled else { return .skipped }

        guard let token = ProcessInfo.processInfo.environment["NOTION_API_KEY"], !token.isEmpty else {
            await publishNotionSignal(state: .unavailable, habits: habits.count, learnings: learnings.count)
            return .unavailable
        }

        var request = URLRequest(url: URL(string: "https://api.notion.com/v1/users/me")!)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")

        do {
            let (_, response) = try await urlSession.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) {
                await publishNotionSignal(state: .configured, habits: habits.count, learnings: learnings.count)
                return .configured
            }
            await publishNotionSignal(state: .unavailable, habits: habits.count, learnings: learnings.count)
            return .unavailable
        } catch {
            if let diagnostics {
                await diagnostics.record(
                    level: .warning,
                    message: "Notion sync check failed.",
                    source: "notion.sync",
                    metadata: ["error": String(describing: error)]
                )
            }
            await publishNotionSignal(state: .unavailable, habits: habits.count, learnings: learnings.count)
            return .unavailable
        }
    }

    private func publishNotionSignal(state: NotionSyncState, habits: Int, learnings: Int) async {
        let stateLabel: String
        switch state {
        case .skipped:
            stateLabel = "skipped"
        case .configured:
            stateLabel = "configured"
        case .unavailable:
            stateLabel = "unavailable"
        }

        await eventBus.publish(
            NotchEvent(
                kind: .signalChanged,
                source: "notion.sync",
                payload: .attributes([
                    "state": stateLabel,
                    "habits": String(habits),
                    "learnings": String(learnings),
                ])
            )
        )
    }
}

private extension ShellStatusSnapshot {
    func updatingCalendar(_ events: [ShellCalendarEvent]) -> ShellStatusSnapshot {
        let nextLabel = events.first.map { "\($0.title) \u{2022} \($0.timeLabel)" } ?? "No events scheduled"
        return ShellStatusSnapshot(
            focusLabel: focusLabel,
            nextEventLabel: nextLabel,
            hostStatusLabel: hostStatusLabel,
            openHighlights: openHighlights,
            overview: overview,
            statusIcons: statusIcons,
            batteryPercentage: batteryPercentage,
            calendarEvents: events,
            localhostServices: localhostServices,
            habits: habits,
            learningSignals: learningSignals
        )
    }

    func updatingLocalhost(_ services: [ShellLocalhostService]) -> ShellStatusSnapshot {
        let healthy = services.filter { $0.status == .healthy }.count
        let hostLabel = services.isEmpty ? "No hosts configured" : "\(healthy)/\(services.count) hosts up"
        return ShellStatusSnapshot(
            focusLabel: focusLabel,
            nextEventLabel: nextEventLabel,
            hostStatusLabel: hostLabel,
            openHighlights: openHighlights,
            overview: overview,
            statusIcons: statusIcons,
            batteryPercentage: batteryPercentage,
            calendarEvents: calendarEvents,
            localhostServices: services,
            habits: habits,
            learningSignals: learningSignals
        )
    }

    func updatingHabitsLearning(
        habits: [ShellHabitProgress],
        learnings: [ShellLearningSignal]
    ) -> ShellStatusSnapshot {
        return ShellStatusSnapshot(
            focusLabel: focusLabel,
            nextEventLabel: nextEventLabel,
            hostStatusLabel: hostStatusLabel,
            openHighlights: openHighlights,
            overview: overview,
            statusIcons: statusIcons,
            batteryPercentage: batteryPercentage,
            calendarEvents: calendarEvents,
            localhostServices: localhostServices,
            habits: habits,
            learningSignals: learnings
        )
    }
}
