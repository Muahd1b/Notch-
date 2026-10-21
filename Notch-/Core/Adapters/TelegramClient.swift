import Foundation

/// Long-polls the Telegram Bot API. Only messages sent *to* the bot arrive here — that is how
/// Telegram exposes a bot's inbox without any unofficial client.
actor TelegramClient {
    static let shared = TelegramClient()

    private var pollTask: Task<Void, Never>?
    private var isRunning = false
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 40
        configuration.timeoutIntervalForResource = 45
        session = URLSession(configuration: configuration)
    }

    func start() async {
        guard !isRunning else { return }
        isRunning = true

        guard let token = await MainActor.run(body: { TelegramInbox.shared.token }), !token.isEmpty else {
            await MainActor.run { TelegramInbox.shared.setStatus(.needsToken) }
            isRunning = false
            return
        }

        await MainActor.run { TelegramInbox.shared.setStatus(.connecting) }
        pollTask = Task { [weak self] in
            await self?.runLoop(token: token)
        }
    }

    func stop() async {
        isRunning = false
        pollTask?.cancel()
        pollTask = nil
        await MainActor.run { TelegramInbox.shared.setStatus(.disabled) }
    }

    /// Clears the stored offset so the next start re-baselines instead of replaying history.
    func restart() async {
        await stop()
        await start()
    }

    private func runLoop(token: String) async {
        var backoff: UInt64 = 3
        var seeded = await MainActor.run { TelegramInbox.shared.updateOffset != nil }

        while !Task.isCancelled && isRunning {
            do {
                if !seeded {
                    try await seedOffset(token: token)
                    seeded = true
                    await MainActor.run { TelegramInbox.shared.setStatus(.connected) }
                }

                let updates = try await fetchUpdates(token: token)
                if !updates.isEmpty {
                    await MainActor.run { TelegramInbox.shared.append(updates) }
                }
                await MainActor.run { TelegramInbox.shared.setStatus(.connected) }
                backoff = 3
            } catch let error as TelegramError {
                await MainActor.run { TelegramInbox.shared.setStatus(.failed(error.message)) }
                if case .unauthorized = error {
                    isRunning = false
                    return
                }
                try? await Task.sleep(for: .seconds(backoff))
                backoff = min(backoff * 3, 60)
            } catch {
                await MainActor.run { TelegramInbox.shared.setStatus(.failed("Network error")) }
                try? await Task.sleep(for: .seconds(backoff))
                backoff = min(backoff * 3, 60)
            }
        }
    }

    // MARK: - API

    private func seedOffset(token: String) async throws {
        // offset = -1 returns the newest update; +1 skips everything that arrived before install.
        let result = try await request(token: token, query: "offset=-1&limit=1&timeout=0")
        if let last = result.last, let identifier = last["update_id"] as? Int {
            await MainActor.run { TelegramInbox.shared.updateOffset = identifier + 1 }
        } else {
            await MainActor.run { TelegramInbox.shared.updateOffset = 0 }
        }
    }

    private func fetchUpdates(token: String) async throws -> [TelegramMessage] {
        let offset = await MainActor.run { TelegramInbox.shared.updateOffset } ?? 0
        let result = try await request(
            token: token,
            query: "offset=\(offset)&timeout=25&allowed_updates=%5B%22message%22%5D"
        )
        let parsed = TelegramUpdateParser.parse(result)
        if let highest = parsed.highestUpdateID {
            let next = max(offset, highest + 1)
            await MainActor.run { TelegramInbox.shared.updateOffset = next }
        }
        return parsed.messages
    }

    private func request(token: String, query: String) async throws -> [[String: Any]] {
        guard let url = URL(string: "https://api.telegram.org/bot\(token)/getUpdates?\(query)") else {
            throw TelegramError.transport
        }

        let (data, response) = try await session.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TelegramError.transport
        }

        if status == 401 || (object["error_code"] as? Int) == 401 {
            throw TelegramError.unauthorized
        }
        guard (object["ok"] as? Bool) == true else {
            let description = (object["description"] as? String) ?? "Telegram rejected the request"
            throw TelegramError.api(description)
        }

        return (object["result"] as? [[String: Any]]) ?? []
    }
}

enum TelegramError: Error {
    case unauthorized
    case api(String)
    case transport

    var message: String {
        switch self {
        case .unauthorized: return "Token rejected"
        case .api(let description): return description
        case .transport: return "Network error"
        }
    }
}

/// Pure parsing so the update format can be tested without the network.
enum TelegramUpdateParser {
    static func parse(_ updates: [[String: Any]]) -> (messages: [TelegramMessage], highestUpdateID: Int?) {
        var messages: [TelegramMessage] = []
        var highest: Int?

        for update in updates {
            guard let identifier = update["update_id"] as? Int else { continue }
            highest = max(highest ?? identifier, identifier)

            guard let message = update["message"] as? [String: Any],
                  let text = message["text"] as? String,
                  let messageID = message["message_id"] as? Int
            else { continue }

            let chat = message["chat"] as? [String: Any] ?? [:]
            let from = message["from"] as? [String: Any] ?? [:]
            let chatTitle = (chat["title"] as? String)
                ?? (chat["first_name"] as? String)
                ?? (chat["username"] as? String)
                ?? "Telegram"
            let author = (from["first_name"] as? String) ?? (from["username"] as? String) ?? chatTitle
            let timestamp = (message["date"] as? NSNumber)?.doubleValue ?? Date().timeIntervalSince1970

            messages.append(
                TelegramMessage(
                    id: messageID,
                    chatTitle: chatTitle,
                    author: author,
                    text: text,
                    receivedAt: Date(timeIntervalSince1970: timestamp)
                )
            )
        }

        return (messages, highest)
    }
}
