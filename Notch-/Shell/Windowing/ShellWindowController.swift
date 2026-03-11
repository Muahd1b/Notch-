import AppKit
import Combine
import CoreGraphics
import SwiftUI

@MainActor
protocol ShellWindowControlling: AnyObject {
    func showWindow()
    func updateTargetDisplay(_ display: ShellDisplay)
    func refreshGeometry()
    func closeWindow()
}

@MainActor
final class ShellWindowController: NSWindowController, ShellWindowControlling {
    private let geometryResolver: ShellGeometryResolver
    private let hapticsService: HapticsService
    private let viewModel: ShellViewModel
    private let settingsStore: AppSettingsStore
    private var cancellables = Set<AnyCancellable>()
    private var targetDisplay: ShellDisplay
    private var hoverTask: Task<Void, Never>?
    private var hoverPollTimer: Timer?
    private var lastPresentationState: ShellPresentationState = .closed

    init(
        display: ShellDisplay,
        viewModel: ShellViewModel,
        geometryResolver: ShellGeometryResolver,
        hapticsService: HapticsService,
        settingsStore: AppSettingsStore
    ) {
        self.targetDisplay = display
        self.viewModel = viewModel
        self.geometryResolver = geometryResolver
        self.hapticsService = hapticsService
        self.settingsStore = settingsStore
        self.lastPresentationState = viewModel.presentationState(for: display.id)

        let screenGeometry = display.geometry
        let closedSize = geometryResolver.shellSize(
            for: .closed,
            baseNotchSize: geometryResolver.notchSize(for: screenGeometry, settings: settingsStore.shellSizingSettings)
        )
        let initialWindowSize = geometryResolver.windowSize(for: .closed, shellSize: closedSize)
        let initialFrame = geometryResolver.anchoredFrame(
            for: .closed,
            shellSize: closedSize,
            windowSize: initialWindowSize,
            in: screenGeometry
        )
        let panel = ShellPanel(frame: initialFrame)

        super.init(window: panel)

        let hostView = NSHostingView(rootView: ShellRootView(viewModel: viewModel, displayID: display.id))
        hostView.setAccessibilityElement(true)
        hostView.setAccessibilityIdentifier("shell-root")
        panel.contentView = hostView
        panel.setFrame(initialFrame, display: true)
        panel.onTrackedHoverChanged = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncPointerHover()
            }
        }

        bindPresentationChanges()
        updateTrackingRegion()
        startHoverMonitoring()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow() {
        window?.orderFrontRegardless()
        if ProcessInfo.processInfo.arguments.contains("-uitest-mode") {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
        }
        updateFrame(animated: false)
    }

    func updateTargetDisplay(_ display: ShellDisplay) {
        targetDisplay = display
        lastPresentationState = presentationState
        updateFrame(animated: false)
    }

    func refreshGeometry() {
        updateFrame(animated: false)
    }

    func closeWindow() {
        hoverTask?.cancel()
        hoverPollTimer?.invalidate()
        hoverPollTimer = nil
        close()
    }

    deinit {
        hoverPollTimer?.invalidate()
    }

    private func bindPresentationChanges() {
        viewModel.presentationStateDidChange
            .sink { [weak self] _ in
                self?.handlePresentationStateChange()
            }
            .store(in: &cancellables)

        Publishers.MergeMany(
            settingsStore.$notchHeightMode.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settingsStore.$nonNotchHeightMode.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settingsStore.$notchHeight.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settingsStore.$nonNotchHeight.dropFirst().map { _ in () }.eraseToAnyPublisher()
        )
            .sink { [weak self] _ in
                self?.updateFrame(animated: false)
            }
            .store(in: &cancellables)
    }

    private func handlePresentationStateChange() {
        guard presentationState != lastPresentationState else { return }
        lastPresentationState = presentationState
        updateFrame(animated: true)
        updateTrackingRegion()
    }

    private func updateFrame(animated: Bool) {
        guard let window else { return }

        let screenGeometry = targetDisplay.geometry
        let notchSize = geometryResolver.notchSize(for: screenGeometry, settings: settingsStore.shellSizingSettings)
        viewModel.updateClosedNotchSize(notchSize, on: displayID)
        let shellSize = geometryResolver.shellSize(
            for: presentationState,
            baseNotchSize: notchSize
        )
        let windowSize = geometryResolver.windowSize(for: presentationState, shellSize: shellSize)
        let nextFrame = geometryResolver.anchoredFrame(
            for: presentationState,
            shellSize: shellSize,
            windowSize: windowSize,
            in: screenGeometry
        )

        window.setFrame(nextFrame, display: true, animate: animated)
        updateTrackingRegion()
    }

    private func updateTrackedHover(_ hovering: Bool) {
        guard hovering != pointerHovering else { return }
        handleTrackedHoverChanged(hovering)
    }

    private func handleTrackedHoverChanged(_ hovering: Bool) {
        hoverTask?.cancel()
        viewModel.updatePointerHovering(hovering, on: displayID)

        if hovering {
            guard settingsStore.openNotchOnHover, case .closed = presentationState else { return }

            hoverTask = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .seconds(settingsStore.hoverDelay))
                guard !Task.isCancelled else { return }
                guard self.pointerHovering, case .closed = self.presentationState else { return }

                if self.settingsStore.enableHaptics {
                    self.hapticsService.play(.open)
                }

                withAnimation(Animation.interactiveSpring(response: 0.38, dampingFraction: 0.8, blendDuration: 0)) {
                    self.viewModel.open(.hover, on: self.displayID)
                }
            }
            return
        }

        hoverTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            guard !self.pointerHovering else { return }
            guard case .open(let reason) = self.presentationState else { return }
            guard reason == .hover || !self.settingsStore.keepShellOpenOnClick else { return }

            if self.settingsStore.enableHaptics {
                self.hapticsService.play(.settle)
            }

            withAnimation(Animation.interactiveSpring(response: 0.38, dampingFraction: 0.8, blendDuration: 0)) {
                self.viewModel.close(on: self.displayID)
            }
        }
    }

    private func updateTrackingRegion() {
        guard let panel = window as? ShellPanel else { return }

        let windowBounds = CGRect(origin: .zero, size: panel.frame.size)
        panel.configureTracking(rect: trackingRect(for: presentationState, in: windowBounds))
    }

    private func startHoverMonitoring() {
        hoverPollTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncPointerHover()
            }
        }
        hoverPollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func syncPointerHover() {
        guard let panel = window as? ShellPanel else { return }

        let mouseLocation = NSEvent.mouseLocation
        guard let pointerDisplayID = activeDisplayID(at: mouseLocation),
              pointerDisplayID == targetDisplay.cgDisplayID else {
            updateTrackedHover(false)
            return
        }

        guard targetDisplay.geometry.frame.contains(mouseLocation) else {
            updateTrackedHover(false)
            return
        }
        let isHovering: Bool

        switch presentationState {
        case .closed:
            let entryRect = screenHoverActivationRect(for: panel)
            let sustainRect = screenTrackingRect(for: .closed, panel: panel)
            isHovering = pointerHovering
                ? sustainRect.contains(mouseLocation)
                : entryRect.contains(mouseLocation)
        case .open(let reason):
            isHovering = screenTrackingRect(for: .open(reason), panel: panel).contains(mouseLocation)
        }

        updateTrackedHover(isHovering)
    }

    private func activeDisplayID(at point: CGPoint) -> CGDirectDisplayID? {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) else {
            return nil
        }

        let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return CGDirectDisplayID(screenNumber?.uint32Value ?? 0)
    }

    private func trackingRect(for state: ShellPresentationState, in windowBounds: CGRect) -> CGRect {
        switch state {
        case .closed:
            return CGRect(
                x: (windowBounds.width - closedNotchSize.width) / 2,
                y: windowBounds.height - closedNotchSize.height,
                width: closedNotchSize.width,
                height: closedNotchSize.height
            )
        case .open:
            return CGRect(
                x: (windowBounds.width - ShellSizing.openNotchSize.width) / 2,
                y: windowBounds.height - ShellSizing.openNotchSize.height,
                width: ShellSizing.openNotchSize.width,
                height: ShellSizing.openNotchSize.height
            )
        }
    }

    private func screenTrackingRect(for state: ShellPresentationState, panel: ShellPanel) -> CGRect {
        let localRect = trackingRect(for: state, in: CGRect(origin: .zero, size: panel.frame.size))
        return CGRect(
            x: panel.frame.origin.x + localRect.origin.x,
            y: panel.frame.origin.y + localRect.origin.y,
            width: localRect.width,
            height: localRect.height
        )
    }

    private var displayID: String {
        targetDisplay.id
    }

    private var presentationState: ShellPresentationState {
        viewModel.presentationState(for: displayID)
    }

    private var pointerHovering: Bool {
        viewModel.isPointerHovering(on: displayID)
    }

    private var closedNotchSize: CGSize {
        viewModel.closedNotchSize(for: displayID)
    }

    private func screenHoverActivationRect(for panel: ShellPanel) -> CGRect {
        let localRect = trackingRect(for: .closed, in: CGRect(origin: .zero, size: panel.frame.size))
            .insetBy(
                dx: ShellSizing.closedHoverActivationHorizontalInset,
                dy: ShellSizing.closedHoverActivationVerticalInset
            )

        return CGRect(
            x: panel.frame.origin.x + localRect.origin.x,
            y: panel.frame.origin.y + localRect.origin.y,
            width: localRect.width,
            height: localRect.height
        )
    }
}
