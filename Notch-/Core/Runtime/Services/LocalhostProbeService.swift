import AppKit
import EventKit
import Foundation

private struct LocalhostProbeDefinition: Sendable {
    let id: String
    let name: String
    let endpoint: String
    let processHint: String
}

actor LocalhostProbeService {
    private let eventBus: NotchEventBus
    private let diagnostics: RuntimeDiagnostics?
    private let definitions: [LocalhostProbeDefinition]
    private let urlSession: URLSession

    init(eventBus: NotchEventBus, diagnostics: RuntimeDiagnostics?) {
        self.eventBus = eventBus
        self.diagnostics = diagnostics
        self.urlSession = URLSession(configuration: .ephemeral)
        self.definitions = [
            LocalhostProbeDefinition(id: "svc-1", name: "notch-api", endpoint: "http://localhost:8080", processHint: "8080"),
            LocalhostProbeDefinition(id: "svc-2", name: "notch-web", endpoint: "http://localhost:3000", processHint: "3000"),
            LocalhostProbeDefinition(id: "svc-3", name: "worker-jobs", endpoint: "http://localhost:9091", processHint: "worker"),
        ]
    }

    func refresh(showHealthyServices: Bool) async -> [ShellLocalhostService] {
        var services: [ShellLocalhostService] = []
        services.reserveCapacity(definitions.count)

        for definition in definitions {
            let service = await probeService(definition)
            services.append(service)
        }

        if !showHealthyServices {
            let unhealthy = services.filter { $0.status != .healthy }
            if !unhealthy.isEmpty {
                services = unhealthy
            }
        }

        await eventBus.publish(
            NotchEvent(
                kind: .entityUpserted,
                source: "localhost.probe",
                payload: .attributes([
                    "count": String(services.count),
                    "healthy": String(services.filter { $0.status == .healthy }.count),
                ])
            )
        )

        if let diagnostics {
            let downServices = services.filter { $0.status == .down }.map(\.name)
            if !downServices.isEmpty {
                await diagnostics.record(
                    level: .warning,
                    message: "One or more localhost services are down.",
                    source: "localhost.probe",
                    metadata: ["downServices": downServices.joined(separator: ",")]
                )
            }
        }

        return services
    }

    private func probeService(_ definition: LocalhostProbeDefinition) async -> ShellLocalhostService {
        let status = await requestStatus(for: definition.endpoint)
        let resources = sampleProcessResources(for: definition.processHint)

        return ShellLocalhostService(
            id: definition.id,
            name: definition.name,
            endpoint: definition.endpoint,
            status: status,
            ramUsageMB: resources.ramMB,
            cpuPercent: resources.cpuPercent
        )
    }

    private func requestStatus(for endpoint: String) async -> ShellLocalhostServiceStatus {
        guard let url = URL(string: endpoint) else { return .down }

        var request = URLRequest(url: url)
        request.timeoutInterval = 1.2
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (_, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return .healthy }
            switch httpResponse.statusCode {
            case 200..<400:
                return .healthy
            case 400..<500:
                return .degraded
            default:
                return .down
            }
        } catch {
            return .down
        }
    }

    private func sampleProcessResources(for hint: String) -> (ramMB: Int, cpuPercent: Int) {
        let pids = processIDs(matching: hint)
        guard !pids.isEmpty else { return (0, 0) }

        var ramTotalKB = 0
        var cpuTotal = 0.0

        for pid in pids {
            let rss = readSingleMetric(command: "/bin/ps", arguments: ["-o", "rss=", "-p", String(pid)])
            let cpu = readSingleMetric(command: "/bin/ps", arguments: ["-o", "%cpu=", "-p", String(pid)])
            ramTotalKB += Int(rss) ?? 0
            cpuTotal += Double(cpu) ?? 0
        }

        return (max(0, ramTotalKB / 1024), max(0, Int(cpuTotal.rounded())))
    }

    private func processIDs(matching hint: String) -> [Int] {
        guard let output = runCommand(command: "/usr/bin/pgrep", arguments: ["-f", hint]) else { return [] }
        return output
            .split(separator: "\n")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private func readSingleMetric(command: String, arguments: [String]) -> String {
        runCommand(command: command, arguments: arguments)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
    }

    private func runCommand(command: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
