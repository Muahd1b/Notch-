import AppKit

enum HapticEvent {
    case open
    case settle
}

@MainActor
final class HapticsService {
    func play(_ event: HapticEvent) {
        let performer = NSHapticFeedbackManager.defaultPerformer

        switch event {
        case .open:
            performer.perform(.alignment, performanceTime: .now)
        case .settle:
            performer.perform(.levelChange, performanceTime: .now)
        }
    }
}
