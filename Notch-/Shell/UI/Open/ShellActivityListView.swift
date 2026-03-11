import SwiftUI

struct ShellActivityListView: View {
    private let rows: [(title: String, value: String)] = [
        ("Shell", "Home tab stays neutral until live modules arrive"),
        ("Agents", "Codex, Claude, and OpenClaw settings shell ready"),
        ("Localhost", "Probe registry comes after shell parity"),
        ("Focus", "Scroll viewport keeps shell size stable"),
        ("State", "Open shell remains a fixed viewport"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(rows, id: \.title) { row in
                activityRow(title: row.title, value: row.value)
            }
        }
    }

    private func activityRow(title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
