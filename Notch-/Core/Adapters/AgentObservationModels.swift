import Foundation

enum ObservedAgentProvider: String, Codable, Sendable, CaseIterable {
    case codex
    case claudeCode
    case openCode
    case ollama

    var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .claudeCode: return "Claude"
        case .openCode: return "OpenCode"
        case .ollama: return "Ollama"
        }
    }

    var symbolName: String {
        switch self {
        case .codex: return "chevron.left.forwardslash.chevron.right"
        case .claudeCode: return "asterisk"
        case .openCode: return "terminal"
        case .ollama: return "brain"
        }
    }

    /// Process names used to decide whether a provider is currently running.
    var processNames: [String] {
        switch self {
        case .codex: return ["codex"]
        case .claudeCode: return ["claude"]
        case .openCode: return ["opencode"]
        case .ollama: return ["ollama"]
        }
    }
}

enum ObservedAgentStatus: String, Codable, Sendable {
    /// The agent is mid-turn.
    case ongoing
    /// The agent finished a turn and nobody has looked at the result yet.
    case needsReview
    /// The last turn was aborted or failed.
    case failed
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
    let model: String?
    let summary: String?
    let branch: String?
    let tokensUsed: Int?
    let tokenLimit: Int?
    /// Codex plan usage for the current rate-limit window, when the rollout reports it.
    let planUsagePercent: Int?
}

struct AgentObserverPayload: Equatable, Codable, Sendable {
    let updatedAt: Date
    let sessions: [ObservedAgentSession]
}
