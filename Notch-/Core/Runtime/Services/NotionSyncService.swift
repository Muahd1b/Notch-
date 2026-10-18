import AppKit
import EventKit
import Foundation

enum NotionSyncState: Sendable {
    case skipped
    case configured
    case unavailable
}

actor NotionSyncService {
    private let eventBus: NotchEventBus
    private let diagnostics: RuntimeDiagnostics?
    private let urlSession: URLSession

    init(eventBus: NotchEventBus, diagnostics: RuntimeDiagnostics?) {
        self.eventBus = eventBus
        self.diagnostics = diagnostics
        self.urlSession = URLSession(configuration: .ephemeral)
    }

    func syncIfConfigured(
        habits: [ShellHabitProgress],
        learnings: [ShellLearningSignal],
        enabled: Bool
    ) async -> NotionSyncState {
        guard enabled else { return .skipped }

        guard let token = ProcessInfo.processInfo.environment["NOTION_API_KEY"], !token.isEmpty else {
            await publishNotionSignal(state: .unavailable, habits: habits.count, learnings: learnings.count)
            return .unavailable
        }

        var request = URLRequest(url: URL(string: "https://api.notion.com/v1/users/me")!)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")

        do {
            let (_, response) = try await urlSession.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) {
                await publishNotionSignal(state: .configured, habits: habits.count, learnings: learnings.count)
                return .configured
            }
            await publishNotionSignal(state: .unavailable, habits: habits.count, learnings: learnings.count)
            return .unavailable
        } catch {
            if let diagnostics {
                await diagnostics.record(
                    level: .warning,
                    message: "Notion sync check failed.",
                    source: "notion.sync",
                    metadata: ["error": String(describing: error)]
                )
            }
            await publishNotionSignal(state: .unavailable, habits: habits.count, learnings: learnings.count)
            return .unavailable
        }
    }

    private func publishNotionSignal(state: NotionSyncState, habits: Int, learnings: Int) async {
        let stateLabel: String
        switch state {
        case .skipped:
            stateLabel = "skipped"
        case .configured:
            stateLabel = "configured"
        case .unavailable:
            stateLabel = "unavailable"
        }

        await eventBus.publish(
            NotchEvent(
                kind: .signalChanged,
                source: "notion.sync",
                payload: .attributes([
                    "state": stateLabel,
                    "habits": String(habits),
                    "learnings": String(learnings),
                ])
            )
        )
    }
}
