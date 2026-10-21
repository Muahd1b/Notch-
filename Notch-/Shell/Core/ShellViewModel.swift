import Foundation
import Combine

@MainActor
final class ShellViewModel: ObservableObject {
    private static let maxFocusSessionRecords = 40
    private let defaultDisplayID = "__default__"

    @Published private(set) var presentationState: ShellPresentationState = .closed
    @Published private(set) var statusSnapshot: ShellStatusSnapshot
    @Published private(set) var closedNotchSize: CGSize
    @Published private(set) var selectedOpenTab: ShellOpenTab
    @Published private(set) var isPointerHovering = false
    @Published private var presentationStatesByDisplay: [String: ShellPresentationState]
    @Published private var closedNotchSizesByDisplay: [String: CGSize]
    @Published private var pointerHoveringByDisplay: [String: Bool]
    @Published private var presentationStateChangeTick: UInt = 0
    @Published var focusDraftNote = ""
    @Published private(set) var focusTimerPhase: FocusTimerPhase = .idle
    @Published private(set) var focusRemainingSeconds = 0
    @Published private(set) var focusIsPaused = false
    @Published private(set) var focusSessionRecords: [FocusSessionRecord] = []

    private let settingsStore: AppSettingsStore
    private let hapticsService: HapticsService?
    private let notificationService: FocusNotificationService
    private var focusHistoryStore: FocusSessionHistoryStoring?
    private var onCalendarPageAppeared: (() async -> Void)?
    private var onCreateCalendarEvent: ((String) async -> Bool)?
    private var onCreateReminder: ((String) async -> Bool)?
    private var onCreateFocusBlock: (() async -> Bool)?
    private var onLocalhostPageAppeared: (() async -> Void)?
    private var onHabitsPageAppeared: (() async -> Void)?
    private var onToggleHabit: ((String) async -> Void)?
    private var onCaptureLearningSignal: (() async -> Void)?
    private var focusTickerTask: Task<Void, Never>?
    private var activeSessionStartedAt: Date?
    private var activeSessionPlannedSeconds = 0
    private var activeSessionNote = ""

    init(
        statusSnapshot: ShellStatusSnapshot,
        initialPresentationState: ShellPresentationState = .closed,
        closedNotchSize: CGSize = CGSize(width: 185, height: 32),
        settingsStore: AppSettingsStore,
        hapticsService: HapticsService? = nil,
        notificationService: FocusNotificationService = .shared
    ) {
        self.statusSnapshot = statusSnapshot
        self.presentationState = initialPresentationState
        self.closedNotchSize = closedNotchSize
        self.selectedOpenTab = .home
        if settingsStore.rememberLastTab,
           let raw = UserDefaults.standard.string(forKey: AppSettingsKeys.lastOpenTab),
           let restored = ShellOpenTab(rawValue: raw) {
            self.selectedOpenTab = restored
        }
        self.settingsStore = settingsStore
        self.hapticsService = hapticsService
        self.notificationService = notificationService
        self.presentationStatesByDisplay = [defaultDisplayID: initialPresentationState]
        self.closedNotchSizesByDisplay = [defaultDisplayID: closedNotchSize]
        self.pointerHoveringByDisplay = [defaultDisplayID: false]
    }

    convenience init() {
        self.init(statusSnapshot: .phaseZero, settingsStore: AppSettingsStore.shared)
    }

    deinit {
        focusTickerTask?.cancel()
    }

    func updatePointerHovering(_ isHovering: Bool) {
        updatePointerHovering(isHovering, on: defaultDisplayID)
    }

    func open(_ reason: OpenReason = .userInitiated) {
        open(reason, on: defaultDisplayID)
    }

    func close() {
        close(on: defaultDisplayID)
    }

    func toggleOpen() {
        toggleOpen(on: defaultDisplayID)
    }

    func updatePointerHovering(_ isHovering: Bool, on displayID: String) {
        pointerHoveringByDisplay[displayID] = isHovering

        if displayID == defaultDisplayID {
            isPointerHovering = isHovering
        }
    }

    func open(_ reason: OpenReason = .userInitiated, on displayID: String) {
        setPresentationState(.open(reason), on: displayID, collapseOtherDisplays: true)
    }

    func close(on displayID: String) {
        if !settingsStore.rememberLastTab {
            selectedOpenTab = .home
        }
        setPresentationState(.closed, on: displayID)
    }

    func toggleOpen(on displayID: String) {
        switch presentationState(for: displayID) {
        case .open:
            close(on: displayID)
        case .closed:
            open(on: displayID)
        }
    }

    func cyclePreviewState() {
        switch presentationState(for: defaultDisplayID) {
        case .closed:
            open(.pinned, on: defaultDisplayID)
        case .open:
            close(on: defaultDisplayID)
        }
    }

    func updateClosedNotchSize(_ size: CGSize) {
        updateClosedNotchSize(size, on: defaultDisplayID)
    }

