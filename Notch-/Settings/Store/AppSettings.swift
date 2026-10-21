import AppKit
import Combine
import Foundation

final class AppSettingsStore: ObservableObject {
    static let shared = AppSettingsStore()

    @Published var menubarIcon: Bool { didSet { defaults.set(menubarIcon, forKey: AppSettingsKeys.menubarIcon) } }
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: AppSettingsKeys.launchAtLogin)
            LaunchAtLoginService.apply(enabled: launchAtLogin)
        }
    }
    @Published var showOnAllDisplays: Bool { didSet { defaults.set(showOnAllDisplays, forKey: AppSettingsKeys.showOnAllDisplays) } }
    @Published var preferredDisplayID: String? {
        didSet {
            if let preferredDisplayID {
                defaults.set(preferredDisplayID, forKey: AppSettingsKeys.preferredDisplayID)
            } else {
                defaults.removeObject(forKey: AppSettingsKeys.preferredDisplayID)
            }
        }
    }
    @Published var automaticallySwitchDisplay: Bool { didSet { defaults.set(automaticallySwitchDisplay, forKey: AppSettingsKeys.automaticallySwitchDisplay) } }

    @Published var notchHeightMode: WindowHeightMode { didSet { defaults.set(notchHeightMode.rawValue, forKey: AppSettingsKeys.notchHeightMode) } }
    @Published var nonNotchHeightMode: WindowHeightMode { didSet { defaults.set(nonNotchHeightMode.rawValue, forKey: AppSettingsKeys.nonNotchHeightMode) } }
    @Published var notchHeight: Double { didSet { defaults.set(notchHeight, forKey: AppSettingsKeys.notchHeight) } }
    @Published var nonNotchHeight: Double { didSet { defaults.set(nonNotchHeight, forKey: AppSettingsKeys.nonNotchHeight) } }

    @Published var openNotchOnHover: Bool { didSet { defaults.set(openNotchOnHover, forKey: AppSettingsKeys.openNotchOnHover) } }
    @Published var enableHaptics: Bool { didSet { defaults.set(enableHaptics, forKey: AppSettingsKeys.enableHaptics) } }
    @Published var rememberLastTab: Bool { didSet { defaults.set(rememberLastTab, forKey: AppSettingsKeys.rememberLastTab) } }
    @Published var hoverDelay: Double { didSet { defaults.set(hoverDelay, forKey: AppSettingsKeys.hoverDelay) } }
    @Published var settingsIconInSymbolBar: Bool { didSet { defaults.set(settingsIconInSymbolBar, forKey: AppSettingsKeys.settingsIconInSymbolBar) } }
    @Published var useGlassHighlighting: Bool { didSet { defaults.set(useGlassHighlighting, forKey: AppSettingsKeys.useGlassHighlighting) } }
    @Published var dimShellWhenInactive: Bool { didSet { defaults.set(dimShellWhenInactive, forKey: AppSettingsKeys.dimShellWhenInactive) } }
    @Published var notificationsEnabled: Bool { didSet { defaults.set(notificationsEnabled, forKey: AppSettingsKeys.notificationsEnabled) } }
    @Published var notificationsClosedStateEnabled: Bool { didSet { defaults.set(notificationsClosedStateEnabled, forKey: AppSettingsKeys.notificationsClosedStateEnabled) } }
    @Published var notificationsShowBadges: Bool { didSet { defaults.set(notificationsShowBadges, forKey: AppSettingsKeys.notificationsShowBadges) } }

    @Published var calendarEnabled: Bool { didSet { defaults.set(calendarEnabled, forKey: AppSettingsKeys.calendarEnabled) } }
    @Published var calendarShowAllDayEvents: Bool { didSet { defaults.set(calendarShowAllDayEvents, forKey: AppSettingsKeys.calendarShowAllDayEvents) } }
    @Published var calendarIncludeTomorrow: Bool { didSet { defaults.set(calendarIncludeTomorrow, forKey: AppSettingsKeys.calendarIncludeTomorrow) } }
    @Published var calendarLookaheadHours: Double { didSet { defaults.set(calendarLookaheadHours, forKey: AppSettingsKeys.calendarLookaheadHours) } }
    @Published var calendarClosedStateEnabled: Bool { didSet { defaults.set(calendarClosedStateEnabled, forKey: AppSettingsKeys.calendarClosedStateEnabled) } }
    @Published var hideCompletedReminders: Bool { didSet { defaults.set(hideCompletedReminders, forKey: AppSettingsKeys.hideCompletedReminders) } }
    @Published var hideAllDayEvents: Bool { didSet { defaults.set(hideAllDayEvents, forKey: AppSettingsKeys.hideAllDayEvents) } }
    @Published var autoScrollToNextEvent: Bool { didSet { defaults.set(autoScrollToNextEvent, forKey: AppSettingsKeys.autoScrollToNextEvent) } }
    @Published var alwaysShowFullEventTitles: Bool { didSet { defaults.set(alwaysShowFullEventTitles, forKey: AppSettingsKeys.alwaysShowFullEventTitles) } }
    @Published var selectedCalendarSourceIDs: Set<String> {
        didSet { defaults.set(Array(selectedCalendarSourceIDs).sorted(), forKey: AppSettingsKeys.selectedCalendarSourceIDs) }
    }
    @Published var selectedReminderSourceIDs: Set<String> {
        didSet { defaults.set(Array(selectedReminderSourceIDs).sorted(), forKey: AppSettingsKeys.selectedReminderSourceIDs) }
    }
    @Published var mediaControlsEnabled: Bool { didSet { defaults.set(mediaControlsEnabled, forKey: AppSettingsKeys.mediaControlsEnabled) } }
    @Published var mediaClosedStateEnabled: Bool { didSet { defaults.set(mediaClosedStateEnabled, forKey: AppSettingsKeys.mediaClosedStateEnabled) } }
    @Published var mediaSpotifyIntegrationEnabled: Bool { didSet { defaults.set(mediaSpotifyIntegrationEnabled, forKey: AppSettingsKeys.mediaSpotifyIntegrationEnabled) } }
    @Published var mediaAppleMusicIntegrationEnabled: Bool { didSet { defaults.set(mediaAppleMusicIntegrationEnabled, forKey: AppSettingsKeys.mediaAppleMusicIntegrationEnabled) } }

    @Published var codexMonitoringEnabled: Bool { didSet { defaults.set(codexMonitoringEnabled, forKey: AppSettingsKeys.codexMonitoringEnabled) } }
    @Published var claudeMonitoringEnabled: Bool { didSet { defaults.set(claudeMonitoringEnabled, forKey: AppSettingsKeys.claudeMonitoringEnabled) } }
    @Published var openCodeMonitoringEnabled: Bool { didSet { defaults.set(openCodeMonitoringEnabled, forKey: AppSettingsKeys.openCodeMonitoringEnabled) } }
    @Published var ollamaMonitoringEnabled: Bool { didSet { defaults.set(ollamaMonitoringEnabled, forKey: AppSettingsKeys.ollamaMonitoringEnabled) } }
    @Published var showIdleAgents: Bool { didSet { defaults.set(showIdleAgents, forKey: AppSettingsKeys.showIdleAgents) } }
    @Published var agentStatusInClosedState: Bool { didSet { defaults.set(agentStatusInClosedState, forKey: AppSettingsKeys.agentStatusInClosedState) } }
    @Published var agentRefreshInterval: Double { didSet { defaults.set(agentRefreshInterval, forKey: AppSettingsKeys.agentRefreshInterval) } }

    @Published var localhostMonitoringEnabled: Bool { didSet { defaults.set(localhostMonitoringEnabled, forKey: AppSettingsKeys.localhostMonitoringEnabled) } }
    @Published var localhostShowHealthyServices: Bool { didSet { defaults.set(localhostShowHealthyServices, forKey: AppSettingsKeys.localhostShowHealthyServices) } }
    @Published var localhostClosedStateEnabled: Bool { didSet { defaults.set(localhostClosedStateEnabled, forKey: AppSettingsKeys.localhostClosedStateEnabled) } }
    @Published var localhostRefreshInterval: Double { didSet { defaults.set(localhostRefreshInterval, forKey: AppSettingsKeys.localhostRefreshInterval) } }
    @Published var localhostFailureDebounce: Double { didSet { defaults.set(localhostFailureDebounce, forKey: AppSettingsKeys.localhostFailureDebounce) } }

    @Published var habitsEnabled: Bool { didSet { defaults.set(habitsEnabled, forKey: AppSettingsKeys.habitsEnabled) } }
    @Published var habitsClosedStateEnabled: Bool { didSet { defaults.set(habitsClosedStateEnabled, forKey: AppSettingsKeys.habitsClosedStateEnabled) } }
    @Published var habitsReminderEnabled: Bool { didSet { defaults.set(habitsReminderEnabled, forKey: AppSettingsKeys.habitsReminderEnabled) } }
    @Published var habitsDailyResetHour: Double { didSet { defaults.set(habitsDailyResetHour, forKey: AppSettingsKeys.habitsDailyResetHour) } }

    @Published var learningsEnabled: Bool { didSet { defaults.set(learningsEnabled, forKey: AppSettingsKeys.learningsEnabled) } }
    @Published var notionSyncEnabled: Bool { didSet { defaults.set(notionSyncEnabled, forKey: AppSettingsKeys.notionSyncEnabled) } }
    @Published var autoCaptureLearnings: Bool { didSet { defaults.set(autoCaptureLearnings, forKey: AppSettingsKeys.autoCaptureLearnings) } }
    @Published var learningDigestEnabled: Bool { didSet { defaults.set(learningDigestEnabled, forKey: AppSettingsKeys.learningDigestEnabled) } }

    @Published var focusEnabled: Bool { didSet { defaults.set(focusEnabled, forKey: AppSettingsKeys.focusEnabled) } }
    @Published var focusClosedStateEnabled: Bool { didSet { defaults.set(focusClosedStateEnabled, forKey: AppSettingsKeys.focusClosedStateEnabled) } }
    @Published var focusDurationMinutes: Double { didSet { defaults.set(focusDurationMinutes, forKey: AppSettingsKeys.focusDurationMinutes) } }
    @Published var shortBreakMinutes: Double { didSet { defaults.set(shortBreakMinutes, forKey: AppSettingsKeys.shortBreakMinutes) } }
    @Published var autoStartBreaks: Bool { didSet { defaults.set(autoStartBreaks, forKey: AppSettingsKeys.autoStartBreaks) } }
    @Published var autoStartFocusSessions: Bool { didSet { defaults.set(autoStartFocusSessions, forKey: AppSettingsKeys.autoStartFocusSessions) } }

    @Published var showDebugOverlay: Bool { didSet { defaults.set(showDebugOverlay, forKey: AppSettingsKeys.showDebugOverlay) } }
    @Published var logAdapterFailures: Bool { didSet { defaults.set(logAdapterFailures, forKey: AppSettingsKeys.logAdapterFailures) } }
    @Published var keepShellOpenOnClick: Bool { didSet { defaults.set(keepShellOpenOnClick, forKey: AppSettingsKeys.keepShellOpenOnClick) } }
    @Published var gesturesEnabled: Bool { didSet { defaults.set(gesturesEnabled, forKey: AppSettingsKeys.gesturesEnabled) } }
    @Published var horizontalMediaGesturesEnabled: Bool { didSet { defaults.set(horizontalMediaGesturesEnabled, forKey: AppSettingsKeys.horizontalMediaGesturesEnabled) } }
    @Published var closeGestureEnabled: Bool { didSet { defaults.set(closeGestureEnabled, forKey: AppSettingsKeys.closeGestureEnabled) } }
    @Published var gestureSensitivity: Double { didSet { defaults.set(gestureSensitivity, forKey: AppSettingsKeys.gestureSensitivity) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        menubarIcon = defaults.object(forKey: AppSettingsKeys.menubarIcon) as? Bool ?? true
        launchAtLogin = defaults.object(forKey: AppSettingsKeys.launchAtLogin) as? Bool ?? false
        showOnAllDisplays = defaults.object(forKey: AppSettingsKeys.showOnAllDisplays) as? Bool ?? false
        preferredDisplayID = defaults.string(forKey: AppSettingsKeys.preferredDisplayID)
        automaticallySwitchDisplay = defaults.object(forKey: AppSettingsKeys.automaticallySwitchDisplay) as? Bool ?? false

        notchHeightMode = WindowHeightMode(rawValue: defaults.string(forKey: AppSettingsKeys.notchHeightMode) ?? "") ?? .matchRealNotchSize
        nonNotchHeightMode = WindowHeightMode(rawValue: defaults.string(forKey: AppSettingsKeys.nonNotchHeightMode) ?? "") ?? .matchMenuBar
        notchHeight = defaults.object(forKey: AppSettingsKeys.notchHeight) as? Double ?? 38
        nonNotchHeight = defaults.object(forKey: AppSettingsKeys.nonNotchHeight) as? Double ?? 24

        openNotchOnHover = defaults.object(forKey: AppSettingsKeys.openNotchOnHover) as? Bool ?? true
        enableHaptics = defaults.object(forKey: AppSettingsKeys.enableHaptics) as? Bool ?? true
        rememberLastTab = defaults.object(forKey: AppSettingsKeys.rememberLastTab) as? Bool ?? false
        hoverDelay = defaults.object(forKey: AppSettingsKeys.hoverDelay) as? Double ?? 0.45
        settingsIconInSymbolBar = defaults.object(forKey: AppSettingsKeys.settingsIconInSymbolBar) as? Bool ?? true
        useGlassHighlighting = defaults.object(forKey: AppSettingsKeys.useGlassHighlighting) as? Bool ?? true
        dimShellWhenInactive = defaults.object(forKey: AppSettingsKeys.dimShellWhenInactive) as? Bool ?? true
        notificationsEnabled = defaults.object(forKey: AppSettingsKeys.notificationsEnabled) as? Bool ?? true
        notificationsClosedStateEnabled = defaults.object(forKey: AppSettingsKeys.notificationsClosedStateEnabled) as? Bool ?? true
        notificationsShowBadges = defaults.object(forKey: AppSettingsKeys.notificationsShowBadges) as? Bool ?? true

        calendarEnabled = defaults.object(forKey: AppSettingsKeys.calendarEnabled) as? Bool ?? true
        calendarShowAllDayEvents = defaults.object(forKey: AppSettingsKeys.calendarShowAllDayEvents) as? Bool ?? true
        calendarIncludeTomorrow = defaults.object(forKey: AppSettingsKeys.calendarIncludeTomorrow) as? Bool ?? false
        calendarLookaheadHours = defaults.object(forKey: AppSettingsKeys.calendarLookaheadHours) as? Double ?? 8
        calendarClosedStateEnabled = defaults.object(forKey: AppSettingsKeys.calendarClosedStateEnabled) as? Bool ?? true
        hideCompletedReminders = defaults.object(forKey: AppSettingsKeys.hideCompletedReminders) as? Bool ?? true
        hideAllDayEvents = defaults.object(forKey: AppSettingsKeys.hideAllDayEvents) as? Bool ?? false
        autoScrollToNextEvent = defaults.object(forKey: AppSettingsKeys.autoScrollToNextEvent) as? Bool ?? true
        alwaysShowFullEventTitles = defaults.object(forKey: AppSettingsKeys.alwaysShowFullEventTitles) as? Bool ?? false
        selectedCalendarSourceIDs = Set(defaults.stringArray(forKey: AppSettingsKeys.selectedCalendarSourceIDs) ?? [])
        selectedReminderSourceIDs = Set(defaults.stringArray(forKey: AppSettingsKeys.selectedReminderSourceIDs) ?? [])
        mediaControlsEnabled = defaults.object(forKey: AppSettingsKeys.mediaControlsEnabled) as? Bool ?? true
        mediaClosedStateEnabled = defaults.object(forKey: AppSettingsKeys.mediaClosedStateEnabled) as? Bool ?? true
        mediaSpotifyIntegrationEnabled = defaults.object(forKey: AppSettingsKeys.mediaSpotifyIntegrationEnabled) as? Bool ?? true
        mediaAppleMusicIntegrationEnabled = defaults.object(forKey: AppSettingsKeys.mediaAppleMusicIntegrationEnabled) as? Bool ?? true

        codexMonitoringEnabled = defaults.object(forKey: AppSettingsKeys.codexMonitoringEnabled) as? Bool ?? true
        claudeMonitoringEnabled = defaults.object(forKey: AppSettingsKeys.claudeMonitoringEnabled) as? Bool ?? true
        openCodeMonitoringEnabled = defaults.object(forKey: AppSettingsKeys.openCodeMonitoringEnabled) as? Bool ?? true
        ollamaMonitoringEnabled = defaults.object(forKey: AppSettingsKeys.ollamaMonitoringEnabled) as? Bool ?? true
        showIdleAgents = defaults.object(forKey: AppSettingsKeys.showIdleAgents) as? Bool ?? false
        agentStatusInClosedState = defaults.object(forKey: AppSettingsKeys.agentStatusInClosedState) as? Bool ?? true
        agentRefreshInterval = defaults.object(forKey: AppSettingsKeys.agentRefreshInterval) as? Double ?? 10

        localhostMonitoringEnabled = defaults.object(forKey: AppSettingsKeys.localhostMonitoringEnabled) as? Bool ?? true
        localhostShowHealthyServices = defaults.object(forKey: AppSettingsKeys.localhostShowHealthyServices) as? Bool ?? false
        localhostClosedStateEnabled = defaults.object(forKey: AppSettingsKeys.localhostClosedStateEnabled) as? Bool ?? true
        localhostRefreshInterval = defaults.object(forKey: AppSettingsKeys.localhostRefreshInterval) as? Double ?? 5
        localhostFailureDebounce = defaults.object(forKey: AppSettingsKeys.localhostFailureDebounce) as? Double ?? 2

        habitsEnabled = defaults.object(forKey: AppSettingsKeys.habitsEnabled) as? Bool ?? true
        habitsClosedStateEnabled = defaults.object(forKey: AppSettingsKeys.habitsClosedStateEnabled) as? Bool ?? false
        habitsReminderEnabled = defaults.object(forKey: AppSettingsKeys.habitsReminderEnabled) as? Bool ?? true
        habitsDailyResetHour = defaults.object(forKey: AppSettingsKeys.habitsDailyResetHour) as? Double ?? 4

        learningsEnabled = defaults.object(forKey: AppSettingsKeys.learningsEnabled) as? Bool ?? true
        notionSyncEnabled = defaults.object(forKey: AppSettingsKeys.notionSyncEnabled) as? Bool ?? false
        autoCaptureLearnings = defaults.object(forKey: AppSettingsKeys.autoCaptureLearnings) as? Bool ?? true
        learningDigestEnabled = defaults.object(forKey: AppSettingsKeys.learningDigestEnabled) as? Bool ?? false

        focusEnabled = defaults.object(forKey: AppSettingsKeys.focusEnabled) as? Bool ?? true
        focusClosedStateEnabled = defaults.object(forKey: AppSettingsKeys.focusClosedStateEnabled) as? Bool ?? true
        focusDurationMinutes = defaults.object(forKey: AppSettingsKeys.focusDurationMinutes) as? Double ?? 25
        shortBreakMinutes = defaults.object(forKey: AppSettingsKeys.shortBreakMinutes) as? Double ?? 5
        autoStartBreaks = defaults.object(forKey: AppSettingsKeys.autoStartBreaks) as? Bool ?? false
        autoStartFocusSessions = defaults.object(forKey: AppSettingsKeys.autoStartFocusSessions) as? Bool ?? false

        showDebugOverlay = defaults.object(forKey: AppSettingsKeys.showDebugOverlay) as? Bool ?? false
        logAdapterFailures = defaults.object(forKey: AppSettingsKeys.logAdapterFailures) as? Bool ?? true
        keepShellOpenOnClick = defaults.object(forKey: AppSettingsKeys.keepShellOpenOnClick) as? Bool ?? false
        gesturesEnabled = defaults.object(forKey: AppSettingsKeys.gesturesEnabled) as? Bool ?? true
        horizontalMediaGesturesEnabled = defaults.object(forKey: AppSettingsKeys.horizontalMediaGesturesEnabled) as? Bool ?? false
        closeGestureEnabled = defaults.object(forKey: AppSettingsKeys.closeGestureEnabled) as? Bool ?? true
        gestureSensitivity = defaults.object(forKey: AppSettingsKeys.gestureSensitivity) as? Double ?? 0.5

        seedPreferredDisplayIfNeeded()
    }

    var shellSizingSettings: ShellSizingSettings {
        ShellSizingSettings(
            notchHeightMode: notchHeightMode,
            nonNotchHeightMode: nonNotchHeightMode,
            notchHeight: notchHeight,
            nonNotchHeight: nonNotchHeight
        )
    }

    func availableDisplays() -> [(id: String, name: String)] {
        NSScreen.screens.map { screen in
            let display = ShellDisplay(screen: screen)
            return (display.id, screen.localizedName)
        }
    }

    private func seedPreferredDisplayIfNeeded() {
        guard preferredDisplayID == nil else { return }

        let displays = NSScreen.screens.map(ShellDisplay.init(screen:))

        if let mainNotchedDisplay = NSScreen.main
            .map(ShellDisplay.init(screen:))
            .flatMap({ mainDisplay in
                displays.first(where: { $0.id == mainDisplay.id && $0.geometry.safeAreaInsets.top > 0 })
            }) {
            preferredDisplayID = mainNotchedDisplay.id
            return
        }

        if let firstNotchedDisplay = displays.first(where: { $0.geometry.safeAreaInsets.top > 0 }) {
            preferredDisplayID = firstNotchedDisplay.id
            return
        }

        preferredDisplayID = displays.first?.id
    }
}
