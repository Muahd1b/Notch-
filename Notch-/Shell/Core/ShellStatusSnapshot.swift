import Foundation

struct ShellStatusSnapshot: Equatable {
    let focusLabel: String
    let nextEventLabel: String
    let hostStatusLabel: String
    let openHighlights: [ShellHighlight]
    let overview: ShellOverviewSnapshot
    let statusIcons: [ShellStatusIcon]
    let batteryPercentage: Int
    let calendarEvents: [ShellCalendarEvent]
    let localhostServices: [ShellLocalhostService]
    let habits: [ShellHabitProgress]
    let learningSignals: [ShellLearningSignal]

    static let phaseZero = ShellStatusSnapshot(
        focusLabel: "25m focus",
        nextEventLabel: "No schedule live",
        hostStatusLabel: "3 hosts up",
        openHighlights: [
            ShellHighlight(title: "Focus", value: "Pomodoro shell ready"),
            ShellHighlight(title: "Shell", value: "Home tab stays neutral until modules ship"),
            ShellHighlight(title: "Hosts", value: "Local probes planned"),
        ],
        overview: ShellOverviewSnapshot(
            title: "Shell foundation",
            subtitle: "Focus and host status aligned",
            leadingLabel: "Phase 0",
            trailingLabel: "Parity",
            progress: 0.52
        ),
        statusIcons: [],
        batteryPercentage: 95,
        calendarEvents: [
            ShellCalendarEvent(
                id: "cal-1",
                startAt: Date().addingTimeInterval(34 * 60),
                endAt: Date().addingTimeInterval((34 + 45) * 60),
                title: "Design Review",
                timeLabel: "11:00 - 11:45",
                relativeLabel: "in 34m",
                location: "Notch Studio",
                sourceID: "work",
                source: "Work",
                sourceColorHex: "#0A84FF",
                isAllDay: false
            ),
            ShellCalendarEvent(
                id: "cal-2",
                startAt: Date().addingTimeInterval(3 * 3600),
                endAt: Date().addingTimeInterval(3 * 3600 + 30 * 60),
                title: "Agent Status Sync",
                timeLabel: "13:00 - 13:30",
                relativeLabel: "today",
                location: "Online",
                sourceID: "personal",
                source: "Personal",
                sourceColorHex: "#30D158",
                isAllDay: false
            ),
            ShellCalendarEvent(
                id: "cal-3",
                startAt: Date().addingTimeInterval(6 * 3600),
                endAt: Date().addingTimeInterval(6 * 3600 + 40 * 60),
                title: "Prep Financial Board",
                timeLabel: "16:00 - 16:40",
                relativeLabel: "today",
                location: "Local",
                sourceID: "business",
                source: "Business",
                sourceColorHex: "#FF9F0A",
                isAllDay: false
            ),
            ShellCalendarEvent(
                id: "cal-4",
                startAt: Calendar.current.startOfDay(for: Date()),
                endAt: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date(),
                title: "Family Dinner",
                timeLabel: "All Day",
                relativeLabel: "today",
                location: "Home",
                sourceID: "family",
                source: "Family",
                sourceColorHex: "#FF375F",
                isAllDay: true
            ),
        ],
        localhostServices: [
            ShellLocalhostService(
                id: "svc-1",
                name: "notch-api",
                endpoint: "http://localhost:8080",
                status: .healthy,
                ramUsageMB: 412,
                cpuPercent: 9
            ),
            ShellLocalhostService(
                id: "svc-2",
                name: "notch-web",
                endpoint: "http://localhost:3000",
                status: .healthy,
                ramUsageMB: 286,
                cpuPercent: 6
            ),
            ShellLocalhostService(
                id: "svc-3",
                name: "worker-jobs",
                endpoint: "http://localhost:9091",
                status: .degraded,
                ramUsageMB: 688,
                cpuPercent: 34
            ),
        ],
        habits: [],
        learningSignals: []
    )
}

struct ShellHighlight: Equatable, Identifiable {
    let title: String
    let value: String

    var id: String { title }
}

struct ShellOverviewSnapshot: Equatable {
    let title: String
    let subtitle: String
    let leadingLabel: String
    let trailingLabel: String
    let progress: Double
}

struct ShellStatusIcon: Equatable, Identifiable {
    let symbolName: String
    let accessibilityIdentifier: String

    var id: String { accessibilityIdentifier }
}

struct ShellCalendarEvent: Equatable, Identifiable, Codable {
    let id: String
    let startAt: Date
    let endAt: Date
    let title: String
    let timeLabel: String
    let relativeLabel: String
    let location: String
    let sourceID: String
    let source: String
    let sourceColorHex: String?
    let isAllDay: Bool
    let isReminder: Bool
    let isCompleted: Bool

    init(
        id: String,
        startAt: Date,
        endAt: Date,
        title: String,
        timeLabel: String,
        relativeLabel: String,
        location: String,
        sourceID: String,
        source: String,
        sourceColorHex: String? = nil,
        isAllDay: Bool,
        isReminder: Bool = false,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.startAt = startAt
        self.endAt = endAt
        self.title = title
        self.timeLabel = timeLabel
        self.relativeLabel = relativeLabel
        self.location = location
        self.sourceID = sourceID
        self.source = source
        self.sourceColorHex = sourceColorHex
        self.isAllDay = isAllDay
        self.isReminder = isReminder
        self.isCompleted = isCompleted
    }
}

struct ShellLocalhostService: Equatable, Identifiable, Codable {
    let id: String
    let name: String
    let endpoint: String
    let status: ShellLocalhostServiceStatus
    let ramUsageMB: Int
    let cpuPercent: Int
}

enum ShellLocalhostServiceStatus: String, Equatable, Codable {
    case healthy
    case degraded
    case down
}

struct ShellHabitProgress: Equatable, Identifiable, Codable {
    let id: String
    let title: String
    let completedUnits: Int
    let targetUnits: Int
    let streakDays: Int

    var progressValue: Double {
        guard targetUnits > 0 else { return 0 }
        return min(1, Double(completedUnits) / Double(targetUnits))
    }
}

struct ShellLearningSignal: Equatable, Identifiable, Codable {
    let id: String
    let title: String
    let source: String
    let capturedAtLabel: String
}
