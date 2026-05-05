import Foundation
import UIKit

private struct VersionedAppSnapshot: Codable {
    var schemaVersion: Int
    var snapshot: AppSnapshot
}

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
    private let currentSchemaVersion = 1

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
            if let versioned = try? decoder.decode(VersionedAppSnapshot.self, from: data) {
                return versioned.snapshot
            }
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

            let versioned = VersionedAppSnapshot(schemaVersion: currentSchemaVersion, snapshot: snapshot)
            let data = try encoder.encode(versioned)
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

        let versioned = VersionedAppSnapshot(schemaVersion: currentSchemaVersion, snapshot: snapshot)
        let data = try encoder.encode(versioned)
        let exportURL = fileManager.temporaryDirectory
            .appending(path: "anchor-export-\(Int(Date().timeIntervalSince1970)).json")
        try data.write(to: exportURL, options: [.atomic, .completeFileProtection])
        return exportURL
    }

    func exportTherapistReport(snapshot: AppSnapshot, memorySignals: [MemorySignal], monthlyReview: MonthlyReview?) throws -> URL {
        let exportURL = fileManager.temporaryDirectory
            .appending(path: "anchor-therapy-report-\(Int(Date().timeIntervalSince1970)).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { context in
            context.beginPage()
            var cursor: CGFloat = 40
            draw("Anchor Reflection Report", at: &cursor, size: 22, weight: .bold)
            draw("Generated \(Date().formatted(date: .abbreviated, time: .shortened))", at: &cursor, size: 10, color: .secondaryLabel)
            cursor += 10
            draw("This report is a user-controlled reflection summary. It is not therapy, diagnosis, medical care, or crisis support.", at: &cursor, size: 11, color: .secondaryLabel)
            cursor += 14

            draw("Overview", at: &cursor, size: 16, weight: .semibold)
            draw("Entries: \(snapshot.journalEntries.count)", at: &cursor)
            draw("Daily reviews: \(snapshot.dailyReviews.count)", at: &cursor)
            draw("Goals: \(snapshot.reflectionGoals.count)", at: &cursor)
            if let monthlyReview {
                draw("Current month: \(monthlyReview.monthTitle), \(monthlyReview.entryCount) entries across \(monthlyReview.activeDays) days, average mood \(String(format: "%.1f", monthlyReview.averageMood))/5.", at: &cursor)
            }
            cursor += 10

            if let monthlyReview {
                draw("Monthly Stats", at: &cursor, size: 16, weight: .semibold)
                if monthlyReview.summary.isEmpty == false {
                    draw(monthlyReview.summary, at: &cursor)
                }
                if monthlyReview.moodRange.isEmpty == false {
                    draw(monthlyReview.moodRange, at: &cursor)
                }
                draw(monthlyReview.strongestPattern, at: &cursor)
                draw(monthlyReview.progress, at: &cursor)
                draw("Next experiment: \(monthlyReview.nextExperiment)", at: &cursor)
                cursor += 10
            }

            draw("Recurring Signals", at: &cursor, size: 16, weight: .semibold)
            if memorySignals.isEmpty {
                draw("No repeated memory signals yet.", at: &cursor)
            } else {
                for signal in memorySignals.prefix(8) {
                    draw("• \(signal.title): \(signal.detail)", at: &cursor)
                }
            }
            cursor += 10

            draw("Recent Daily Reviews", at: &cursor, size: 16, weight: .semibold)
            for review in snapshot.dailyReviews.sorted(by: { $0.date > $1.date }).prefix(5) {
                draw("\(review.date.formatted(date: .abbreviated, time: .omitted)): \(review.summary)", at: &cursor)
                draw("Try next: \(review.insight.action)", at: &cursor, size: 10, color: .secondaryLabel)
            }
        }
        try data.write(to: exportURL, options: [.atomic, .completeFileProtection])
        return exportURL
    }

    private func draw(_ text: String, at cursor: inout CGFloat, size: CGFloat = 11, weight: UIFont.Weight = .regular, color: UIColor = .label) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let rect = CGRect(x: 40, y: cursor, width: 532, height: 1000)
        let height = NSString(string: text).boundingRect(
            with: CGSize(width: 532, height: 1000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        ).height
        NSString(string: text).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
        cursor += ceil(height) + 7
    }
}
