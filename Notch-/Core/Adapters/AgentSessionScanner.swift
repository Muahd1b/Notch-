import Foundation

/// Reads local agent session stores and normalizes them into `ObservedAgentSession` values.
///
/// All scanning is bounded: only the newest files per provider are opened and only the head and
/// tail slices are decoded, so a 300 MB rollout log costs the same as a small one.
enum AgentSessionScanner {
    private static let tailBytes = 96 * 1024
    private static let headBytes = 8 * 1024
    private static let maxEnumeratedFiles = 4_000
    private static let maxFilesPerProvider = 6

    // MARK: - Codex

    static func codexSessions(
        rootPath: String = "\(NSHomeDirectory())/.codex/sessions",
        limit: Int = 6
    ) -> [ObservedAgentSession] {
        let files = recentFiles(
            roots: [rootPath],
            extensions: ["jsonl"],
            limit: min(limit, maxFilesPerProvider) * 3
        )
        let threadNames = codexThreadNames(sessionsRoot: rootPath)

        return files.compactMap { file -> ObservedAgentSession? in
            var cwd: String?
            var threadID: String?
            if let firstLine = headLines(of: file.url).first,
               let object = jsonObject(fromLine: firstLine),
               let payload = object["payload"] as? [String: Any] {
                // Guardian/subagent rollouts are machine review threads, not the user's work.
                if payload["thread_source"] as? String == "guardian_review" { return nil }
                if let source = payload["source"] as? [String: Any], source["subagent"] != nil { return nil }

                cwd = payload["cwd"] as? String
                threadID = payload["id"] as? String
            }
            let workspace = cwd ?? file.url.deletingLastPathComponent().path

            let tail = tailLines(of: file.url)
            let usage = codexUsage(in: tail)
            let model = codexModel(in: tail)
            let title = threadID.flatMap { threadNames[$0] } ?? workspaceTitle(for: workspace)

            return ObservedAgentSession(
                id: "codex-\(file.url.lastPathComponent)",
                provider: .codex,
                title: title,
                workspacePath: workspace,
                status: codexStatus(in: tail, lastActivityAt: file.modifiedAt),
                confidence: usage == nil ? .medium : .high,
                lastActivityAt: file.modifiedAt,
                model: model,
                summary: lastUserMessage(in: tail),
                branch: nil,
                tokensUsed: usage?.used,
                tokenLimit: usage?.limit,
                planUsagePercent: codexPlanUsage(in: tail)
            )
        }
    }

    /// `~/.codex/session_index.jsonl` maps thread ids to the name the user gave the thread.
    private static func codexThreadNames(sessionsRoot: String) -> [String: String] {
        let indexURL = URL(fileURLWithPath: sessionsRoot)
            .deletingLastPathComponent()
            .appendingPathComponent("session_index.jsonl")
        guard FileManager.default.fileExists(atPath: indexURL.path) else { return [:] }

        var names: [String: String] = [:]
        for line in lines(of: indexURL, fromEnd: true, byteCount: 256 * 1024) {
            guard
                let object = jsonObject(fromLine: line),
                let identifier = object["id"] as? String,
                let name = object["thread_name"] as? String,
                !name.isEmpty
            else { continue }
            names[identifier] = name
        }
        return names
    }

    private static func codexStatus(
        in lines: [String],
        lastActivityAt: Date,
        now: Date = Date()
    ) -> ObservedAgentStatus {
        for line in lines.reversed() {
            guard
                let object = jsonObject(fromLine: line),
                object["type"] as? String == "event_msg",
                let payload = object["payload"] as? [String: Any],
                let type = payload["type"] as? String
            else { continue }

            switch type {
            case "task_complete":
                return .needsReview
            case "turn_aborted":
                return .failed
            case "task_started":
                return status(for: lastActivityAt, now: now)
            default:
                continue
            }
        }
        return status(for: lastActivityAt, now: now)
    }

    private static func codexPlanUsage(in lines: [String]) -> Int? {
        for line in lines.reversed() {
            guard
                let object = jsonObject(fromLine: line),
                object["type"] as? String == "event_msg",
                let payload = object["payload"] as? [String: Any],
                payload["type"] as? String == "token_count",
                let info = payload["info"] as? [String: Any],
                let limits = info["rate_limits"] as? [String: Any],
                let primary = limits["primary"] as? [String: Any],
                let percent = (primary["used_percent"] as? NSNumber)?.intValue
            else { continue }
            return percent
        }
        return nil
    }

    private static func codexUsage(in lines: [String]) -> (used: Int, limit: Int?)? {
        for line in lines.reversed() {
            guard let object = jsonObject(fromLine: line) else { continue }
            guard let payload = object["payload"] as? [String: Any] else { continue }

            if object["type"] as? String == "event_msg",
               payload["type"] as? String == "token_count",
               let info = payload["info"] as? [String: Any],
               let total = info["total_token_usage"] as? [String: Any],
               let used = total["total_tokens"] as? Int {
                return (used, info["model_context_window"] as? Int)
            }

            if object["type"] as? String == "token_usage_record",
               let thread = payload["thread_token_usage"] as? [String: Any],
               let used = thread["total_tokens"] as? Int {
                return (used, nil)
            }
        }
        return nil
    }

