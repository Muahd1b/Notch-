import Foundation
import UserNotifications

@MainActor
final class FocusNotificationService {
    static let shared = FocusNotificationService()

    private let center = UNUserNotificationCenter.current()

    func postBoundaryNotification(title: String, body: String, enabled: Bool) {
        guard enabled else { return }

        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.enqueueNotification(title: title, body: body)
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted {
                        self.enqueueNotification(title: title, body: body)
                    }
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    private func enqueueNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "focus-boundary-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}
