import SwiftUI

@main
struct NotchApp: App {
    @NSApplicationDelegateAdaptor(ShellAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
