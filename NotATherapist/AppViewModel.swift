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
    private let onboardingCompletedAtKey = "onboardingCompletedAt"
    private let midnightTimestampMigrationKey = "midnightTimestampMigrationV1"
    private let weeklyReminderWeekdayKey = "weeklyReviewReminderWeekday"
    private let weeklyReminderHourKey = "weeklyReviewReminderHour"
    private let weeklyReminderMinuteKey = "weeklyReviewReminderMinute"
    private let lastWeeklyCheckInAtKey = "lastWeeklyCheckInAt"

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

            if defaults.bool(forKey: midnightTimestampMigrationKey) == false {
                let didMigrate = migrateMidnightEntryTimestamps()
                defaults.set(true, forKey: midnightTimestampMigrationKey)
                if didMigrate {
                    saveSnapshot()
                }
            }
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
            selectedJournalDate = Date()
            router.openNewQuickThought()
        case .runDailyReview:
            selectedJournalDate = Date()
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
        streakGoal: Int = 3,
        assessment: OnboardingProfile.AssessmentProfile? = nil
    ) {
        let defaults = UserDefaults.standard
        defaults.set(preferredName, forKey: "onboardingPreferredName")
        defaults.set(ageRange, forKey: "onboardingAgeRange")
        defaults.set(lifeContext.joined(separator: "|"), forKey: "onboardingLifeContext")
        defaults.set(focusAreas.joined(separator: "|"), forKey: "onboardingFocusAreas")
        defaults.set(reflectionGoal, forKey: "onboardingReflectionGoal")
        defaults.set(personalStory, forKey: "onboardingPersonalStory")
        defaults.set(max(1, streakGoal), forKey: "onboardingStreakGoal")
        if defaults.object(forKey: onboardingCompletedAtKey) == nil {
            defaults.set(Date(), forKey: onboardingCompletedAtKey)
        }

        let profile = OnboardingProfile(
            preferredName: preferredName,
            ageRange: ageRange,
            lifeContext: lifeContext,
            focusAreas: focusAreas,
            reflectionGoal: reflectionGoal,
            personalStory: personalStory,
            streakGoal: max(1, streakGoal),
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

    var currentStreakDays: Int {
        streakSummary.current
    }

    var longestStreakDays: Int {
        streakSummary.longest
    }

    var streakGoalDays: Int {
        if onboardingProfile.streakGoal > 0 {
            return onboardingProfile.streakGoal
        }
        let marker = "Streak goal:"
        if let line = onboardingProfile.lifeContext.first(where: { $0.hasPrefix(marker) }) {
            let digits = line.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            return max(1, Int(digits) ?? 3)
        }
        let stored = UserDefaults.standard.integer(forKey: "onboardingStreakGoal")
        return stored > 0 ? stored : 3
    }

    var streakProgressText: String {
        "\(min(currentStreakDays, streakGoalDays))/\(streakGoalDays) days"
    }

    var companionTint: Color {
        journalEntries.first?.mood.companionColor ?? .white
    }

    var adaptiveFollowUpQuestion: String? {
        guard let assessment = onboardingProfile.assessment else { return nil }
        let sortedDomains = assessment.domains.sorted { $0.score > $1.score }
        guard let top = sortedDomains.first else { return nil }

        switch top.domain.lowercased() {
        case "anxiety":
            return "Follow-up: What was one moment today where your worry dropped even slightly, and what helped?"
        case "mood":
            return "Follow-up: What gave you even a small lift in energy or mood today?"
        default:
            return "Follow-up: What boundary or pause helped your stress stay more manageable today?"
        }
    }

    func entries(on date: Date) -> [JournalEntry] {
        journalEntries
            .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }

    func latestEntry(on date: Date) -> JournalEntry? {
        journalEntries.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    @discardableResult
    private func migrateMidnightEntryTimestamps() -> Bool {
        guard journalEntries.isEmpty == false else { return false }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: journalEntries.indices) { index in
            calendar.startOfDay(for: journalEntries[index].date)
        }
        var updated = journalEntries
        var didChange = false

        for (_, indices) in grouped {
            let midnightIndices = indices.filter { index in
                let comps = calendar.dateComponents([.hour, .minute, .second], from: journalEntries[index].date)
                return (comps.hour ?? 0) == 0 && (comps.minute ?? 0) == 0 && (comps.second ?? 0) == 0
            }
            guard midnightIndices.isEmpty == false else { continue }

            // Preserve visible ordering by using current array order; assign a daytime timestamp so
            // entries no longer collide at 00:00 and can supersede earlier same-day entries.
            for (offset, index) in midnightIndices.sorted().enumerated() {
                let baseDay = calendar.startOfDay(for: journalEntries[index].date)
                let migrated = calendar.date(byAdding: .minute, value: 12 * 60 + offset, to: baseDay) ?? journalEntries[index].date
                if updated[index].date != migrated {
                    updated[index].date = migrated
                    didChange = true
                }
            }
        }

        if didChange {
            journalEntries = updated
        }
        return didChange
    }

    func checkInCountThisWeek() -> Int {
        currentWeekDates.filter { day in
            journalEntries.contains { Calendar.current.isDate($0.date, inSameDayAs: day) }
        }.count
    }

    var hasWeeklyReview: Bool {
        weeklyReadiness.ready
    }

    var isWeeklyCheckInAvailableNow: Bool {
        guard hasWeeklyReview else { return false }
        let now = Date()
        let slot = mostRecentWeeklySlot(beforeOrAt: now)
        guard now >= slot else { return false }
        if let last = UserDefaults.standard.object(forKey: lastWeeklyCheckInAtKey) as? Date {
            return last < slot
        }
        return true
    }

    var nextWeeklyCheckInDate: Date {
        let now = Date()
        let slot = mostRecentWeeklySlot(beforeOrAt: now)
        if let last = UserDefaults.standard.object(forKey: lastWeeklyCheckInAtKey) as? Date, last >= slot {
            return Calendar.current.date(byAdding: .day, value: 7, to: slot) ?? slot
        }
        if now < slot { return slot }
        return isWeeklyCheckInAvailableNow ? now : (Calendar.current.date(byAdding: .day, value: 7, to: slot) ?? slot)
    }

    var weeklyCheckInAvailabilityText: String {
        guard hasWeeklyReview else { return weeklyUnlockProgressText }
        if isWeeklyCheckInAvailableNow {
            return "Weekly check-in is ready now."
        }
        return "Next weekly check-in: \(nextWeeklyCheckInDate.formatted(date: .abbreviated, time: .shortened))."
    }

    var weeklyReadiness: (dayCount: Int, entryCount: Int, ready: Bool) {
        let dayCount = Set(journalEntries.map { Calendar.current.startOfDay(for: $0.date) }).count
        let entryCount = journalEntries.count
        let ready = dayCount >= 3
        return (dayCount, entryCount, ready)
    }

    var weeklyUnlockProgressText: String {
        let readiness = weeklyReadiness
        if readiness.ready {
            return "Weekly check-in is unlocked."
        }
        let daysNeeded = max(0, 3 - readiness.dayCount)
        return "Unlock weekly after \(daysNeeded) more active day\(daysNeeded == 1 ? "" : "s")."
    }

    var weeklyUnlockProgressRatio: Double {
        let readiness = weeklyReadiness
        if readiness.ready { return 1 }
        return min(1.0, Double(readiness.dayCount) / 3.0)
    }

    var onboardingMission: [(title: String, done: Bool)] {
        let today = Date()
        let wroteToday = entries(on: today).isEmpty == false
        let reviewedToday = dailyReview(on: today) != nil
        return [
            ("Write today's check-in", wroteToday),
            ("Run today's review", reviewedToday),
            ("Unlock weekly check-in", hasWeeklyReview)
        ]
    }

    var onboardingMissionProgressText: String {
        let mission = onboardingMission
        let doneCount = mission.filter(\.done).count
        return "\(doneCount)/\(mission.count) steps complete"
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
        applyAdaptiveAssessmentAdjustment(reason: "entry_update")
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
    func reviewDay(_ date: Date, preferLocal: Bool = false) async -> DailyReview? {
        onboardingProfile = .current
        let dayEntries = entries(on: date)
        guard dayEntries.isEmpty == false else { return nil }
        let recentEntries = dailyContextEntries(for: date)
        let existingDayReview = dailyReviews.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
        let hasUsedAIDailyReview = existingDayReview?.source == "openai"

        let review: DailyReview
        if planTier == .premium && hasUsedAIDailyReview == false && preferLocal == false {
            var apiReview: DailyReview?
            let maxAttempts = 3
            for attempt in 1...maxAttempts {
                do {
                    let candidate = try await apiService.dailyReview(
                        date: date,
                        entries: dayEntries,
                        recentEntries: recentEntries,
                        profile: onboardingProfile,
                        healthSummary: healthSummary,
                        goals: reflectionGoals
                    )
                    if candidate.source == "openai" {
                        apiReview = candidate
                        break
                    }
                } catch {
                    if attempt < maxAttempts {
                        let delayNanos: UInt64 = attempt == 1 ? 450_000_000 : 900_000_000
                        try? await Task.sleep(nanoseconds: delayNanos)
                    }
                }
            }

            if let apiReview {
                review = apiReview
            } else {
                guard let fallback = insightService.dailyReview(
                    for: date,
                    entries: dayEntries,
                    recentEntries: recentEntries,
                    profile: onboardingProfile,
                    healthSummary: healthSummary
                ) else {
                    aiConnection = .unavailable
                    return nil
                }
                aiConnection = .unavailable
                var localReview = fallback
                localReview.source = "fallback"
                review = localReview
            }
        } else if planTier == .premium {
            guard let fallback = insightService.dailyReview(
                for: date,
                entries: dayEntries,
                recentEntries: recentEntries,
                profile: onboardingProfile,
                healthSummary: healthSummary
            ) else { return nil }
            aiConnection = .connected(model: "openai")
            var localReview = fallback
            localReview.source = "fallback"
            review = localReview
        } else {
            guard let fallback = insightService.dailyReview(
                for: date,
                entries: dayEntries,
                recentEntries: recentEntries,
                profile: onboardingProfile,
                healthSummary: healthSummary
            ) else { return nil }
            var localReview = fallback
            localReview.source = "fallback"
            review = localReview
        }

        var storedReview = sanitizedReview(review)
        if planTier == .premium {
            aiConnection = storedReview.source == "openai" ? .connected(model: "openai") : .unavailable
        }

        if let existingIndex = dailyReviews.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            storedReview.acceptedGoalID = dailyReviews[existingIndex].acceptedGoalID
            dailyReviews[existingIndex] = storedReview
        } else {
            dailyReviews.insert(storedReview, at: 0)
        }

        replaceInsights(for: storedReview)
        applyAdaptiveAssessmentAdjustment(reason: "daily_review")
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

        var review: DailyReview?
        let maxAttempts = 3
        for attempt in 1...maxAttempts {
            do {
                review = try await apiService.onboardingDailyReview(
                    date: date,
                    entries: dayEntries,
                    recentEntries: recentEntries,
                    profile: onboardingProfile,
                    healthSummary: healthSummary,
                    goals: reflectionGoals
                )
                break
            } catch {
                if attempt < maxAttempts {
                    let delayNanos: UInt64 = attempt == 1 ? 450_000_000 : 900_000_000
                    try? await Task.sleep(nanoseconds: delayNanos)
                }
            }
        }

        guard let review else {
            guard let fallback = insightService.dailyReview(
                for: date,
                entries: dayEntries,
                recentEntries: recentEntries,
                profile: onboardingProfile,
                healthSummary: healthSummary
            ) else {
                aiConnection = .unavailable
                return nil
            }
            aiConnection = .unavailable
            var storedFallback = sanitizedReview(fallback)
            if let existingIndex = dailyReviews.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
                storedFallback.acceptedGoalID = dailyReviews[existingIndex].acceptedGoalID
                dailyReviews[existingIndex] = storedFallback
            } else {
                dailyReviews.insert(storedFallback, at: 0)
            }

            replaceInsights(for: storedFallback)
            applyAdaptiveAssessmentAdjustment(reason: "onboarding_first_reflection")
            await refreshWeeklyReview()
            saveSnapshot()
            return storedFallback
        }

        aiConnection = review.source == "openai" ? .connected(model: "openai") : .unknown
        var storedReview = sanitizedReview(review)
        if let existingIndex = dailyReviews.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            storedReview.acceptedGoalID = dailyReviews[existingIndex].acceptedGoalID
            dailyReviews[existingIndex] = storedReview
        } else {
            dailyReviews.insert(storedReview, at: 0)
        }

        replaceInsights(for: storedReview)
        applyAdaptiveAssessmentAdjustment(reason: "onboarding_first_reflection")
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
        applyAdaptiveAssessmentAdjustment(reason: "weekly_review")
        saveSnapshot()
    }

    func startWeeklyConversation() async -> Conversation {
        guard isWeeklyCheckInAvailableNow else {
            let preview = weeklyCheckInAvailabilityText
            let blocked = Conversation(
                id: UUID(),
                title: "Weekly check-in",
                date: Date(),
                preview: preview,
                messages: [ConversationMessage(id: UUID(), sender: .ai, text: preview, date: Date())],
                status: .ended,
                remainingTurns: 0,
                maxTurns: 0,
                deepeningUsed: false,
                phase: .core
            )
            return blocked
        }

        onboardingProfile = .current
        await refreshWeeklyReview()

        let conversation: Conversation
        do {
            conversation = try await apiService.startConversation(weeklyReview: weeklyReview, profile: onboardingProfile)
        } catch {
            conversation = conversationService.newWeeklyConversation(review: weeklyReview, profile: onboardingProfile)
        }

        conversations.insert(conversation, at: 0)
        UserDefaults.standard.set(Date(), forKey: lastWeeklyCheckInAtKey)
        saveSnapshot()
        return conversation
    }

    private func mostRecentWeeklySlot(beforeOrAt date: Date) -> Date {
        let defaults = UserDefaults.standard
        let weekdayRaw = defaults.integer(forKey: weeklyReminderWeekdayKey)
        let weekday = weekdayRaw == 0 ? 1 : weekdayRaw
        let hour = defaults.object(forKey: weeklyReminderHourKey) == nil ? 18 : defaults.integer(forKey: weeklyReminderHourKey)
        let minute = defaults.integer(forKey: weeklyReminderMinuteKey)

        var calendar = Calendar.current
        calendar.firstWeekday = 1

        var target = DateComponents()
        target.weekday = weekday
        target.hour = hour
        target.minute = minute
        target.second = 0

        let end = date.addingTimeInterval(1)
        if let next = calendar.nextDate(after: end, matching: target, matchingPolicy: .nextTimePreservingSmallerComponents, direction: .backward) {
            return next
        }
        return date
    }

    func sendMessage(_ text: String, in conversation: Conversation, action: String? = nil) async -> Conversation {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else { return conversation }
        var updated = conversations[index]
        guard updated.status == .active, updated.remainingTurns > 0 else { return updated }

        if action == "Save suggested step", let suggestion = latestSuggestedGoal(from: updated) {
            guard hasGoalAgreement(in: updated) else {
                updated.messages.append(
                    ConversationMessage(
                        id: UUID(),
                        sender: .ai,
                        text: "Before I save it, I want your agreement. Does this feel realistic for 7 days, or what should I adjust?",
                        date: Date()
                    )
                )
                updated.preview = "Waiting for goal agreement"
                conversations[index] = updated
                saveSnapshot()
                return updated
            }

            let synthesized = synthesizeWeeklyGoal(from: updated, fallback: suggestion)
            let goal = addReflectionGoal(
                title: synthesized.title,
                reason: synthesized.reason,
                sourceConversationID: updated.id,
                durationDays: 7
            )
            updated.contextHints.removeAll { $0.hasPrefix("suggested_goal::") }
            updated.messages.append(
                ConversationMessage(
                    id: UUID(),
                    sender: .ai,
                    text: "Saved: \(goal.title). You’ll see it in Next steps.",
                    date: Date()
                )
            )
            updated.preview = "Goal added: \(goal.title)"
            conversations[index] = updated
            saveSnapshot()
            return updated
        }

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
                    let encoded = encodeSuggestedGoal(title: goal.title, reason: goal.reason)
                    updated.contextHints.removeAll { $0.hasPrefix("suggested_goal::") }
                    updated.contextHints.append(encoded)
                    updated.preview = "Suggested step: \(goal.title)"
                }
            } else {
                let isFinalTurn = updated.remainingTurns <= 1
                let baseReply = conversationService.reply(to: text, action: action, remainingTurns: updated.remainingTurns, profile: onboardingProfile)
                updated.remainingTurns = max(0, updated.remainingTurns - 1)
                if isFinalTurn {
                    updated.status = .ended
                    reply = "\(baseReply) We’ll pause here for today. One weekly action: \(weeklyCloseAction(for: onboardingProfile))."
                } else {
                    reply = baseReply
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
                let title = "Finish one small unfinished thing"
                let reason = "Agreed during the weekly check-in."
                updated.contextHints.removeAll { $0.hasPrefix("suggested_goal::") }
                updated.contextHints.append(encodeSuggestedGoal(title: title, reason: reason))
                updated.messages.append(
                    ConversationMessage(
                        id: UUID(),
                        sender: .ai,
                        text: "Suggested next step: \(title). If you want, tap “Save suggested step”.",
                        date: Date()
                    )
                )
                updated.preview = "Suggested step: \(title)"
            }
        }

        conversations[index] = updated
        saveSnapshot()
        return updated
    }

    private func encodeSuggestedGoal(title: String, reason: String) -> String {
        let safeTitle = title.replacingOccurrences(of: "::", with: " - ")
        let safeReason = reason.replacingOccurrences(of: "::", with: " - ")
        return "suggested_goal::\(safeTitle)::\(safeReason)"
    }

    private func latestSuggestedGoal(from conversation: Conversation) -> (title: String, reason: String)? {
        guard let raw = conversation.contextHints.last(where: { $0.hasPrefix("suggested_goal::") }) else { return nil }
        let parts = raw.components(separatedBy: "::")
        guard parts.count >= 3 else { return nil }
        return (parts[1], parts[2])
    }

    private func synthesizeWeeklyGoal(from conversation: Conversation, fallback: (title: String, reason: String)) -> (title: String, reason: String) {
        let userText = conversation.messages
            .filter { $0.sender == .user }
            .map { $0.text.lowercased() }
            .joined(separator: " ")

        let title: String
        let reason: String

        if userText.contains("sleep") || userText.contains("tired") || userText.contains("night") {
            title = "7-day sleep consistency plan"
            reason = "Agreed plan: for the next 7 days, keep one fixed wake time (±30 min), start wind-down 45 minutes before bed, and log the result each day."
        } else if userText.contains("anxiety") || userText.contains("panic") || userText.contains("worry") {
            title = "7-day anxiety reset plan"
            reason = "Agreed plan: for the next 7 days, run one 60-second reset before your hardest moment and write one line on what changed."
        } else if userText.contains("work") || userText.contains("deadline") || userText.contains("meeting") {
            title = "7-day work pressure plan"
            reason = "Agreed plan: for the next 7 days, close or park one unresolved work loop daily and set a next step before ending your day."
        } else if userText.contains("driving") || userText.contains("drive") {
            title = "7-day calmer driving plan"
            reason = "Agreed plan: for the next 7 days, do one pre-drive calming step before each key drive and track your anxiety before/after."
        } else {
            title = fallback.title.hasPrefix("7-day") ? fallback.title : "7-day focus plan"
            reason = "Agreed plan for the next 7 days: \(fallback.reason)"
        }

        return (title, reason)
    }

    private func hasGoalAgreement(in conversation: Conversation) -> Bool {
        guard let lastUser = conversation.messages.last(where: { $0.sender == .user })?.text.lowercased() else {
            return false
        }
        let signals = [
            "yes",
            "sounds good",
            "let's do it",
            "lets do it",
            "i agree",
            "works for me",
            "that works",
            "do that",
            "save it"
        ]
        return signals.contains(where: { lastUser.contains($0) })
    }

    private func weeklyCloseAction(for profile: OnboardingProfile) -> String {
        if let focus = profile.focusAreas.first?.lowercased(), focus.contains("sleep") {
            return "Set a fixed wind-down time tonight and protect it for 3 nights."
        }
        if let focus = profile.focusAreas.first?.lowercased(), focus.contains("anxiety") {
            return "Use one 60-second reset once daily before your hardest moment."
        }
        return "Pick one small unfinished item and close it within 20 minutes."
    }

    @discardableResult
    func addReflectionGoal(title: String, reason: String, sourceConversationID: UUID? = nil, durationDays: Int = 3) -> ReflectionGoal {
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
            dueDate: Calendar.current.date(byAdding: .day, value: max(1, durationDays), to: Date()),
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

    private var streakSummary: (current: Int, longest: Int) {
        let calendar = Calendar.current
        let days = Set(journalEntries.map { calendar.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return (0, 0) }
        let sortedDays = days.sorted()

        var longest = 1
        var running = 1
        for idx in 1..<sortedDays.count {
            let previous = sortedDays[idx - 1]
            let current = sortedDays[idx]
            if let nextExpected = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(nextExpected, inSameDayAs: current) {
                running += 1
            } else {
                running = 1
            }
            longest = max(longest, running)
        }

        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        guard days.contains(today) || days.contains(yesterday) else {
            return (0, longest)
        }

        var current = days.contains(today) ? 1 : 0
        var cursor = days.contains(today) ? today : yesterday
        while let previous = calendar.date(byAdding: .day, value: -1, to: cursor),
              days.contains(previous) {
            current += 1
            cursor = previous
        }
        return (current, longest)
    }

    private func applyAdaptiveAssessmentAdjustment(reason: String) {
        onboardingProfile = .current
        guard var profile = optionalOnboardingProfile(),
              var assessment = profile.assessment else { return }

        let recent = journalEntries
            .sorted { $0.date > $1.date }
            .prefix(14)
        guard recent.count >= 3 else { return }

        let recent7 = Array(recent.prefix(7))
        let lowMoodCount = recent7.filter { $0.mood.score <= 2 }.count
        let highMoodCount = recent7.filter { $0.mood.score >= 4 }.count
        let stressSignals = recent7.filter { $0.themes.contains("Stress") || $0.themes.contains("Anxiety") }.count

        var delta = 0
        if lowMoodCount >= 3 || stressSignals >= 3 { delta += 1 }
        if highMoodCount >= 3 { delta -= 1 }

        let completionSignals = recent7.filter {
            let text = $0.text.lowercased()
            return ["done", "finished", "completed", "calmer", "better", "easier"].contains(where: text.contains)
        }.count
        if completionSignals >= 2 { delta -= 1 }

        delta = max(-2, min(2, delta))
        guard delta != 0 else { return }

        let originalScore = assessment.totalScore
        assessment.totalScore = max(0, min(assessment.maxScore, assessment.totalScore + delta))

        if let top = assessment.domains.enumerated().max(by: { $0.element.score < $1.element.score }) {
            let updated = max(0, min(top.element.maxScore, top.element.score + delta))
            assessment.domains[top.offset].score = updated
            let ratio = top.element.maxScore == 0 ? 0 : Double(updated) / Double(top.element.maxScore)
            assessment.domains[top.offset].level = ratio >= 0.67 ? "high" : (ratio >= 0.34 ? "moderate" : "low")
        }

        assessment.completedAt = Date()
        profile.assessment = assessment
        profile.lifeContext = profile.lifeContext.filter { $0.hasPrefix("Adaptive baseline:") == false }
        profile.lifeContext.append("Adaptive baseline: \(originalScore) -> \(assessment.totalScore) (\(reason))")
        persistOnboardingProfile(profile)
    }

    private func optionalOnboardingProfile() -> OnboardingProfile? {
        let profile = onboardingProfile
        if profile.preferredName.isEmpty &&
            profile.personalStory.isEmpty &&
            profile.focusAreas.isEmpty &&
            profile.lifeContext.isEmpty &&
            profile.assessment == nil {
            return nil
        }
        return profile
    }

    private func persistOnboardingProfile(_ profile: OnboardingProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "onboardingProfileV2")
            onboardingProfile = .current
        }
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