    private static func codexModel(in lines: [String]) -> String? {
        for line in lines.reversed() {
            guard let object = jsonObject(fromLine: line) else { continue }
            if object["type"] as? String == "turn_context",
               let payload = object["payload"] as? [String: Any],
               let model = payload["model"] as? String {
                return model
            }
        }
        return nil
    }

    // MARK: - Claude Code

    static func claudeSessions(
        rootPath: String = "\(NSHomeDirectory())/.claude/projects",
        limit: Int = 6
    ) -> [ObservedAgentSession] {
        let files = recentFiles(
            roots: [rootPath],
            extensions: ["jsonl"],
            limit: min(limit, maxFilesPerProvider) * 3
        )

        return files.compactMap { file -> ObservedAgentSession? in
            let tail = tailLines(of: file.url)
            var cwd: String?
            var model: String?
            var tokens: Int?
            var branch: String?

            for line in tail.reversed() {
                guard let object = jsonObject(fromLine: line) else { continue }
                if cwd == nil { cwd = object["cwd"] as? String }
                if branch == nil { branch = object["gitBranch"] as? String }
                if let message = object["message"] as? [String: Any] {
                    if model == nil { model = message["model"] as? String }
                    if tokens == nil,
                       let usage = message["usage"] as? [String: Any] {
                        let input = usage["input_tokens"] as? Int ?? 0
                        let output = usage["output_tokens"] as? Int ?? 0
                        let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
                        let cacheWrite = usage["cache_creation_input_tokens"] as? Int ?? 0
                        let total = input + output + cacheRead + cacheWrite
                        if total > 0 { tokens = total }
                    }
                }
            }

            let workspace = cwd ?? file.url.deletingLastPathComponent().path
            return ObservedAgentSession(
                id: "claude-\(file.url.lastPathComponent)",
                provider: .claudeCode,
                title: workspaceTitle(for: workspace),
                workspacePath: workspace,
                status: claudeStatus(in: tail, lastActivityAt: file.modifiedAt),
                confidence: tokens == nil ? .medium : .high,
                lastActivityAt: file.modifiedAt,
                model: model,
                summary: lastUserMessage(in: tail),
                branch: branch,
                tokensUsed: tokens,
                tokenLimit: 200_000,
                planUsagePercent: nil
            )
        }
    }

    /// A transcript whose last line is an assistant turn that ended cleanly is waiting for review;
    /// if the user has spoken since, the agent is mid-turn again.
    private static func claudeStatus(
        in lines: [String],
        lastActivityAt: Date,
        now: Date = Date()
    ) -> ObservedAgentStatus {
        for line in lines.reversed() {
            guard
                let object = jsonObject(fromLine: line),
                let type = object["type"] as? String
            else { continue }

            switch type {
            case "assistant":
                let stopReason = (object["message"] as? [String: Any])?["stop_reason"] as? String
                return stopReason == "end_turn" ? .needsReview : .ongoing
            case "user":
                return .ongoing
            default:
                continue
            }
        }
        return status(for: lastActivityAt, now: now)
    }

    // MARK: - OpenCode

