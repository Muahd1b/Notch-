import Foundation

/// What needs a decision from the operator: scheduled work that stopped, agent runs
/// waiting behind an approval gate, and repos whose main branch is not green.
struct ShellOpsSnapshot: Equatable {
    var automations: [ShellAutomation] = []
    var needsYou: [ShellNeedsYouItem] = []
    var repos: [ShellRepoStatus] = []
    var updatedAt: Date = .distantPast

    static let empty = ShellOpsSnapshot()

    var overdueCount: Int {
        automations.filter { $0.issue != nil }.count
    }

    var attentionCount: Int {
        needsYou.count + overdueCount + repos.filter { $0.ciState == "failure" }.count
    }
}

enum ShellOpsIssue: String, Equatable, Codable {
    /// A one-shot schedule whose date has passed without ever running to completion.
    case expired
    /// Paused long enough that it is no longer a decision anyone is actively holding.
    case stale
}

struct ShellAutomation: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let isActive: Bool
    let scheduleLabel: String
    let lastRunAt: Date?
    let issue: ShellOpsIssue?
}

enum ShellOpsAttentionKind: String, Equatable, Codable {
    case ack
    case failed
    case blocked
}

struct ShellNeedsYouItem: Identifiable, Equatable, Codable {
    let id: String
    let kind: ShellOpsAttentionKind
    let title: String
    let detail: String
    let createdAt: Date
}

struct ShellRepoStatus: Identifiable, Equatable, Codable {
    /// Short repo name, e.g. `Kernscale-Operations`.
    let id: String
    /// `success`, `failure`, `running`, or `unknown`.
    let ciState: String
    let ciLabel: String
    let openPRs: Int
}

struct OpsObserverPayload: Equatable, Codable, Sendable {
    let updatedAt: Date
    let automations: [ShellAutomation]
    let needsYou: [ShellNeedsYouItem]
    let repos: [ShellRepoStatus]
}
