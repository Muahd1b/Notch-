import EventKit
import AppKit
import SwiftUI

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case notifications = "Notifications"
    case calendar = "Calendar"
    case media = "Media"
    case agents = "Agents"
    case localhost = "Localhost"
    case habits = "Habits"
    case learnings = "Learnings"
    case focus = "Focus"
    case advanced = "Advanced"
    case about = "About"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .general:
            return "gear"
        case .appearance:
            return "eye"
        case .notifications:
            return "bell.badge"
        case .calendar:
            return "calendar"
        case .media:
            return "play.fill"
        case .agents:
            return "bolt.badge.clock"
        case .localhost:
            return "server.rack"
        case .habits:
            return "checklist"
        case .learnings:
            return "book.closed"
        case .focus:
            return "timer"
        case .advanced:
            return "gearshape.2"
        case .about:
            return "info.circle"
        }
    }
}

struct SettingsView: View {
    private static let defaultWidth: CGFloat = 920
    private static let minimumWidth: CGFloat = 880

    @ObservedObject var settings: AppSettingsStore
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.rawValue, systemImage: tab.symbolName)
                    }
                }
            }
            .listStyle(.sidebar)
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(200)
        } detail: {
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView(settings: settings)
                case .appearance:
                    AppearanceSettingsView(settings: settings)
                case .notifications:
                    NotificationSettingsView(settings: settings)
                case .calendar:
                    CalendarSettingsView(settings: settings)
                case .media:
                    MediaSettingsView(settings: settings)
                case .agents:
                    AgentSettingsView(settings: settings)
                case .localhost:
                    LocalhostSettingsView(settings: settings)
                case .habits:
                    HabitsSettingsView(settings: settings)
                case .learnings:
                    LearningsSettingsView(settings: settings)
                case .focus:
                    FocusSettingsView(settings: settings)
                case .advanced:
                    AdvancedSettingsView(settings: settings)
                case .about:
                    AboutSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Quit app") {
                    NSApp.terminate(nil)
                }
                .controlSize(.extraLarge)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: Self.minimumWidth, idealWidth: Self.defaultWidth, maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings-root")
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettingsStore
    @State private var screens: [(id: String, name: String)] = []

    var body: some View {
        Form {
            Section {
                Toggle("Show menu bar icon", isOn: $settings.menubarIcon)
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                Toggle("Show on all displays", isOn: $settings.showOnAllDisplays)

                Picker("Preferred display", selection: Binding($settings.preferredDisplayID, replacingNilWith: "")) {
                    ForEach(screens, id: \.id) { screen in
                        Text(screen.name).tag(screen.id)
                    }
                }
                .disabled(settings.showOnAllDisplays || screens.isEmpty)

                Toggle("Automatically switch displays", isOn: $settings.automaticallySwitchDisplay)
                    .disabled(settings.showOnAllDisplays)
            } header: {
                Text("System features")
            }

            Section {
                Picker("Notch height on notch displays", selection: $settings.notchHeightMode) {
                    ForEach(WindowHeightMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                if settings.notchHeightMode == .custom {
                    Slider(value: $settings.notchHeight, in: 15...45, step: 1)
                }

                Picker("Notch height on non-notch displays", selection: $settings.nonNotchHeightMode) {
                    ForEach(WindowHeightMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                if settings.nonNotchHeightMode == .custom {
                    Slider(value: $settings.nonNotchHeight, in: 15...45, step: 1)
                }
            } header: {
                Text("Notch sizing")
            }

            Section {
                Toggle("Open notch on hover", isOn: $settings.openNotchOnHover)
                Toggle("Enable haptic feedback", isOn: $settings.enableHaptics)
                Toggle("Remember last tab", isOn: $settings.rememberLastTab)

                if settings.openNotchOnHover {
                    LabeledContent("Hover delay") {
                        HStack(spacing: 12) {
                            Text("\(settings.hoverDelay, specifier: "%.1f")s")
                                .foregroundStyle(.secondary)
                            Slider(value: $settings.hoverDelay, in: 0...1, step: 0.1)
                                .frame(width: 220)
                        }
                    }
                }
            } header: {
                Text("Notch behavior")
            }

            Section {
                Toggle("Enable gestures", isOn: $settings.gesturesEnabled)
                Toggle("Close gesture", isOn: $settings.closeGestureEnabled)
                    .disabled(!settings.gesturesEnabled)

                LabeledContent("Gesture sensitivity") {
                    Text(gestureSensitivityLabel(settings.gestureSensitivity))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.gestureSensitivity, in: 0...1, step: 0.1)
                    .disabled(!settings.gesturesEnabled)
            } header: {
                SettingsSectionHeader(title: "Gesture control", badge: "Beta")
            } footer: {
                Text("Two-finger swipe up closes the notch. Down gestures can become the primary open path when hover-open is disabled.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("General")
        .onAppear {
            screens = settings.availableDisplays()
            if settings.preferredDisplayID == nil {
                settings.preferredDisplayID = screens.first?.id
            }
        }
    }
}

private struct AppearanceSettingsView: View {
    @ObservedObject var settings: AppSettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Show settings icon in symbol bar", isOn: $settings.settingsIconInSymbolBar)
                Toggle("Use glass highlighting", isOn: $settings.useGlassHighlighting)
                Toggle("Dim shell when inactive", isOn: $settings.dimShellWhenInactive)
            } header: {
                Text("Shell appearance")
            } footer: {
                Text("This first pass ports the Boring Notch shell language and adapts its controls to Notch-.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .navigationTitle("Appearance")
    }
}

private struct NotificationSettingsView: View {
    @ObservedObject var settings: AppSettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Enable notifications", isOn: $settings.notificationsEnabled)
                Toggle("Show notifications in closed state", isOn: $settings.notificationsClosedStateEnabled)
                    .disabled(!settings.notificationsEnabled)
                Toggle("Show notification badges in header", isOn: $settings.notificationsShowBadges)
                    .disabled(!settings.notificationsEnabled)
            } header: {
                Text("Visibility")
            }

            Section {
                Toggle("Use haptics for urgent notifications", isOn: $settings.enableHaptics)
                    .disabled(!settings.notificationsEnabled)
                Text("Notification haptics reuse the global shell haptics channel.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Delivery")
            }
        }
        .navigationTitle("Notifications")
    }
}

private struct CalendarSettingsView: View {
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

private struct MediaSettingsView: View {
    @ObservedObject var settings: AppSettingsStore
    @ObservedObject private var media = ShellMediaIntegrationService.shared

    var body: some View {
        Form {
            Section {
                Toggle("Enable media controls", isOn: $settings.mediaControlsEnabled)
                Toggle("Show media in closed state", isOn: $settings.mediaClosedStateEnabled)
                    .disabled(!settings.mediaControlsEnabled)
            } header: {
                Text("Playback")
            }

            Section {
                Toggle("Enable gestures", isOn: $settings.gesturesEnabled)
                Toggle("Change media with horizontal gestures", isOn: $settings.horizontalMediaGesturesEnabled)
                    .disabled(!settings.gesturesEnabled || !settings.mediaControlsEnabled)
                Toggle("Keep shell open while controlling media", isOn: $settings.keepShellOpenOnClick)
                    .disabled(!settings.mediaControlsEnabled)
            } header: {
                Text("Interaction")
            }

            Section {
                providerRow(
                    title: "Spotify",
                    enabled: $settings.mediaSpotifyIntegrationEnabled,
                    connected: media.spotifyConnected,
                    connect: { await media.connect(.spotify) },
                    disconnect: { await media.disconnect(.spotify) }
                )

                providerRow(
                    title: "Apple Music",
                    enabled: $settings.mediaAppleMusicIntegrationEnabled,
                    connected: media.appleMusicConnected,
                    connect: { await media.connect(.appleMusic) },
                    disconnect: { await media.disconnect(.appleMusic) }
                )

                Button("Open macOS Automation Privacy") {
                    openAutomationPrivacySettings()
                }
                .buttonStyle(.link)

                Text(media.statusLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Integrations")
            }
        }
        .navigationTitle("Media")
        .onAppear {
            media.start()
            Task { await media.refresh() }
        }
        .onDisappear {
            media.stop()
        }
    }

    @ViewBuilder
    private func providerRow(
        title: String,
        enabled: Binding<Bool>,
        connected: Bool,
        connect: @escaping @Sendable () async -> Void,
        disconnect: @escaping @Sendable () async -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Enable \(title) integration", isOn: enabled)
                .onChange(of: enabled.wrappedValue) { _, isEnabled in
                    Task {
                        if isEnabled {
                            await connect()
                        } else {
                            await disconnect()
                        }
                    }
                }

            HStack {
                Text(connected ? "Connected" : (enabled.wrappedValue ? "Enabled, waiting for app" : "Disabled"))
                    .font(.footnote)
                    .foregroundStyle(connected ? .green : .secondary)
                Spacer()
                Button(connected ? "Disconnect" : "Connect") {
                    Task {
                        if connected {
                            await disconnect()
                        } else {
                            await connect()
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func openAutomationPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct AgentSettingsView: View {
    @ObservedObject var settings: AppSettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Codex monitoring", isOn: $settings.codexMonitoringEnabled)
                Toggle("Claude Code monitoring", isOn: $settings.claudeMonitoringEnabled)
                Toggle("OpenClaw monitoring", isOn: $settings.openClawMonitoringEnabled)
            } header: {
                Text("Providers")
            }

            Section {
                Toggle("Show agent status in closed state", isOn: $settings.agentStatusInClosedState)
                Toggle("Show idle agents", isOn: $settings.showIdleAgents)
                LabeledContent("Refresh interval") {
                    Text("\(Int(settings.agentRefreshInterval))s")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.agentRefreshInterval, in: 3...30, step: 1)
            } header: {
                Text("Visibility")
            }
        }
        .navigationTitle("Agents")
    }
}

private struct LocalhostSettingsView: View {
    @ObservedObject var settings: AppSettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Enable localhost monitoring", isOn: $settings.localhostMonitoringEnabled)
                Toggle("Show localhost in closed state", isOn: $settings.localhostClosedStateEnabled)
                    .disabled(!settings.localhostMonitoringEnabled)
                Toggle("Show healthy services", isOn: $settings.localhostShowHealthyServices)
                    .disabled(!settings.localhostMonitoringEnabled)
            } header: {
                Text("Service registry")
            }

            Section {
                LabeledContent("Refresh interval") {
                    Text("\(Int(settings.localhostRefreshInterval))s")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.localhostRefreshInterval, in: 2...30, step: 1)
                    .disabled(!settings.localhostMonitoringEnabled)

                LabeledContent("Failure debounce") {
                    Text("\(settings.localhostFailureDebounce, specifier: "%.1f")s")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.localhostFailureDebounce, in: 0.5...10, step: 0.5)
                    .disabled(!settings.localhostMonitoringEnabled)
            } header: {
                Text("Polling")
            }
        }
        .navigationTitle("Localhost")
    }
}

private struct HabitsSettingsView: View {
    @ObservedObject var settings: AppSettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Enable habits", isOn: $settings.habitsEnabled)
                Toggle("Show habits in closed state", isOn: $settings.habitsClosedStateEnabled)
                    .disabled(!settings.habitsEnabled)
                Toggle("Daily reminders", isOn: $settings.habitsReminderEnabled)
                    .disabled(!settings.habitsEnabled)
            } header: {
                Text("Daily tracking")
            }

            Section {
                LabeledContent("Reset hour") {
                    Text(formatHour(settings.habitsDailyResetHour))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.habitsDailyResetHour, in: 0...23, step: 1)
                    .disabled(!settings.habitsEnabled)
            } header: {
                Text("Schedule")
            }
        }
        .navigationTitle("Habits")
    }
}

private struct LearningsSettingsView: View {
    @ObservedObject var settings: AppSettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Enable learnings", isOn: $settings.learningsEnabled)
                Toggle("Auto-capture learning sessions", isOn: $settings.autoCaptureLearnings)
                    .disabled(!settings.learningsEnabled)
                Toggle("Enable daily digest", isOn: $settings.learningDigestEnabled)
                    .disabled(!settings.learningsEnabled)
            } header: {
                Text("Capture")
            }

            Section {
                Toggle("Sync to Notion", isOn: $settings.notionSyncEnabled)
                    .disabled(!settings.learningsEnabled)
                Text("Notion sync is kept local-first and can remain disabled until the local model is stable.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Sync")
            }
        }
        .navigationTitle("Learnings")
    }
}

