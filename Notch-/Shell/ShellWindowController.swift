import AppKit
import Combine
import SwiftUI

@MainActor
protocol ShellWindowControlling: AnyObject {
    func showWindow()
    func updateTargetDisplay(_ display: ShellDisplay)
    func refreshGeometry()
}

@MainActor
final class ShellWindowController: NSWindowController, ShellWindowControlling {
    private let geometryResolver: ShellGeometryResolver
    private let hapticsService: HapticsService
    private let viewModel: ShellViewModel
    private var cancellables = Set<AnyCancellable>()
    private var targetDisplay: ShellDisplay

    init(
        display: ShellDisplay,
        viewModel: ShellViewModel,
        geometryResolver: ShellGeometryResolver,
        hapticsService: HapticsService
    ) {
        self.targetDisplay = display
        self.viewModel = viewModel
        self.geometryResolver = geometryResolver
        self.hapticsService = hapticsService

        let screenGeometry = display.geometry
        let closedSize = geometryResolver.shellSize(
            for: .closed,
            baseNotchSize: geometryResolver.notchSize(for: screenGeometry)
        )
        let initialFrame = geometryResolver.anchoredFrame(for: closedSize, in: screenGeometry)
        let panel = ShellPanel(frame: initialFrame)

        super.init(window: panel)

        let hostView = NSHostingView(rootView: ShellRootView(viewModel: viewModel))
        panel.contentView = hostView
        panel.setFrame(initialFrame, display: true)

        bindPresentationChanges()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow() {
        window?.orderFrontRegardless()
        updateFrame(animated: false)
    }

    func updateTargetDisplay(_ display: ShellDisplay) {
        targetDisplay = display
        updateFrame(animated: false)
    }

    func refreshGeometry() {
        updateFrame(animated: false)
    }

    private func bindPresentationChanges() {
        viewModel.$presentationState
            .dropFirst()
            .sink { [weak self] _ in
                self?.handlePresentationStateChange()
            }
            .store(in: &cancellables)
    }

    private func handlePresentationStateChange() {
        updateFrame(animated: true)

        if case .open = viewModel.presentationState {
            hapticsService.play(.open)
        } else {
            hapticsService.play(.settle)
        }
    }

    private func updateFrame(animated: Bool) {
        guard let window else { return }

        let screenGeometry = targetDisplay.geometry
        let notchSize = geometryResolver.notchSize(for: screenGeometry)
        let shellSize = geometryResolver.shellSize(
            for: viewModel.presentationState,
            baseNotchSize: notchSize
        )
        let nextFrame = geometryResolver.anchoredFrame(for: shellSize, in: screenGeometry)

        window.setFrame(nextFrame, display: true, animate: animated)
    }
}
