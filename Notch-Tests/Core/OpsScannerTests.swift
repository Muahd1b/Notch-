import Foundation
import Testing
@testable import Notch_

@Suite("Ops scanner")
struct OpsScannerTests {
    private func makeTemporaryRoot() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("notch-ops-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test("Automations parse name, schedule and status")
    func automationsParseSpec() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let active = root.appendingPathComponent("nightly-plan", isDirectory: true)
        try FileManager.default.createDirectory(at: active, withIntermediateDirectories: true)
        try """
        kind = "cron"
        name = "Nightly plan"
        status = "ACTIVE"
        rrule = "FREQ=DAILY;INTERVAL=3"
        """.write(to: active.appendingPathComponent("automation.toml"), atomically: true, encoding: .utf8)

        let paused = root.appendingPathComponent("old-job", isDirectory: true)
        try FileManager.default.createDirectory(at: paused, withIntermediateDirectories: true)
        try """
        name = "Old job"
        status = "PAUSED"
        rrule = "FREQ=HOURLY"
        """.write(to: paused.appendingPathComponent("automation.toml"), atomically: true, encoding: .utf8)
        let staleDate = Date().addingTimeInterval(-10 * 24 * 3600)
        let memory = paused.appendingPathComponent("memory.md")
        try "old".write(to: memory, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: staleDate], ofItemAtPath: memory.path)

        let automations = OpsScanner.automations(rootPath: root.path)
        #expect(automations.count == 2)

        let nightly = try #require(automations.first { $0.id == "nightly-plan" })
        #expect(nightly.name == "Nightly plan")
        #expect(nightly.isActive)
        #expect(nightly.scheduleLabel == "every 3 days")
        #expect(nightly.issue == nil)

        let old = try #require(automations.first { $0.id == "old-job" })
        #expect(old.issue == .stale)
        #expect(automations.first?.id == "old-job", "issues sort first")
    }

    @Test("Passed one-shot schedules are flagged as expired")
    func expiredOneShot() {
        let rrule = "FREQ=DAILY;BYMONTH=1;BYMONTHDAY=5;BYHOUR=9;BYMINUTE=30;COUNT=1"
        #expect(OpsScanner.expiredOneShot(rrule: rrule) != nil)
        #expect(OpsScanner.expiredOneShot(rrule: "FREQ=DAILY;COUNT=1") == nil)
        #expect(OpsScanner.expiredOneShot(rrule: "FREQ=DAILY;INTERVAL=3") == nil)
    }

    @Test("Schedules humanize without an rrule engine")
    func scheduleLabels() {
        #expect(OpsScanner.humanSchedule("FREQ=MINUTELY;INTERVAL=30") == "every 30 min")
        #expect(OpsScanner.humanSchedule("FREQ=DAILY") == "daily")
        #expect(OpsScanner.humanSchedule("FREQ=WEEKLY;INTERVAL=2") == "every 2 weeks")
        #expect(OpsScanner.humanSchedule("") == "manual")
    }

    @Test("Awaiting-ack runs surface as needs-you items")
    func awaitingAcksFound() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let run = root
            .appendingPathComponent("repo", isDirectory: true)
            .appendingPathComponent(".orchestration/runs/run-1", isDirectory: true)
        try FileManager.default.createDirectory(at: run, withIntermediateDirectories: true)

        try """
        run_id: "run-1"
        repo_root: "/tmp/repo"
        issue_id: "JON-42"
        risk_level: "critical"
        acks_remaining: "release"
        phase: "awaiting_ack"
        created_at: "2026-10-20T11:00:00Z"
        """.write(to: run.appendingPathComponent("state.yaml"), atomically: true, encoding: .utf8)

        let approved = root
            .appendingPathComponent("repo/.orchestration/runs/run-2", isDirectory: true)
        try FileManager.default.createDirectory(at: approved, withIntermediateDirectories: true)
        try """
        run_id: "run-2"
        phase: "approved"
        """.write(to: approved.appendingPathComponent("state.yaml"), atomically: true, encoding: .utf8)

        let items = OpsScanner.awaitingAcks(searchRoots: [root.path])
        #expect(items.count == 1)
        #expect(items.first?.id == "ack-run-1")
        #expect(items.first?.title == "JON-42")
        #expect(items.first?.detail.contains("release") == true)
    }

    @Test("CI run JSON maps to green, red and running")
    func runStateParsing() {
        let green = OpsScanner.parseRunState(#"[{"status":"completed","conclusion":"success","createdAt":"2026-10-21T09:00:00Z"}]"#)
        #expect(green.ciState == "success")

        let red = OpsScanner.parseRunState(#"[{"status":"completed","conclusion":"failure","createdAt":"2026-10-20T09:00:00Z"}]"#)
        #expect(red.ciState == "failure")

        let running = OpsScanner.parseRunState(#"[{"status":"in_progress","conclusion":null,"createdAt":"2026-10-21T09:00:00Z"}]"#)
        #expect(running.ciState == "running")

        #expect(OpsScanner.parseRunState(nil).ciState == "unknown")
        #expect(OpsScanner.parseRunState("").ciState == "unknown")
    }
}
