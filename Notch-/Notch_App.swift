import SwiftUI

@main
struct Notch_App: App {
    @NSApplicationDelegateAdaptor(ShellAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
