import AppKit
import EventKit
import Foundation

actor HabitsLearningStoreService {
    private enum LegacyMockIDs {
        static let habits: Set<String> = ["habit-1", "habit-2", "habit-3"]
        static let learnings: Set<String> = ["learn-1", "learn-2", "learn-3"]
    }

    private enum Keys {
        static let habits = "notch.store.habits"
        static let learnings = "notch.store.learnings"
        static let habitsLastDailyResetAnchor = "notch.store.habits.lastDailyResetAnchor"
    }

    private let persistenceStore: PersistenceStore
    private let eventBus: NotchEventBus
    private let diagnostics: RuntimeDiagnostics?

    private var cachedHabits: [ShellHabitProgress] = []
    private var cachedLearnings: [ShellLearningSignal] = []
    private var lastDailyResetAnchor: Date?

    init(
        persistenceStore: PersistenceStore,
        eventBus: NotchEventBus,
        diagnostics: RuntimeDiagnostics?
    ) {
        self.persistenceStore = persistenceStore
        self.eventBus = eventBus
        self.diagnostics = diagnostics
    }

    func start(dailyResetHour: Double) async {
        await loadFromPersistence()
        await applyDailyResetIfNeeded(dailyResetHour: dailyResetHour)
    }

    func refresh(dailyResetHour: Double) async {
        await loadFromPersistence()
        await applyDailyResetIfNeeded(dailyResetHour: dailyResetHour)
    }

    func habits() -> [ShellHabitProgress] {
        cachedHabits
    }

    func learnings() -> [ShellLearningSignal] {
        cachedLearnings
    }

    func toggleHabit(id: String) async {
        guard let index = cachedHabits.firstIndex(where: { $0.id == id }) else { return }
        var habit = cachedHabits[index]
        let targetUnits = max(1, habit.targetUnits)
        let isCompleted = habit.completedUnits >= targetUnits
        let nextCompletedUnits = isCompleted ? 0 : min(targetUnits, habit.completedUnits + 1)
        habit = ShellHabitProgress(
            id: habit.id,
            title: habit.title,
            completedUnits: nextCompletedUnits,
            targetUnits: targetUnits,
            streakDays: habit.streakDays
        )
        cachedHabits[index] = habit
        await persistHabits()
        await publishMutationSignal(type: "habit", id: id)
    }

    func createHabit(title: String, targetUnits: Int) async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }

        if cachedHabits.contains(where: { $0.title.localizedCaseInsensitiveCompare(trimmedTitle) == .orderedSame }) {
            return false
        }

        let habit = ShellHabitProgress(
            id: "habit-\(UUID().uuidString)",
            title: trimmedTitle,
            completedUnits: 0,
            targetUnits: max(1, targetUnits),
            streakDays: 0
        )

        cachedHabits.append(habit)
        await persistHabits()
        await publishMutationSignal(type: "habit", id: habit.id)
        return true
    }

    func reorderHabits(fromOffsets source: IndexSet, toOffset destination: Int) async -> Bool {
        guard !source.isEmpty else { return false }
        guard source.allSatisfy({ $0 >= 0 && $0 < cachedHabits.count }) else { return false }

        let movedHabits = source.map { cachedHabits[$0] }
        var remainingHabits: [ShellHabitProgress] = []
        remainingHabits.reserveCapacity(max(0, cachedHabits.count - source.count))

        for (index, habit) in cachedHabits.enumerated() where !source.contains(index) {
            remainingHabits.append(habit)
        }

        let clampedDestination = max(0, min(destination, cachedHabits.count))
        let removedBeforeDestination = source.filter { $0 < clampedDestination }.count
        let adjustedDestination = max(
            0,
            min(clampedDestination - removedBeforeDestination, remainingHabits.count)
        )

        remainingHabits.insert(contentsOf: movedHabits, at: adjustedDestination)
        guard remainingHabits != cachedHabits else { return false }

        cachedHabits = remainingHabits
        await persistHabits()
        await publishMutationSignal(type: "habit-reorder", id: movedHabits.first?.id ?? "none")
        return true
    }

    func deleteHabit(id: String) async -> Bool {
        guard let index = cachedHabits.firstIndex(where: { $0.id == id }) else { return false }
        cachedHabits.remove(at: index)
        await persistHabits()
        await publishMutationSignal(type: "habit", id: id)
        return true
    }

    func deleteLegacyMockData() async -> Bool {
        let habitsBefore = cachedHabits.count
        let learningsBefore = cachedLearnings.count

        cachedHabits.removeAll(where: { LegacyMockIDs.habits.contains($0.id) })
        cachedLearnings.removeAll(where: { LegacyMockIDs.learnings.contains($0.id) })

        let didChange = habitsBefore != cachedHabits.count || learningsBefore != cachedLearnings.count
        guard didChange else { return false }

        await persistHabits()
        await persistLearnings()
        await publishMutationSignal(type: "mock-cleanup", id: "legacy-phase-zero")
        return true
    }

    func captureLearningSignal() async {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let label = formatter.string(from: Date())

        let entry = ShellLearningSignal(
            id: "learn-\(UUID().uuidString)",
            title: "Learning capture \(label)",
            source: "Local",
            capturedAtLabel: "just now"
        )

        cachedLearnings.insert(entry, at: 0)
        if cachedLearnings.count > 30 {
            cachedLearnings = Array(cachedLearnings.prefix(30))
        }
        await persistLearnings()
        await publishMutationSignal(type: "learning", id: entry.id)
    }

    private func loadFromPersistence() async {
        do {
            cachedHabits = try await persistenceStore.load([ShellHabitProgress].self, for: Keys.habits) ?? []
            cachedLearnings = try await persistenceStore.load([ShellLearningSignal].self, for: Keys.learnings) ?? []
            lastDailyResetAnchor = await persistenceStore.date(for: Keys.habitsLastDailyResetAnchor)
        } catch {
            if let diagnostics {
                await diagnostics.record(
                    level: .error,
                    message: "Failed to load habits/learnings persistence.",
                    source: "habits.local",
                    metadata: ["error": String(describing: error)]
                )
            }
            cachedHabits = []
            cachedLearnings = []
            lastDailyResetAnchor = nil
        }
    }

    private func applyDailyResetIfNeeded(dailyResetHour: Double) async {
        let boundary = currentResetBoundary(now: Date(), dailyResetHour: dailyResetHour)

        if let lastDailyResetAnchor, lastDailyResetAnchor >= boundary {
            return
        }

        let shouldResetHabits = lastDailyResetAnchor != nil
        if shouldResetHabits {
            var didMutate = false
            for index in cachedHabits.indices {
                guard cachedHabits[index].completedUnits != 0 else { continue }
                let habit = cachedHabits[index]
                cachedHabits[index] = ShellHabitProgress(
                    id: habit.id,
                    title: habit.title,
                    completedUnits: 0,
                    targetUnits: habit.targetUnits,
                    streakDays: habit.streakDays
                )
                didMutate = true
            }

            if didMutate {
                await persistHabits()
                await publishMutationSignal(type: "habit-daily-reset", id: boundary.formatted(.iso8601))
            }
        }

        lastDailyResetAnchor = boundary
        await persistenceStore.setDate(boundary, for: Keys.habitsLastDailyResetAnchor)
    }

    private func currentResetBoundary(now: Date, dailyResetHour: Double) -> Date {
        let calendar = Calendar.current
        let clampedHour = max(0, min(23, Int(dailyResetHour.rounded())))

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = clampedHour
        components.minute = 0
        components.second = 0

        let todayBoundary = calendar.date(from: components) ?? calendar.startOfDay(for: now)
        if now >= todayBoundary {
            return todayBoundary
        }

        return calendar.date(byAdding: .day, value: -1, to: todayBoundary) ?? todayBoundary
    }

    private func persistHabits() async {
        do {
            try await persistenceStore.save(cachedHabits, for: Keys.habits)
        } catch {
            if let diagnostics {
                await diagnostics.record(
                    level: .error,
                    message: "Failed to persist habits.",
                    source: "habits.local",
                    metadata: ["error": String(describing: error)]
                )
            }
        }
    }

    private func persistLearnings() async {
        do {
            try await persistenceStore.save(cachedLearnings, for: Keys.learnings)
        } catch {
            if let diagnostics {
                await diagnostics.record(
                    level: .error,
                    message: "Failed to persist learnings.",
                    source: "learning.local",
                    metadata: ["error": String(describing: error)]
                )
            }
        }
    }

    private func publishMutationSignal(type: String, id: String) async {
        await eventBus.publish(
            NotchEvent(
                kind: .entityUpserted,
                source: "habits.local",
                payload: .attributes([
                    "type": type,
                    "id": id,
                    "habitsCount": String(cachedHabits.count),
                    "learningsCount": String(cachedLearnings.count),
                ])
            )
        )
    }
}
