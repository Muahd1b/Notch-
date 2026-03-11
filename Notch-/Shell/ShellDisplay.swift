import AppKit

struct ShellDisplay: Equatable {
    let id: String
    let geometry: ScreenGeometry
}

extension ShellDisplay {
    init(screen: NSScreen) {
        let geometry = ScreenGeometry(screen: screen)
        let origin = "\(Int(geometry.frame.origin.x))x\(Int(geometry.frame.origin.y))"
        let size = "\(Int(geometry.frame.width))x\(Int(geometry.frame.height))"

        self.init(
            id: "\(screen.localizedName)-\(origin)-\(size)",
            geometry: geometry
        )
    }
}

@MainActor
protocol ShellDisplayProviding {
    func preferredDisplay() -> ShellDisplay?
}

@MainActor
struct DefaultShellDisplayProvider: ShellDisplayProviding {
    func preferredDisplay() -> ShellDisplay? {
        let screen = NSScreen.main ?? NSScreen.screens.first
        return screen.map(ShellDisplay.init(screen:))
    }
}