    func updateClosedNotchSize(_ size: CGSize, on displayID: String) {
        closedNotchSizesByDisplay[displayID] = size

        if displayID == defaultDisplayID {
            closedNotchSize = size
        }
    }

    func presentationState(for displayID: String) -> ShellPresentationState {
        presentationStatesByDisplay[displayID] ?? .closed
    }

    func closedNotchSize(for displayID: String) -> CGSize {
        closedNotchSizesByDisplay[displayID] ?? closedNotchSize
    }

    func isPointerHovering(on displayID: String) -> Bool {
        pointerHoveringByDisplay[displayID] ?? false
    }

    var presentationStateDidChange: AnyPublisher<Void, Never> {
        $presentationStateChangeTick
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    func updateStatusSnapshot(_ snapshot: ShellStatusSnapshot) {
        statusSnapshot = snapshot
    }

    func configureFocusHistoryStore(_ store: FocusSessionHistoryStoring?) {
        focusHistoryStore = store
    }

    func restoreFocusHistory() async {
        guard let focusHistoryStore else { return }
        let stored = await focusHistoryStore.loadHistory()
        guard !stored.isEmpty else { return }

        var recordsByID: [String: FocusSessionRecord] = [:]
        for record in stored {
            recordsByID[record.id] = record
        }
        for record in focusSessionRecords {
            recordsByID[record.id] = record
        }

        focusSessionRecords = Array(
            recordsByID.values
                .sorted(by: { $0.endedAt > $1.endedAt })
                .prefix(Self.maxFocusSessionRecords)
        )
    }

    private func setPresentationState(
        _ nextState: ShellPresentationState,
        on displayID: String,
        collapseOtherDisplays: Bool = false
    ) {
        var didChange = false

        if presentationStatesByDisplay[displayID] != nextState {
            presentationStatesByDisplay[displayID] = nextState
            didChange = true
        }

        if collapseOtherDisplays {
            for (otherDisplayID, state) in presentationStatesByDisplay where otherDisplayID != displayID && state != .closed {
                presentationStatesByDisplay[otherDisplayID] = .closed
                didChange = true
            }
        }

        if displayID == defaultDisplayID {
            presentationState = nextState
        } else {
            presentationState = presentationStatesByDisplay[defaultDisplayID] ?? .closed
        }

        if didChange {
            presentationStateChangeTick &+= 1
        }
    }

    func selectOpenTab(_ tab: ShellOpenTab) {
        guard selectedOpenTab != tab else { return }
        selectedOpenTab = tab
        if settingsStore.rememberLastTab {
            UserDefaults.standard.set(tab.rawValue, forKey: AppSettingsKeys.lastOpenTab)
        }
        hapticsService?.play(.selection)
    }

    func playSelectionHaptic() {
        hapticsService?.play(.selection)
    }

    func configurePageActions(
        onCalendarPageAppeared: (() async -> Void)? = nil,
        onCreateCalendarEvent: ((String) async -> Bool)? = nil,
        onCreateReminder: ((String) async -> Bool)? = nil,
        onCreateFocusBlock: (() async -> Bool)? = nil,
        onLocalhostPageAppeared: (() async -> Void)? = nil,
        onHabitsPageAppeared: (() async -> Void)? = nil,
        onToggleHabit: ((String) async -> Void)? = nil,
        onCaptureLearningSignal: (() async -> Void)? = nil
    ) {
        self.onCalendarPageAppeared = onCalendarPageAppeared
        self.onCreateCalendarEvent = onCreateCalendarEvent
        self.onCreateReminder = onCreateReminder
        self.onCreateFocusBlock = onCreateFocusBlock
        self.onLocalhostPageAppeared = onLocalhostPageAppeared
        self.onHabitsPageAppeared = onHabitsPageAppeared
        self.onToggleHabit = onToggleHabit
        self.onCaptureLearningSignal = onCaptureLearningSignal
    }

    func calendarPageAppeared() {
        Task {
            await onCalendarPageAppeared?()
        }
    }

    func createCalendarEvent(title: String = "New Event") {
        playSelectionHaptic()
        Task {
            let created = await onCreateCalendarEvent?(title) ?? false
            hapticsService?.play(created ? .success : .failure)
        }
    }

    func createReminder(title: String = "New Reminder") {
        playSelectionHaptic()
        Task {
            let created = await onCreateReminder?(title) ?? false
            hapticsService?.play(created ? .success : .failure)
        }
    }

    func createFocusBlock() {
        playSelectionHaptic()
        Task {
            let created = await onCreateFocusBlock?() ?? false
            hapticsService?.play(created ? .success : .failure)
        }
    }

    func localhostPageAppeared() {
        Task {
            await onLocalhostPageAppeared?()
        }
    }

    func toggleHabitCompletion(id: String) {
        playSelectionHaptic()
        Task {
            await onToggleHabit?(id)
        }
    }

    func habitsPageAppeared() {
        Task {
            await onHabitsPageAppeared?()
        }
    }

    func captureLearningSignal() {
        playSelectionHaptic()
        Task {
            await onCaptureLearningSignal?()
        }
    }

    var focusRemainingLabel: String {
        let bounded = max(0, focusRemainingSeconds)
        let minutes = bounded / 60
        let seconds = bounded % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var focusTimerIsRunning: Bool {
        focusTimerPhase != .idle
    }

    func startFocusSession() {
        playSelectionHaptic()
        startTimerSession(
            phase: .focus,
            note: focusDraftNote,
            autoStarted: false
        )
    }

    func startBreakSession() {
        playSelectionHaptic()
        startTimerSession(
            phase: .breakTime,
            note: "",
            autoStarted: false
        )
    }

    func toggleFocusPauseResume() {
        guard focusTimerPhase != .idle else { return }
        focusIsPaused.toggle()
        playSelectionHaptic()
    }

    func stopFocusSession() {
        guard focusTimerPhase != .idle else { return }
        playSelectionHaptic()
        resetFocusTimerState()
    }

    private func startTimerSession(
        phase: FocusTimerPhase,
        note: String,
        autoStarted: Bool
    ) {
        guard phase != .idle else { return }

        focusTickerTask?.cancel()
        focusTimerPhase = phase
        focusIsPaused = false
        activeSessionStartedAt = Date()
        activeSessionPlannedSeconds = configuredDurationSeconds(for: phase)
        focusRemainingSeconds = activeSessionPlannedSeconds
        activeSessionNote = phase == .focus ? note.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        if phase == .focus && !autoStarted {
            focusDraftNote = ""
        }
        startFocusTicker()
    }

    private func configuredDurationSeconds(for phase: FocusTimerPhase) -> Int {
        switch phase {
        case .focus:
            return max(60, Int((settingsStore.focusDurationMinutes * 60).rounded()))
        case .breakTime:
            return max(60, Int((settingsStore.shortBreakMinutes * 60).rounded()))
        case .idle:
            return 0
        }
    }

    private func startFocusTicker() {
        focusTickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                await self.advanceFocusTimerTick()
            }
        }
    }

