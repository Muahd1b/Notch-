import Foundation
import Testing
@testable import Notch_

@MainActor
struct ShellViewModelTests {
    @Test
    func pointerHoverTrackingDoesNotMutatePresentationStateOnItsOwn() {
        let viewModel = ShellViewModel()

        viewModel.updatePointerHovering(true)
        #expect(viewModel.isPointerHovering == true)
        #expect(viewModel.presentationState == .closed)

        viewModel.updatePointerHovering(false)
        #expect(viewModel.isPointerHovering == false)
        #expect(viewModel.presentationState == .closed)
    }

    @Test
    func toggleOpenMovesBetweenOpenAndClosed() {
        let viewModel = ShellViewModel()

        viewModel.toggleOpen()
        #expect(viewModel.presentationState == .open(.userInitiated))

        viewModel.toggleOpen()
        #expect(viewModel.presentationState == .closed)
    }

    @Test
    func openingOneDisplayCollapsesOtherDisplays() {
        let viewModel = ShellViewModel()

        viewModel.open(.hover, on: "primary")
        #expect(viewModel.presentationState(for: "primary") == .open(.hover))
        #expect(viewModel.presentationState(for: "external") == .closed)

        viewModel.open(.userInitiated, on: "external")
        #expect(viewModel.presentationState(for: "external") == .open(.userInitiated))
        #expect(viewModel.presentationState(for: "primary") == .closed)
    }

    @Test
    func cyclePreviewStateTogglesPinnedOpenAndClosed() {
        let viewModel = ShellViewModel()

        viewModel.cyclePreviewState()
        #expect(viewModel.presentationState == .open(.pinned))

        viewModel.cyclePreviewState()
        #expect(viewModel.presentationState == .closed)
    }

    @Test
    func closeResetsSelectedTabWhenRememberLastTabIsDisabled() {
        let defaults = UserDefaults(suiteName: "ShellViewModelTests-\(UUID().uuidString)")!
        let settingsStore = AppSettingsStore(defaults: defaults)
        settingsStore.rememberLastTab = false
        let viewModel = ShellViewModel(statusSnapshot: .phaseZero, settingsStore: settingsStore)

        viewModel.open()
        viewModel.selectOpenTab(.agents)
        viewModel.close()

        #expect(viewModel.selectedOpenTab == .home)
    }

    @Test
    func selectOpenTabChangesSelection() {
        let viewModel = ShellViewModel()
        #expect(viewModel.selectedOpenTab == .home)

        viewModel.selectOpenTab(.calendar)
        #expect(viewModel.selectedOpenTab == .calendar)

        viewModel.selectOpenTab(.localhost)
        #expect(viewModel.selectedOpenTab == .localhost)
    }

    @Test
    func toggleHabitCompletionInvokesConfiguredHandler() async {
        let viewModel = ShellViewModel()
        let recorder = HabitToggleRecorder()

        viewModel.configurePageActions(
            onToggleHabit: { id in
                await recorder.record(id)
            }
        )

        viewModel.toggleHabitCompletion(id: "habit-1")
        try? await Task.sleep(for: .milliseconds(60))

        #expect(await recorder.lastID == "habit-1")
    }

    @Test
    func startFocusSessionAppliesConfiguredDurationAndNote() {
        let defaults = UserDefaults(suiteName: "ShellViewModelFocusStart-\(UUID().uuidString)")!
        let settingsStore = AppSettingsStore(defaults: defaults)
        settingsStore.focusDurationMinutes = 1
        let viewModel = ShellViewModel(statusSnapshot: .phaseZero, settingsStore: settingsStore)

        viewModel.focusDraftNote = "Ship timer page"
        viewModel.startFocusSession()

        #expect(viewModel.focusTimerPhase == .focus)
        #expect(viewModel.focusRemainingSeconds == 60)
        #expect(viewModel.focusDraftNote.isEmpty)
        #expect(viewModel.focusTimerIsRunning == true)

        viewModel.stopFocusSession()
    }

    @Test
    func stopFocusSessionResetsTimerState() {
        let defaults = UserDefaults(suiteName: "ShellViewModelFocusStop-\(UUID().uuidString)")!
        let settingsStore = AppSettingsStore(defaults: defaults)
        settingsStore.focusDurationMinutes = 1
        let viewModel = ShellViewModel(statusSnapshot: .phaseZero, settingsStore: settingsStore)

        viewModel.startFocusSession()
        #expect(viewModel.focusTimerIsRunning == true)

        viewModel.stopFocusSession()
        #expect(viewModel.focusTimerPhase == .idle)
        #expect(viewModel.focusRemainingSeconds == 0)
        #expect(viewModel.focusIsPaused == false)
        #expect(viewModel.focusTimerIsRunning == false)
    }
}

private actor HabitToggleRecorder {
    private(set) var lastID: String?

    func record(_ id: String) {
        lastID = id
    }
}
