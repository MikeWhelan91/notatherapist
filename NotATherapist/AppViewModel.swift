import Foundation
import SwiftUI
import WidgetKit

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
    @Published var aiConnection: AIConnectionState = .unknown
    @Published var iCloudSyncState: ICloudSyncState = .off
    @Published var planTier: AppPlanTier
    @Published var widgetStylePreset: WidgetStylePreset
    @Published var widgetAffirmationCategories: Set<WidgetAffirmationCategory>

    private let insightService = MockAIInsightService()
    private let weeklyReviewService = MockWeeklyReviewService()
    private let conversationService = MockConversationService()
    private let apiService = NotATherapistAPIService()
    private let localStore = LocalAppStore()
    private let widgetPayloadStore = WidgetPayloadStore()
    private let iCloudSyncService = ICloudSyncService.shared
    private let iCloudSyncEnabledKey = "iCloudSyncEnabled"
    private let planTierKey = "appPlanTier"
    private let widgetStylePresetKey = "widgetStylePreset"
    private let widgetAffirmationCategoriesKey = "widgetAffirmationCategories"
    private let widgetAffirmationIndexKey = "widgetAffirmationIndex"

    init(seedWithMockData: Bool = false) {
        let defaults = UserDefaults.standard
        let savedTier = defaults.string(forKey: planTierKey)
        let migratedPremium = defaults.bool(forKey: "premiumDailyReviewsEnabled")
        _planTier = Published(initialValue: AppPlanTier(rawValue: savedTier ?? "") ?? (migratedPremium ? .premium : .free))
        _widgetStylePreset = Published(initialValue: WidgetStylePreset(rawValue: defaults.string(forKey: widgetStylePresetKey) ?? "") ?? .minimal)
        let storedCategoryIDs = defaults.stringArray(forKey: widgetAffirmationCategoriesKey) ?? []
        let storedCategories = Set(storedCategoryIDs.compactMap(WidgetAffirmationCategory.init(rawValue:)))
        _widgetAffirmationCategories = Published(initialValue: storedCategories.isEmpty ? Set(WidgetAffirmationCategory.allCases) : storedCategories)

        if seedWithMockData {
            let initialEntries = MockData.entries
            journalEntries = initialEntries
            insights = MockData.insights
            weeklyReview = weeklyReviewService.latestReview(from: initialEntries)
        } else if let snapshot = localStore.load() {
            selectedMood = snapshot.selectedMood
            journalEntries = snapshot.journalEntries
            insights = snapshot.insights
            conversations = snapshot.conversations
            weeklyReview = snapshot.weeklyReview
            healthSummary = snapshot.healthSummary
            reflectionGoals = snapshot.reflectionGoals
            dailyReviews = snapshot.dailyReviews
        } else {
            journalEntries = []
            insights = []
            weeklyReview = weeklyReviewService.latestReview(from: [])
        }
        refreshWidgetPayload()
    }

    var latestInsight: Insight? {
        insights.sorted { $0.date > $1.date }.first
    }

    var localSignals: [Insight] {
        insightService.localSignals(
            from: journalEntries,
            dailyReviews: dailyReviews,
            goals: reflectionGoals,
            healthSummary: healthSummary
        )
    }

    var hasInsightContent: Bool {
        insights.isEmpty == false || localSignals.isEmpty == false
    }

    var isPremium: Bool {
        get { planTier == .premium }
        set {
            planTier = newValue ? .premium : .free
            UserDefaults.standard.set(planTier.rawValue, forKey: planTierKey)
            refreshWidgetPayload()
        }
    }

    func updatePreferredName(_ name: String) {
        UserDefaults.standard.set(name, forKey: "onboardingPreferredName")
        onboardingProfile = .current
        refreshWidgetPayload()
    }

    func updateWidgetStylePreset(_ style: WidgetStylePreset) {
        widgetStylePreset = style
        UserDefaults.standard.set(style.rawValue, forKey: widgetStylePresetKey)
        refreshWidgetPayload()
    }

    func setWidgetAffirmationCategory(_ category: WidgetAffirmationCategory, enabled: Bool) {
        if enabled {
            widgetAffirmationCategories.insert(category)
        } else if widgetAffirmationCategories.count > 1 {
            widgetAffirmationCategories.remove(category)
        }
        UserDefaults.standard.set(widgetAffirmationCategories.map(\.rawValue), forKey: widgetAffirmationCategoriesKey)
        refreshWidgetPayload()
    }

    func cycleWidgetAffirmation() {
        let defaults = UserDefaults.standard
        let options = widgetAffirmationOptions()
        guard options.isEmpty == false else { return }
        let next = (defaults.integer(forKey: widgetAffirmationIndexKey) + 1) % options.count
        defaults.set(next, forKey: widgetAffirmationIndexKey)
        refreshWidgetPayload()
    }

    func handle(_ command: AnchorAppCommand, router: AppRouter) {
        switch command {
        case .newQuickThought:
            router.openNewQuickThought()
        case .runDailyReview:
            router.runDailyReview()
        case .startWeeklyCheckIn:
            router.openWeeklyCheckIn()
        case .nextAffirmation:
            cycleWidgetAffirmation()
        }
    }

    func updateOnboardingProfile(
        preferredName: String,
        ageRange: String,
        lifeContext: [String],
        focusAreas: [String],
        reflectionGoal: String,
        personalStory: String,
        assessment: OnboardingProfile.AssessmentProfile? = nil
    ) {
        let defaults = UserDefaults.standard
        defaults.set(preferredName, forKey: "onboardingPreferredName")
        defaults.set(ageRange, forKey: "onboardingAgeRange")
        defaults.set(lifeContext.joined(separator: "|"), forKey: "onboardingLifeContext")
        defaults.set(focusAreas.joined(separator: "|"), forKey: "onboardingFocusAreas")
        defaults.set(reflectionGoal, forKey: "onboardingReflectionGoal")
        defaults.set(personalStory, forKey: "onboardingPersonalStory")

        let profile = OnboardingProfile(
            preferredName: preferredName,
            ageRange: ageRange,
            lifeContext: lifeContext,
            focusAreas: focusAreas,
            reflectionGoal: reflectionGoal,
            personalStory: personalStory,
            assessment: assessment
        )
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: "onboardingProfileV2")
        }

        onboardingProfile = .current
        saveSnapshot()
    }

    var latestDailyReview: DailyReview? {
        dailyReviews.sorted { $0.createdAt > $1.createdAt }.first
    }

    var currentWeekDates: [Date] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedJournalDate)?.start ?? Date()
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var centeredTodayDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (-3...3).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
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
        saveSnapshot()
        return entry
    }

    func dailyReview(on date: Date) -> DailyReview? {
        dailyReviews
            .first { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .map(sanitizedReview)
    }

    @discardableResult
    func reviewDay(_ date: Date) async -> DailyReview? {
        onboardingProfile = .current
        let dayEntries = entries(on: date)
        guard dayEntries.isEmpty == false else { return nil }
        let recentEntries = dailyContextEntries(for: date)

        let review: DailyReview
        if planTier == .premium {
            do {
                review = try await apiService.dailyReview(
                    date: date,
                    entries: dayEntries,
                    recentEntries: recentEntries,
                    profile: onboardingProfile,
                    healthSummary: healthSummary,
                    goals: reflectionGoals
                )
                if review.source != "openai" {
                    aiConnection = .unavailable
                    return nil
                }
            } catch {
                aiConnection = .unavailable
                return nil
            }
        } else {
            guard let fallback = insightService.dailyReview(
                for: date,
                entries: dayEntries,
                recentEntries: recentEntries,
                profile: onboardingProfile,
                healthSummary: healthSummary
            ) else { return nil }
            review = fallback
        }

        var storedReview = sanitizedReview(review)

        if let existingIndex = dailyReviews.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            storedReview.acceptedGoalID = dailyReviews[existingIndex].acceptedGoalID
            dailyReviews[existingIndex] = storedReview
        } else {
            dailyReviews.insert(storedReview, at: 0)
        }

        replaceInsights(for: storedReview)
        await refreshWeeklyReview()
        saveSnapshot()
        return storedReview
    }

    @discardableResult
    func generateOnboardingFirstReflection(for date: Date) async -> DailyReview? {
        onboardingProfile = .current
        let dayEntries = entries(on: date)
        guard dayEntries.isEmpty == false else { return nil }
        let recentEntries = dailyContextEntries(for: date)

        let review: DailyReview
        do {
            review = try await apiService.onboardingDailyReview(
                date: date,
                entries: dayEntries,
                recentEntries: recentEntries,
                profile: onboardingProfile,
                healthSummary: healthSummary,
                goals: reflectionGoals
            )
            aiConnection = review.source == "openai" ? .connected(model: "openai") : .unknown
        } catch {
            guard let fallback = insightService.dailyReview(
                for: date,
                entries: dayEntries,
                recentEntries: recentEntries,
                profile: onboardingProfile,
                healthSummary: healthSummary
            ) else { return nil }
            review = fallback
            aiConnection = .unavailable
        }

        var storedReview = sanitizedReview(review)
        if let existingIndex = dailyReviews.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            storedReview.acceptedGoalID = dailyReviews[existingIndex].acceptedGoalID
            dailyReviews[existingIndex] = storedReview
        } else {
            dailyReviews.insert(storedReview, at: 0)
        }

        replaceInsights(for: storedReview)
        await refreshWeeklyReview()
        saveSnapshot()
        return storedReview
    }

    private func dailyContextEntries(for date: Date) -> [JournalEntry] {
        let windowDays = planTier == .premium ? 21 : 5
        let maxEntries = planTier == .premium ? 90 : 20
        return contextEntries(for: date, windowDays: windowDays, maxEntries: maxEntries)
    }

    private func weeklyContextEntries(for date: Date = Date()) -> [JournalEntry] {
        let windowDays = planTier == .premium ? 120 : 30
        let maxEntries = planTier == .premium ? 220 : 45
        let scoped = contextEntries(for: date, windowDays: windowDays, maxEntries: maxEntries, includeSameDay: true)
        if scoped.count >= 5 {
            return scoped
        }
        return journalEntries.sorted { $0.date < $1.date }
    }

    private func contextEntries(for date: Date, windowDays: Int, maxEntries: Int, includeSameDay: Bool = false) -> [JournalEntry] {
        let start = Calendar.current.date(byAdding: .day, value: -windowDays, to: date) ?? date
        let filtered = journalEntries
            .filter { entry in
                entry.date >= start &&
                entry.date <= date &&
                (includeSameDay || Calendar.current.isDate(entry.date, inSameDayAs: date) == false)
            }
            .sorted { $0.date < $1.date }
        if filtered.count <= maxEntries {
            return filtered
        }
        return Array(filtered.suffix(maxEntries))
    }

    @discardableResult
    func acceptGoal(from review: DailyReview) -> ReflectionGoal {
        let review = sanitizedReview(review)
        let title = review.suggestedGoalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            return addReflectionGoal(
                title: "One small next step",
                reason: "Saved from your daily review.",
                sourceConversationID: nil
            )
        }
        let goal = addReflectionGoal(
            title: title,
            reason: review.suggestedGoalReason,
            sourceConversationID: nil
        )
        if let index = dailyReviews.firstIndex(where: { $0.id == review.id }) {
            dailyReviews[index].acceptedGoalID = goal.id
        }
        saveSnapshot()
        return goal
    }

    private func sanitizedReview(_ review: DailyReview) -> DailyReview {
        var review = review

        if review.insight.emotionalRead == "Today reads steadier than usual." {
            review.insight.emotionalRead = "There is a steady moment in today's entries."
        }

        return review
    }

    func updateHealthSummary(_ summary: HealthSummary?) {
        healthSummary = summary
        weeklyReview = weeklyReviewService.latestReview(from: journalEntries, healthSummary: summary)
        saveSnapshot()
    }

    func refreshWeeklyReview() async {
        let scopedEntries = weeklyContextEntries()
        guard hasWeeklyReview else {
            weeklyReview = weeklyReviewService.latestReview(from: scopedEntries, healthSummary: healthSummary)
            return
        }

        onboardingProfile = .current
        do {
            if let review = try await apiService.weeklyReview(
                entries: scopedEntries,
                profile: onboardingProfile,
                healthSummary: healthSummary,
                goals: reflectionGoals,
                planTier: planTier
            ) {
                weeklyReview = review
            }
        } catch {
            weeklyReview = weeklyReviewService.latestReview(from: scopedEntries, healthSummary: healthSummary)
        }
        saveSnapshot()
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
        saveSnapshot()
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
                    profile: onboardingProfile,
                    planTier: planTier
                )
            } catch {
                response = nil
            }

            let reply: String
            if let response {
                updated.remainingTurns = response.remainingTurns
                updated.status = response.status
                if let maxTurns = response.maxTurns {
                    updated.maxTurns = maxTurns
                }
                if let deepeningUsed = response.deepeningUsed {
                    updated.deepeningUsed = deepeningUsed
                }
                if let phase = response.phase {
                    updated.phase = phase
                }
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

            let replyContext = response?.replyContext?.trimmingCharacters(in: .whitespacesAndNewlines)
            let contextNote = (updated.phase == .deeper && (replyContext?.isEmpty == false)) ? replyContext : nil
            updated.messages.append(
                ConversationMessage(
                    id: UUID(),
                    sender: .ai,
                    text: reply,
                    date: Date(),
                    replyContext: contextNote
                )
            )
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
        saveSnapshot()
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
        saveSnapshot()
        return goal
    }

    func toggleGoal(_ goal: ReflectionGoal) {
        guard let index = reflectionGoals.firstIndex(where: { $0.id == goal.id }) else { return }
        reflectionGoals[index].status = reflectionGoals[index].status == .active ? .completed : .active
        saveSnapshot()
    }

    func refreshAIConnection() async {
        aiConnection = .checking
        do {
            let health = try await apiService.health()
            aiConnection = health.ai == "configured" ? .connected(model: health.model) : .fallback(model: health.model)
        } catch {
            aiConnection = .unavailable
        }
    }

    func exportLocalData() -> URL? {
        try? localStore.export(snapshot)
    }

    func deleteLocalData() {
        journalEntries = []
        insights = []
        conversations = []
        weeklyReview = weeklyReviewService.latestReview(from: [])
        healthSummary = nil
        reflectionGoals = []
        dailyReviews = []
        selectedMood = .okay
        localStore.delete()
    }

    var isICloudSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: iCloudSyncEnabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: iCloudSyncEnabledKey)
            iCloudSyncState = newValue ? .checking : .off
        }
    }

    func refreshICloudStatus() async {
        guard isICloudSyncEnabled else {
            iCloudSyncState = .off
            return
        }
        iCloudSyncState = .checking
        iCloudSyncState = await iCloudSyncService.accountStatus()
    }

    func pushToICloud() async {
        guard isICloudSyncEnabled else { return }
        iCloudSyncState = .checking
        do {
            let date = try await iCloudSyncService.push(snapshot)
            iCloudSyncState = .synced(date)
        } catch {
            iCloudSyncState = .unavailable("iCloud sync failed")
        }
    }

    func pullFromICloud() async {
        guard isICloudSyncEnabled else { return }
        iCloudSyncState = .checking
        do {
            if let snapshot = try await iCloudSyncService.pull() {
                apply(snapshot)
                saveSnapshot()
                iCloudSyncState = .synced(Date())
            } else {
                iCloudSyncState = .available
            }
        } catch {
            iCloudSyncState = .unavailable("No iCloud data")
        }
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

    private var snapshot: AppSnapshot {
        AppSnapshot(
            selectedMood: selectedMood,
            journalEntries: journalEntries,
            insights: insights,
            conversations: conversations,
            weeklyReview: weeklyReview,
            healthSummary: healthSummary,
            reflectionGoals: reflectionGoals,
            dailyReviews: dailyReviews
        )
    }

    private func saveSnapshot() {
        localStore.save(snapshot)
        refreshWidgetPayload()
        if isICloudSyncEnabled {
            Task {
                await pushToICloud()
            }
        }
    }

    private func apply(_ snapshot: AppSnapshot) {
        selectedMood = snapshot.selectedMood
        journalEntries = snapshot.journalEntries
        insights = snapshot.insights
        conversations = snapshot.conversations
        weeklyReview = snapshot.weeklyReview
        healthSummary = snapshot.healthSummary
        reflectionGoals = snapshot.reflectionGoals
        dailyReviews = snapshot.dailyReviews
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

    private func refreshWidgetPayload() {
        let affirmationOptions = widgetAffirmationOptions()
        let defaults = UserDefaults.standard
        let savedIndex = defaults.integer(forKey: widgetAffirmationIndexKey)
        let normalizedIndex = affirmationOptions.isEmpty ? 0 : min(savedIndex, affirmationOptions.count - 1)
        defaults.set(normalizedIndex, forKey: widgetAffirmationIndexKey)
        let payload = WidgetAffirmationPayload(
            preferredName: onboardingProfile.preferredName,
            planTier: planTier == .premium ? .premium : .free,
            primaryText: widgetPrimaryText(),
            secondaryText: widgetSecondaryText(),
            affirmationText: affirmationOptions.isEmpty ? nil : affirmationOptions[normalizedIndex],
            affirmationOptions: affirmationOptions,
            affirmationIndex: normalizedIndex,
            stylePreset: widgetStylePreset,
            enabledCategories: Array(widgetAffirmationCategories),
            issueContext: widgetIssueContext(),
            updatedAt: Date()
        )
        widgetPayloadStore.save(payload)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func widgetPrimaryText() -> String {
        if planTier == .premium,
           let aiReview = latestDailyReview,
           aiReview.source == "openai",
           aiReview.insight.action.isEmpty == false {
            return aiReview.insight.action
        }

        let issue = widgetIssueContext().lowercased()
        if issue.contains("anxiety") {
            return "Pause, breathe, and name one thing that feels manageable now."
        }
        if issue.contains("sleep") {
            return "Protect a clear stop point tonight. Rest supports tomorrow."
        }
        if issue.contains("stress") || issue.contains("burnout") {
            return "Choose one thing to finish, then release the rest for now."
        }
        if issue.contains("focus") || issue.contains("adhd") || issue.contains("attention") {
            return "Pick one small task and stay with it for ten minutes."
        }
        if let goal = reflectionGoals.first(where: { $0.status == .active }) {
            return goal.title
        }
        return "One short note today is enough."
    }

    private func widgetSecondaryText() -> String {
        if planTier == .premium,
           let aiReview = latestDailyReview,
           aiReview.source == "openai",
           aiReview.insight.reframe.isEmpty == false {
            return aiReview.insight.reframe
        }

        if journalEntries.isEmpty {
            return "Log one line in Anchor and your next review will become more personal."
        }

        if let review = latestDailyReview {
            return review.summary
        }

        return "Your journal history builds clearer weekly patterns over time."
    }

    private func widgetAffirmationOptions() -> [String] {
        let categories = widgetAffirmationCategories.isEmpty ? Set(WidgetAffirmationCategory.allCases) : widgetAffirmationCategories
        var options: [String] = []
        let preferred = onboardingProfile.preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let issue = widgetIssueContext().lowercased()
        if categories.contains(.grounding) {
            options.append("You are safe in this moment.")
            options.append("You can slow down and come back to the present.")
        }
        if categories.contains(.confidence) {
            options.append(preferred.isEmpty ? "You can handle this one step at a time." : "\(preferred), you are doing better than you think.")
            options.append("You have already handled hard days before.")
        }
        if categories.contains(.focus) {
            options.append("Small progress still counts.")
            options.append("One clear task is enough right now.")
        }
        if categories.contains(.rest) {
            options.append("Rest is productive.")
            options.append("You do not need to earn recovery.")
        }
        if categories.contains(.stress) {
            options.append("You can let go of what is not urgent.")
            options.append("Pressure does not define your worth.")
        }

        if issue.contains("anxiety") {
            options.append("Anxiety is a feeling, not a verdict.")
        }
        if issue.contains("sleep") {
            options.append("Protecting sleep is an act of care.")
        }
        if issue.contains("stress") || issue.contains("burnout") {
            options.append("Doing one thing well is enough.")
        }
        if issue.contains("focus") || issue.contains("adhd") || issue.contains("attention") {
            options.append("You can begin small and still make progress.")
        }
        if options.isEmpty {
            options = ["You are allowed to take this one step at a time."]
        }
        var deduped: [String] = []
        for option in options where deduped.contains(option) == false {
            deduped.append(option)
        }
        return deduped
    }

    private func widgetIssueContext() -> String {
        if onboardingProfile.focusAreas.isEmpty == false {
            return onboardingProfile.focusAreas.joined(separator: " · ")
        }
        return "General reflection"
    }
}
