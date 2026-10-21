import Combine
import Foundation

struct TelegramMessage: Identifiable, Equatable, Codable, Sendable {
    let id: Int
    let chatTitle: String
    let author: String
    let text: String
    let receivedAt: Date
}

enum TelegramStatus: Equatable, Sendable {
    case disabled
    case needsToken
    case connecting
    case connected
    case failed(String)

    var label: String {
        switch self {
        case .disabled: return "Off"
        case .needsToken: return "Add a bot token"
        case .connecting: return "Connecting…"
        case .connected: return "Connected"
        case .failed(let reason): return reason
        }
    }
}

/// Single source of truth for the Notifications page. Written by `TelegramClient` on the main actor.
@MainActor
final class TelegramInbox: ObservableObject {
    static let shared = TelegramInbox()

    @Published private(set) var messages: [TelegramMessage] = []
    @Published private(set) var status: TelegramStatus = .disabled
    @Published private(set) var unreadCount: Int = 0
    @Published private(set) var lastReadAt: Date = .distantPast
    @Published private(set) var lastError: String?

    private let defaults: UserDefaults
    private let messagesKey = "notch.telegram.messages"
    private let offsetKey = "notch.telegram.updateOffset"
    private let maxMessages = 60

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: messagesKey),
           let decoded = try? JSONDecoder().decode([TelegramMessage].self, from: data) {
            messages = decoded
        }
    }

    var token: String? {
        KeychainStore.string(for: "telegram.botToken")
    }

    var hasToken: Bool {
        !(token ?? "").isEmpty
    }

    var updateOffset: Int? {
        get { defaults.object(forKey: offsetKey) as? Int }
        set { defaults.set(newValue, forKey: offsetKey) }
    }

    /// Messages newer than the last time the page was opened count as unread.
    func setUnread(_ count: Int) {
        unreadCount = max(0, count)
    }

    func markAllRead() {
        unreadCount = 0
        lastReadAt = Date()
    }

    func setStatus(_ status: TelegramStatus) {
        self.status = status
    }

    func append(_ incoming: [TelegramMessage]) {
        guard !incoming.isEmpty else { return }
        let existing = Set(messages.map(\.id))
        let fresh = incoming.filter { !existing.contains($0.id) }
        guard !fresh.isEmpty else { return }

        messages = (fresh + messages)
            .sorted { $0.receivedAt > $1.receivedAt }
            .prefix(maxMessages)
            .map { $0 }
        // Only count arrivals once the page has been opened at least once.
        unreadCount += fresh.count
        persist()
    }

    func saveToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainStore.remove(account: "telegram.botToken")
        } else {
            KeychainStore.set(trimmed, for: "telegram.botToken")
        }
        lastError = nil
        status = trimmed.isEmpty ? .needsToken : .connecting
    }

    func clear() {
        messages = []
        unreadCount = 0
        defaults.removeObject(forKey: messagesKey)
        defaults.removeObject(forKey: offsetKey)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(messages) else { return }
        defaults.set(data, forKey: messagesKey)
    }
}
