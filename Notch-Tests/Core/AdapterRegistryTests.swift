import Foundation
import Testing
@testable import Notch_

private final class TestAdapter: NotchAdapter {
    let id: String
    let kind: AdapterKind

    private var health: AdapterHealth
    private var confidence: AdapterConfidence
    private var lastSyncAt: Date?

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var refreshCallCount = 0

    init(
        id: String,
        kind: AdapterKind,
        health: AdapterHealth = .unknown,
        confidence: AdapterConfidence = .medium
    ) {
        self.id = id
        self.kind = kind
        self.health = health
        self.confidence = confidence
    }

    func snapshot() async -> AdapterSnapshot {
        AdapterSnapshot(
            id: id,
            kind: kind,
            health: health,
            confidence: confidence,
            lastSyncAt: lastSyncAt
        )
    }

    func start() async {
        startCallCount += 1
        health = .healthy
        lastSyncAt = Date()
    }

    func stop() async {
        stopCallCount += 1
        health = AdapterHealth(state: .disconnected, detail: "stopped")
    }

    func refresh() async {
        refreshCallCount += 1
        lastSyncAt = Date()
    }
}

struct AdapterRegistryTests {
    @Test
    func duplicateAdapterRegistrationThrows() async throws {
        let registry = AdapterRegistry(eventBus: NotchEventBus())
        let adapter = TestAdapter(id: "calendar.main", kind: .calendar)

        try await registry.register(adapter)

        await #expect(throws: AdapterRegistryError.duplicateAdapterID("calendar.main")) {
            try await registry.register(adapter)
        }
    }

    @Test
    func startAndRefreshAffectSnapshotsAndHealthSummary() async throws {
        let registry = AdapterRegistry(eventBus: NotchEventBus())
        let adapter = TestAdapter(id: "localhost.probe", kind: .localhost)

        try await registry.register(adapter)
        await registry.startAll()
        await registry.refreshAll()

        let snapshots = await registry.snapshots()
        let summary = await registry.healthSummary()

        #expect(snapshots.count == 1)
        #expect(snapshots[0].health.state == .healthy)
        #expect(summary.total == 1)
        #expect(summary.healthy == 1)
        #expect(adapter.startCallCount == 1)
        #expect(adapter.refreshCallCount == 1)
    }

    @Test
    func unregisterStopsAdapter() async throws {
        let registry = AdapterRegistry(eventBus: NotchEventBus())
        let adapter = TestAdapter(id: "agents.codex", kind: .agents)

        try await registry.register(adapter)
        try await registry.unregister(id: "agents.codex")

        #expect(adapter.stopCallCount == 1)
        let snapshots = await registry.snapshots()
        #expect(snapshots.isEmpty)
    }
}