    private func advanceFocusTimerTick() {
        guard focusTimerPhase != .idle else { return }
        guard !focusIsPaused else { return }

        if focusRemainingSeconds > 0 {
            focusRemainingSeconds -= 1
        }

        if focusRemainingSeconds <= 0 {
            completeCurrentTimerInterval()
        }
    }

    private func completeCurrentTimerInterval() {
        let completedPhase = focusTimerPhase
        guard completedPhase != .idle else { return }

        appendSessionRecord(for: completedPhase)
        playBoundaryHapticPattern()

        switch completedPhase {
        case .focus:
            let autoStartBreak = settingsStore.autoStartBreaks
            notificationService.postBoundaryNotification(
                title: "Focus Session Ended",
                body: autoStartBreak ? "Break session started." : "Start your break when ready.",
                enabled: settingsStore.notificationsEnabled
            )
            if autoStartBreak {
                startTimerSession(phase: .breakTime, note: "", autoStarted: true)
            } else {
                resetFocusTimerState()
            }

        case .breakTime:
            let autoStartFocus = settingsStore.autoStartFocusSessions
            notificationService.postBoundaryNotification(
                title: "Break Ended",
                body: autoStartFocus ? "New focus session started." : "Ready for your next focus session.",
                enabled: settingsStore.notificationsEnabled
            )
            if autoStartFocus {
                startTimerSession(phase: .focus, note: "", autoStarted: true)
            } else {
                resetFocusTimerState()
            }

        case .idle:
            break
        }
    }

    private func appendSessionRecord(for phase: FocusTimerPhase) {
        let record = FocusSessionRecord(
            id: UUID().uuidString,
            phase: phase,
            durationSeconds: max(0, activeSessionPlannedSeconds),
            note: phase == .focus ? activeSessionNote : "",
            endedAt: Date()
        )
        focusSessionRecords.insert(record, at: 0)
        if focusSessionRecords.count > Self.maxFocusSessionRecords {
            focusSessionRecords = Array(focusSessionRecords.prefix(Self.maxFocusSessionRecords))
        }
        persistFocusSessionRecord(record)
        activeSessionNote = ""
        activeSessionStartedAt = nil
        activeSessionPlannedSeconds = 0
    }

    private func persistFocusSessionRecord(_ record: FocusSessionRecord) {
        guard let focusHistoryStore else { return }
        Task {
            await focusHistoryStore.append(record)
        }
    }

    private func resetFocusTimerState() {
        focusTickerTask?.cancel()
        focusTickerTask = nil
        focusTimerPhase = .idle
        focusRemainingSeconds = 0
        focusIsPaused = false
        activeSessionStartedAt = nil
        activeSessionPlannedSeconds = 0
        activeSessionNote = ""
    }

    private func playBoundaryHapticPattern() {
        hapticsService?.play(.settle)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(140))
            self?.hapticsService?.play(.settle)
            try? await Task.sleep(for: .milliseconds(140))
            self?.hapticsService?.play(.settle)
        }
    }
}
