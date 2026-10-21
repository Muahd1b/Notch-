import AppKit
import EventKit
import Foundation

actor CalendarEventKitService {
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
            // Never prompt at launch: permission is requested from Settings, in context.
            return false
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
            // Never prompt at launch: permission is requested from Settings, in context.
            return false
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
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
