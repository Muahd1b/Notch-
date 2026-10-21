import AppKit
import EventKit
import SwiftUI
import UniformTypeIdentifiers

struct MediaSettingsView: View {
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
