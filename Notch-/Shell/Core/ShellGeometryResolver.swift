import AppKit

struct ScreenGeometry: Equatable {
    let frame: CGRect
    let visibleFrame: CGRect
    let safeAreaInsets: NSEdgeInsets
    let auxiliaryTopLeftWidth: CGFloat?
    let auxiliaryTopRightWidth: CGFloat?
}

extension ScreenGeometry {
    init(screen: NSScreen) {
        frame = screen.frame
        visibleFrame = screen.visibleFrame
        safeAreaInsets = screen.safeAreaInsets
        auxiliaryTopLeftWidth = screen.auxiliaryTopLeftArea?.width
        auxiliaryTopRightWidth = screen.auxiliaryTopRightArea?.width
    }

    static func == (lhs: ScreenGeometry, rhs: ScreenGeometry) -> Bool {
        lhs.frame == rhs.frame
            && lhs.visibleFrame == rhs.visibleFrame
            && lhs.safeAreaInsets.top == rhs.safeAreaInsets.top
            && lhs.safeAreaInsets.left == rhs.safeAreaInsets.left
            && lhs.safeAreaInsets.bottom == rhs.safeAreaInsets.bottom
            && lhs.safeAreaInsets.right == rhs.safeAreaInsets.right
            && lhs.auxiliaryTopLeftWidth == rhs.auxiliaryTopLeftWidth
            && lhs.auxiliaryTopRightWidth == rhs.auxiliaryTopRightWidth
    }
}

struct ShellGeometryResolver {
    let fallbackWidth: CGFloat

    nonisolated init(fallbackWidth: CGFloat = 185) {
        self.fallbackWidth = fallbackWidth
    }

    nonisolated func notchSize(for geometry: ScreenGeometry) -> CGSize {
        notchSize(for: geometry, settings: .default)
    }

    nonisolated func notchSize(for geometry: ScreenGeometry, settings: ShellSizingSettings) -> CGSize {
        let hasNotch = geometry.safeAreaInsets.top > 0
            && geometry.auxiliaryTopLeftWidth != nil
            && geometry.auxiliaryTopRightWidth != nil

        if hasNotch,
           let leftWidth = geometry.auxiliaryTopLeftWidth,
           let rightWidth = geometry.auxiliaryTopRightWidth {
            let notchWidth = max(geometry.frame.width - leftWidth - rightWidth + 4, 120)
            let menuBarHeight = geometry.frame.maxY - geometry.visibleFrame.maxY
            let notchHeight: CGFloat

            switch settings.notchHeightMode {
            case .matchRealNotchSize:
                notchHeight = geometry.safeAreaInsets.top
            case .matchMenuBar:
                notchHeight = menuBarHeight
            case .custom:
                notchHeight = CGFloat(settings.notchHeight)
            }

            return CGSize(width: notchWidth, height: notchHeight)
        }

        let menuBarHeight = max(geometry.frame.maxY - geometry.visibleFrame.maxY, 28)
        let fallbackHeight: CGFloat

        switch settings.nonNotchHeightMode {
        case .matchRealNotchSize:
            fallbackHeight = CGFloat(settings.notchHeight)
        case .matchMenuBar:
            fallbackHeight = menuBarHeight
        case .custom:
            fallbackHeight = CGFloat(settings.nonNotchHeight)
        }

        return CGSize(width: fallbackWidth, height: fallbackHeight)
    }

    nonisolated func shellSize(for state: ShellPresentationState, baseNotchSize: CGSize) -> CGSize {
        switch state {
        case .closed:
            return baseNotchSize
        case .open:
            return ShellSizing.openNotchSize
        }
    }

    nonisolated func windowSize(for state: ShellPresentationState, shellSize: CGSize) -> CGSize {
        CGSize(
            width: ShellSizing.openNotchSize.width + (ShellSizing.shadowPadding * 2),
            height: ShellSizing.openNotchSize.height + ShellSizing.shadowPadding
        )
    }

    nonisolated func anchoredFrame(
        for state: ShellPresentationState,
        shellSize: CGSize,
        windowSize: CGSize,
        in geometry: ScreenGeometry
    ) -> CGRect {
        return CGRect(
            x: geometry.frame.midX - (windowSize.width / 2),
            y: geometry.frame.maxY - windowSize.height,
            width: windowSize.width,
            height: windowSize.height
        )
    }
}
