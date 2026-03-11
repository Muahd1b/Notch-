import SwiftUI

private enum ShellOpenTabSide {
    case left
    case right
}

enum ShellOpenTab: String, CaseIterable, Equatable {
    case home
    case notifications
    case calendar
    case mediaControl
    case habits
    case agents
    case openClaw
    case focusTimer
    case hud
    case localhost
    case financialBoard

    var symbolName: String {
        switch self {
        case .home:
            return "house.fill"
        case .notifications:
            return "bell.fill"
        case .calendar:
            return "calendar"
        case .mediaControl:
            return "play.fill"
        case .habits:
            return "checkmark.circle.fill"
        case .agents:
            return "bolt.badge.clock"
        case .openClaw:
            return "pawprint.fill"
        case .focusTimer:
            return "timer"
        case .hud:
            return "microphone.circle"
        case .localhost:
            return "server.rack"
        case .financialBoard:
            return "dollarsign.circle"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .home:
            return "shell-home-tab"
        case .notifications:
            return "shell-notifications-tab"
        case .calendar:
            return "shell-calendar-tab"
        case .mediaControl:
            return "shell-media-control-tab"
        case .habits:
            return "shell-habits-tab"
        case .agents:
            return "shell-agents-tab"
        case .openClaw:
            return "shell-openclaw-tab"
        case .focusTimer:
            return "shell-focus-tab"
        case .hud:
            return "shell-hud-tab"
        case .localhost:
            return "shell-localhost-tab"
        case .financialBoard:
            return "shell-financial-board-tab"
        }
    }

    fileprivate var side: ShellOpenTabSide {
        switch self {
        case .home, .notifications, .calendar, .mediaControl, .habits, .agents, .openClaw:
            return .left
        case .focusTimer, .hud, .localhost, .financialBoard:
            return .right
        }
    }
}

struct ShellHeaderView: View {
    @ObservedObject var viewModel: ShellViewModel
    let displayID: String
    @ObservedObject private var settings = AppSettingsStore.shared
    let statusSnapshot: ShellStatusSnapshot

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                tabCluster(tabs: leftTabs)

                Spacer(minLength: centerGapWidth)

                HStack(spacing: ShellSizing.headerSideGroupSpacing) {
                    tabCluster(tabs: rightTabs)
                    statusCluster
                }
            }

            if case .open = presentationState {
                Rectangle()
                    .fill(.black)
                    .frame(width: closedNotchSize.width, height: max(24, closedNotchSize.height))
                    .mask {
                        NotchShape(
                            topCornerRadius: ShellSizing.cornerRadiusInsets.closed.top,
                            bottomCornerRadius: ShellSizing.cornerRadiusInsets.closed.bottom
                        )
                    }
            }
        }
        .padding(.leading, ShellSizing.headerLeadingInset)
        .padding(.trailing, ShellSizing.headerTrailingInset)
        .padding(.top, 3)
        .foregroundStyle(.gray)
    }

    private var leftTabs: [ShellOpenTab] {
        ShellOpenTab.allCases.filter { $0.side == .left }
    }

    private var rightTabs: [ShellOpenTab] {
        ShellOpenTab.allCases.filter { $0.side == .right }
    }

    private var centerGapWidth: CGFloat {
        guard case .open = presentationState else { return 0 }
        return closedNotchSize.width + ShellSizing.headerCenterGapPadding
    }

    private func tabCluster(tabs: [ShellOpenTab]) -> some View {
        HStack(spacing: ShellSizing.headerTabSpacing) {
            ForEach(tabs, id: \.rawValue) { tab in
                tabButton(tab: tab)
            }
        }
    }

    private var statusCluster: some View {
        HStack(spacing: ShellSizing.headerStatusGroupSpacing) {
            ForEach(statusSnapshot.statusIcons) { icon in
                Image(systemName: icon.symbolName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))
                    .accessibilityIdentifier(icon.accessibilityIdentifier)
            }

            if settings.settingsIconInSymbolBar {
                settingsButton {
                    SettingsWindowController.shared.showWindow()
                }
            }

            Image(systemName: "battery.100percent")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white)
        }
    }

    private func tabButton(tab: ShellOpenTab) -> some View {
        Button {
            viewModel.selectOpenTab(tab)
        } label: {
            Image(systemName: tab.symbolName)
                .foregroundStyle(.white)
                .font(.system(size: 13, weight: .medium))
                .frame(width: ShellSizing.headerTabButtonWidth, height: ShellSizing.headerTabHeight)
                .background {
                    if viewModel.selectedOpenTab == tab {
                        Circle()
                            .fill(Color(nsColor: .secondarySystemFill))
                    } else {
                        Circle()
                            .fill(.clear)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(tab.accessibilityIdentifier)
    }

    private func settingsButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Capsule()
                .fill(.black)
                .frame(
                    width: ShellSizing.headerActionButtonSize.width,
                    height: ShellSizing.headerActionButtonSize.height
                )
                .overlay {
                    Image(systemName: "gear")
                        .foregroundStyle(.white)
                        .font(.system(size: 14, weight: .medium))
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("shell-settings-button")
    }

    private var presentationState: ShellPresentationState {
        viewModel.presentationState(for: displayID)
    }

    private var closedNotchSize: CGSize {
        viewModel.closedNotchSize(for: displayID)
    }
}
