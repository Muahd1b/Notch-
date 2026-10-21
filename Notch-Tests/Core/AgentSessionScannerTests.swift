import Foundation
import Testing
@testable import Notch_

@Suite("Agent session scanner")
struct AgentSessionScannerTests {
    private func makeTemporaryRoot() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("notch-agent-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test("Codex rollout yields usage, model, summary and workspace")
    func codexScannerExtractsUsageModelAndWorkspace() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let sessionDirectory = root.appendingPathComponent("2026/10/21", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)

        let now = ISO8601DateFormatter().string(from: Date())
        let contents = [
            #"{"timestamp":"\#(now)","type":"session_meta","payload":{"cwd":"/Users/jonasknppel/Businesses/Notch-","model_provider":"openai"}}"#,
            #"{"timestamp":"\#(now)","type":"turn_context","payload":{"model":"gpt-5.1-codex"}}"#,
            #"{"timestamp":"\#(now)","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"text","text":"Make the agents page real"}]}}"#,
            #"{"timestamp":"\#(now)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":132044},"model_context_window":258400}}}"#,
        ].joined(separator: "\n") + "\n"

        try contents.write(
            to: sessionDirectory.appendingPathComponent("rollout-2026-10-21T10-28-36.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let sessions = AgentSessionScanner.codexSessions(rootPath: root.path)
        let session = try #require(sessions.first)

        #expect(session.provider == .codex)
        #expect(session.title == "Notch-")
        #expect(session.workspacePath == "/Users/jonasknppel/Businesses/Notch-")
        #expect(session.model == "gpt-5.1-codex")
        #expect(session.tokensUsed == 132_044)
        #expect(session.tokenLimit == 258_400)
        #expect(session.summary == "Make the agents page real")
        #expect(session.status == .ongoing)
        #expect(session.confidence == .high)
    }

    @Test("Claude transcript yields usage and cwd")
    func claudeScannerExtractsUsageAndCwd() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let projectDirectory = root.appendingPathComponent("-Users-jonasknppel-Businesses-Notch-", isDirectory: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

        let contents = [
            #"{"type":"user","cwd":"/Users/jonasknppel/Businesses/Notch-","message":{"role":"user","content":[{"type":"text","text":"Polish the focus page"}]}}"#,
            #"{"type":"assistant","cwd":"/Users/jonasknppel/Businesses/Notch-","message":{"role":"assistant","model":"claude-sonnet-4-5","usage":{"input_tokens":1000,"output_tokens":250,"cache_read_input_tokens":500,"cache_creation_input_tokens":250}}}"#,
        ].joined(separator: "\n") + "\n"

        try contents.write(
            to: projectDirectory.appendingPathComponent("session.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let sessions = AgentSessionScanner.claudeSessions(rootPath: root.path)
        let session = try #require(sessions.first)

        #expect(session.provider == .claudeCode)
        #expect(session.model == "claude-sonnet-4-5")
        #expect(session.tokensUsed == 2_000)
        #expect(session.tokenLimit == 200_000)
        #expect(session.workspacePath == "/Users/jonasknppel/Businesses/Notch-")
    }

    @Test("OpenCode database rows map to sessions")
    func openCodeScannerReadsSessionDatabase() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let databasePath = root.appendingPathComponent("opencode.db").path
        _ = ShellCommand.run("/usr/bin/sqlite3", [
            databasePath,
            """
            create table session_v2 (id text primary key, title text, directory text,
            tokens_input integer, tokens_output integer, time_updated integer);
            insert into session_v2 values ('ses_test','Pulling latest changes','/Users/jonasknppel',82768,9018,1792574303907);
            create table message (id text primary key, session_id text, time_created integer, data text);
            insert into message values ('msg_1','ses_test',1792574303000,'{"role":"user"}');
            insert into message values ('msg_2','ses_test',1792574303907,'{"role":"assistant"}');
            """,
        ])

        let sessions = await AgentSessionScanner.openCodeSessions(databasePath: databasePath)
        let session = try #require(sessions.first)

        #expect(session.provider == .openCode)
        #expect(session.title == "Pulling latest changes")
        #expect(session.tokensUsed == 91_786)
        #expect(session.tokenLimit == nil)
        #expect(session.status == .needsReview)
    }

    @Test("Finished Codex turn reads as needs review, not idle")
    func codexTurnCompletionNeedsReview() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let sessionDirectory = root.appendingPathComponent("2026/10/21", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)

        let contents = [
            #"{"type":"session_meta","payload":{"id":"thread-1","cwd":"/Users/jonasknppel/Businesses/Notch-","thread_source":"user"}}"#,
            #"{"type":"event_msg","payload":{"type":"task_started"}}"#,
            #"{"type":"event_msg","payload":{"type":"task_complete","payload":{"last_agent_message":"Done"}}}"#,
            #"{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":1000},"rate_limits":{"primary":{"used_percent":42}}}}}"#,
        ].joined(separator: "\n") + "\n"

        try contents.write(
            to: sessionDirectory.appendingPathComponent("rollout-2026-10-21T10-00-00.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let session = try #require(AgentSessionScanner.codexSessions(rootPath: root.path).first)
        #expect(session.status == .needsReview)
        #expect(session.planUsagePercent == 42)
    }

    @Test("Guardian review rollouts are hidden from the agent list")
    func guardianRolloutsAreFiltered() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let sessionDirectory = root.appendingPathComponent("2026/10/21", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)

        let contents = #"{"type":"session_meta","payload":{"cwd":"/tmp","thread_source":"guardian_review","source":{"subagent":"guardian"}}}"# + "\n"
        try contents.write(
            to: sessionDirectory.appendingPathComponent("rollout-guardian.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        #expect(AgentSessionScanner.codexSessions(rootPath: root.path).isEmpty)
    }

    @Test("Completed Claude turn reads as needs review")
    func claudeEndTurnNeedsReview() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let projectDirectory = root.appendingPathComponent("-Users-jonasknppel-Businesses-Notch-", isDirectory: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

        let contents = [
            #"{"type":"user","cwd":"/Users/jonasknppel/Businesses/Notch-","message":{"role":"user","content":"Fix it"}}"#,
            #"{"type":"assistant","cwd":"/Users/jonasknppel/Businesses/Notch-","message":{"role":"assistant","model":"claude-sonnet-4-5","stop_reason":"end_turn"}}"#,
        ].joined(separator: "\n") + "\n"

        try contents.write(
            to: projectDirectory.appendingPathComponent("session.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let session = try #require(AgentSessionScanner.claudeSessions(rootPath: root.path).first)
        #expect(session.status == .needsReview)
    }

    @Test("Recency window drives ongoing vs idle")
    func statusUsesRecencyWindow() {
        let now = Date()
        #expect(AgentSessionScanner.status(for: now.addingTimeInterval(-30), now: now) == .ongoing)
        #expect(AgentSessionScanner.status(for: now.addingTimeInterval(-600), now: now) == .idle)
    }
}
