import SwiftUI

@MainActor
struct ShellOpsPageView: View {
    @ObservedObject var viewModel: ShellViewModel
    let statusSnapshot: ShellStatusSnapshot

    private var ops: ShellOpsSnapshot { statusSnapshot.ops }

    private var failedAgents: [ShellAgentSession] {
        statusSnapshot.agentSessions.filter { $0.status == .failed }
    }

    private var attentionCount: Int {
        ops.needsYou.count + failedAgents.count
    }

    private var flaggedAutomations: [ShellAutomation] {
        ops.automations.filter { $0.issue != nil }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            needsYouColumn
                .frame(width: 240, alignment: .topLeading)
            rightColumn
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Needs you

    private var needsYouColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Needs you")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Text(attentionCount == 0 ? "clear" : "\(attentionCount) open")
                    .font(.caption)
                    .foregroundStyle(attentionCount == 0 ? .white.opacity(0.45) : Color.orange)
            }
            .padding(.horizontal, 2)

            if ops.needsYou.isEmpty && failedAgents.isEmpty {
                emptyState(
                    symbol: "checkmark.seal",
                    title: "Nothing blocked",
                    detail: "No ack gates, no failed agent turns."
                )
            } else {
                VStack(spacing: 4) {
                    ForEach(ops.needsYou) { item in
                        attentionRow(
                            symbol: item.kind == .ack ? "hand.raised.fill" : "exclamationmark.triangle.fill",
                            title: item.title,
                            detail: item.detail,
                            tint: .orange
                        )
                    }
                    ForEach(failedAgents) { session in
                        attentionRow(
                            symbol: session.provider.symbolName,
                            title: session.title,
                            detail: "\(session.provider.title) failed · \(session.lastActivityLabel)",
                            tint: .red
                        )
                    }
                }
            }
        }
    }

    private func attentionRow(symbol: String, title: String, detail: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(tint)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    // MARK: - Automations and repos

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            repoStrip
            automationList
        }
    }

    private var repoStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Repos", trailing: ops.repos.isEmpty ? nil : "\(ops.repos.count) watched")
            if ops.repos.isEmpty {
                Text("Waiting for the first GitHub poll…")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                VStack(spacing: 2) {
                    ForEach(ops.repos) { repo in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(repoTint(repo))
                                .frame(width: 6, height: 6)
                            Text(repo.id)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(repo.ciLabel)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.45))
                            if repo.openPRs > 0 {
                                Text("\(repo.openPRs) PR")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.blue.opacity(0.9))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.blue.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var automationList: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(
                "Automations",
                trailing: "\(ops.automations.filter(\.isActive).count) active · \(ops.overdueCount) overdue"
            )

            if flaggedAutomations.isEmpty {
                Text("Nothing expired or stale.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                ForEach(flaggedAutomations.prefix(3)) { automation in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(automationTint(automation))
                            .frame(width: 5, height: 5)
                        Text(automation.name)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(automation.issue == .expired ? "expired" : "stale")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(automation.issue == .expired ? Color.red : Color.orange)
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Bits

    private func sectionHeader(_ title: String, trailing: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
            Spacer(minLength: 6)
            if let trailing {
                Text(trailing)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private func emptyState(symbol: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.green.opacity(0.8))
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func automationTint(_ automation: ShellAutomation) -> Color {
        switch automation.issue {
        case .expired: return .red
        case .stale: return .orange
        case nil: return automation.isActive ? .green.opacity(0.85) : .white.opacity(0.25)
        }
    }

    private func repoTint(_ repo: ShellRepoStatus) -> Color {
        switch repo.ciState {
        case "success": return .green
        case "failure": return .red
        case "running": return .blue
        default: return .white.opacity(0.25)
        }
    }
}
