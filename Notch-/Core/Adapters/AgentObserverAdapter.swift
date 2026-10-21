import Foundation

actor AgentObserverAdapter: NotchAdapter {
    nonisolated let id = "agents.observer"
    nonisolated let kind: AdapterKind = .agents

    private let eventBus: NotchEventBus
    private let diagnostics: RuntimeDiagnostics?
    private let encoder: JSONEncoder
    private var pollTask: Task<Void, Never>?
    private var health: AdapterHealth = .unknown
    private var lastSyncAt: Date?

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
            confidence: .medium,
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
                let interval = await self.refreshIntervalSeconds()
                try? await Task.sleep(for: .seconds(interval))
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
        let settings = await MainActor.run {
            (
                codex: AppSettingsStore.shared.codexMonitoringEnabled,
                claude: AppSettingsStore.shared.claudeMonitoringEnabled,
                openCode: AppSettingsStore.shared.openCodeMonitoringEnabled,
                ollama: AppSettingsStore.shared.ollamaMonitoringEnabled,
                showIdle: AppSettingsStore.shared.showIdleAgents
            )
        }

        let sessions = await collectSessions(settings: settings)
        NSLog("Notch- agent observer: %d session(s)", sessions.count)
        let now = Date()
        lastSyncAt = now
        health = .healthy

        await publish(sessions: sessions, updatedAt: now)
    }

    // MARK: - Collection

    private func collectSessions(settings: (codex: Bool, claude: Bool, openCode: Bool, ollama: Bool, showIdle: Bool)) async -> [ObservedAgentSession] {
        let runningProviders = Self.runningProviderProcesses()
        var sessions: [ObservedAgentSession] = []

        if settings.codex {
            sessions.append(contentsOf: AgentSessionScanner.codexSessions())
        }
        if settings.claude {
            sessions.append(contentsOf: AgentSessionScanner.claudeSessions())
        }
        if settings.openCode {
            sessions.append(contentsOf: await AgentSessionScanner.openCodeSessions())
        }
        if settings.ollama {
            sessions.append(contentsOf: await AgentSessionScanner.ollamaSessions())
        }

        sessions = sessions.map { session in
            guard let provider = runningProviders[session.provider] else { return session }
            guard session.status == .idle, provider else { return session }
            return ObservedAgentSession(
                id: session.id,
                provider: session.provider,
                title: session.title,
                workspacePath: session.workspacePath,
                status: .ongoing,
                confidence: session.confidence,
                lastActivityAt: session.lastActivityAt,
                model: session.model,
                summary: session.summary,
                tokensUsed: session.tokensUsed,
                tokenLimit: session.tokenLimit,
                planUsagePercent: session.planUsagePercent
            )
        }

        if !settings.showIdle {
            sessions.removeAll { $0.status == .idle }
        }

        return Array(sessions.sorted { $0.lastActivityAt > $1.lastActivityAt }.prefix(12))
    }

    /// One `ps` sweep per refresh keeps process detection cheap and provider-agnostic.
    private static func runningProviderProcesses() -> [ObservedAgentProvider: Bool] {
        let output = ShellCommand.run("/bin/ps", ["-Ao", "comm="]) ?? ""
        let processNames = Set(
            output.lowercased()
                .split(separator: "\n")
                .map { String($0).split(separator: "/").last.map(String.init) ?? "" }
        )

        var result: [ObservedAgentProvider: Bool] = [:]
        for provider in ObservedAgentProvider.allCases where !provider.processNames.isEmpty {
            result[provider] = provider.processNames.contains { processNames.contains($0) }
        }
        return result
    }

    // MARK: - Publishing

    private func publish(sessions: [ObservedAgentSession], updatedAt: Date) async {
        do {
            let payload = AgentObserverPayload(updatedAt: updatedAt, sessions: sessions)
            let data = try encoder.encode(payload)
            let json = String(data: data, encoding: .utf8) ?? "{}"
            await eventBus.publish(
                NotchEvent(
                    kind: .entityUpserted,
                    source: "adapter.agents.observer",
                    payload: .text(json)
                )
            )
        } catch {
            if let diagnostics {
                await diagnostics.record(
                    level: .warning,
                    message: "Failed to encode agent observer payload.",
                    source: "adapter.agents.observer",
                    metadata: ["error": String(describing: error)]
                )
            }
        }
    }

    private func refreshIntervalSeconds() async -> Double {
        await MainActor.run {
            max(3, AppSettingsStore.shared.agentRefreshInterval)
        }
    }
}
