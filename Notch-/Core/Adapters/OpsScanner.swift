import Foundation

/// Local-only readers for the operator signals: Codex automations, orchestration ack gates,
/// and (through `gh`) repository health. Everything here is bounded and side-effect free.
enum OpsScanner {
    private static let maxScannedDirectories = 20_000

    // MARK: - Automations

    static func automations(
        rootPath: String = "\(NSHomeDirectory())/.codex/automations",
        now: Date = Date()
    ) -> [ShellAutomation] {
        let fileManager = FileManager.default
        guard let directories = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: rootPath),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let entries = directories.compactMap { directory -> ShellAutomation? in
            let specURL = directory.appendingPathComponent("automation.toml")
            guard let text = try? String(contentsOf: specURL, encoding: .utf8) else { return nil }

            let identifier = directory.lastPathComponent
            let name = parseTomlScalar("name", in: text) ?? identifier
            let status = parseTomlScalar("status", in: text) ?? "ACTIVE"
            let rrule = parseTomlScalar("rrule", in: text) ?? ""
            let isActive = status.uppercased() == "ACTIVE"

            let lastRunAt = lastRunDate(in: directory)
            let issue = automationIssue(
                isActive: isActive,
                rrule: rrule,
                lastRunAt: lastRunAt,
                now: now
            )

            return ShellAutomation(
                id: identifier,
                name: name,
                isActive: isActive,
                scheduleLabel: humanSchedule(rrule),
                lastRunAt: lastRunAt,
                issue: issue
            )
        }

        return entries.sorted { lhs, rhs in
            if (lhs.issue != nil) != (rhs.issue != nil) { return lhs.issue != nil }
            if lhs.isActive != rhs.isActive { return lhs.isActive }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func lastRunDate(in directory: URL) -> Date? {
        let candidates = ["checkpoint.json", "memory.md", "state.json"]
        for name in candidates {
            let url = directory.appendingPathComponent(name)
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { continue }
            if let modified = attributes[.modificationDate] as? Date { return modified }
        }
        return nil
    }

    private static func automationIssue(
        isActive: Bool,
        rrule: String,
        lastRunAt: Date?,
        now: Date
    ) -> ShellOpsIssue? {
        if let expired = expiredOneShot(rrule: rrule, now: now) {
            // A one-shot whose date has passed without a recent run never fired.
            if let lastRunAt, lastRunAt >= expired { return nil }
            return .expired
        }
        guard !isActive else { return nil }
        guard let lastRunAt, now.timeIntervalSince(lastRunAt) > 7 * 24 * 3600 else { return nil }
        return .stale
    }

    /// `BYMONTH`/`BYMONTHDAY` plus `COUNT=1` is a one-shot calendar date; return it when passed.
    static func expiredOneShot(rrule: String, now: Date = Date()) -> Date? {
        guard rrule.contains("COUNT=1") else { return nil }
        let fields = rruleFields(rrule)
        guard
            let month = fields["BYMONTH"].flatMap({ Int($0) }),
            let day = fields["BYMONTHDAY"].flatMap({ Int($0) })
        else { return nil }

        var components = DateComponents()
        components.year = Calendar.current.component(.year, from: now)
        components.month = month
        components.day = day
        components.hour = fields["BYHOUR"].flatMap { Int($0) } ?? 0
        components.minute = fields["BYMINUTE"].flatMap { Int($0) } ?? 0
        guard let date = Calendar.current.date(from: components), date < now else { return nil }
        return date
    }

    static func rruleFields(_ rrule: String) -> [String: String] {
        var fields: [String: String] = [:]
        for part in rrule.split(separator: ";") {
            let pieces = part.split(separator: "=", maxSplits: 1)
            guard pieces.count == 2 else { continue }
            fields[String(pieces[0])] = String(pieces[1])
        }
        return fields
    }

    static func humanSchedule(_ rrule: String) -> String {
        guard !rrule.isEmpty else { return "manual" }
        let fields = rruleFields(rrule)
        let interval = fields["INTERVAL"].flatMap { Int($0) } ?? 1

        switch fields["FREQ"] {
        case "MINUTELY":
            return interval == 1 ? "every minute" : "every \(interval) min"
        case "HOURLY":
            return interval == 1 ? "hourly" : "every \(interval) h"
        case "DAILY":
            return interval == 1 ? "daily" : "every \(interval) days"
        case "WEEKLY":
            return interval == 1 ? "weekly" : "every \(interval) weeks"
        case "MONTHLY":
            return interval == 1 ? "monthly" : "every \(interval) months"
        default:
            return rrule
        }
    }

    static func parseTomlScalar(_ key: String, in text: String) -> String? {
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\(key) ") || trimmed.hasPrefix("\(key)=") else { continue }
            guard let equals = trimmed.firstIndex(of: "=") else { continue }
            var value = trimmed[trimmed.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value.removeFirst()
                value.removeLast()
            }
            return value.isEmpty ? nil : value
        }
        return nil
    }

