import Foundation

enum PeekReason: String, Equatable {
    case hover
    case statusChange
}

enum OpenReason: String, Equatable {
    case userInitiated
    case pinned
}

enum ShellPresentationState: Equatable {
    case closed
    case peek(PeekReason)
    case open(OpenReason)

    var isExpanded: Bool {
        switch self {
        case .closed:
            return false
        case .peek, .open:
            return true
        }
    }
}
