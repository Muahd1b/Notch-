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

    /// Last seven days, oldest first, for the focus history strip.
    var focusLastSevenDays: [FocusDayMetric] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let minutes = focusMinutes(
                in: focusRecordsCompleted.filter { calendar.isDate($0.endedAt, inSameDayAs: day) }
            )
            return FocusDayMetric(date: day, minutes: minutes)
        }
    }

    /// Consecutive days ending today or yesterday that contain at least one completed focus session.
    var focusCurrentStreak: Int {
        let calendar = Calendar.current
        let daysWithSessions = Set(
            focusRecordsCompleted.map { calendar.startOfDay(for: $0.endedAt) }
        )

        var streak = 0
        var cursor = calendar.startOfDay(for: Date())

        if !daysWithSessions.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  daysWithSessions.contains(yesterday) else { return 0 }
            cursor = yesterday
        }

        while daysWithSessions.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    var lastFocusSessionLabel: String? {
        guard let record = focusRecordsCompleted.first else { return nil }
        let minutes = max(1, record.durationSeconds / 60)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "\(minutes)m · \(formatter.localizedString(for: record.endedAt, relativeTo: Date()))"
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

struct FocusDayMetric: Identifiable, Equatable {
    let date: Date
    let minutes: Int

    var id: Date { date }
}
