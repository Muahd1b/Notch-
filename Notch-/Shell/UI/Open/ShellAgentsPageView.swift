import AppKit
import AVFoundation
import Combine
import CoreGraphics
import SwiftUI

@MainActor
struct ShellAgentsPageView: View {
    @ObservedObject var viewModel: ShellViewModel
    let statusSnapshot: ShellStatusSnapshot

    @State private var selectedSessionID: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            sessionsColumn
                .frame(width: 292, alignment: .topLeading)

            detailColumn
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if selectedSessionID == nil {
                selectedSessionID = statusSnapshot.agentSessions.first?.id
            }
        }
        .onChange(of: statusSnapshot.agentSessions.map(\.id)) { _, _ in
            guard let selectedSessionID else {
                self.selectedSessionID = statusSnapshot.agentSessions.first?.id
                return
            }
            if !statusSnapshot.agentSessions.contains(where: { $0.id == selectedSessionID }) {
                self.selectedSessionID = statusSnapshot.agentSessions.first?.id
            }
        }
    }

    private var sessionsColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Agent Sessions")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))

            if statusSnapshot.agentSessions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No active observers")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Enable Codex or Claude monitoring in Settings > Agents.")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(11)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(statusSnapshot.agentSessions) { session in
                            Button {
                                selectedSessionID = session.id
                                viewModel.playSelectionHaptic()
                            } label: {
                                HStack(alignment: .top, spacing: 7) {
                                    Circle()
                                        .fill(statusColor(session.status))
                                        .frame(width: 7, height: 7)
                                        .padding(.top, 3)

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(session.provider.title)
                                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.74))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(providerColor(session.provider).opacity(0.35), in: Capsule())

                                            Text(session.status == .ongoing ? "ONGOING" : "IDLE")
                                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.65))
                                        }

                                        Text(session.title)
                                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)

                                        Text(session.lastActivityLabel)
                                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.58))
                                            .lineLimit(1)
                                    }

                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    (selectedSessionID == session.id ? .white.opacity(0.11) : .white.opacity(0.05)),
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var detailColumn: some View {
        let selected = statusSnapshot.agentSessions.first(where: { $0.id == selectedSessionID }) ?? statusSnapshot.agentSessions.first
        let ongoingCount = statusSnapshot.agentSessions.filter { $0.status == .ongoing }.count
        let idleCount = statusSnapshot.agentSessions.filter { $0.status == .idle }.count
        let providerCount = Set(statusSnapshot.agentSessions.map(\.provider)).count

        return VStack(alignment: .leading, spacing: 8) {
            Text("Agent Overview")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))

            HStack(spacing: 8) {
                metricCard(title: "Ongoing", value: "\(ongoingCount)")
                metricCard(title: "Idle", value: "\(idleCount)")
                metricCard(title: "Providers", value: "\(providerCount)")
            }

            if let selected {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(selected.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(selected.confidence.rawValue.uppercased())
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    Text(selected.workspacePath)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(selected.provider.title)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                        Text("•")
                            .foregroundStyle(.white.opacity(0.46))
                        Text(selected.status == .ongoing ? "ongoing" : "idle")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(statusColor(selected.status))
                        Text("•")
                            .foregroundStyle(.white.opacity(0.46))
                        Text(selected.lastActivityLabel)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.64))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Text("Waiting for agent activity.")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
        }
    }

    private func providerColor(_ provider: ShellAgentProvider) -> Color {
        switch provider {
        case .codex:
            return .blue
        case .claudeCode:
            return .orange
        case .openClaw:
            return .purple
        }
    }

    private func statusColor(_ status: ShellAgentSessionStatus) -> Color {
        switch status {
        case .ongoing:
            return .green
        case .idle:
            return .white.opacity(0.56)
        }
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
