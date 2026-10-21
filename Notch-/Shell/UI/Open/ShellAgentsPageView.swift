import AppKit
import SwiftUI

@MainActor
struct ShellAgentsPageView: View {
    @ObservedObject var viewModel: ShellViewModel
    let statusSnapshot: ShellStatusSnapshot

    @State private var selectedSessionID: String?
    @State private var copiedPath = false

    private var sessions: [ShellAgentSession] {
        statusSnapshot.agentSessions
    }

    private var needsReviewCount: Int {
        sessions.filter { $0.status == .needsReview }.count
    }

    private var summaryLabel: String {
        if needsReviewCount > 0 { return "\(needsReviewCount) need review" }
        let working = sessions.filter { $0.status == .ongoing }.count
        return working > 0 ? "\(working) working" : "idle"
    }

    private var selectedSession: ShellAgentSession? {
        sessions.first { $0.id == selectedSessionID } ?? sessions.first
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            sessionsColumn
                .frame(width: 288, alignment: .topLeading)

            detailColumn
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { syncSelection() }
        .onChange(of: sessions.map(\.id)) { _, _ in syncSelection() }
    }

    private func syncSelection() {
        guard let current = selectedSessionID, sessions.contains(where: { $0.id == current }) else {
            selectedSessionID = sessions.first?.id
            return
        }
    }

    // MARK: - List

    private var sessionsColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Agents")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Text(summaryLabel)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 2)

            if sessions.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(sessions) { session in
                            sessionRow(session)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("No agent activity", systemImage: "moon.zzz")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text("Sessions appear here when Codex, Claude Code, OpenCode or Ollama are running. Enable or disable providers in Settings › Agents.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sessionRow(_ session: ShellAgentSession) -> some View {
        let isSelected = session.id == selectedSession?.id

        return Button {
            selectedSessionID = session.id
            viewModel.playSelectionHaptic()
        } label: {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: session.provider.symbolName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(providerTint(session.provider))
                    .frame(width: 22, height: 22)
                    .background(providerTint(session.provider).opacity(0.16), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(session.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        StatusDot(status: session.status)
                    }

                    Text(session.summary ?? session.workspaceLabel)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(session.provider.title)
                        if let model = session.model {
                            Text("·")
                            Text(model).lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        Text(session.lastActivityLabel)
                    }
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.42))
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.12 : 0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(isSelected ? 0.14 : 0), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail

    private var detailColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            metricsRow

            if let selectedSession {
                detailCard(selectedSession)
            } else {
                Text("Select a session to see workspace, model and token usage.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Overview")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer(minLength: 8)
            if let latest = sessions.first {
                Text("Updated \(latest.lastActivityLabel)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 2)
    }

    private var metricsRow: some View {
        HStack(spacing: 8) {
            MetricTile(
                title: "Needs review",
                value: "\(sessions.filter { $0.status == .needsReview }.count)",
                tint: .orange
            )
            MetricTile(
                title: "Working",
                value: "\(sessions.filter { $0.status == .ongoing }.count)",
                tint: .green
            )
            MetricTile(
                title: "Providers",
                value: "\(Set(sessions.map(\.provider)).count)",
                tint: .blue
            )
        }
    }

    private func detailCard(_ session: ShellAgentSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(session.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 8)
                StatusPill(status: session.status)
            }

            if let branch = session.branch, !branch.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.caption2)
                    Text(branch)
                        .font(.caption2.monospaced())
                }
                .foregroundStyle(.white.opacity(0.55))
            }

            if let summary = session.summary {
                Text(summary)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            pathRow(session)
            usageSection(session)

            HStack(spacing: 6) {
                Image(systemName: "gauge.with.dots.needle.33percent")
                Text("\(session.confidence.rawValue) confidence")
                Spacer(minLength: 4)
                Text(session.provider.title)
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.45))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func pathRow(_ session: ShellAgentSession) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
            Text(session.workspaceLabel)
                .font(.caption.monospaced())
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
                .truncationMode(.head)
            Spacer(minLength: 4)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(session.workspacePath, forType: .string)
                copiedPath = true
                viewModel.playSelectionHaptic()
                Task {
                    try? await Task.sleep(for: .seconds(1.6))
                    copiedPath = false
                }
            } label: {
                Image(systemName: copiedPath ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(copiedPath ? 0.9 : 0.5))
            }
            .buttonStyle(.plain)
            .help("Copy workspace path")
        }
    }

    private func usageSection(_ session: ShellAgentSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Token usage")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                Spacer(minLength: 4)
                Text(session.usageLabel ?? "not reported")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(session.usageLabel == nil ? 0.4 : 0.72))
            }

            if let fraction = session.usageFraction {
                UsageBar(fraction: fraction, tint: fraction > 0.85 ? .orange : providerTint(session.provider))
            } else {
                UsageBar(fraction: 0, tint: providerTint(session.provider), isPlaceholder: true)
            }

            if let plan = session.planUsagePercent {
                Text("Plan window \(plan)% used")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(plan >= 85 ? Color.orange : .white.opacity(0.45))
            }
        }
    }

    private func providerTint(_ provider: ShellAgentProvider) -> Color {
        switch provider {
        case .codex: return .blue
        case .claudeCode: return .orange
        case .openCode: return .teal
        case .ollama: return .purple
        }
    }
}

// MARK: - Building blocks

private struct StatusDot: View {
    let status: ShellAgentSessionStatus

    var body: some View {
        Circle()
            .fill(status.tint)
            .frame(width: 6, height: 6)
            .accessibilityLabel(status.label)
    }
}

private struct StatusPill: View {
    let status: ShellAgentSessionStatus

    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(status.tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(status.tint.opacity(0.12), in: Capsule())
    }
}

extension ShellAgentSessionStatus {
    var label: String {
        switch self {
        case .ongoing: return "Working"
        case .needsReview: return "Needs review"
        case .failed: return "Failed"
        case .idle: return "Idle"
        }
    }

    var tint: Color {
        switch self {
        case .ongoing: return .green
        case .needsReview: return .orange
        case .failed: return .red
        case .idle: return .white.opacity(0.3)
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct UsageBar: View {
    let fraction: Double
    let tint: Color
    var isPlaceholder = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.09))
                if !isPlaceholder {
                    Capsule()
                        .fill(tint.opacity(0.85))
                        .frame(width: max(4, proxy.size.width * fraction))
                }
            }
        }
        .frame(height: 5)
        .animation(.easeOut(duration: 0.25), value: fraction)
    }
}
