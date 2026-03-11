import Combine
import Foundation

enum PermissionDomain: String, CaseIterable, Sendable, Codable {
    case calendar
    case reminders
    case notifications
    case camera
    case microphone
    case screenRecording
    case mediaLibrary
    case automation
}

enum PermissionStatus: String, CaseIterable, Sendable, Codable {
    case ready
    case needsSetup
    case denied
    case unavailable
}

struct PermissionSnapshot: Equatable, Sendable, Codable {
    let domain: PermissionDomain
    let status: PermissionStatus
    let updatedAt: Date
}

struct PermissionSummary: Equatable, Sendable {
    let readyCount: Int
    let needsSetupCount: Int
    let deniedCount: Int
    let unavailableCount: Int
}

@MainActor
final class PermissionsManager: ObservableObject {
    @Published private(set) var statuses: [PermissionDomain: PermissionSnapshot]

    private let eventBus: NotchEventBus

    init(
        eventBus: NotchEventBus,
        initialStatuses: [PermissionDomain: PermissionStatus] = [:]
    ) {
        self.eventBus = eventBus

        var seededStatuses: [PermissionDomain: PermissionSnapshot] = [:]
        let now = Date()

        for domain in PermissionDomain.allCases {
            let status = initialStatuses[domain] ?? .needsSetup
            seededStatuses[domain] = PermissionSnapshot(domain: domain, status: status, updatedAt: now)
        }

        statuses = seededStatuses
    }

    func status(for domain: PermissionDomain) -> PermissionStatus {
        statuses[domain]?.status ?? .needsSetup
    }

    func updateStatus(_ status: PermissionStatus, for domain: PermissionDomain) {
        let snapshot = PermissionSnapshot(
            domain: domain,
            status: status,
            updatedAt: Date()
        )
        statuses[domain] = snapshot

        Task {
            await eventBus.publish(
                NotchEvent(
                    kind: .signalChanged,
                    source: "permissions.\(domain.rawValue)",
                    payload: .attributes([
                        "domain": domain.rawValue,
                        "status": status.rawValue,
                    ])
                )
            )
        }
    }

    func summary() -> PermissionSummary {
        let values = statuses.values.map(\.status)
        return PermissionSummary(
            readyCount: values.filter { $0 == .ready }.count,
            needsSetupCount: values.filter { $0 == .needsSetup }.count,
            deniedCount: values.filter { $0 == .denied }.count,
            unavailableCount: values.filter { $0 == .unavailable }.count
        )
    }
}
