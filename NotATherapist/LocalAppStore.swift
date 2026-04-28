import Foundation

struct AppSnapshot: Codable {
    var selectedMood: MoodLevel
    var journalEntries: [JournalEntry]
    var insights: [Insight]
    var conversations: [Conversation]
    var weeklyReview: WeeklyReview
    var healthSummary: HealthSummary?
    var reflectionGoals: [ReflectionGoal]
    var dailyReviews: [DailyReview]
}

struct LocalAppStore {
    private let fileManager = FileManager.default

    private var storeURL: URL {
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "NotATherapist", directoryHint: .isDirectory)
        return directory.appending(path: "app-state.json")
    }

    func load() -> AppSnapshot? {
        do {
            let data = try Data(contentsOf: storeURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(AppSnapshot.self, from: data)
        } catch {
            return nil
        }
    }

    func save(_ snapshot: AppSnapshot) {
        do {
            let directory = storeURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            let data = try encoder.encode(snapshot)
            try data.write(to: storeURL, options: [.atomic, .completeFileProtection])
        } catch {
            assertionFailure("Failed to save app state: \(error)")
        }
    }

    func delete() {
        try? fileManager.removeItem(at: storeURL)
    }

    func export(_ snapshot: AppSnapshot) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(snapshot)
        let exportURL = fileManager.temporaryDirectory
            .appending(path: "anchor-export-\(Int(Date().timeIntervalSince1970)).json")
        try data.write(to: exportURL, options: [.atomic])
        return exportURL
    }
}
