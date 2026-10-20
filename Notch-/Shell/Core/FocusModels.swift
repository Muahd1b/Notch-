import Foundation

enum FocusTimerPhase: String, Equatable, Codable, Sendable {
    case idle
    case focus
    case breakTime

    var title: String {
        switch self {
        case .idle:
            return "Idle"
        case .focus:
            return "Focus"
        case .breakTime:
            return "Break"
        }
    }
}

struct FocusSessionRecord: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let phase: FocusTimerPhase
    let durationSeconds: Int
    let note: String
    let endedAt: Date
}