private struct FocusSettingsView: View {
    @ObservedObject var settings: AppSettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Enable focus timer", isOn: $settings.focusEnabled)
                Toggle("Show focus in closed state", isOn: $settings.focusClosedStateEnabled)
                    .disabled(!settings.focusEnabled)
            } header: {
                Text("Timer")
            }

            Section {
                LabeledContent("Focus duration") {
                    Text("\(Int(settings.focusDurationMinutes)) min")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.focusDurationMinutes, in: 15...90, step: 5)
                    .disabled(!settings.focusEnabled)

                LabeledContent("Short break") {
                    Text("\(Int(settings.shortBreakMinutes)) min")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.shortBreakMinutes, in: 3...20, step: 1)
                    .disabled(!settings.focusEnabled)
            } header: {
                Text("Durations")
            }

            Section {
                Toggle("Auto-start breaks", isOn: $settings.autoStartBreaks)
                    .disabled(!settings.focusEnabled)
                Toggle("Auto-start next focus session", isOn: $settings.autoStartFocusSessions)
                    .disabled(!settings.focusEnabled)
            } header: {
                Text("Automation")
            }
        }
        .navigationTitle("Focus")
    }
}

private struct AdvancedSettingsView: View {
    @ObservedObject var settings: AppSettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Log adapter failures", isOn: $settings.logAdapterFailures)
                Toggle("Show debug overlay", isOn: $settings.showDebugOverlay)
                Toggle("Keep shell open after click", isOn: $settings.keepShellOpenOnClick)
            } header: {
                Text("Diagnostics")
            }

            Section {
                Text("These controls are for shell iteration and adapter bring-up. Keep them conservative until the core spine is in place.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Notes")
            }
        }
        .navigationTitle("Advanced")
    }
}

