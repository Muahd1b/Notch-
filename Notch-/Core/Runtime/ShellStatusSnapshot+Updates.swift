import Foundation

extension ShellStatusSnapshot {
    func updatingCalendar(_ events: [ShellCalendarEvent]) -> ShellStatusSnapshot {
        let nextLabel = events.first.map { "\($0.title) \u{2022} \($0.timeLabel)" } ?? "No events scheduled"
        return ShellStatusSnapshot(
            focusLabel: focusLabel,
            nextEventLabel: nextLabel,
            hostStatusLabel: hostStatusLabel,
            openHighlights: openHighlights,
            overview: overview,
            statusIcons: statusIcons,
            batteryPercentage: batteryPercentage,
            calendarEvents: events,
            localhostServices: localhostServices,
            agentSessions: agentSessions,
            habits: habits,
            learningSignals: learningSignals,
            ops: ops
        )
    }

    func updatingLocalhost(_ services: [ShellLocalhostService]) -> ShellStatusSnapshot {
        let healthy = services.filter { $0.status == .healthy }.count
        let hostLabel = services.isEmpty ? "No hosts configured" : "\(healthy)/\(services.count) hosts up"
        return ShellStatusSnapshot(
            focusLabel: focusLabel,
            nextEventLabel: nextEventLabel,
            hostStatusLabel: hostLabel,
            openHighlights: openHighlights,
            overview: overview,
            statusIcons: statusIcons,
            batteryPercentage: batteryPercentage,
            calendarEvents: calendarEvents,
            localhostServices: services,
            agentSessions: agentSessions,
            habits: habits,
            learningSignals: learningSignals,
            ops: ops
        )
    }

    func updatingHabitsLearning(
        habits: [ShellHabitProgress],
        learnings: [ShellLearningSignal]
    ) -> ShellStatusSnapshot {
        return ShellStatusSnapshot(
            focusLabel: focusLabel,
            nextEventLabel: nextEventLabel,
            hostStatusLabel: hostStatusLabel,
            openHighlights: openHighlights,
            overview: overview,
            statusIcons: statusIcons,
            batteryPercentage: batteryPercentage,
            calendarEvents: calendarEvents,
            localhostServices: localhostServices,
            agentSessions: agentSessions,
            habits: habits,
            learningSignals: learnings,
            ops: ops
        )
    }

    func updatingAgents(_ sessions: [ShellAgentSession]) -> ShellStatusSnapshot {
        return ShellStatusSnapshot(
            focusLabel: focusLabel,
            nextEventLabel: nextEventLabel,
            hostStatusLabel: hostStatusLabel,
            openHighlights: openHighlights,
            overview: overview,
            statusIcons: statusIcons,
            batteryPercentage: batteryPercentage,
            calendarEvents: calendarEvents,
            localhostServices: localhostServices,
            agentSessions: sessions,
            habits: habits,
            learningSignals: learningSignals,
            ops: ops
        )
    }
}
