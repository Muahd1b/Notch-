import AppKit
import EventKit
import SwiftUI
import UniformTypeIdentifiers

struct AgentSettingsView: View {
    @ObservedObject var settings: AppSettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Codex monitoring", isOn: $settings.codexMonitoringEnabled)
                Text("Reads ~/.codex/sessions for active rollouts, model and token usage.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Claude Code monitoring", isOn: $settings.claudeMonitoringEnabled)
                Text("Reads ~/.claude/projects transcripts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("OpenCode monitoring", isOn: $settings.openCodeMonitoringEnabled)
                Text("Reads the local OpenCode session database.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Ollama monitoring", isOn: $settings.ollamaMonitoringEnabled)
                Text("Queries the local Ollama runtime on port 11434.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Best-effort workspace scan; lower confidence than the structured providers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
