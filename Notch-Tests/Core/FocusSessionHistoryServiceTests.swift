import Foundation
import Testing
@testable import Notch_

struct FocusSessionHistoryServiceTests {
    @Test
    func appendedSessionsRoundTripNewestFirst() async {
        let suiteName = "FocusSessionHistoryTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let persistenceStore = PersistenceStore(defaults: defaults)
        let service = FocusSessionHistoryService(persistenceStore: persistenceStore)

        await service.append(makeRecord(id: "older", minutesAgo: 30))
        await service.append(makeRecord(id: "newer", minutesAgo: 5))

        let reloadedService = FocusSessionHistoryService(persistenceStore: persistenceStore)
        let history = await reloadedService.loadHistory()

        #expect(history.map(\.id) == ["newer", "older"])
    }

    @Test
    func duplicateIdentifiersKeepTheNewestRecord() async {
        let suiteName = "FocusSessionHistoryDedupeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let persistenceStore = PersistenceStore(defaults: defaults)
        let service = FocusSessionHistoryService(persistenceStore: persistenceStore)

        await service.append(makeRecord(id: "session-1", minutesAgo: 20))
        await service.append(makeRecord(id: "session-1", minutesAgo: 2))

        let history = await service.loadHistory()
        #expect(history.count == 1)
        #expect(history.first?.id == "session-1")
        if let endedAt = history.first?.endedAt {
            #expect(endedAt > Date().addingTimeInterval(-5 * 60))
        } else {
            Issue.record("Expected the newest duplicate record to survive")
        }
    }

    @Test
    func historyIsTrimmedToMaximumRecordCount() async {
        let suiteName = "FocusSessionHistoryTrimTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let persistenceStore = PersistenceStore(defaults: defaults)
        let service = FocusSessionHistoryService(persistenceStore: persistenceStore)

        for index in 0..<(FocusSessionHistoryService.maxRecordCount + 5) {
            await service.append(makeRecord(id: "focus-\(index)", minutesAgo: index))
        }

        let history = await service.loadHistory()
        #expect(history.count == FocusSessionHistoryService.maxRecordCount)
        #expect(history.first?.id == "focus-0")
        #expect(history.last?.id == "focus-\(FocusSessionHistoryService.maxRecordCount - 1)")
    }

    @Test
    func clearHistoryRemovesPersistedSessions() async {
        let suiteName = "FocusSessionHistoryClearTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let persistenceStore = PersistenceStore(defaults: defaults)
        let service = FocusSessionHistoryService(persistenceStore: persistenceStore)

        await service.append(makeRecord(id: "session-1", minutesAgo: 1))
        await service.clearHistory()

        let history = await service.loadHistory()
        #expect(history.isEmpty)
    }

    private func makeRecord(id: String, minutesAgo: Int) -> FocusSessionRecord {
        FocusSessionRecord(
            id: id,
            phase: .focus,
            durationSeconds: 25 * 60,
            note: "",
            endedAt: Date().addingTimeInterval(-Double(minutesAgo) * 60)
        )
    }
}
