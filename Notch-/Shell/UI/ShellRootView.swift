import SwiftUI

struct ShellRootView: View {
    @ObservedObject var viewModel: ShellViewModel
    let displayID: String
    @State private var hapticsTrigger = false

    private let animationSpring = Animation.interactiveSpring(response: 0.38, dampingFraction: 0.8, blendDuration: 0)
    private let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
    private let closeAnimation = Animation.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
    private let shellFadeProfile: [(horizontalExpansion: CGFloat, bottomExpansion: CGFloat, opacityFactor: Double)] = [
        (0.42, 0.6, 0.084),
        (0.74, 1.1, 0.081),
        (1.12, 1.7, 0.078),
        (1.53, 2.4, 0.074),
        (1.95, 3.2, 0.069),
        (2.39, 4.1, 0.064),
        (2.85, 5.1, 0.058),
        (3.32, 6.2, 0.052),
        (3.80, 7.4, 0.046),
        (4.30, 8.7, 0.041),
        (4.82, 10.1, 0.036),
        (5.35, 11.6, 0.031),
        (5.90, 13.2, 0.026),
        (6.46, 14.9, 0.021),
        (7.04, 16.7, 0.016),
        (7.63, 18.6, 0.012),
        (8.24, 20.6, 0.008)
    ]

    var body: some View {
        ZStack(alignment: .top) {
            shellBody
        }
        .coordinateSpace(name: "shell-root-space")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contextMenu {
            Button("Settings") {
                SettingsWindowController.shared.showWindow()
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shell-root")
        .sensoryFeedback(.alignment, trigger: hapticsTrigger)
    }

    private var shellBody: some View {
        ZStack(alignment: .top) {
            shellFadeGeometry
            shellSurface
                .frame(width: shellBodyWidth, height: shellBodyHeight, alignment: .top)
        }
            .padding(.horizontal, ShellSizing.shadowPadding)
            .padding(.bottom, ShellSizing.shadowPadding)
            .frame(
                width: shellBodyWidth + (ShellSizing.shadowPadding * 2),
                height: shellBodyHeight + ShellSizing.shadowPadding,
                alignment: .top
            )
            .contentShape(shellShape)
            .onTapGesture {
                if case .closed = presentationState {
                    toggleShellHaptics()
                    withAnimation(animationSpring) {
                        viewModel.open(.userInitiated, on: displayID)
                    }
                }
            }
            .animation(
                presentationState.isExpanded ? openAnimation : closeAnimation,
                value: presentationState
            )
    }

    private var shellSurface: some View {
        shellChrome
            .overlay {
                shellContentLayer
            }
    }

    private var shellFadeGeometry: some View {
        ZStack(alignment: .top) {
            ForEach(Array(shellFadeProfile.enumerated()), id: \.offset) { _, layer in
                NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
                    .fill(Color.black.opacity(shellShadowOpacity * layer.opacityFactor))
                    .frame(
                        width: shellBodyWidth + (layer.horizontalExpansion * 2),
                        height: shellBodyHeight + layer.bottomExpansion,
                        alignment: .top
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private var shellChrome: some View {
        Color.black
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.black)
                    .frame(height: 1)
                    .padding(.horizontal, topCornerRadius)
            }
            .clipShape(shellShape)
    }

    private var shellContentLayer: some View {
        ZStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(shellContentPadding)
        }
        .padding(.horizontal, shellInnerHorizontalInset)
        .padding([.horizontal, .bottom], presentationState.isExpanded ? 12 : 0)
        .clipShape(shellShape)
    }

    @ViewBuilder
    private var content: some View {
        switch presentationState {
        case .closed:
            Rectangle()
                .fill(.clear)
                .frame(width: max(closedNotchSize.width - 20, 0), height: closedNotchSize.height)

        case .open:
            ShellOpenContentView(viewModel: viewModel, displayID: displayID, statusSnapshot: viewModel.statusSnapshot)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var shellShape: NotchShape {
        NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
    }

    private var shellBodyHeight: CGFloat {
        switch presentationState {
        case .open:
            return ShellSizing.openNotchSize.height
        case .closed:
            return closedNotchSize.height
        }
    }

    private var shellBodyWidth: CGFloat {
        switch presentationState {
        case .open:
            return ShellSizing.openNotchSize.width
        case .closed:
            return closedNotchSize.width
        }
    }

    private var shellShadowOpacity: Double {
        switch presentationState {
        case .open:
            return 0.7
        case .closed:
            return 0
        }
    }

    private var shellInnerHorizontalInset: CGFloat {
        switch presentationState {
        case .open:
            return ShellSizing.cornerRadiusInsets.opened.top
        case .closed:
            return ShellSizing.cornerRadiusInsets.closed.bottom
        }
    }

    private var shellContentPadding: EdgeInsets {
        switch presentationState {
        case .closed:
            return EdgeInsets()
        case .open:
            return EdgeInsets(top: 0, leading: 12, bottom: 12, trailing: 12)
        }
    }

    private var topCornerRadius: CGFloat {
        switch presentationState {
        case .closed:
            return ShellSizing.cornerRadiusInsets.closed.top
        case .open:
            return ShellSizing.cornerRadiusInsets.opened.top
        }
    }

    private var bottomCornerRadius: CGFloat {
        switch presentationState {
        case .closed:
            return ShellSizing.cornerRadiusInsets.closed.bottom
        case .open:
            return ShellSizing.cornerRadiusInsets.opened.bottom
        }
    }

    private var presentationState: ShellPresentationState {
        viewModel.presentationState(for: displayID)
    }

    private var closedNotchSize: CGSize {
        viewModel.closedNotchSize(for: displayID)
    }

    private func toggleShellHaptics() {
        hapticsTrigger.toggle()
    }
}
