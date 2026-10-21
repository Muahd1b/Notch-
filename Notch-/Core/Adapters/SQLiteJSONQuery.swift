import Foundation

/// Minimal bridge to the system `sqlite3` binary so the app can read local agent databases
/// without linking SQLite into the target.
enum SQLiteJSONQuery {
    static func run(databasePath: String, query: String) async -> [[String: Any]]? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: runSync(databasePath: databasePath, query: query))
            }
        }
    }

    private static func runSync(databasePath: String, query: String) -> [[String: Any]]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-readonly", "-json", databasePath, query]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0, !data.isEmpty else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
    }
}
