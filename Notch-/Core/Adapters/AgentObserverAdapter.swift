import Foundation

enum ObservedAgentProvider: String, Codable, Sendable {
    case codex
    case claudeCode
}

enum ObservedAgentStatus: String, Codable, Sendable {
    case ongoing
    case idle
}

struct ObservedAgentSession: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let provider: ObservedAgentProvider
    let title: String
    let workspacePath: String
    let status: ObservedAgentStatus
    let confidence: AdapterConfidence
    let lastActivityAt: Date
}

struct AgentObserverPayload: Equatable, Codable, Sendable {
    let updatedAt: Date
    let sessions: [ObservedAgentSession]
}

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
        let codexEnabled = await MainActor.run { AppSettingsStore.shared.codexMonitoringEnabled }
        let claudeEnabled = await MainActor.run { AppSettingsStore.shared.claudeMonitoringEnabled }
        let sessions = collectSessions(codexEnabled: codexEnabled, claudeEnabled: claudeEnabled)
        let now = Date()
        lastSyncAt = now
        health = .healthy

        do {
            let payload = AgentObserverPayload(updatedAt: now, sessions: sessions)
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

    private func collectSessions(codexEnabled: Bool, claudeEnabled: Bool) -> [ObservedAgentSession] {
        var sessions: [ObservedAgentSession] = []

        if codexEnabled {
            sessions.append(
                contentsOf: scanProvider(
                    provider: .codex,
                    rootPaths: ["\(NSHomeDirectory())/.codex/sessions"],
                    allowedExtensions: ["jsonl"]
                )
            )
        }

        if claudeEnabled {
            sessions.append(
                contentsOf: scanProvider(
                    provider: .claudeCode,
                    rootPaths: [
                        "\(NSHomeDirectory())/.claude/projects",
                        "\(NSHomeDirectory())/.claude/sessions",
                    ],
                    allowedExtensions: ["jsonl", "json"]
                )
            )
        }

        return Array(
            sessions
                .sorted(by: { $0.lastActivityAt > $1.lastActivityAt })
                .prefix(12)
        )
    }

    private func scanProvider(
        provider: ObservedAgentProvider,
        rootPaths: [String],
        allowedExtensions: Set<String>
    ) -> [ObservedAgentSession] {
        struct Candidate {
            let fileURL: URL
            let modifiedAt: Date
        }

        let fileManager = FileManager.default
        var candidates: [Candidate] = []
        candidates.reserveCapacity(16)

        for rootPath in rootPaths {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: rootPath, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }

            let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
            guard let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            var scannedFileCount = 0
            for case let fileURL as URL in enumerator {
                scannedFileCount += 1
                if scannedFileCount > 5000 {
                    break
                }

                guard
                    let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                    values.isRegularFile == true
                else {
                    continue
                }

                let ext = fileURL.pathExtension.lowercased()
                guard allowedExtensions.contains(ext) else { continue }
                guard let modifiedAt = values.contentModificationDate else { continue }

                candidates.append(Candidate(fileURL: fileURL, modifiedAt: modifiedAt))
            }
        }

        let sorted = candidates.sorted(by: { $0.modifiedAt > $1.modifiedAt })
        let recent = Array(sorted.prefix(6))
        let now = Date()

        return recent.map { candidate in
            let status: ObservedAgentStatus =
                candidate.modifiedAt > now.addingTimeInterval(-10 * 60) ? .ongoing : .idle

            return ObservedAgentSession(
                id: "\(provider.rawValue)-\(candidate.fileURL.path)",
                provider: provider,
                title: candidate.fileURL.deletingPathExtension().lastPathComponent,
                workspacePath: candidate.fileURL.deletingLastPathComponent().path,
                status: status,
                confidence: .medium,
                lastActivityAt: candidate.modifiedAt
            )
        }
    }
}
