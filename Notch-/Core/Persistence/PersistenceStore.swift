import Foundation

enum PersistenceStoreError: Error, Equatable {
    case encodingFailed(String)
    case decodingFailed(String)
}

actor PersistenceStore {
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        defaults: UserDefaults = .standard,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.defaults = defaults
        self.encoder = encoder
        self.decoder = decoder
    }

    func save<T: Codable>(_ value: T, for key: String) throws {
        do {
            let data = try encoder.encode(value)
            defaults.set(data, forKey: key)
        } catch {
            throw PersistenceStoreError.encodingFailed(key)
        }
    }

    func load<T: Codable>(_ type: T.Type, for key: String) throws -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw PersistenceStoreError.decodingFailed(key)
        }
    }

    func removeValue(for key: String) {
        defaults.removeObject(forKey: key)
    }

    func containsValue(for key: String) -> Bool {
        defaults.object(forKey: key) != nil
    }

    func setDate(_ date: Date?, for key: String) {
        defaults.set(date, forKey: key)
    }

    func date(for key: String) -> Date? {
        defaults.object(forKey: key) as? Date
    }
}
