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

        #expect(notchSize.width == 276)
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

        #expect(notchSize.width == 185)
        #expect(notchSize.height == 28)
    }

    @Test
    func openStateUsesPinnedBoringNotchOpenSize() {
        let shellSize = resolver.shellSize(
            for: .open(.userInitiated),
            baseNotchSize: CGSize(width: 272, height: 32)
        )
        let windowSize = resolver.windowSize(for: .open(.userInitiated), shellSize: shellSize)

        #expect(shellSize.width == 640)
        #expect(shellSize.height == 190)
        #expect(windowSize.width == 680)
        #expect(windowSize.height == 210)
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

        let shellSize = CGSize(width: 420, height: 180)
        let windowSize = resolver.windowSize(for: .closed, shellSize: shellSize)
        let anchoredFrame = resolver.anchoredFrame(
            for: .closed,
            shellSize: shellSize,
            windowSize: windowSize,
            in: geometry
        )

        #expect(windowSize.width == 680)
        #expect(windowSize.height == 210)
        #expect(anchoredFrame.origin.x == 416)
        #expect(anchoredFrame.origin.y == 772)
    }

    @Test
    func openStateFramePreservesCenteredShellWhileAddingHaloRoom() {
        let geometry = ScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: CGRect(x: 0, y: 28, width: 1512, height: 954),
            safeAreaInsets: NSEdgeInsets(top: 32, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftWidth: 620,
            auxiliaryTopRightWidth: 620
        )
        let shellSize = CGSize(width: 640, height: 190)
        let windowSize = resolver.windowSize(for: .open(.userInitiated), shellSize: shellSize)

        let anchoredFrame = resolver.anchoredFrame(
            for: .open(.userInitiated),
            shellSize: shellSize,
            windowSize: windowSize,
            in: geometry
        )

        #expect(anchoredFrame.origin.x == 416)
        #expect(anchoredFrame.origin.y == 772)
        #expect(anchoredFrame.width == 680)
        #expect(anchoredFrame.height == 210)
    }
}
