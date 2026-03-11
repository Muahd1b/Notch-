import Foundation
import Combine

@MainActor
final class ShellViewModel: ObservableObject {
    @Published private(set) var presentationState: ShellPresentationState = .closed
    @Published private(set) var statusSnapshot: ShellStatusSnapshot

    init(statusSnapshot: ShellStatusSnapshot) {
        self.statusSnapshot = statusSnapshot
    }

    convenience init() {
        self.init(statusSnapshot: .phaseZero)
    }

    func setHovering(_ isHovering: Bool) {
        switch (presentationState, isHovering) {
        case (.closed, true):
            presentationState = .peek(.hover)
        case (.peek(.hover), false):
            presentationState = .closed
        default:
            break
        }
    }

    func open() {
        presentationState = .open(.userInitiated)
    }

    func close() {
        presentationState = .closed
    }

    func toggleOpen() {
        switch presentationState {
        case .open:
            close()
        case .closed, .peek:
            open()
        }
    }

    func cyclePreviewState() {
        switch presentationState {
        case .closed:
            presentationState = .peek(.statusChange)
        case .peek:
            presentationState = .open(.pinned)
        case .open:
            presentationState = .closed
        }
    }
}
