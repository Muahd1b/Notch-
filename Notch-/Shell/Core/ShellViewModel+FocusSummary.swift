import Foundation

@MainActor
extension ShellViewModel {
    var focusSessionsTodayCount: Int {
        focusSessionsToday.count
    }

    var focusMinutesToday: Int {
        focusMinutes(in: focusSessionsToday)
    }

    var focusSessionsAllTimeCount: Int {
        focusRecordsCompleted.count
    }

    var focusMinutesAllTime: Int {
        focusMinutes(in: focusRecordsCompleted)
    }

    private var focusRecordsCompleted: [FocusSessionRecord] {
        focusSessionRecords.filter { $0.phase == .focus }
    }

    private var focusSessionsToday: [FocusSessionRecord] {
        let now = Date()
        return focusRecordsCompleted.filter {
            Calendar.current.isDate($0.endedAt, inSameDayAs: now)
        }
    }

    private func focusMinutes(in records: [FocusSessionRecord]) -> Int {
        records.reduce(0) { $0 + max(0, $1.durationSeconds / 60) }
    }
}
