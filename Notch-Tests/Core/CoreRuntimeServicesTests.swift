import Foundation
import Testing
@testable import Notch_

@MainActor
struct CoreRuntimeServicesTests {
    @Test
    func startPublishesRuntimeDiagnosticEvent() async {
        let suiteName = "CoreRuntimeServicesTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let runtime = CoreRuntimeServices(defaults: defaults)
        await runtime.start()

        let events = await runtime.eventBus.recentEvents(limit: 10)
        #expect(events.contains(where: { $0.source == "diagnostics" }))

        await runtime.stop()
    }

    @Test
    func toggleHabitCompletionIncrementsProgressThenResets() async {
        let suiteName = "CoreRuntimeServicesHabitsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let runtime = CoreRuntimeServices(defaults: defaults, externalIntegrationsEnabled: true)
        let recorder = SnapshotRecorder()
        runtime.bindShellSnapshotConsumer { snapshot in
            recorder.record(snapshot)
        }

        await runtime.start()
        await runtime.refreshHabitsLearning()

        let initial = recorder.latest.habits.first(where: { $0.id == "habit-1" })
        #expect(initial?.completedUnits == 2)
        #expect(initial?.targetUnits == 3)

        await runtime.toggleHabitCompletion(id: "habit-1")
        let afterFirstToggle = recorder.latest.habits.first(where: { $0.id == "habit-1" })
        #expect(afterFirstToggle?.completedUnits == 3)

        await runtime.toggleHabitCompletion(id: "habit-1")
        let afterSecondToggle = recorder.latest.habits.first(where: { $0.id == "habit-1" })
        #expect(afterSecondToggle?.completedUnits == 0)

        await runtime.stop()
    }
}

@MainActor
private final class SnapshotRecorder {
    private(set) var latest: ShellStatusSnapshot = .phaseZero

    func record(_ snapshot: ShellStatusSnapshot) {
        latest = snapshot
    }
}
