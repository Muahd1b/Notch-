import AppKit
import Combine
import Foundation

enum WindowHeightMode: String, CaseIterable, Identifiable, Codable {
    case matchRealNotchSize
    case matchMenuBar
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .matchRealNotchSize:
            return "Match real notch height"
        case .matchMenuBar:
            return "Match menubar height"
        case .custom:
            return "Custom height"
        }
    }
}

@MainActor
final class AppSettingsStore: ObservableObject {
    static let shared = AppSettingsStore()

    @Published var menubarIcon: Bool { didSet { defaults.set(menubarIcon, forKey: Keys.menubarIcon) } }
    @Published var launchAtLogin: Bool { didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) } }
    @Published var showOnAllDisplays: Bool { didSet { defaults.set(showOnAllDisplays, forKey: Keys.showOnAllDisplays) } }
    @Published var preferredDisplayID: String? {
        didSet {
            if let preferredDisplayID {
                defaults.set(preferredDisplayID, forKey: Keys.preferredDisplayID)
            } else {
                defaults.removeObject(forKey: Keys.preferredDisplayID)
            }
        }
    }
    @Published var automaticallySwitchDisplay: Bool { didSet { defaults.set(automaticallySwitchDisplay, forKey: Keys.automaticallySwitchDisplay) } }

    @Published var notchHeightMode: WindowHeightMode { didSet { defaults.set(notchHeightMode.rawValue, forKey: Keys.notchHeightMode) } }
    @Published var nonNotchHeightMode: WindowHeightMode { didSet { defaults.set(nonNotchHeightMode.rawValue, forKey: Keys.nonNotchHeightMode) } }
    @Published var notchHeight: Double { didSet { defaults.set(notchHeight, forKey: Keys.notchHeight) } }
    @Published var nonNotchHeight: Double { didSet { defaults.set(nonNotchHeight, forKey: Keys.nonNotchHeight) } }

    @Published var openNotchOnHover: Bool { didSet { defaults.set(openNotchOnHover, forKey: Keys.openNotchOnHover) } }
    @Published var enableHaptics: Bool { didSet { defaults.set(enableHaptics, forKey: Keys.enableHaptics) } }
    @Published var rememberLastTab: Bool { didSet { defaults.set(rememberLastTab, forKey: Keys.rememberLastTab) } }
    @Published var hoverDelay: Double { didSet { defaults.set(hoverDelay, forKey: Keys.hoverDelay) } }
    @Published var settingsIconInSymbolBar: Bool { didSet { defaults.set(settingsIconInSymbolBar, forKey: Keys.settingsIconInSymbolBar) } }
    @Published var useGlassHighlighting: Bool { didSet { defaults.set(useGlassHighlighting, forKey: Keys.useGlassHighlighting) } }
    @Published var dimShellWhenInactive: Bool { didSet { defaults.set(dimShellWhenInactive, forKey: Keys.dimShellWhenInactive) } }
    @Published var notificationsEnabled: Bool { didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) } }
    @Published var notificationsClosedStateEnabled: Bool { didSet { defaults.set(notificationsClosedStateEnabled, forKey: Keys.notificationsClosedStateEnabled) } }
    @Published var notificationsShowBadges: Bool { didSet { defaults.set(notificationsShowBadges, forKey: Keys.notificationsShowBadges) } }

    @Published var calendarEnabled: Bool { didSet { defaults.set(calendarEnabled, forKey: Keys.calendarEnabled) } }
    @Published var calendarShowAllDayEvents: Bool { didSet { defaults.set(calendarShowAllDayEvents, forKey: Keys.calendarShowAllDayEvents) } }
    @Published var calendarIncludeTomorrow: Bool { didSet { defaults.set(calendarIncludeTomorrow, forKey: Keys.calendarIncludeTomorrow) } }
    @Published var calendarLookaheadHours: Double { didSet { defaults.set(calendarLookaheadHours, forKey: Keys.calendarLookaheadHours) } }
    @Published var calendarClosedStateEnabled: Bool { didSet { defaults.set(calendarClosedStateEnabled, forKey: Keys.calendarClosedStateEnabled) } }
    @Published var hideCompletedReminders: Bool { didSet { defaults.set(hideCompletedReminders, forKey: Keys.hideCompletedReminders) } }
    @Published var hideAllDayEvents: Bool { didSet { defaults.set(hideAllDayEvents, forKey: Keys.hideAllDayEvents) } }
    @Published var autoScrollToNextEvent: Bool { didSet { defaults.set(autoScrollToNextEvent, forKey: Keys.autoScrollToNextEvent) } }
    @Published var alwaysShowFullEventTitles: Bool { didSet { defaults.set(alwaysShowFullEventTitles, forKey: Keys.alwaysShowFullEventTitles) } }
    @Published var selectedCalendarSourceIDs: Set<String> {
        didSet { defaults.set(Array(selectedCalendarSourceIDs).sorted(), forKey: Keys.selectedCalendarSourceIDs) }
    }
    @Published var selectedReminderSourceIDs: Set<String> {
        didSet { defaults.set(Array(selectedReminderSourceIDs).sorted(), forKey: Keys.selectedReminderSourceIDs) }
    }
    @Published var mediaControlsEnabled: Bool { didSet { defaults.set(mediaControlsEnabled, forKey: Keys.mediaControlsEnabled) } }
    @Published var mediaClosedStateEnabled: Bool { didSet { defaults.set(mediaClosedStateEnabled, forKey: Keys.mediaClosedStateEnabled) } }
    @Published var mediaSpotifyIntegrationEnabled: Bool { didSet { defaults.set(mediaSpotifyIntegrationEnabled, forKey: Keys.mediaSpotifyIntegrationEnabled) } }
    @Published var mediaAppleMusicIntegrationEnabled: Bool { didSet { defaults.set(mediaAppleMusicIntegrationEnabled, forKey: Keys.mediaAppleMusicIntegrationEnabled) } }

    @Published var codexMonitoringEnabled: Bool { didSet { defaults.set(codexMonitoringEnabled, forKey: Keys.codexMonitoringEnabled) } }
    @Published var claudeMonitoringEnabled: Bool { didSet { defaults.set(claudeMonitoringEnabled, forKey: Keys.claudeMonitoringEnabled) } }
    @Published var openClawMonitoringEnabled: Bool { didSet { defaults.set(openClawMonitoringEnabled, forKey: Keys.openClawMonitoringEnabled) } }
    @Published var showIdleAgents: Bool { didSet { defaults.set(showIdleAgents, forKey: Keys.showIdleAgents) } }
    @Published var agentStatusInClosedState: Bool { didSet { defaults.set(agentStatusInClosedState, forKey: Keys.agentStatusInClosedState) } }
    @Published var agentRefreshInterval: Double { didSet { defaults.set(agentRefreshInterval, forKey: Keys.agentRefreshInterval) } }

    @Published var localhostMonitoringEnabled: Bool { didSet { defaults.set(localhostMonitoringEnabled, forKey: Keys.localhostMonitoringEnabled) } }
    @Published var localhostShowHealthyServices: Bool { didSet { defaults.set(localhostShowHealthyServices, forKey: Keys.localhostShowHealthyServices) } }
    @Published var localhostClosedStateEnabled: Bool { didSet { defaults.set(localhostClosedStateEnabled, forKey: Keys.localhostClosedStateEnabled) } }
    @Published var localhostRefreshInterval: Double { didSet { defaults.set(localhostRefreshInterval, forKey: Keys.localhostRefreshInterval) } }
    @Published var localhostFailureDebounce: Double { didSet { defaults.set(localhostFailureDebounce, forKey: Keys.localhostFailureDebounce) } }

    @Published var habitsEnabled: Bool { didSet { defaults.set(habitsEnabled, forKey: Keys.habitsEnabled) } }
    @Published var habitsClosedStateEnabled: Bool { didSet { defaults.set(habitsClosedStateEnabled, forKey: Keys.habitsClosedStateEnabled) } }
    @Published var habitsReminderEnabled: Bool { didSet { defaults.set(habitsReminderEnabled, forKey: Keys.habitsReminderEnabled) } }
    @Published var habitsDailyResetHour: Double { didSet { defaults.set(habitsDailyResetHour, forKey: Keys.habitsDailyResetHour) } }

    @Published var learningsEnabled: Bool { didSet { defaults.set(learningsEnabled, forKey: Keys.learningsEnabled) } }
    @Published var notionSyncEnabled: Bool { didSet { defaults.set(notionSyncEnabled, forKey: Keys.notionSyncEnabled) } }
    @Published var autoCaptureLearnings: Bool { didSet { defaults.set(autoCaptureLearnings, forKey: Keys.autoCaptureLearnings) } }
    @Published var learningDigestEnabled: Bool { didSet { defaults.set(learningDigestEnabled, forKey: Keys.learningDigestEnabled) } }

    @Published var focusEnabled: Bool { didSet { defaults.set(focusEnabled, forKey: Keys.focusEnabled) } }
    @Published var focusClosedStateEnabled: Bool { didSet { defaults.set(focusClosedStateEnabled, forKey: Keys.focusClosedStateEnabled) } }
    @Published var focusDurationMinutes: Double { didSet { defaults.set(focusDurationMinutes, forKey: Keys.focusDurationMinutes) } }
    @Published var shortBreakMinutes: Double { didSet { defaults.set(shortBreakMinutes, forKey: Keys.shortBreakMinutes) } }
    @Published var autoStartBreaks: Bool { didSet { defaults.set(autoStartBreaks, forKey: Keys.autoStartBreaks) } }
    @Published var autoStartFocusSessions: Bool { didSet { defaults.set(autoStartFocusSessions, forKey: Keys.autoStartFocusSessions) } }

    @Published var showDebugOverlay: Bool { didSet { defaults.set(showDebugOverlay, forKey: Keys.showDebugOverlay) } }
    @Published var logAdapterFailures: Bool { didSet { defaults.set(logAdapterFailures, forKey: Keys.logAdapterFailures) } }
    @Published var keepShellOpenOnClick: Bool { didSet { defaults.set(keepShellOpenOnClick, forKey: Keys.keepShellOpenOnClick) } }
    @Published var gesturesEnabled: Bool { didSet { defaults.set(gesturesEnabled, forKey: Keys.gesturesEnabled) } }
    @Published var horizontalMediaGesturesEnabled: Bool { didSet { defaults.set(horizontalMediaGesturesEnabled, forKey: Keys.horizontalMediaGesturesEnabled) } }
    @Published var closeGestureEnabled: Bool { didSet { defaults.set(closeGestureEnabled, forKey: Keys.closeGestureEnabled) } }
    @Published var gestureSensitivity: Double { didSet { defaults.set(gestureSensitivity, forKey: Keys.gestureSensitivity) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        menubarIcon = defaults.object(forKey: Keys.menubarIcon) as? Bool ?? true
        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        showOnAllDisplays = defaults.object(forKey: Keys.showOnAllDisplays) as? Bool ?? false
        preferredDisplayID = defaults.string(forKey: Keys.preferredDisplayID)
        automaticallySwitchDisplay = defaults.object(forKey: Keys.automaticallySwitchDisplay) as? Bool ?? false

        notchHeightMode = WindowHeightMode(rawValue: defaults.string(forKey: Keys.notchHeightMode) ?? "") ?? .matchRealNotchSize
        nonNotchHeightMode = WindowHeightMode(rawValue: defaults.string(forKey: Keys.nonNotchHeightMode) ?? "") ?? .matchMenuBar
        notchHeight = defaults.object(forKey: Keys.notchHeight) as? Double ?? 38
        nonNotchHeight = defaults.object(forKey: Keys.nonNotchHeight) as? Double ?? 24

        openNotchOnHover = defaults.object(forKey: Keys.openNotchOnHover) as? Bool ?? true
        enableHaptics = defaults.object(forKey: Keys.enableHaptics) as? Bool ?? true
        rememberLastTab = defaults.object(forKey: Keys.rememberLastTab) as? Bool ?? false
        hoverDelay = defaults.object(forKey: Keys.hoverDelay) as? Double ?? 0.45
        settingsIconInSymbolBar = defaults.object(forKey: Keys.settingsIconInSymbolBar) as? Bool ?? true
        useGlassHighlighting = defaults.object(forKey: Keys.useGlassHighlighting) as? Bool ?? true
        dimShellWhenInactive = defaults.object(forKey: Keys.dimShellWhenInactive) as? Bool ?? true
        notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        notificationsClosedStateEnabled = defaults.object(forKey: Keys.notificationsClosedStateEnabled) as? Bool ?? true
        notificationsShowBadges = defaults.object(forKey: Keys.notificationsShowBadges) as? Bool ?? true

        calendarEnabled = defaults.object(forKey: Keys.calendarEnabled) as? Bool ?? true
        calendarShowAllDayEvents = defaults.object(forKey: Keys.calendarShowAllDayEvents) as? Bool ?? true
        calendarIncludeTomorrow = defaults.object(forKey: Keys.calendarIncludeTomorrow) as? Bool ?? false
        calendarLookaheadHours = defaults.object(forKey: Keys.calendarLookaheadHours) as? Double ?? 8
        calendarClosedStateEnabled = defaults.object(forKey: Keys.calendarClosedStateEnabled) as? Bool ?? true
        hideCompletedReminders = defaults.object(forKey: Keys.hideCompletedReminders) as? Bool ?? true
        hideAllDayEvents = defaults.object(forKey: Keys.hideAllDayEvents) as? Bool ?? false
        autoScrollToNextEvent = defaults.object(forKey: Keys.autoScrollToNextEvent) as? Bool ?? true
        alwaysShowFullEventTitles = defaults.object(forKey: Keys.alwaysShowFullEventTitles) as? Bool ?? false
        selectedCalendarSourceIDs = Set(defaults.stringArray(forKey: Keys.selectedCalendarSourceIDs) ?? [])
        selectedReminderSourceIDs = Set(defaults.stringArray(forKey: Keys.selectedReminderSourceIDs) ?? [])
        mediaControlsEnabled = defaults.object(forKey: Keys.mediaControlsEnabled) as? Bool ?? true
        mediaClosedStateEnabled = defaults.object(forKey: Keys.mediaClosedStateEnabled) as? Bool ?? true
        mediaSpotifyIntegrationEnabled = defaults.object(forKey: Keys.mediaSpotifyIntegrationEnabled) as? Bool ?? true
        mediaAppleMusicIntegrationEnabled = defaults.object(forKey: Keys.mediaAppleMusicIntegrationEnabled) as? Bool ?? true

        codexMonitoringEnabled = defaults.object(forKey: Keys.codexMonitoringEnabled) as? Bool ?? true
        claudeMonitoringEnabled = defaults.object(forKey: Keys.claudeMonitoringEnabled) as? Bool ?? true
        openClawMonitoringEnabled = defaults.object(forKey: Keys.openClawMonitoringEnabled) as? Bool ?? false
        showIdleAgents = defaults.object(forKey: Keys.showIdleAgents) as? Bool ?? false
        agentStatusInClosedState = defaults.object(forKey: Keys.agentStatusInClosedState) as? Bool ?? true
        agentRefreshInterval = defaults.object(forKey: Keys.agentRefreshInterval) as? Double ?? 10

        localhostMonitoringEnabled = defaults.object(forKey: Keys.localhostMonitoringEnabled) as? Bool ?? true
        localhostShowHealthyServices = defaults.object(forKey: Keys.localhostShowHealthyServices) as? Bool ?? false
        localhostClosedStateEnabled = defaults.object(forKey: Keys.localhostClosedStateEnabled) as? Bool ?? true
        localhostRefreshInterval = defaults.object(forKey: Keys.localhostRefreshInterval) as? Double ?? 5
        localhostFailureDebounce = defaults.object(forKey: Keys.localhostFailureDebounce) as? Double ?? 2

        habitsEnabled = defaults.object(forKey: Keys.habitsEnabled) as? Bool ?? true
        habitsClosedStateEnabled = defaults.object(forKey: Keys.habitsClosedStateEnabled) as? Bool ?? false
        habitsReminderEnabled = defaults.object(forKey: Keys.habitsReminderEnabled) as? Bool ?? true
        habitsDailyResetHour = defaults.object(forKey: Keys.habitsDailyResetHour) as? Double ?? 4

        learningsEnabled = defaults.object(forKey: Keys.learningsEnabled) as? Bool ?? true
        notionSyncEnabled = defaults.object(forKey: Keys.notionSyncEnabled) as? Bool ?? false
        autoCaptureLearnings = defaults.object(forKey: Keys.autoCaptureLearnings) as? Bool ?? true
        learningDigestEnabled = defaults.object(forKey: Keys.learningDigestEnabled) as? Bool ?? false

        focusEnabled = defaults.object(forKey: Keys.focusEnabled) as? Bool ?? true
        focusClosedStateEnabled = defaults.object(forKey: Keys.focusClosedStateEnabled) as? Bool ?? true
        focusDurationMinutes = defaults.object(forKey: Keys.focusDurationMinutes) as? Double ?? 25
        shortBreakMinutes = defaults.object(forKey: Keys.shortBreakMinutes) as? Double ?? 5
        autoStartBreaks = defaults.object(forKey: Keys.autoStartBreaks) as? Bool ?? false
        autoStartFocusSessions = defaults.object(forKey: Keys.autoStartFocusSessions) as? Bool ?? false

        showDebugOverlay = defaults.object(forKey: Keys.showDebugOverlay) as? Bool ?? false
        logAdapterFailures = defaults.object(forKey: Keys.logAdapterFailures) as? Bool ?? true
        keepShellOpenOnClick = defaults.object(forKey: Keys.keepShellOpenOnClick) as? Bool ?? false
        gesturesEnabled = defaults.object(forKey: Keys.gesturesEnabled) as? Bool ?? true
        horizontalMediaGesturesEnabled = defaults.object(forKey: Keys.horizontalMediaGesturesEnabled) as? Bool ?? false
        closeGestureEnabled = defaults.object(forKey: Keys.closeGestureEnabled) as? Bool ?? true
        gestureSensitivity = defaults.object(forKey: Keys.gestureSensitivity) as? Double ?? 0.5

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

private enum Keys {
    static let menubarIcon = "notch.menubarIcon"
    static let launchAtLogin = "notch.launchAtLogin"
    static let showOnAllDisplays = "notch.showOnAllDisplays"
    static let preferredDisplayID = "notch.preferredDisplayID"
    static let automaticallySwitchDisplay = "notch.automaticallySwitchDisplay"

    static let notchHeightMode = "notch.notchHeightMode"
    static let nonNotchHeightMode = "notch.nonNotchHeightMode"
    static let notchHeight = "notch.notchHeight"
    static let nonNotchHeight = "notch.nonNotchHeight"

    static let openNotchOnHover = "notch.openNotchOnHover"
    static let enableHaptics = "notch.enableHaptics"
    static let rememberLastTab = "notch.rememberLastTab"
    static let hoverDelay = "notch.hoverDelay"
    static let settingsIconInSymbolBar = "notch.settingsIconInSymbolBar"
    static let useGlassHighlighting = "notch.useGlassHighlighting"
    static let dimShellWhenInactive = "notch.dimShellWhenInactive"
    static let notificationsEnabled = "notch.notificationsEnabled"
    static let notificationsClosedStateEnabled = "notch.notificationsClosedStateEnabled"
    static let notificationsShowBadges = "notch.notificationsShowBadges"

    static let calendarEnabled = "notch.calendarEnabled"
    static let calendarShowAllDayEvents = "notch.calendarShowAllDayEvents"
    static let calendarIncludeTomorrow = "notch.calendarIncludeTomorrow"
    static let calendarLookaheadHours = "notch.calendarLookaheadHours"
    static let calendarClosedStateEnabled = "notch.calendarClosedStateEnabled"
    static let hideCompletedReminders = "notch.hideCompletedReminders"
    static let hideAllDayEvents = "notch.hideAllDayEvents"
    static let autoScrollToNextEvent = "notch.autoScrollToNextEvent"
    static let alwaysShowFullEventTitles = "notch.alwaysShowFullEventTitles"
    static let selectedCalendarSourceIDs = "notch.selectedCalendarSourceIDs"
    static let selectedReminderSourceIDs = "notch.selectedReminderSourceIDs"
    static let mediaControlsEnabled = "notch.mediaControlsEnabled"
    static let mediaClosedStateEnabled = "notch.mediaClosedStateEnabled"
    static let mediaSpotifyIntegrationEnabled = "notch.mediaSpotifyIntegrationEnabled"
    static let mediaAppleMusicIntegrationEnabled = "notch.mediaAppleMusicIntegrationEnabled"

    static let codexMonitoringEnabled = "notch.codexMonitoringEnabled"
    static let claudeMonitoringEnabled = "notch.claudeMonitoringEnabled"
    static let openClawMonitoringEnabled = "notch.openClawMonitoringEnabled"
    static let showIdleAgents = "notch.showIdleAgents"
    static let agentStatusInClosedState = "notch.agentStatusInClosedState"
    static let agentRefreshInterval = "notch.agentRefreshInterval"

    static let localhostMonitoringEnabled = "notch.localhostMonitoringEnabled"
    static let localhostShowHealthyServices = "notch.localhostShowHealthyServices"
    static let localhostClosedStateEnabled = "notch.localhostClosedStateEnabled"
    static let localhostRefreshInterval = "notch.localhostRefreshInterval"
    static let localhostFailureDebounce = "notch.localhostFailureDebounce"

    static let habitsEnabled = "notch.habitsEnabled"
    static let habitsClosedStateEnabled = "notch.habitsClosedStateEnabled"
    static let habitsReminderEnabled = "notch.habitsReminderEnabled"
    static let habitsDailyResetHour = "notch.habitsDailyResetHour"

    static let learningsEnabled = "notch.learningsEnabled"
    static let notionSyncEnabled = "notch.notionSyncEnabled"
    static let autoCaptureLearnings = "notch.autoCaptureLearnings"
    static let learningDigestEnabled = "notch.learningDigestEnabled"

    static let focusEnabled = "notch.focusEnabled"
    static let focusClosedStateEnabled = "notch.focusClosedStateEnabled"
    static let focusDurationMinutes = "notch.focusDurationMinutes"
    static let shortBreakMinutes = "notch.shortBreakMinutes"
    static let autoStartBreaks = "notch.autoStartBreaks"
    static let autoStartFocusSessions = "notch.autoStartFocusSessions"

    static let showDebugOverlay = "notch.showDebugOverlay"
    static let logAdapterFailures = "notch.logAdapterFailures"
    static let keepShellOpenOnClick = "notch.keepShellOpenOnClick"
    static let gesturesEnabled = "notch.gesturesEnabled"
    static let horizontalMediaGesturesEnabled = "notch.horizontalMediaGesturesEnabled"
    static let closeGestureEnabled = "notch.closeGestureEnabled"
    static let gestureSensitivity = "notch.gestureSensitivity"
}
