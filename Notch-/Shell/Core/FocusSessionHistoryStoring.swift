import Foundation

protocol FocusSessionHistoryStoring: Sendable {
    func loadHistory() async -> [FocusSessionRecord]
    func append(_ record: FocusSessionRecord) async
    func clearHistory() async
}
