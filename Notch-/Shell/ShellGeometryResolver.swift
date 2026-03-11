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

    nonisolated init(fallbackWidth: CGFloat = 220) {
        self.fallbackWidth = fallbackWidth
    }

    nonisolated func notchSize(for geometry: ScreenGeometry) -> CGSize {
        let hasNotch = geometry.safeAreaInsets.top > 0
            && geometry.auxiliaryTopLeftWidth != nil
            && geometry.auxiliaryTopRightWidth != nil

        if hasNotch,
           let leftWidth = geometry.auxiliaryTopLeftWidth,
           let rightWidth = geometry.auxiliaryTopRightWidth {
            let notchWidth = max(geometry.frame.width - leftWidth - rightWidth, 120)
            return CGSize(width: notchWidth, height: geometry.safeAreaInsets.top)
        }

        let fallbackHeight = max(geometry.frame.maxY - geometry.visibleFrame.maxY, 28)
        return CGSize(width: fallbackWidth, height: fallbackHeight)
    }

    nonisolated func shellSize(for state: ShellPresentationState, baseNotchSize: CGSize) -> CGSize {
        switch state {
        case .closed:
            return baseNotchSize
        case .peek:
            return CGSize(
                width: max(baseNotchSize.width + 96, 280),
                height: max(baseNotchSize.height + 40, 72)
            )
        case .open:
            return CGSize(
                width: max(baseNotchSize.width + 220, 420),
                height: 180
            )
        }
    }

    nonisolated func anchoredFrame(for size: CGSize, in geometry: ScreenGeometry) -> CGRect {
        CGRect(
            x: geometry.frame.midX - (size.width / 2),
            y: geometry.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}
