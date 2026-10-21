import Foundation
import Testing
@testable import Notch_

@Suite("Telegram updates")
struct TelegramUpdateParserTests {
    private func update(
        id: Int,
        messageID: Int,
        text: String?,
        chatTitle: String? = "Jonas",
        date: TimeInterval = 1_792_000_000
    ) -> [String: Any] {
        var message: [String: Any] = [
            "message_id": messageID,
            "date": date,
            "chat": ["id": 42, "first_name": chatTitle ?? "Jonas"],
            "from": ["first_name": "Jonas"],
        ]
        if let text { message["text"] = text }
        return ["update_id": id, "message": message]
    }

    @Test("Text messages map to inbox rows")
    func parsesMessages() {
        let result = TelegramUpdateParser.parse([
            update(id: 10, messageID: 1, text: "Ship the ops tab"),
            update(id: 11, messageID: 2, text: "And the notifications page"),
        ])

        #expect(result.messages.count == 2)
        #expect(result.messages.first?.text == "Ship the ops tab")
        #expect(result.messages.first?.chatTitle == "Jonas")
        #expect(result.highestUpdateID == 11)
    }

    @Test("Non-text updates are ignored but still advance the offset")
    func skipsNonText() {
        let result = TelegramUpdateParser.parse([
            ["update_id": 20, "edited_message": ["message_id": 3]],
            update(id: 21, messageID: 4, text: nil),
            update(id: 22, messageID: 5, text: "only this one"),
        ])

        #expect(result.messages.count == 1)
        #expect(result.messages.first?.text == "only this one")
        #expect(result.highestUpdateID == 22)
    }

    @Test("Empty payload is a no-op")
    func emptyPayload() {
        let result = TelegramUpdateParser.parse([])
        #expect(result.messages.isEmpty)
        #expect(result.highestUpdateID == nil)
    }

    @Test("Inbox deduplicates by message id")
    @MainActor
    func inboxDeduplicates() {
        let defaults = UserDefaults(suiteName: "telegram-inbox-test-\(UUID().uuidString)") ?? .standard
        let inbox = TelegramInbox(defaults: defaults)
        let message = TelegramMessage(id: 1, chatTitle: "Jonas", author: "Jonas", text: "hi", receivedAt: Date())

        inbox.append([message])
        inbox.append([message])

        #expect(inbox.messages.count == 1)
        #expect(inbox.unreadCount == 1)
    }
}
