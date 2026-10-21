import AppKit
import EventKit
import SwiftUI
import UniformTypeIdentifiers

struct CalendarSettingsView: View {
    @ObservedObject var settings: AppSettingsStore
    @State private var calendars: [SelectableSource] = []
    @State private var reminders: [SelectableSource] = []
    @State private var eventStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @State private var reminderStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    @State private var requestingCalendarAccess = false
    @State private var requestingReminderAccess = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Calendar Access") {
                    permissionBadge(for: eventStatus, domain: .calendar)
                }

                if !hasCalendarAccess {
                    Button("Connect Apple Calendar") {
                        Task { await requestCalendarAccess() }
                    }
                    .disabled(requestingCalendarAccess)
                }

                LabeledContent("Reminders Access") {
                    permissionBadge(for: reminderStatus, domain: .reminders)
                }

                if !hasReminderAccess {
                    Button("Connect Apple Reminders") {
                        Task { await requestReminderAccess() }
                    }
                    .disabled(requestingReminderAccess)
                }

                if eventStatus == .denied || reminderStatus == .denied {
                    Button("Open System Settings Privacy") {
                        openPrivacySettings()
                    }
                }

                Button("Reload Calendars & Reminders") {
                    Task { await loadSourcesFromEventKit() }
                }
            } header: {
                Text("Apple Connections")
            } footer: {
                Text("Connect Apple Calendar and Reminders here. After access is granted, selectable sources appear below.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Show calendar", isOn: $settings.calendarEnabled)
                Toggle("Hide completed reminders", isOn: $settings.hideCompletedReminders)
                    .disabled(!settings.calendarEnabled)
                Toggle("Hide all-day events", isOn: $settings.hideAllDayEvents)
                    .disabled(!settings.calendarEnabled)
                Toggle("Auto-scroll to next event", isOn: $settings.autoScrollToNextEvent)
                    .disabled(!settings.calendarEnabled)
                Toggle("Always show full event titles", isOn: $settings.alwaysShowFullEventTitles)
                    .disabled(!settings.calendarEnabled)
            } header: {
                Text("General")
            }

            Section {
                Toggle("Show next event in closed state", isOn: $settings.calendarClosedStateEnabled)
                    .disabled(!settings.calendarEnabled)
                Toggle("Include all-day events in open notch", isOn: $settings.calendarShowAllDayEvents)
                    .disabled(!settings.calendarEnabled)
                Toggle("Include tomorrow when today is empty", isOn: $settings.calendarIncludeTomorrow)
                    .disabled(!settings.calendarEnabled)
                LabeledContent("Lookahead window") {
                    Text("\(Int(settings.calendarLookaheadHours))h")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.calendarLookaheadHours, in: 1...24, step: 1)
                    .disabled(!settings.calendarEnabled)
            } header: {
                Text("Notch presentation")
            }

            SourceSelectionSection(
                title: "Calendars",
                sources: calendars,
                selection: $settings.selectedCalendarSourceIDs,
                disabled: !settings.calendarEnabled
            )

            SourceSelectionSection(
                title: "Reminders",
                sources: reminders,
                selection: $settings.selectedReminderSourceIDs,
                disabled: !settings.calendarEnabled
            )
        }
        .navigationTitle("Calendar")
        .task {
            refreshAuthorizationStatuses()
            await loadSourcesFromEventKit()
        }
    }

    private func loadSourcesFromEventKit() async {
        let eventStore = EKEventStore()
        refreshAuthorizationStatuses()

        let eventCalendars: [EKCalendar]
        switch eventStatus {
        case .fullAccess, .authorized:
            eventCalendars = eventStore.calendars(for: .event)
        default:
            eventCalendars = []
        }

        let reminderCalendars: [EKCalendar]
        switch reminderStatus {
        case .fullAccess, .authorized, .writeOnly:
            reminderCalendars = eventStore.calendars(for: .reminder)
        default:
            reminderCalendars = []
        }

        calendars = eventCalendars.map { calendar in
            SelectableSource(
                id: calendar.calendarIdentifier,
                name: calendar.title,
                color: Color(nsColor: calendar.color)
            )
        }

        reminders = reminderCalendars.map { calendar in
            SelectableSource(
                id: calendar.calendarIdentifier,
                name: calendar.title,
                color: Color(nsColor: calendar.color)
            )
        }
    }

    private var hasCalendarAccess: Bool {
        switch eventStatus {
        case .fullAccess, .authorized:
            return true
        default:
            return false
        }
    }

    private var hasReminderAccess: Bool {
        switch reminderStatus {
        case .fullAccess, .authorized, .writeOnly:
            return true
        default:
            return false
        }
    }

    private enum PermissionDomain {
        case calendar
        case reminders
    }

    private func permissionBadge(for status: EKAuthorizationStatus, domain: PermissionDomain) -> some View {
        let label: String
        let color: Color

        switch status {
        case .fullAccess, .authorized:
            label = "Connected"
            color = .green
        case .writeOnly:
            label = domain == .reminders ? "Write Only" : "Limited"
            color = .orange
        case .notDetermined:
            label = "Not Connected"
            color = .secondary
        case .denied:
            label = "Denied"
            color = .red
        case .restricted:
            label = "Restricted"
            color = .orange
        @unknown default:
            label = "Unknown"
            color = .secondary
        }

        return Text(label)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
    }

    private func refreshAuthorizationStatuses() {
        eventStatus = EKEventStore.authorizationStatus(for: .event)
        reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
    }

    private func requestCalendarAccess() async {
        if eventStatus == .denied || eventStatus == .restricted {
            openPrivacySettings()
            return
        }

        requestingCalendarAccess = true
        defer { requestingCalendarAccess = false }

        let eventStore = EKEventStore()
        if #available(macOS 14.0, *) {
            _ = await withCheckedContinuation { continuation in
                eventStore.requestFullAccessToEvents { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        } else {
#if swift(>=5.9)
            _ = await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
#endif
        }

        refreshAuthorizationStatuses()
        await loadSourcesFromEventKit()
    }

    private func requestReminderAccess() async {
        if reminderStatus == .denied || reminderStatus == .restricted {
            openPrivacySettings()
            return
        }

        requestingReminderAccess = true
        defer { requestingReminderAccess = false }

        let eventStore = EKEventStore()
        if #available(macOS 14.0, *) {
            _ = await withCheckedContinuation { continuation in
                eventStore.requestFullAccessToReminders { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        } else {
#if swift(>=5.9)
            _ = await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .reminder) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
#endif
        }

        refreshAuthorizationStatuses()
        await loadSourcesFromEventKit()
    }

    private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}
