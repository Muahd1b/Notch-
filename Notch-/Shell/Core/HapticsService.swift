import AppKit

enum HapticEvent {
    case open
    case settle
    case selection
    case success
    case failure
}

@MainActor
final class HapticsService {
    private let settingsStore: AppSettingsStore

    init(settingsStore: AppSettingsStore) {
        self.settingsStore = settingsStore
    }

    convenience init() {
        self.init(settingsStore: AppSettingsStore.shared)
    }

    func play(_ event: HapticEvent) {
        guard settingsStore.enableHaptics else { return }

        let performer = NSHapticFeedbackManager.defaultPerformer

        switch event {
        case .open:
            performer.perform(.alignment, performanceTime: .now)
        case .settle:
            performer.perform(.levelChange, performanceTime: .now)
        case .selection:
            performer.perform(.alignment, performanceTime: .now)
        case .success:
            performer.perform(.alignment, performanceTime: .now)
        case .failure:
            performer.perform(.levelChange, performanceTime: .now)
        }
    }
}
