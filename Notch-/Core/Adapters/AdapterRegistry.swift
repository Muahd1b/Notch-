import Foundation

enum AdapterKind: String, CaseIterable, Sendable, Codable {
    case home
    case notifications
    case calendar
    case media
    case habits
    case agents
    case hud
    case localhost
    case openclaw
    case financial
    case learning
    case focus
}

enum AdapterConfidence: String, CaseIterable, Sendable, Codable {
    case high
    case medium
    case low
}

enum AdapterHealthState: String, CaseIterable, Sendable, Codable {
    case unknown
    case healthy
    case degraded
    case disconnected
    case unauthorized
    case unsupported
    case failed
}

struct AdapterHealth: Equatable, Sendable, Codable {
    let state: AdapterHealthState
    let detail: String?

    init(state: AdapterHealthState, detail: String? = nil) {
        self.state = state
        self.detail = detail
    }

    static let unknown = AdapterHealth(state: .unknown)
    static let healthy = AdapterHealth(state: .healthy)
}

struct AdapterSnapshot: Identifiable, Equatable, Sendable, Codable {
    let id: String
    let kind: AdapterKind
    let health: AdapterHealth
    let confidence: AdapterConfidence
    let lastSyncAt: Date?
}

protocol NotchAdapter: AnyObject {
    var id: String { get }
    var kind: AdapterKind { get }

    func snapshot() async -> AdapterSnapshot
    func start() async
    func stop() async
    func refresh() async
}

enum AdapterRegistryError: Error, Equatable {
    case duplicateAdapterID(String)
    case adapterNotFound(String)
}

struct AdapterHealthSummary: Equatable, Sendable {
    let total: Int
    let healthy: Int
    let degraded: Int
    let disconnected: Int
    let unauthorized: Int
    let failed: Int
    let unknown: Int
}

actor AdapterRegistry {
    private var adapters: [String: any NotchAdapter] = [:]
    private let eventBus: NotchEventBus
    private let diagnostics: RuntimeDiagnostics?

    init(eventBus: NotchEventBus, diagnostics: RuntimeDiagnostics? = nil) {
        self.eventBus = eventBus
        self.diagnostics = diagnostics
    }

    func register(_ adapter: any NotchAdapter) async throws {
        guard adapters[adapter.id] == nil else {
            throw AdapterRegistryError.duplicateAdapterID(adapter.id)
        }

        adapters[adapter.id] = adapter
        let snapshot = await adapter.snapshot()
        await publishHealth(for: snapshot)
    }

    func unregister(id: String) async throws {
        guard let adapter = adapters.removeValue(forKey: id) else {
            throw AdapterRegistryError.adapterNotFound(id)
        }

        await adapter.stop()
        await eventBus.publish(
            NotchEvent(
                kind: .entityRemoved,
                source: "adapter.registry",
                payload: .attributes([
                    "adapterID": id,
                    "kind": adapter.kind.rawValue,
                ])
            )
        )
    }

    func startAll() async {
        for adapter in adapters.values {
            await adapter.start()
            let snapshot = await adapter.snapshot()
            await publishHealth(for: snapshot)
        }
    }

    func stopAll() async {
        for adapter in adapters.values {
            await adapter.stop()
            let snapshot = await adapter.snapshot()
            await publishHealth(for: snapshot)
        }
    }

    func refreshAll() async {
        for adapter in adapters.values {
            await adapter.refresh()
            let snapshot = await adapter.snapshot()
            await publishHealth(for: snapshot)
        }
    }

    func refresh(id: String) async throws {
        guard let adapter = adapters[id] else {
            throw AdapterRegistryError.adapterNotFound(id)
        }

        await adapter.refresh()
        let snapshot = await adapter.snapshot()
        await publishHealth(for: snapshot)
    }

    func snapshots() async -> [AdapterSnapshot] {
        var collected: [AdapterSnapshot] = []
        for adapter in adapters.values {
            collected.append(await adapter.snapshot())
        }
        return collected.sorted { $0.id < $1.id }
    }

    func healthSummary() async -> AdapterHealthSummary {
        let states = await snapshots().map(\.health.state)
        return AdapterHealthSummary(
            total: states.count,
            healthy: states.filter { $0 == .healthy }.count,
            degraded: states.filter { $0 == .degraded }.count,
            disconnected: states.filter { $0 == .disconnected }.count,
            unauthorized: states.filter { $0 == .unauthorized }.count,
            failed: states.filter { $0 == .failed }.count,
            unknown: states.filter { $0 == .unknown || $0 == .unsupported }.count
        )
    }

    private func publishHealth(for snapshot: AdapterSnapshot) async {
        await eventBus.publish(
            NotchEvent(
                kind: .adapterHealthChanged,
                source: "adapter.\(snapshot.id)",
                payload: .attributes([
                    "adapterID": snapshot.id,
                    "kind": snapshot.kind.rawValue,
                    "health": snapshot.health.state.rawValue,
                    "confidence": snapshot.confidence.rawValue,
                    "detail": snapshot.health.detail ?? "",
                ])
            )
        )

        if let diagnostics {
            let level: RuntimeDiagnosticLevel = snapshot.health.state == .healthy ? .info : .warning
            await diagnostics.record(
                level: level,
                message: "Adapter \(snapshot.id) health is \(snapshot.health.state.rawValue).",
                source: "adapter.registry",
                metadata: [
                    "adapterID": snapshot.id,
                    "kind": snapshot.kind.rawValue,
                    "confidence": snapshot.confidence.rawValue,
                ]
            )
        }
    }
}
