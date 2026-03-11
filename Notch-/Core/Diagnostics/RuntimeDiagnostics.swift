import Foundation

enum RuntimeDiagnosticLevel: String, Sendable, Codable {
    case info
    case warning
    case error
}

struct RuntimeDiagnosticEntry: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let level: RuntimeDiagnosticLevel
    let message: String
    let source: String
    let timestamp: Date
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        level: RuntimeDiagnosticLevel,
        message: String,
        source: String,
        timestamp: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.level = level
        self.message = message
        self.source = source
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

actor RuntimeDiagnostics {
    private let maxEntries: Int
    private let eventBus: NotchEventBus?
    private var entries: [RuntimeDiagnosticEntry] = []

    init(maxEntries: Int = 300, eventBus: NotchEventBus? = nil) {
        self.maxEntries = max(1, maxEntries)
        self.eventBus = eventBus
    }

    func record(
        level: RuntimeDiagnosticLevel,
        message: String,
        source: String,
        metadata: [String: String] = [:]
    ) async {
        let entry = RuntimeDiagnosticEntry(
            level: level,
            message: message,
            source: source,
            metadata: metadata
        )

        entries.append(entry)
        trimIfNeeded()

        if let eventBus {
            await eventBus.publish(
                NotchEvent(
                    kind: .transientEventRaised,
                    source: "diagnostics",
                    payload: .attributes([
                        "level": level.rawValue,
                        "source": source,
                        "message": message,
                    ])
                )
            )
        }
    }

    func allEntries() -> [RuntimeDiagnosticEntry] {
        entries
    }

    func recentEntries(limit: Int = 50) -> [RuntimeDiagnosticEntry] {
        let boundedLimit = max(0, limit)
        guard boundedLimit < entries.count else { return entries }
        return Array(entries.suffix(boundedLimit))
    }

    func clear() {
        entries.removeAll(keepingCapacity: false)
    }

    private func trimIfNeeded() {
        let overflow = entries.count - maxEntries
        guard overflow > 0 else { return }
        entries.removeFirst(overflow)
    }
}
