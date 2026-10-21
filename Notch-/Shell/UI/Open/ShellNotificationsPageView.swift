import SwiftUI

@MainActor
struct ShellNotificationsPageView: View {
    @ObservedObject var viewModel: ShellViewModel
    @ObservedObject private var inbox = TelegramInbox.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if !inbox.hasToken {
                setupState
            } else if inbox.messages.isEmpty {
                idleState
            } else {
                messageList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Telegram")
                .font(.headline)
                .foregroundStyle(.white)
            Circle()
                .fill(statusTint)
                .frame(width: 5, height: 5)
            Text(inbox.status.label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
            Spacer(minLength: 8)
            if inbox.unreadCount > 0 {
                Text("\(inbox.unreadCount) new")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            if !inbox.messages.isEmpty {
                Button("Mark read") { inbox.markAllRead() }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private var setupState: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: "paperplane")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.5))
            Text("No bot connected")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
            Text("Settings › Notifications › Telegram → paste a bot token from @BotFather, then message the bot. Only messages sent to that bot appear here.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var idleState: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: "checkmark.circle")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.45))
            Text("Listening")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
            Text("Send your bot a message and it lands here within a second.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var messageList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 3) {
                ForEach(inbox.messages) { message in
                    messageRow(message)
                }
            }
        }
    }

    private func messageRow(_ message: TelegramMessage) -> some View {
        let isUnread = message.receivedAt > inbox.lastReadAt
        return HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(isUnread ? Color.orange : Color.clear)
                .frame(width: 5, height: 5)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(message.chatTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                    Text(relativeLabel(message.receivedAt))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.35))
                }
                Text(message.text)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var statusTint: Color {
        switch inbox.status {
        case .connected: return .green
        case .connecting: return .blue
        case .failed: return .red
        case .needsToken, .disabled: return .white.opacity(0.3)
        }
    }

    private func relativeLabel(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
