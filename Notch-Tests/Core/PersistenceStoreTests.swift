import Foundation
import Testing
@testable import Notch_

private struct PersistenceSample: Codable, Equatable {
    let value: Int
    let label: String
}

struct PersistenceStoreTests {
    @Test
    func saveLoadAndRemoveRoundTrip() async throws {
        let suiteName = "PersistenceStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PersistenceStore(defaults: defaults)
        let sample = PersistenceSample(value: 42, label: "phase-1")

        try await store.save(sample, for: "sample-key")
        let loaded = try await store.load(PersistenceSample.self, for: "sample-key")
        #expect(loaded == sample)

        await store.removeValue(for: "sample-key")
        let removed = try await store.load(PersistenceSample.self, for: "sample-key")
        #expect(removed == nil)
    }

    @Test
    func loadThrowsWhenStoredPayloadCannotDecode() async {
        let suiteName = "PersistenceStoreDecodeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(Data([0x01, 0x02, 0x03]), forKey: "bad")
        let store = PersistenceStore(defaults: defaults)

        await #expect(throws: PersistenceStoreError.decodingFailed("bad")) {
            _ = try await store.load(PersistenceSample.self, for: "bad")
        }
    }
}
