import Foundation
import Testing
@testable import Notch_

@MainActor
struct CoreRuntimeServicesTests {
    @Test
    func startRegistersAgentsObserverAdapter() async {
        let suiteName = "CoreRuntimeServicesAdapterTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettingsStore.shared
        let previousCodex = settings.codexMonitoringEnabled
        let previousClaude = settings.claudeMonitoringEnabled
        settings.codexMonitoringEnabled = false
        settings.claudeMonitoringEnabled = false
        defer {
            settings.codexMonitoringEnabled = previousCodex
            settings.claudeMonitoringEnabled = previousClaude
        }

        let runtime = CoreRuntimeServices(defaults: defaults, externalIntegrationsEnabled: false)
        await runtime.start()

        let snapshots = await runtime.adapterRegistry.snapshots()
        #expect(snapshots.contains(where: { $0.id == "agents.observer" && $0.kind == .agents }))

        await runtime.stop()
    }

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
        defaults.removeObject(forKey: "notch.store.habits")
        defaults.removeObject(forKey: "notch.store.learnings")

        let runtime = CoreRuntimeServices(defaults: defaults, externalIntegrationsEnabled: true)
        let recorder = SnapshotRecorder()
        runtime.bindShellSnapshotConsumer { snapshot in
            recorder.record(snapshot)
        }

        await runtime.start()
        let created = await runtime.createHabit(title: "Toggle Habit", targetUnits: 2)
        #expect(created)
        let habitID = (await runtime.habitsForSettings()).first(where: { $0.title == "Toggle Habit" })?.id
        #expect(habitID != nil)

        if let habitID {
            await runtime.toggleHabitCompletion(id: habitID)
            let afterFirstToggle = (await runtime.habitsForSettings()).first(where: { $0.id == habitID })
            #expect(afterFirstToggle?.completedUnits == 1)

            await runtime.toggleHabitCompletion(id: habitID)
            let afterSecondToggle = (await runtime.habitsForSettings()).first(where: { $0.id == habitID })
            #expect(afterSecondToggle?.completedUnits == 2)

            await runtime.toggleHabitCompletion(id: habitID)
            let afterThirdToggle = (await runtime.habitsForSettings()).first(where: { $0.id == habitID })
            #expect(afterThirdToggle?.completedUnits == 0)
        }

        await runtime.stop()
    }

    @Test
    func reorderHabitsPersistsOrderAndPublishesToShellSnapshot() async {
        let suiteName = "CoreRuntimeServicesHabitsReorderTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.removeObject(forKey: "notch.store.habits")
        defaults.removeObject(forKey: "notch.store.learnings")

        let settings = AppSettingsStore.shared
        let previousHabitsEnabled = settings.habitsEnabled
        settings.habitsEnabled = true
        defer { settings.habitsEnabled = previousHabitsEnabled }

        let runtime = CoreRuntimeServices(defaults: defaults, externalIntegrationsEnabled: true)
        let recorder = SnapshotRecorder()
        runtime.bindShellSnapshotConsumer { snapshot in
            recorder.record(snapshot)
        }

        await runtime.start()
        #expect(await runtime.createHabit(title: "Journal", targetUnits: 1))
        #expect(await runtime.createHabit(title: "Language", targetUnits: 1))
        #expect(await runtime.createHabit(title: "Sport", targetUnits: 1))

        let initialOrder = (await runtime.habitsForSettings()).map(\.title)
        #expect(initialOrder == ["Journal", "Language", "Sport"])

        let reordered = await runtime.reorderHabits(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(reordered)

        let reorderedSettingsOrder = (await runtime.habitsForSettings()).map(\.title)
        #expect(reorderedSettingsOrder == ["Language", "Sport", "Journal"])
        #expect(recorder.latest.habits.map(\.title) == ["Language", "Sport", "Journal"])

        await runtime.stop()

        let reloadedRuntime = CoreRuntimeServices(defaults: defaults, externalIntegrationsEnabled: true)
        await reloadedRuntime.start()
        let persistedOrder = (await reloadedRuntime.habitsForSettings()).map(\.title)
        #expect(persistedOrder == ["Language", "Sport", "Journal"])
        await reloadedRuntime.stop()
    }
}

@MainActor
private final class SnapshotRecorder {
    private(set) var latest: ShellStatusSnapshot = .phaseZero

    func record(_ snapshot: ShellStatusSnapshot) {
        latest = snapshot
    }
}
