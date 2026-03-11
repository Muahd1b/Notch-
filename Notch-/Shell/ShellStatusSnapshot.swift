import Foundation

struct ShellStatusSnapshot: Equatable {
    let focusLabel: String
    let nextEventLabel: String
    let hostStatusLabel: String
    let openHighlights: [ShellHighlight]

    static let phaseZero = ShellStatusSnapshot(
        focusLabel: "25m focus",
        nextEventLabel: "Calendar clear",
        hostStatusLabel: "3 hosts up",
        openHighlights: [
            ShellHighlight(title: "Focus", value: "Pomodoro shell ready"),
            ShellHighlight(title: "Next Up", value: "Calendar adapter next"),
            ShellHighlight(title: "Hosts", value: "Local probes planned"),
        ]
    )
}

struct ShellHighlight: Equatable, Identifiable {
    let title: String
    let value: String

    var id: String { title }
}
