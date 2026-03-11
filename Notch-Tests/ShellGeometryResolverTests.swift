import AppKit
import Testing
@testable import Notch_

struct ShellGeometryResolverTests {
    private let resolver = ShellGeometryResolver()

    @Test
    func computesRealNotchSizeFromSafeAreaGeometry() {
        let geometry = ScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: CGRect(x: 0, y: 28, width: 1512, height: 954),
            safeAreaInsets: NSEdgeInsets(top: 32, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftWidth: 620,
            auxiliaryTopRightWidth: 620
        )

        let notchSize = resolver.notchSize(for: geometry)

        #expect(notchSize.width == 272)
        #expect(notchSize.height == 32)
    }

    @Test
    func fallsBackToMenuBarHeightOnNonNotchedDisplays() {
        let geometry = ScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
            visibleFrame: CGRect(x: 0, y: 24, width: 1728, height: 1093),
            safeAreaInsets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftWidth: nil,
            auxiliaryTopRightWidth: nil
        )

        let notchSize = resolver.notchSize(for: geometry)

        #expect(notchSize.width == 220)
        #expect(notchSize.height == 28)
    }

    @Test
    func anchorsShellFramesToTopCenter() {
        let geometry = ScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: CGRect(x: 0, y: 28, width: 1512, height: 954),
            safeAreaInsets: NSEdgeInsets(top: 32, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftWidth: 620,
            auxiliaryTopRightWidth: 620
        )

        let anchoredFrame = resolver.anchoredFrame(
            for: CGSize(width: 420, height: 180),
            in: geometry
        )

        #expect(anchoredFrame.origin.x == 546)
        #expect(anchoredFrame.origin.y == 802)
    }
}
