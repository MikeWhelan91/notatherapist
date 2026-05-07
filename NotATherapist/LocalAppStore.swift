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
    var weeklyReviewHistory: [WeeklyReview]
    var monthlyReview: MonthlyReview?
    var healthSummary: HealthSummary?
    var reflectionGoals: [ReflectionGoal]
    var dailyReviews: [DailyReview]
    var calmSessions: [CalmSessionLog] = []

    init(
        selectedMood: MoodLevel,
        journalEntries: [JournalEntry],
        insights: [Insight],
        conversations: [Conversation],
        weeklyReview: WeeklyReview,
        weeklyReviewHistory: [WeeklyReview] = [],
        monthlyReview: MonthlyReview?,
        healthSummary: HealthSummary?,
        reflectionGoals: [ReflectionGoal],
        dailyReviews: [DailyReview],
        calmSessions: [CalmSessionLog] = []
    ) {
        self.selectedMood = selectedMood
        self.journalEntries = journalEntries
        self.insights = insights
        self.conversations = conversations
        self.weeklyReview = weeklyReview
        self.weeklyReviewHistory = weeklyReviewHistory
        self.monthlyReview = monthlyReview
        self.healthSummary = healthSummary
        self.reflectionGoals = reflectionGoals
        self.dailyReviews = dailyReviews
        self.calmSessions = calmSessions
    }

    private enum CodingKeys: String, CodingKey {
        case selectedMood
        case journalEntries
        case insights
        case conversations
        case weeklyReview
        case weeklyReviewHistory
        case monthlyReview
        case healthSummary
        case reflectionGoals
        case dailyReviews
        case calmSessions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedMood = try container.decode(MoodLevel.self, forKey: .selectedMood)
        journalEntries = try container.decode([JournalEntry].self, forKey: .journalEntries)
        insights = try container.decode([Insight].self, forKey: .insights)
        conversations = try container.decode([Conversation].self, forKey: .conversations)
        weeklyReview = try container.decode(WeeklyReview.self, forKey: .weeklyReview)
        weeklyReviewHistory = try container.decodeIfPresent([WeeklyReview].self, forKey: .weeklyReviewHistory) ?? []
        monthlyReview = try container.decodeIfPresent(MonthlyReview.self, forKey: .monthlyReview)
        healthSummary = try container.decodeIfPresent(HealthSummary.self, forKey: .healthSummary)
        reflectionGoals = try container.decode([ReflectionGoal].self, forKey: .reflectionGoals)
        dailyReviews = try container.decode([DailyReview].self, forKey: .dailyReviews)
        calmSessions = try container.decodeIfPresent([CalmSessionLog].self, forKey: .calmSessions) ?? []
    }
}

struct LocalAppStore {
    private let fileManager = FileManager.default
    private let currentSchemaVersion = 1

    private var storeURL: URL {
        fileURL(named: "app-state.json")
    }

    private var backupURL: URL {
        fileURL(named: "app-state.backup.json")
    }

