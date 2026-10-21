import AppKit
import EventKit
import SwiftUI
import UniformTypeIdentifiers

struct LearningsSettingsView: View {
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

struct FocusSettingsView: View {
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

struct AdvancedSettingsView: View {
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
