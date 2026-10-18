import AppKit
import AVFoundation
import Combine
import CoreGraphics
import SwiftUI

@MainActor
struct ShellHomeSummaryView: View {
    let statusSnapshot: ShellStatusSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Home")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                Spacer()
                Text("Live Overview")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }

            HStack(spacing: 8) {
                overviewCard(
                    symbol: "calendar",
                    label: "Calendar",
                    value: "\(statusSnapshot.calendarEvents.count)"
                )
                overviewCard(
                    symbol: "server.rack",
                    label: "Hosts",
                    value: "\(statusSnapshot.localhostServices.filter { $0.status == .healthy }.count)/\(statusSnapshot.localhostServices.count)"
                )
                overviewCard(
                    symbol: "checkmark.circle.fill",
                    label: "Habits",
                    value: "\(statusSnapshot.habits.filter { $0.progressValue >= 1 }.count)/\(statusSnapshot.habits.count)"
                )
                overviewCard(
                    symbol: "brain.head.profile",
                    label: "Learn",
                    value: "\(statusSnapshot.learningSignals.count)"
                )
            }

            HStack(spacing: 8) {
                summaryPill(title: "Focus", value: statusSnapshot.focusLabel)
                summaryPill(title: "Next", value: statusSnapshot.nextEventLabel)
                summaryPill(title: "Local", value: statusSnapshot.hostStatusLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func overviewCard(symbol: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func summaryPill(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.045), in: Capsule())
    }
}
