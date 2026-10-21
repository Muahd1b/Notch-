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
        HStack(alignment: .top, spacing: 10) {
            needsYouColumn
                .frame(width: 236, alignment: .topLeading)
            rightColumn
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Needs you

    private var needsYouColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                emptyState
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

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: "checkmark.seal")
                .font(.title3)
                .foregroundStyle(.green.opacity(0.8))
            Text("Nothing blocked")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
            Text("No ack gates, no failed agent turns.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func attentionRow(symbol: String, title: String, detail: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: symbol)
                .font(.caption2)
                .foregroundStyle(tint)
                .frame(width: 13)
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
        .padding(.vertical, 5)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    // MARK: - Repos and automations

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text("Repos")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer(minLength: 6)
                Text(ops.repos.isEmpty ? "polling…" : "\(ops.repos.count) watched")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }

            ForEach(ops.repos) { repo in
                HStack(spacing: 7) {
                    Circle()
                        .fill(repoTint(repo))
                        .frame(width: 5, height: 5)
                    Text(repo.id)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(repo.ciLabel)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(repo.ciState == "failure" ? Color.red.opacity(0.9) : .white.opacity(0.45))
                    if repo.openPRs > 0 {
                        Text("\(repo.openPRs) PR")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.blue.opacity(0.9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                    }
                }
            }

            Divider()
                .overlay(.white.opacity(0.08))
                .padding(.vertical, 1)

            automationSummary
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var automationSummary: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("Automations")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer(minLength: 4)
                Text("\(ops.automations.filter(\.isActive).count) active · \(ops.overdueCount) overdue")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(ops.overdueCount > 0 ? Color.orange : .white.opacity(0.4))
            }

            if flaggedAutomations.isEmpty {
                Text("Nothing expired or stale.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
            } else {
                ForEach(flaggedAutomations.prefix(2)) { automation in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(automation.issue == .expired ? Color.red : Color.orange)
                            .frame(width: 4, height: 4)
                        Text(automation.name)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(automation.issue == .expired ? "expired" : "stale")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(automation.issue == .expired ? Color.red : Color.orange)
                    }
                }
            }
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
