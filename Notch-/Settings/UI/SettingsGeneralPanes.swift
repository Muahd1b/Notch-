import AppKit
import EventKit
import SwiftUI
import UniformTypeIdentifiers

struct GeneralSettingsView: View {
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

struct AppearanceSettingsView: View {
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
                Text("This first pass ports the Boring Notch shell language and adapts its controls to Controll Notch.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .navigationTitle("Appearance")
    }
}

struct NotificationSettingsView: View {
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
