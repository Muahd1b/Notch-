import Foundation

actor FocusSessionHistoryService: FocusSessionHistoryStoring {
    static let storageKey = "notch.store.focusHistory"
    static let maxRecordCount = 40

    private let persistenceStore: PersistenceStore
    private let diagnostics: RuntimeDiagnostics?

    init(persistenceStore: PersistenceStore, diagnostics: RuntimeDiagnostics? = nil) {
        self.persistenceStore = persistenceStore
        self.diagnostics = diagnostics
    }

    func loadHistory() async -> [FocusSessionRecord] {
        do {
            let stored = try await persistenceStore.load([FocusSessionRecord].self, for: Self.storageKey) ?? []
            return normalize(stored)
        } catch {
            await diagnostics?.record(
                level: .warning,
                message: "Failed to load persisted focus session history.",
                source: "focus.history",
                metadata: ["error": String(describing: error)]
            )
            return []
        }
    }

    func append(_ record: FocusSessionRecord) async {
        let existing = await loadHistory()
        var records = existing.filter { $0.id != record.id }
        records.append(record)
        await save(records)
    }

    func clearHistory() async {
        await persistenceStore.removeValue(for: Self.storageKey)
    }

    private func save(_ records: [FocusSessionRecord]) async {
        do {
            try await persistenceStore.save(normalize(records), for: Self.storageKey)
        } catch {
            await diagnostics?.record(
                level: .warning,
                message: "Failed to persist focus session history.",
                source: "focus.history",
                metadata: ["error": String(describing: error)]
            )
        }
    }

    private func normalize(_ records: [FocusSessionRecord]) -> [FocusSessionRecord] {
        var seen: Set<String> = []
        let unique = records
            .sorted(by: { $0.endedAt > $1.endedAt })
            .filter { seen.insert($0.id).inserted }
        return Array(unique.prefix(Self.maxRecordCount))
    }
}
