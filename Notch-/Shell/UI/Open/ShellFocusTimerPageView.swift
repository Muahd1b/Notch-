import AppKit
import AVFoundation
import Combine
import CoreGraphics
import SwiftUI

@MainActor
struct ShellFocusTimerPageView: View {
    @ObservedObject var viewModel: ShellViewModel
    @ObservedObject private var settings = AppSettingsStore.shared

    var body: some View {
        GeometryReader { proxy in
            let layout = layoutMetrics(for: proxy.size.height)

            HStack(alignment: .top, spacing: layout.columnSpacing) {
                rightTimerColumn(compact: layout.isCompact)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                leftControlsColumn(compact: layout.isCompact)
                    .frame(width: layout.controlsWidth, alignment: .topTrailing)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func leftControlsColumn(compact: Bool) -> some View {
        let focusRecords = viewModel.focusSessionRecords.filter { $0.phase == .focus }
        let totalFocusMinutes = focusRecords.reduce(0) { $0 + max(0, $1.durationSeconds / 60) }

        return VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            HStack(spacing: compact ? 6 : 8) {
                metricCard(title: "Sessions", value: "\(focusRecords.count)", compact: compact)
                metricCard(title: "Minutes", value: "\(totalFocusMinutes)", compact: compact)
            }

            Spacer(minLength: compact ? 4 : 6)

            HStack(spacing: compact ? 6 : 8) {
                compactActionButton(
                    title: "Focus \(Int(settings.focusDurationMinutes))m",
                    symbol: "play.fill",
                    compact: compact,
                    action: viewModel.startFocusSession
                )
                compactActionButton(
                    title: viewModel.focusIsPaused ? "Resume" : "Pause",
                    symbol: viewModel.focusIsPaused ? "play.fill" : "pause.fill",
                    compact: compact,
                    isEnabled: viewModel.focusTimerIsRunning,
                    action: viewModel.toggleFocusPauseResume
                )
            }

            HStack(spacing: compact ? 6 : 8) {
                compactActionButton(
                    title: "Break \(Int(settings.shortBreakMinutes))m",
                    symbol: "cup.and.saucer.fill",
                    compact: compact,
                    action: viewModel.startBreakSession
                )
                compactActionButton(
                    title: "Stop",
                    symbol: "stop.fill",
                    compact: compact,
                    isEnabled: viewModel.focusTimerIsRunning,
                    action: viewModel.stopFocusSession
                )
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func rightTimerColumn(compact: Bool) -> some View {
        GeometryReader { timerProxy in
            let fontSize = timerFontSize(in: timerProxy.size)

            VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                Spacer(minLength: 0)

                Text(viewModel.focusRemainingLabel)
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: compact ? 6 : 8) {
                    Text(viewModel.focusTimerPhase.title.uppercased())
                        .font(.system(size: compact ? 13 : 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))

                    if viewModel.focusIsPaused {
                        Text("Paused")
                            .font(.system(size: compact ? 11 : 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.52))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, compact ? 12 : 14)
            .padding(.vertical, compact ? 8 : 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func compactActionButton(
        title: String,
        symbol: String,
        compact: Bool,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: compact ? 5 : 6) {
                Image(systemName: symbol)
                    .font(.system(size: compact ? 10 : 11, weight: .semibold))
                Text(title)
                    .font(.system(size: compact ? 10 : 10.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white.opacity(isEnabled ? 0.92 : 0.5))
            .padding(.horizontal, compact ? 8 : 9)
            .padding(.vertical, compact ? 6 : 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.62)
    }

    private func metricCard(title: String, value: String, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 3) {
            Text(title)
                .font(.system(size: compact ? 9 : 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
            Text(value)
                .font(.system(size: compact ? 12 : 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 8 : 9)
        .padding(.vertical, compact ? 6 : 7)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func layoutMetrics(for height: CGFloat) -> FocusLayoutMetrics {
        let boundedHeight = max(height, 96)
        let isCompact = boundedHeight < 132
        let controlsWidth: CGFloat = isCompact ? 286 : 304
        let columnSpacing: CGFloat = isCompact ? 8 : 10

        return FocusLayoutMetrics(
            isCompact: isCompact,
            controlsWidth: controlsWidth,
            columnSpacing: columnSpacing
        )
    }

    private func timerFontSize(in size: CGSize) -> CGFloat {
        let widthDriven = size.width * 0.36
        let heightDriven = size.height * 0.62
        return max(52, min(widthDriven, heightDriven))
    }

    private struct FocusLayoutMetrics {
        let isCompact: Bool
        let controlsWidth: CGFloat
        let columnSpacing: CGFloat
    }
}
