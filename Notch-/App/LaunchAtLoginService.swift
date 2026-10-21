import Foundation
import ServiceManagement

/// Registers the app as a login item. `SMAppService` keeps its own state, so this is
/// idempotent and safe to call on every settings write.
enum LaunchAtLoginService {
    static func apply(enabled: Bool) {
        guard !isRunningTests else { return }
        guard Bundle.main.bundleIdentifier != nil else { return }

        let service = SMAppService.mainApp
        let isRegistered = service.status == .enabled
        guard enabled != isRegistered else { return }

        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            NSLog("Notch- launch-at-login update failed: \(error.localizedDescription)")
        }
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
