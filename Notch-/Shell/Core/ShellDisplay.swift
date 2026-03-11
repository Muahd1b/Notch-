import AppKit

struct ShellDisplay: Equatable {
    let id: String
    let cgDisplayID: CGDirectDisplayID
    let geometry: ScreenGeometry
}

extension ShellDisplay {
    init(screen: NSScreen) {
        let geometry = ScreenGeometry(screen: screen)
        let origin = "\(Int(geometry.frame.origin.x))x\(Int(geometry.frame.origin.y))"
        let size = "\(Int(geometry.frame.width))x\(Int(geometry.frame.height))"
        let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        let cgDisplayID = CGDirectDisplayID(screenNumber?.uint32Value ?? 0)

        self.init(
            id: "\(screen.localizedName)-\(origin)-\(size)",
            cgDisplayID: cgDisplayID,
            geometry: geometry
        )
    }
}

@MainActor
protocol ShellDisplayProviding {
    func preferredDisplay() -> ShellDisplay?
    func targetDisplays() -> [ShellDisplay]
}

extension ShellDisplayProviding {
    func targetDisplays() -> [ShellDisplay] {
        guard let display = preferredDisplay() else {
            return []
        }
        return [display]
    }
}

@MainActor
struct DefaultShellDisplayProvider: ShellDisplayProviding {
    private let settingsStore: AppSettingsStore

    init(settingsStore: AppSettingsStore) {
        self.settingsStore = settingsStore
    }

    func preferredDisplay() -> ShellDisplay? {
        let displays = NSScreen.screens.map(ShellDisplay.init(screen:))
        return preferredDisplay(from: displays)
    }

    func targetDisplays() -> [ShellDisplay] {
        let displays = NSScreen.screens.map(ShellDisplay.init(screen:))
        if settingsStore.showOnAllDisplays {
            return displays
        }

        guard let display = preferredDisplay(from: displays) else {
            return []
        }

        return [display]
    }

    private func preferredDisplay(from displays: [ShellDisplay]) -> ShellDisplay? {
        let isUITestMode = ProcessInfo.processInfo.arguments.contains("-uitest-mode")

        if isUITestMode,
           let notchedDisplay = displays.first(where: { $0.geometry.safeAreaInsets.top > 0 }) {
            return notchedDisplay
        }

        if let preferredDisplayID = settingsStore.preferredDisplayID,
           let preferredDisplay = displays.first(where: { $0.id == preferredDisplayID }) {
            return preferredDisplay
        }

        if settingsStore.automaticallySwitchDisplay,
           let mainScreen = NSScreen.main.map(ShellDisplay.init(screen:)),
           let currentMainDisplay = displays.first(where: { $0.id == mainScreen.id }) {
            return currentMainDisplay
        }

        if let notchedDisplay = displays.first(where: { display in
            display.geometry.safeAreaInsets.top > 0
        }) {
            return notchedDisplay
        }

        return displays.first
    }
}
