import CoreGraphics
import Foundation

/// Publishes the operator snapshot: scheduled automations, ack gates, and repo health.
/// Local reads run on every tick; `gh` runs at most once every ten minutes.
actor OpsAdapter: NotchAdapter {
    nonisolated let id = "ops.observer"
    nonisolated let kind: AdapterKind = .agents

    private let eventBus: NotchEventBus
    private let diagnostics: RuntimeDiagnostics?
    private let encoder: JSONEncoder
    private var pollTask: Task<Void, Never>?
    private var health: AdapterHealth = .unknown
    private var lastSyncAt: Date?
    private var cachedRepos: [ShellRepoStatus] = []
    private var reposFetchedAt: Date?

    private static let repoRefreshInterval: TimeInterval = 10 * 60

    init(eventBus: NotchEventBus, diagnostics: RuntimeDiagnostics? = nil) {
        self.eventBus = eventBus
        self.diagnostics = diagnostics
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func snapshot() async -> AdapterSnapshot {
        AdapterSnapshot(
            id: id,
            kind: kind,
            health: health,
            confidence: .high,
            lastSyncAt: lastSyncAt
        )
    }

    func start() async {
        guard pollTask == nil else { return }

        health = .healthy
        await refresh()

        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(90))
                guard !Task.isCancelled else { return }
                await self.refresh()
            }
        }
    }

    func stop() async {
        pollTask?.cancel()
        pollTask = nil
        health = AdapterHealth(state: .disconnected, detail: "stopped")
    }

    func refresh() async {
        // Repo polling is the most expensive tick; do not run it with the lid closed.
        guard CGDisplayIsAsleep(CGMainDisplayID()) == 0 else { return }
        let payload = await collect()
        lastSyncAt = payload.updatedAt
        health = .healthy
        await publish(payload)
    }

    private func collect() async -> OpsObserverPayload {
        let now = Date()
        let automations = OpsScanner.automations(now: now)
        let acks = OpsScanner.awaitingAcks(now: now)
        let repos = await repositoryHealth(now: now)

        return OpsObserverPayload(
            updatedAt: now,
            automations: automations,
            needsYou: acks,
            repos: repos
        )
    }

    private func repositoryHealth(now: Date) async -> [ShellRepoStatus] {
        if let reposFetchedAt, now.timeIntervalSince(reposFetchedAt) < Self.repoRefreshInterval {
            return cachedRepos
        }
        let repos = OpsScanner.repoHealth()
        cachedRepos = repos
        reposFetchedAt = now
        return repos
    }

    private func publish(_ payload: OpsObserverPayload) async {
        // The first tick runs before the registry's adapters are serving; failures are silent by design.
        guard !payload.automations.isEmpty || !payload.repos.isEmpty else { return }

        do {
            let data = try encoder.encode(payload)
            let json = String(data: data, encoding: .utf8) ?? "{}"
            await eventBus.publish(
                NotchEvent(
                    kind: .entityUpserted,
                    source: "adapter.ops.observer",
                    payload: .text(json)
                )
            )
        } catch {
            if let diagnostics {
                await diagnostics.record(
                    level: .warning,
                    message: "Failed to encode ops payload.",
                    source: "adapter.ops.observer",
                    metadata: ["error": String(describing: error)]
                )
            }
        }
    }
}
