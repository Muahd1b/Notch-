import AppKit

@MainActor
final class ShellAppDelegate: NSObject, NSApplicationDelegate {
    private let shellCoordinator = ShellCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        shellCoordinator.start()
    }
}