    static func openCodeSessions(
        databasePath: String = "\(NSHomeDirectory())/.local/share/opencode/opencode.db",
        limit: Int = 6
    ) async -> [ObservedAgentSession] {
        guard FileManager.default.fileExists(atPath: databasePath) else { return [] }

        let query = """
        select id, title, directory, tokens_input, tokens_output, time_updated
        from session_v2
        order by time_updated desc
        limit \(max(1, limit));
        """

        guard let rows = await SQLiteJSONQuery.run(databasePath: databasePath, query: query) else { return [] }
        let roles = await openCodeLastRoles(
            databasePath: databasePath,
            sessionIDs: rows.compactMap { $0["id"] as? String }
        )

        return rows.compactMap { row -> ObservedAgentSession? in
            guard let identifier = row["id"] as? String else { return nil }
            guard let updatedMillis = (row["time_updated"] as? NSNumber)?.doubleValue else { return nil }

            let directory = row["directory"] as? String ?? ""
            let input = row["tokens_input"] as? Int ?? 0
            let output = row["tokens_output"] as? Int ?? 0
            let updatedAt = Date(timeIntervalSince1970: updatedMillis / 1000)
            let status: ObservedAgentStatus
            switch roles[identifier] {
            case "assistant": status = .needsReview
            case "user": status = .ongoing
            default: status = Self.status(for: updatedAt)
            }

            return ObservedAgentSession(
                id: "opencode-\(identifier)",
                provider: .openCode,
                title: (row["title"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    ?? workspaceTitle(for: directory),
                workspacePath: directory,
                status: status,
                confidence: .high,
                lastActivityAt: updatedAt,
                model: nil,
                summary: nil,
                branch: nil,
                tokensUsed: input + output,
                tokenLimit: nil,
                planUsagePercent: nil
            )
        }
    }

    /// Last message role per session, so a finished assistant turn reads as "needs review".
    private static func openCodeLastRoles(
        databasePath: String,
        sessionIDs: [String]
    ) async -> [String: String] {
        guard !sessionIDs.isEmpty else { return [:] }
        let quoted = sessionIDs
            .map { "'" + $0.replacingOccurrences(of: "'", with: "''") + "'" }
            .joined(separator: ",")
        let query = """
        select session_id, json_extract(data, '$.role') as role
        from message
        where session_id in (\(quoted))
        order by time_created desc
        limit 400;
        """
        guard let rows = await SQLiteJSONQuery.run(databasePath: databasePath, query: query) else { return [:] }

        var roles: [String: String] = [:]
        for row in rows {
            guard
                let identifier = row["session_id"] as? String,
                let role = row["role"] as? String,
                roles[identifier] == nil
            else { continue }
            roles[identifier] = role
        }
        return roles
    }

    // MARK: - Ollama

    static func ollamaSessions() async -> [ObservedAgentSession] {
        guard let url = URL(string: "http://127.0.0.1:11434/api/ps") else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5

        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            (response as? HTTPURLResponse)?.statusCode == 200,
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let models = object["models"] as? [[String: Any]]
        else { return [] }

        let now = Date()
        return models.prefix(6).compactMap { model -> ObservedAgentSession? in
            guard let name = model["name"] as? String else { return nil }
            let size = model["size"] as? Int
            return ObservedAgentSession(
                id: "ollama-\(name)",
                provider: .ollama,
                title: name,
                workspacePath: "Local runtime",
                status: .ongoing,
                confidence: .high,
                lastActivityAt: now,
                model: name,
                summary: size.map { "\($0 / 1_000_000_000) GB resident" },
                branch: nil,
                tokensUsed: nil,
                tokenLimit: nil,
                planUsagePercent: nil
            )
        }
    }

    // MARK: - Shared helpers

    static func status(for lastActivityAt: Date, now: Date = Date()) -> ObservedAgentStatus {
        lastActivityAt > now.addingTimeInterval(-3 * 60) ? .ongoing : .idle
    }

    struct RecentlyModifiedFile {
        let url: URL
        let modifiedAt: Date
    }

    static func recentFiles(roots: [String], extensions: Set<String>, limit: Int) -> [RecentlyModifiedFile] {
        let fileManager = FileManager.default
        var candidates: [RecentlyModifiedFile] = []
        var enumerated = 0

        for rootPath in roots {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: rootPath, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }

            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: rootPath, isDirectory: true),
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                enumerated += 1
                if enumerated > maxEnumeratedFiles { break }

                guard extensions.contains(fileURL.pathExtension.lowercased()) else { continue }
                guard
                    let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                    values.isRegularFile == true,
                    let modifiedAt = values.contentModificationDate
                else { continue }

                candidates.append(RecentlyModifiedFile(url: fileURL, modifiedAt: modifiedAt))
            }
        }

        return Array(candidates.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(limit))
    }

    private static func headLines(of url: URL) -> [String] {
        lines(of: url, fromEnd: false, byteCount: headBytes)
    }

    private static func tailLines(of url: URL) -> [String] {
        lines(of: url, fromEnd: true, byteCount: tailBytes)
    }

    private static func lines(of url: URL, fromEnd: Bool, byteCount: Int) -> [String] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }

        guard let size = try? handle.seekToEnd() else { return [] }
        let offset = (fromEnd && size > UInt64(byteCount)) ? size - UInt64(byteCount) : 0
        do {
            try handle.seek(toOffset: offset)
        } catch {
            return []
        }

        guard let data = try? handle.readToEnd(), let text = String(data: data, encoding: .utf8) else { return [] }
        var lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        if fromEnd, offset > 0, !lines.isEmpty {
            lines.removeFirst() // drop a line truncated by the tail offset
        }
        return lines
    }

    static func jsonObject(fromLine line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func lastUserMessage(in lines: [String]) -> String? {
        for line in lines.reversed() {
            guard let object = jsonObject(fromLine: line) else { continue }

            var message: [String: Any]? = object["message"] as? [String: Any]
            if message == nil, let payload = object["payload"] as? [String: Any] {
                message = payload
            }
            guard let message, (message["role"] as? String) == "user" else { continue }

            let text = plainText(from: message["content"])
            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty || cleaned.hasPrefix("<") || cleaned.hasPrefix("[Request") { continue }
            return String(cleaned.prefix(140))
        }
        return nil
    }

    private static func plainText(from content: Any?) -> String {
        if let text = content as? String { return text }
        guard let parts = content as? [[String: Any]] else { return "" }
        for part in parts where part["type"] as? String == "text" {
            if let text = part["text"] as? String { return text }
        }
        return ""
    }

    private static func workspaceTitle(for path: String) -> String {
        let name = (path as NSString).lastPathComponent
        return name.isEmpty ? path : name
    }
}