private struct SourceSelectionSection: View {
    let title: String
    let sources: [SelectableSource]
    @Binding var selection: Set<String>
    let disabled: Bool

    var body: some View {
        Section {
            if sources.isEmpty {
                Text("No sources available yet. Connect access above, then reload.")
                    .foregroundStyle(.secondary)
            }
            ForEach(sources) { source in
                Button {
                    if selection.contains(source.id) {
                        selection.remove(source.id)
                    } else {
                        selection.insert(source.id)
                    }
                } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(source.color)
                            .frame(width: 20, height: 20)
                            .overlay {
                                if selection.contains(source.id) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }

                        Text(source.name)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(disabled)
            }
        } header: {
            Text(title)
        }
    }
}

private struct AboutSettingsView: View {
    var body: some View {
        Form {
            Section {
                Text("Notch-")
                    .font(.headline)
                Text("Developer command center for the notch.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("About")
            }
        }
        .navigationTitle("About")
    }
}

private struct SettingsSectionHeader: View {
    let title: String
    let badge: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            if let badge {
                Text(badge)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.08), in: Capsule())
            }
        }
    }
}

private struct SelectableSource: Identifiable {
    let id: String
    let name: String
    let color: Color
}

private extension Binding where Value == String {
    init(_ source: Binding<String?>, replacingNilWith defaultValue: String) {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { newValue in
                source.wrappedValue = newValue.isEmpty ? nil : newValue
            }
        )
    }
}

private func formatHour(_ value: Double) -> String {
    let hour = Int(value.rounded())
    let suffix = hour < 12 ? "AM" : "PM"
    let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
    return "\(displayHour):00 \(suffix)"
}

private func gestureSensitivityLabel(_ value: Double) -> String {
    switch value {
    case ..<0.34:
        return "Low"
    case ..<0.67:
        return "Medium"
    default:
        return "High"
    }
}
