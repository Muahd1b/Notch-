import EventKit
import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case notifications = "Notifications"
    case calendar = "Calendar"
    case media = "Media"
    case agents = "Agents"
    case localhost = "Localhost"
    case habits = "Habits"
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
    let runtimeServices: CoreRuntimeServices?
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
                    HabitsSettingsView(settings: settings, runtimeServices: runtimeServices)
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
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: Self.minimumWidth, idealWidth: Self.defaultWidth, maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings-root")
    }
}