    // MARK: - Orchestration ack gates

    static func awaitingAcks(
        searchRoots: [String] = ["\(NSHomeDirectory())/Businesses"],
        now: Date = Date()
    ) -> [ShellNeedsYouItem] {
        let fileManager = FileManager.default

        for root in searchRoots {
            guard fileManager.fileExists(atPath: root) else { continue }
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: root, isDirectory: true),
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                options: [.skipsPackageDescendants]
            ) else { continue }

            let rootDepth = URL(fileURLWithPath: root).pathComponents.count
            var scanned = 0
            var items: [ShellNeedsYouItem] = []

            for case let url as URL in enumerator {
                scanned += 1
                if scanned > maxScannedDirectories { break }

                let depth = url.pathComponents.count - rootDepth
                if depth > 9 {
                    enumerator.skipDescendants()
                    continue
                }
                if ["node_modules", ".git", "dist", "build", ".next"].contains(url.lastPathComponent) {
                    enumerator.skipDescendants()
                    continue
                }

                guard url.lastPathComponent == "state.yaml" else { continue }
                let components = url.pathComponents
                guard components.contains(".orchestration"), components.contains("runs") else { continue }

                guard
                    let text = try? String(contentsOf: url, encoding: .utf8),
                    let phase = parseYAMLScalar("phase", in: text),
                    phase == "awaiting_ack"
                else { continue }

                let runID = parseYAMLScalar("run_id", in: text) ?? url.deletingLastPathComponent().lastPathComponent
                let risk = parseYAMLScalar("risk_level", in: text) ?? "unknown"
                let remaining = parseYAMLScalar("acks_remaining", in: text) ?? "execute"
                let issue = parseYAMLScalar("issue_id", in: text)
                let createdAt = parseYAMLScalar("created_at", in: text).flatMap(parseISODate) ?? now

                items.append(
                    ShellNeedsYouItem(
                        id: "ack-\(runID)",
                        kind: .ack,
                        title: issue ?? runID,
                        detail: "\(risk) risk · waiting for \(remaining) ack",
                        createdAt: createdAt
                    )
                )
            }

            if !items.isEmpty {
                return items.sorted { $0.createdAt > $1.createdAt }
            }
        }
        return []
    }

    static func parseYAMLScalar(_ key: String, in text: String) -> String? {
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\(key):") else { continue }
            var value = trimmed.dropFirst(key.count + 1).trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value.removeFirst()
                value.removeLast()
            }
            return value.isEmpty ? nil : value
        }
        return nil
    }

    static func parseISODate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }

    // MARK: - Repository health

    static let watchedRepos = [
        "Kernscale-Operations",
        "Kernscale-Infrastructure",
        "Kernscale-Hosting",
        "Kernscale-Agentic-Layer",
        "Kernscale-Digital-Sovereignty",
    ]

    /// One `gh` pass per repo. Cached by the adapter; never called on a UI tick.
    static func repoHealth(owner: String = "kernscale", repos: [String] = watchedRepos) -> [ShellRepoStatus] {
        repos.map { repo in
            let run = ShellCommand.run("/opt/homebrew/bin/gh", [
                "run", "list", "-R", "\(owner)/\(repo)", "--branch", "main", "--limit", "1",
                "--json", "conclusion,status,createdAt",
            ])
            let prs = ShellCommand.run("/opt/homebrew/bin/gh", [
                "pr", "list", "-R", "\(owner)/\(repo)", "--state", "open", "--json", "number", "--jq", "length",
            ])

            let state = parseRunState(run)
            return ShellRepoStatus(
                id: repo,
                ciState: state.ciState,
                ciLabel: state.label,
                openPRs: Int((prs ?? "").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            )
        }
    }

    static func parseRunState(_ json: String?) -> (ciState: String, label: String) {
        guard
            let data = json?.data(using: .utf8),
            let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
            let first = rows.first
        else { return ("unknown", "no runs") }

        let status = first["status"] as? String ?? "unknown"
        let conclusion = first["conclusion"] as? String ?? ""
        let createdAt = (first["createdAt"] as? String).flatMap(parseISODate)
        let ageLabel = createdAt.map(relativeLabel) ?? ""

        if status != "completed" {
            return ("running", ageLabel.isEmpty ? "running" : "running · \(ageLabel)")
        }
        switch conclusion {
        case "success":
            return ("success", ageLabel.isEmpty ? "green" : "green · \(ageLabel)")
        case "failure", "timed_out", "startup_failure":
            return ("failure", ageLabel.isEmpty ? "red" : "red · \(ageLabel)")
        default:
            return ("unknown", conclusion.isEmpty ? "no runs" : conclusion)
        }
    }

    private static func relativeLabel(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
