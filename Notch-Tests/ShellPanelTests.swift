import AppKit
import Testing
@testable import Notch_

@MainActor
struct ShellPanelTests {
    @Test
    func panelUsesNonActivatingOverlayConfiguration() {
        let panel = ShellPanel(frame: CGRect(x: 0, y: 0, width: 220, height: 32))

        #expect(panel.styleMask.contains(.borderless))
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.backgroundColor == .clear)
        #expect(panel.isOpaque == false)
        #expect(panel.canBecomeKey == false)
        #expect(panel.canBecomeMain == false)
        #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(panel.collectionBehavior.contains(.fullScreenAuxiliary))
    }
}
