import SwiftUI

struct ShellRootView: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(shellPadding)
            .background(shellBackground)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onHover { isHovering in
                viewModel.setHovering(isHovering)
            }
            .accessibilityIdentifier("shell-root")
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.presentationState {
        case .closed:
            HStack(spacing: 8) {
                summaryChip(
                    title: "Focus",
                    value: viewModel.statusSnapshot.focusLabel,
                    accentOpacity: 0.22
                )
                summaryChip(
                    title: "Next",
                    value: viewModel.statusSnapshot.nextEventLabel,
                    accentOpacity: 0.14
                )
                summaryChip(
                    title: "Hosts",
                    value: viewModel.statusSnapshot.hostStatusLabel,
                    accentOpacity: 0.1
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .peek(let reason):
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Developer command center")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text(peekDescription(for: reason))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Button("Open") {
                    viewModel.open()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.08), in: Capsule())
                .accessibilityIdentifier("shell-open-button")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        case .open:
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notch-")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .accessibilityIdentifier("shell-open-title")
                        Text("Phase 0 shell foundation")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Close") {
                        viewModel.close()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.08), in: Capsule())
                    .accessibilityIdentifier("shell-close-button")
                }

                HStack(spacing: 10) {
                    ForEach(viewModel.statusSnapshot.openHighlights) { highlight in
                        shellCard(title: highlight.title, value: highlight.value)
                    }
                }

                Button("Cycle Preview State") {
                    viewModel.cyclePreviewState()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.08), in: Capsule())
                .accessibilityIdentifier("shell-cycle-button")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var shellBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.black.opacity(0.92))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            }
    }

    private var shellPadding: CGFloat {
        switch viewModel.presentationState {
        case .closed:
            return 12
        case .peek:
            return 14
        case .open:
            return 18
        }
    }

    private var cornerRadius: CGFloat {
        switch viewModel.presentationState {
        case .closed:
            return 16
        case .peek:
            return 22
        case .open:
            return 26
        }
    }

    private func peekDescription(for reason: PeekReason) -> String {
        switch reason {
        case .hover:
            return "Hover preview with focus, calendar, and localhost at-a-glance."
        case .statusChange:
            return "Transient shell state wired for future notifications."
        }
    }

    private func shellCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func summaryChip(title: String, value: String, accentOpacity: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .foregroundStyle(.white.opacity(0.94))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [
                    .white.opacity(accentOpacity),
                    .white.opacity(0.05),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}
