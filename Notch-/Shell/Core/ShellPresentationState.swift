import Foundation

enum OpenReason: String, Equatable {
    case hover
    case userInitiated
    case pinned
}

enum ShellPresentationState: Equatable {
    case closed
    case open(OpenReason)

    var isExpanded: Bool {
        switch self {
        case .closed:
            return false
        case .open:
            return true
        }
    }
}
