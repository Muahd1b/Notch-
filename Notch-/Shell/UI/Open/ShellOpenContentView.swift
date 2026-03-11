import SwiftUI

@MainActor
struct ShellOpenContentView: View {
    @ObservedObject var viewModel: ShellViewModel
    let displayID: String
    let statusSnapshot: ShellStatusSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ShellHeaderView(viewModel: viewModel, displayID: displayID, statusSnapshot: statusSnapshot)
                .frame(height: max(24, viewModel.closedNotchSize(for: displayID).height))

            if viewModel.selectedOpenTab == .focusTimer ||
                viewModel.selectedOpenTab == .calendar ||
                viewModel.selectedOpenTab == .hud
            {
                openViewportContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, ShellSizing.openContentSpacing)
                    .clipped()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    openViewportContent
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.top, ShellSizing.openContentSpacing)
                }
                .scrollDisabled(false)
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
            }
        }
    }

    @ViewBuilder
    private var openViewportContent: some View {
        switch viewModel.selectedOpenTab {
        case .home:
            ShellHomeSummaryView(statusSnapshot: statusSnapshot)
                .accessibilityIdentifier("shell-home-page")
        case .calendar:
            ShellCalendarPageView(viewModel: viewModel, statusSnapshot: statusSnapshot)
                .accessibilityIdentifier("shell-calendar-page")
        case .localhost:
            ShellLocalhostPageView(viewModel: viewModel, statusSnapshot: statusSnapshot)
                .accessibilityIdentifier("shell-localhost-page")
        case .habits:
            ShellHabitsLearningsPageView(viewModel: viewModel, statusSnapshot: statusSnapshot)
                .accessibilityIdentifier("shell-habits-page")
        case .notifications:
            ShellFeaturePlaceholderPageView(
                title: "Notifications",
                subtitle: "WhatsApp, Discord, Instagram, Telegram",
                metric: "4 sources"
            )
            .accessibilityIdentifier("shell-notifications-page")
        case .mediaControl:
            ShellMediaControlPageView(viewModel: viewModel)
            .accessibilityIdentifier("shell-media-control-page")
        case .agents:
            ShellFeaturePlaceholderPageView(
                title: "Agents Status",
                subtitle: "Codex, Claude, Ollama, OpenCode status board",
                metric: "ongoing / idle"
            )
            .accessibilityIdentifier("shell-agents-page")
        case .openClaw:
            ShellFeaturePlaceholderPageView(
                title: "OpenClaw",
                subtitle: "Chat panel plus runtime metrics",
                metric: "MCP aware"
            )
            .accessibilityIdentifier("shell-openclaw-page")
        case .focusTimer:
            ShellFocusTimerPageView(viewModel: viewModel)
                .accessibilityIdentifier("shell-focus-page")
        case .hud:
            ShellHUDPageView(viewModel: viewModel)
            .accessibilityIdentifier("shell-hud-page")
        case .financialBoard:
            ShellFeaturePlaceholderPageView(
                title: "Financial Board",
                subtitle: "Profit, MRR, revenue and trend charts",
                metric: "multi-business"
            )
            .accessibilityIdentifier("shell-financial-board-page")
        }
    }
}
