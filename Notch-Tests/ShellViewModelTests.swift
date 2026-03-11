import Testing
@testable import Notch_

@MainActor
struct ShellViewModelTests {
    @Test
    func hoverTransitionsMoveBetweenClosedAndPeek() {
        let viewModel = ShellViewModel()

        viewModel.setHovering(true)
        #expect(viewModel.presentationState == .peek(.hover))

        viewModel.setHovering(false)
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
    func cyclePreviewStateWalksAllPhaseZeroStates() {
        let viewModel = ShellViewModel()

        viewModel.cyclePreviewState()
        #expect(viewModel.presentationState == .peek(.statusChange))

        viewModel.cyclePreviewState()
        #expect(viewModel.presentationState == .open(.pinned))

        viewModel.cyclePreviewState()
        #expect(viewModel.presentationState == .closed)
    }
}
