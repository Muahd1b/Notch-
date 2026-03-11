import AppKit

final class ShellPanel: NSPanel {
    var onTrackedHoverChanged: ((Bool) -> Void)?
    var currentTrackingRect: CGRect { trackedRect }

    private var trackingArea: NSTrackingArea?
    private var trackedRect: CGRect = .zero
    private var isTrackingHoverActive = false

    init(frame: CGRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        level = .statusBar
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func configureTracking(rect: CGRect) {
        trackedRect = rect

        guard let contentView else { return }

        if let trackingArea {
            contentView.removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: rect,
            options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(trackingArea)
        self.trackingArea = trackingArea

        syncTrackingState()
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        setTrackingHoverActive(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        setTrackingHoverActive(false)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        syncTrackingState()
    }

    private func syncTrackingState() {
        guard let contentView else { return }

        let screenPoint = NSEvent.mouseLocation
        let windowPoint = convertPoint(fromScreen: screenPoint)
        let viewPoint = contentView.convert(windowPoint, from: nil)
        setTrackingHoverActive(trackedRect.contains(viewPoint))
    }

    private func setTrackingHoverActive(_ isActive: Bool) {
        guard isTrackingHoverActive != isActive else { return }
        isTrackingHoverActive = isActive
        onTrackedHoverChanged?(isActive)
    }
}
