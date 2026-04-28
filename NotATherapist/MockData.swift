import Foundation

enum MockData {
    static let calendar = Calendar.current

    static var entries: [JournalEntry] {
        let service = MockAIInsightService()
        let drafts: [(Int, MoodLevel, EntryType, String)] = [
            (-6, .okay, .reflection, "Sunday evening felt heavier than it needed to. Work kept coming back into my head."),
            (-5, .good, .win, "Went for a long walk before answering messages. I felt clearer afterwards."),
            (-4, .low, .rant, "Too many open tabs, too many requests, and not enough clean stopping points."),
            (-2, .okay, .quickThought, "I slept badly but writing the list down helped a little."),
            (-1, .good, .reflection, "The meeting was fine once I picked the one point I actually needed to make."),
            (0, .okay, .quickThought, "I keep circling the same work decision. It might need one small close rather than more thinking.")
        ]

        var built: [JournalEntry] = []
        for draft in drafts {
            let date = calendar.date(byAdding: .day, value: draft.0, to: Date()) ?? Date()
            let themes = service.themes(for: draft.3, entryType: draft.2)
            var entry = JournalEntry(
                id: UUID(),
                date: date,
                mood: draft.1,
                entryType: draft.2,
                text: draft.3,
                aiInsight: StructuredInsight(emotionalRead: "", pattern: "", reframe: "", action: ""),
                themes: themes
            )
            entry.aiInsight = service.insight(for: entry, recentEntries: built)
            built.append(entry)
        }
        return built.sorted { $0.date > $1.date }
    }

    static var insights: [Insight] {
        [
            Insight(id: UUID(), title: "Unfinished decisions", body: "Work entries often mention unfinished decisions.", category: "Patterns", date: Date(), type: .pattern),
            Insight(id: UUID(), title: "Movement helps", body: "Mood trends higher on days with a walk or gym note.", category: "Suggestions", date: calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date(), type: .suggestion),
            Insight(id: UUID(), title: "Sunday pressure", body: "Stress tends to appear before the week starts.", category: "Recent", date: calendar.date(byAdding: .day, value: -2, to: Date()) ?? Date(), type: .emotionalRead),
            Insight(id: UUID(), title: "One close", body: "A single finished task may help more than a longer plan.", category: "Suggestions", date: calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date(), type: .action)
        ]
    }

    static var sounds: [CalmSound] {
        [
            CalmSound(id: UUID(), title: "Rain", subtitle: "Soft steady rain", icon: "cloud.rain", duration: "20 min"),
            CalmSound(id: UUID(), title: "Ocean", subtitle: "Low shore wash", icon: "water.waves", duration: "18 min"),
            CalmSound(id: UUID(), title: "Forest", subtitle: "Light wind in trees", icon: "leaf", duration: "16 min"),
            CalmSound(id: UUID(), title: "Night", subtitle: "Quiet room tone", icon: "moon", duration: "25 min"),
            CalmSound(id: UUID(), title: "Fan", subtitle: "Even white noise", icon: "fan", duration: "30 min")
        ]
    }
}
