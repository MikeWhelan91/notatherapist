import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var selectedMood: MoodLevel = .okay
    @Published var journalEntries: [JournalEntry]
    @Published var insights: [Insight]
    @Published var conversations: [Conversation] = []
    @Published var weeklyReview: WeeklyReview
    @Published var sounds: [CalmSound] = MockData.sounds
    @Published var selectedJournalDate: Date = Date()
    @Published var onboardingProfile: OnboardingProfile = .current
    @Published var healthSummary: HealthSummary?
    @Published var reflectionGoals: [ReflectionGoal] = []
    @Published var dailyReviews: [DailyReview] = []

    private let insightService = MockAIInsightService()
    private let weeklyReviewService = MockWeeklyReviewService()
    private let conversationService = MockConversationService()
    private let apiService = NotATherapistAPIService()

    init(seedWithMockData: Bool = false) {
        let initialEntries = seedWithMockData ? MockData.entries : []
        journalEntries = initialEntries
        insights = seedWithMockData ? MockData.insights : []
        weeklyReview = weeklyReviewService.latestReview(from: initialEntries)
    }

    var latestInsight: Insight? {
        insights.sorted { $0.date > $1.date }.first
    }

    var latestDailyReview: DailyReview? {
        dailyReviews.sorted { $0.createdAt > $1.createdAt }.first
    }

    var currentWeekDates: [Date] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedJournalDate)?.start ?? Date()
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    func entries(on date: Date) -> [JournalEntry] {
        journalEntries
            .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }

    func checkInCountThisWeek() -> Int {
        currentWeekDates.filter { day in
            journalEntries.contains { Calendar.current.isDate($0.date, inSameDayAs: day) }
        }.count
    }

    var hasWeeklyReview: Bool {
        let dayCount = Set(journalEntries.map { Calendar.current.startOfDay(for: $0.date) }).count
        return dayCount >= 3 || journalEntries.count >= 5
    }

    func addEntry(text: String, mood: MoodLevel, type: EntryType, date: Date = Date()) -> JournalEntry {
        onboardingProfile = .current
        let themes = insightService.themes(for: text, entryType: type)
        let entry = JournalEntry(
            id: UUID(),
            date: date,
            mood: mood,
            entryType: type,
            text: text,
            aiInsight: StructuredInsight(emotionalRead: "", pattern: "", reframe: "", action: ""),
            themes: themes,
            sleepHours: healthSummary?.lastNightSleep,
            steps: healthSummary?.averageSteps
        )
        journalEntries.insert(entry, at: 0)

        checkForGoalProgress(in: entry)
        weeklyReview = weeklyReviewService.latestReview(from: journalEntries, healthSummary: healthSummary)
        selectedMood = mood
        return entry
    }

    func dailyReview(on date: Date) -> DailyReview? {
        dailyReviews.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    @discardableResult
    func reviewDay(_ date: Date) async -> DailyReview? {
        onboardingProfile = .current
        let dayEntries = entries(on: date)
        guard dayEntries.isEmpty == false else { return nil }

        let review: DailyReview
        do {
            review = try await apiService.dailyReview(
                date: date,
                entries: dayEntries,
                profile: onboardingProfile,
                healthSummary: healthSummary
            )
        } catch {
            guard let fallback = insightService.dailyReview(
                for: date,
                entries: dayEntries,
                profile: onboardingProfile,
                healthSummary: healthSummary
            ) else { return nil }
            review = fallback
        }

        var storedReview = review

        if let existingIndex = dailyReviews.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            storedReview.acceptedGoalID = dailyReviews[existingIndex].acceptedGoalID
            dailyReviews[existingIndex] = storedReview
        } else {
            dailyReviews.insert(storedReview, at: 0)
        }

        replaceInsights(for: storedReview)
        await refreshWeeklyReview()
        return storedReview
    }

    @discardableResult
    func acceptGoal(from review: DailyReview) -> ReflectionGoal {
        let goal = addReflectionGoal(
            title: review.suggestedGoalTitle,
            reason: review.suggestedGoalReason,
            sourceConversationID: nil
        )
        if let index = dailyReviews.firstIndex(where: { $0.id == review.id }) {
            dailyReviews[index].acceptedGoalID = goal.id
        }
        return goal
    }

    func updateHealthSummary(_ summary: HealthSummary?) {
        healthSummary = summary
        weeklyReview = weeklyReviewService.latestReview(from: journalEntries, healthSummary: summary)
    }

    func refreshWeeklyReview() async {
        guard hasWeeklyReview else {
            weeklyReview = weeklyReviewService.latestReview(from: journalEntries, healthSummary: healthSummary)
            return
        }

        onboardingProfile = .current
        do {
            if let review = try await apiService.weeklyReview(
                entries: journalEntries,
                profile: onboardingProfile,
                healthSummary: healthSummary
            ) {
                weeklyReview = review
            }
        } catch {
            weeklyReview = weeklyReviewService.latestReview(from: journalEntries, healthSummary: healthSummary)
        }
    }

    func startWeeklyConversation() async -> Conversation {
        onboardingProfile = .current
        await refreshWeeklyReview()

        let conversation: Conversation
        do {
            conversation = try await apiService.startConversation(weeklyReview: weeklyReview, profile: onboardingProfile)
        } catch {
            conversation = conversationService.newWeeklyConversation(review: weeklyReview, profile: onboardingProfile)
        }

        conversations.insert(conversation, at: 0)
        return conversation
    }

    func sendMessage(_ text: String, in conversation: Conversation, action: String? = nil) async -> Conversation {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else { return conversation }
        var updated = conversations[index]
        guard updated.status == .active, updated.remainingTurns > 0 else { return updated }

        let displayText = action ?? text
        updated.messages.append(ConversationMessage(id: UUID(), sender: .user, text: displayText, date: Date()))

        if action == "End for today" {
            updated.status = .ended
            updated.messages.append(ConversationMessage(id: UUID(), sender: .ai, text: "That's enough for today. Let it sit.", date: Date()))
        } else {
            onboardingProfile = .current
            let response: ConversationReplyResponse?
            do {
                response = try await apiService.reply(
                    text: text,
                    action: action,
                    remainingTurns: updated.remainingTurns,
                    conversation: updated,
                    profile: onboardingProfile
                )
            } catch {
                response = nil
            }

            let reply: String
            if let response {
                updated.remainingTurns = response.remainingTurns
                updated.status = response.status
                reply = response.reply
                if let goal = response.suggestedGoal {
                    reflectionGoals.insert(goal, at: 0)
                    updated.preview = "Goal added: \(goal.title)"
                }
            } else {
                updated.remainingTurns -= 1
                if updated.remainingTurns == 0 {
                    updated.status = .ended
                    reply = "That's enough for today. Let it sit."
                } else {
                    reply = conversationService.reply(to: text, action: action, remainingTurns: updated.remainingTurns, profile: onboardingProfile)
                }
            }

            updated.messages.append(ConversationMessage(id: UUID(), sender: .ai, text: reply, date: Date()))
            updated.preview = reply

            if action == "Give me one action", response?.suggestedGoal == nil {
                let goal = addReflectionGoal(
                    title: "Finish one small unfinished thing",
                    reason: "Agreed during the weekly check-in.",
                    sourceConversationID: updated.id
                )
                updated.messages.append(
                    ConversationMessage(
                        id: UUID(),
                        sender: .ai,
                        text: "I added this to Today: \(goal.title). We can check it at the next review.",
                        date: Date()
                    )
                )
                updated.preview = "Goal added: \(goal.title)"
            }
        }

        conversations[index] = updated
        return updated
    }

    @discardableResult
    func addReflectionGoal(title: String, reason: String, sourceConversationID: UUID? = nil) -> ReflectionGoal {
        let existing = reflectionGoals.first {
            $0.status == .active && $0.title.caseInsensitiveCompare(title) == .orderedSame
        }
        if let existing {
            return existing
        }

        let goal = ReflectionGoal(
            id: UUID(),
            title: title,
            reason: reason,
            createdAt: Date(),
            dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
            status: .active,
            sourceConversationID: sourceConversationID,
            checkInPrompt: "How did this go: \(title.lowercased())?"
        )
        reflectionGoals.insert(goal, at: 0)
        return goal
    }

    func toggleGoal(_ goal: ReflectionGoal) {
        guard let index = reflectionGoals.firstIndex(where: { $0.id == goal.id }) else { return }
        reflectionGoals[index].status = reflectionGoals[index].status == .active ? .completed : .active
    }

    private func checkForGoalProgress(in entry: JournalEntry) {
        let lowerText = entry.text.lowercased()
        let progressWords = ["done", "finished", "closed", "sorted", "sent", "completed"]
        guard progressWords.contains(where: lowerText.contains) else { return }

        guard let index = reflectionGoals.firstIndex(where: { goal in
            guard goal.status == .active else { return false }
            let keywords = goal.title
                .lowercased()
                .split(separator: " ")
                .map(String.init)
                .filter { $0.count > 3 }
            return keywords.contains(where: lowerText.contains)
        }) else { return }

        reflectionGoals[index].status = .completed
        insights.insert(
            Insight(
                id: UUID(),
                title: "Goal noticed",
                body: "You appear to have made progress on \(reflectionGoals[index].title.lowercased()).",
                category: "Suggestions",
                date: entry.date,
                type: .suggestion
            ),
            at: 0
        )
    }

    private func replaceInsights(for review: DailyReview) {
        insights.removeAll { insight in
            Calendar.current.isDate(insight.date, inSameDayAs: review.date)
        }

        let generated = [
            Insight(id: UUID(), title: "Daily review", body: review.summary, category: "Recent", date: review.createdAt, type: .emotionalRead),
            Insight(id: UUID(), title: "Pattern", body: review.insight.pattern, category: "Patterns", date: review.createdAt, type: .pattern),
            Insight(id: UUID(), title: "One useful next step", body: review.insight.action, category: "Suggestions", date: review.createdAt, type: .action)
        ]
        insights.insert(contentsOf: generated, at: 0)
    }
}
