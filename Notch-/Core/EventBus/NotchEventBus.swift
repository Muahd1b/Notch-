import Foundation

enum NotchEventKind: String, Sendable, Codable {
    case entityUpserted
    case entityRemoved
    case signalChanged
    case adapterHealthChanged
    case transientEventRaised
}

enum NotchEventPayload: Sendable, Equatable, Codable {
    case none
    case text(String)
    case attributes([String: String])
}

struct NotchEvent: Sendable, Equatable, Codable {
    let id: UUID
    let kind: NotchEventKind
    let source: String
    let timestamp: Date
    let payload: NotchEventPayload

    init(
        id: UUID = UUID(),
        kind: NotchEventKind,
        source: String,
        timestamp: Date = Date(),
        payload: NotchEventPayload = .none
    ) {
        self.id = id
        self.kind = kind
        self.source = source
        self.timestamp = timestamp
        self.payload = payload
    }
}

actor NotchEventBus {
    struct Subscription {
        let id: UUID
        let stream: AsyncStream<NotchEvent>
    }

    private let maxBufferedEvents: Int
    private var continuations: [UUID: AsyncStream<NotchEvent>.Continuation] = [:]
    private var bufferedEvents: [NotchEvent] = []

    init(maxBufferedEvents: Int = 200) {
        self.maxBufferedEvents = max(1, maxBufferedEvents)
    }

    func publish(_ event: NotchEvent) {
        bufferedEvents.append(event)
        trimBufferIfNeeded()

        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    func subscribe() -> Subscription {
        let id = UUID()
        let stream = AsyncStream<NotchEvent>(bufferingPolicy: .bufferingNewest(maxBufferedEvents)) { continuation in
            continuations[id] = continuation
            continuation.onTermination = { @Sendable [id] _ in
                Task {
                    await self.unsubscribe(id: id)
                }
            }
        }

        return Subscription(id: id, stream: stream)
    }

    func unsubscribe(id: UUID) {
        guard let continuation = continuations.removeValue(forKey: id) else { return }
        continuation.finish()
    }

    func recentEvents(limit: Int = 50) -> [NotchEvent] {
        let boundedLimit = max(0, limit)
        guard boundedLimit < bufferedEvents.count else { return bufferedEvents }
        return Array(bufferedEvents.suffix(boundedLimit))
    }

    func clearBuffer() {
        bufferedEvents.removeAll(keepingCapacity: false)
    }

    private func trimBufferIfNeeded() {
        let overflow = bufferedEvents.count - maxBufferedEvents
        guard overflow > 0 else { return }
        bufferedEvents.removeFirst(overflow)
    }
}
