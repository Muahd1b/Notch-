import Foundation

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

enum AppSettingsKeys {
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
    static let lastOpenTab = "notch.lastOpenTab"
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
    static let openCodeMonitoringEnabled = "notch.openCodeMonitoringEnabled"
    static let ollamaMonitoringEnabled = "notch.ollamaMonitoringEnabled"
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