    private func fileURL(named name: String) -> URL {
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "NotATherapist", directoryHint: .isDirectory)
        return directory.appending(path: name)
    }

    func load() -> AppSnapshot? {
        load(from: storeURL)
    }

    func save(_ snapshot: AppSnapshot) {
        save(snapshot, to: storeURL)
    }

    func delete() {
        try? fileManager.removeItem(at: storeURL)
    }

    func loadBackup() -> AppSnapshot? {
        load(from: backupURL)
    }

    func saveBackup(_ snapshot: AppSnapshot) {
        save(snapshot, to: backupURL)
    }

    func deleteBackup() {
        try? fileManager.removeItem(at: backupURL)
    }

    private func load(from url: URL) -> AppSnapshot? {
        do {
            let data = try Data(contentsOf: url)
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

    private func save(_ snapshot: AppSnapshot, to url: URL) {
        do {
            let directory = url.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            let versioned = VersionedAppSnapshot(schemaVersion: currentSchemaVersion, snapshot: snapshot)
            let data = try encoder.encode(versioned)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            assertionFailure("Failed to save app state: \(error)")
        }
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
            let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
            let contentWidth: CGFloat = 532
            let leftInset: CGFloat = 40
            let topInset: CGFloat = 40
            let bottomInset: CGFloat = 40
            let primaryColor = UIColor(white: 0.08, alpha: 1)
            let secondaryColor = UIColor(white: 0.36, alpha: 1)

            var cursor = topInset

            func requiredHeight(
                _ text: String,
                size: CGFloat,
                weight: UIFont.Weight
            ) -> CGFloat {
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineBreakMode = .byWordWrapping
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: size, weight: weight),
                    .paragraphStyle: paragraph
                ]
                let height = NSString(string: text).boundingRect(
                    with: CGSize(width: contentWidth, height: 1000),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                ).height
                return ceil(height) + 7
            }

            func beginPageIfNeeded(nextBlockHeight: CGFloat) {
                if cursor + nextBlockHeight <= pageBounds.height - bottomInset {
                    return
                }
                context.beginPage()
                cursor = topInset
            }

            func drawText(
                _ text: String,
                size: CGFloat = 11,
                weight: UIFont.Weight = .regular,
                color: UIColor = UIColor(white: 0.08, alpha: 1)
            ) {
                let height = requiredHeight(text, size: size, weight: weight)
                beginPageIfNeeded(nextBlockHeight: height)
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineBreakMode = .byWordWrapping
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: size, weight: weight),
                    .foregroundColor: color,
                    .paragraphStyle: paragraph
                ]
                let rect = CGRect(x: leftInset, y: cursor, width: contentWidth, height: 1000)
                NSString(string: text).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
                cursor += height
            }

            func drawSectionTitle(_ text: String) {
                cursor += 8
                drawText(text, size: 16, weight: .semibold, color: primaryColor)
                cursor += 2
            }

            context.beginPage()

            drawText("Anchor Reflection Report", size: 22, weight: .bold, color: primaryColor)
            drawText("Generated \(Date().formatted(date: .abbreviated, time: .shortened))", size: 10, weight: .regular, color: secondaryColor)
            cursor += 10
            drawText("This report is a user-controlled reflection summary. It is not therapy, diagnosis, medical care, or crisis support.", size: 11, weight: .regular, color: secondaryColor)
            cursor += 14

            drawSectionTitle("Overview")
            drawText("Entries: \(snapshot.journalEntries.count)", color: primaryColor)
            drawText("Daily reviews: \(snapshot.dailyReviews.count)", color: primaryColor)
            drawText("Goals: \(snapshot.reflectionGoals.count)", color: primaryColor)
            if let monthlyReview {
                drawText("Current month: \(monthlyReview.monthTitle), \(monthlyReview.entryCount) entries across \(monthlyReview.activeDays) days, average mood \(String(format: "%.1f", monthlyReview.averageMood))/5.", color: primaryColor)
            }

            if let monthlyReview {
                drawSectionTitle("Monthly Stats")
                if monthlyReview.summary.isEmpty == false {
                    drawText(monthlyReview.summary, color: primaryColor)
                }
                if monthlyReview.moodRange.isEmpty == false {
                    drawText(monthlyReview.moodRange, color: primaryColor)
                }
                if monthlyReview.strongestPattern.isEmpty == false {
                    drawText(monthlyReview.strongestPattern, color: primaryColor)
                }
                if monthlyReview.progress.isEmpty == false {
                    drawText(monthlyReview.progress, color: primaryColor)
                }
                if monthlyReview.nextExperiment.isEmpty == false {
                    drawText("Next focus: \(monthlyReview.nextExperiment)", color: primaryColor)
                }
            }

            drawSectionTitle("Recurring Signals")
            if memorySignals.isEmpty {
                drawText("No repeated memory signals yet.", color: secondaryColor)
            } else {
                for signal in memorySignals.prefix(8) {
                    drawText("• \(signal.title): \(signal.detail)", color: primaryColor)
                }
            }

            drawSectionTitle("Recent Daily Reviews")
            for review in snapshot.dailyReviews.sorted(by: { $0.date > $1.date }).prefix(5) {
                drawText("\(review.date.formatted(date: .abbreviated, time: .omitted)): \(review.summary)", color: primaryColor)
                drawText("Try next: \(review.insight.action)", size: 10, weight: .regular, color: secondaryColor)
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
