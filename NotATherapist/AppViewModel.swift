import Foundation
import SwiftUI
import UIKit
import WidgetKit

@MainActor
final class AppViewModel: ObservableObject {
    enum CompanionTrend {
        case improving
        case stable
        case regressing
    }

    struct CompanionStatePoint: Identifiable {
        let id = UUID()
        let date: Date
        let score: Double
        let confidence: Double
        let state: CompanionEmotionalState
    }

    struct CompanionRegulationSnapshot {
        let score: Double // 0 = frantic, 1 = calm
        let confidence: Double
        let state: CompanionEmotionalState
        let trend: CompanionTrend
        let personality: CompanionPersonality
        let tint: Color
    }

    struct CompanionDriver: Identifiable {
        let id = UUID()
        let name: String
        let contribution: Double
        let direction: String
        let tip: String
    }

    @Published var selectedMood: MoodLevel = .okay
    @Published var journalEntries: [JournalEntry]
    @Published var insights: [Insight]
    @Published var conversations: [Conversation] = []
    @Published var weeklyReview: WeeklyReview
    @Published var monthlyReview: MonthlyReview?
    @Published var sounds: [CalmSound] = MockData.sounds
    @Published var selectedJournalDate: Date = Date()
    @Published var onboardingProfile: OnboardingProfile = .current
    @Published var healthSummary: HealthSummary?
    @Published var reflectionGoals: [ReflectionGoal] = []
    @Published var dailyReviews: [DailyReview] = []
    @Published var aiConnection: AIConnectionState = .unknown
    @Published var iCloudSyncState: ICloudSyncState = .off
    @Published var planTier: AppPlanTier
    @Published var isDemoDataEnabled: Bool
    @Published var widgetStylePreset: WidgetStylePreset
    @Published var widgetAccentColor: WidgetAccentColor
    @Published var widgetFontStyle: WidgetFontStyle
    @Published var widgetAffirmationCategories: Set<WidgetAffirmationCategory>
    @Published var premiumBillingCycle: PremiumBillingCycle

    private let insightService = MockAIInsightService()
    private let weeklyReviewService = MockWeeklyReviewService()
    private let conversationService = MockConversationService()
    private let apiService = NotATherapistAPIService()
    private let localStore = LocalAppStore()
    private let widgetPayloadStore = WidgetPayloadStore()
    private let iCloudSyncService = ICloudSyncService.shared
    private let iCloudSyncEnabledKey = "iCloudSyncEnabled"
    private let planTierKey = "appPlanTier"
    private let demoDataEnabledKey = "demoDataEnabled"
    private let widgetStylePresetKey = "widgetStylePreset"
    private let widgetAccentColorKey = "widgetAccentColor"
    private let widgetFontStyleKey = "widgetFontStyle"
    private let widgetAffirmationCategoriesKey = "widgetAffirmationCategories"
    private let premiumBillingCycleKey = "premiumBillingCycle"
    private let widgetAffirmationIndexKey = "widgetAffirmationIndex"
    private let onboardingCompletedAtKey = "onboardingCompletedAt"
    private let midnightTimestampMigrationKey = "midnightTimestampMigrationV1"
    private let weeklyReminderWeekdayKey = "weeklyReviewReminderWeekday"
    private let weeklyReminderHourKey = "weeklyReviewReminderHour"
    private let weeklyReminderMinuteKey = "weeklyReviewReminderMinute"
    private let lastWeeklyCheckInAtKey = "lastWeeklyCheckInAt"
    private let calmSessionDatesKey = "calmSessionDatesV1"
    private var calmSessionDates: [Date] = []

    init(seedWithMockData: Bool = false) {
        let defaults = UserDefaults.standard
        let savedTier = defaults.string(forKey: planTierKey)
        let migratedPremium = defaults.bool(forKey: "premiumDailyReviewsEnabled")
        let demoEnabled = defaults.bool(forKey: demoDataEnabledKey)
        _planTier = Published(initialValue: AppPlanTier(rawValue: savedTier ?? "") ?? (migratedPremium ? .premium : .free))
        _isDemoDataEnabled = Published(initialValue: demoEnabled)
        _widgetStylePreset = Published(initialValue: WidgetStylePreset(rawValue: defaults.string(forKey: widgetStylePresetKey) ?? "") ?? .minimal)
        _widgetAccentColor = Published(initialValue: WidgetAccentColor(rawValue: defaults.string(forKey: widgetAccentColorKey) ?? "") ?? .green)
        _widgetFontStyle = Published(initialValue: WidgetFontStyle(rawValue: defaults.string(forKey: widgetFontStyleKey) ?? "") ?? .rounded)
        _premiumBillingCycle = Published(initialValue: PremiumBillingCycle(rawValue: defaults.string(forKey: premiumBillingCycleKey) ?? "") ?? .annual)
        let storedCategoryIDs = defaults.stringArray(forKey: widgetAffirmationCategoriesKey) ?? []
        let storedCategories = Set(storedCategoryIDs.compactMap(WidgetAffirmationCategory.init(rawValue:)))
        _widgetAffirmationCategories = Published(initialValue: storedCategories.isEmpty ? Set(WidgetAffirmationCategory.allCases) : storedCategories)

        if seedWithMockData || demoEnabled {
            let demo = localStore.load() ?? Self.buildDemoSnapshot(using: weeklyReviewService)
            selectedMood = demo.selectedMood
            journalEntries = demo.journalEntries
            insights = demo.insights
            conversations = demo.conversations
            weeklyReview = demo.weeklyReview
            monthlyReview = demo.monthlyReview
            healthSummary = demo.healthSummary
            reflectionGoals = demo.reflectionGoals
            dailyReviews = demo.dailyReviews
        } else if let snapshot = localStore.load() {
            selectedMood = snapshot.selectedMood
            journalEntries = snapshot.journalEntries
            insights = snapshot.insights
            conversations = snapshot.conversations
            weeklyReview = snapshot.weeklyReview
            monthlyReview = snapshot.monthlyReview
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
        if let stored = defaults.array(forKey: calmSessionDatesKey) as? [TimeInterval] {
            calmSessionDates = stored.map(Date.init(timeIntervalSince1970:))
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

    var memorySignals: [MemorySignal] {
        buildMemorySignals(from: journalEntries)
    }

    var currentMonthlyReview: MonthlyReview? {
        monthlyReview ?? monthlyStatsReview(containing: Date())
    }

    var hasInsightContent: Bool {
        insights.isEmpty == false ||
        localSignals.isEmpty == false ||
        weeklyReview.primaryLoop?.isEmpty == false ||
        weeklyReview.nextExperiment?.isEmpty == false ||
        weeklyReview.progressSignal?.isEmpty == false
    }

    var hasExistingUserState: Bool {
        UserDefaults.standard.object(forKey: onboardingCompletedAtKey) != nil ||
            journalEntries.isEmpty == false ||
            dailyReviews.isEmpty == false ||
            conversations.isEmpty == false ||
            onboardingProfile.focusAreas.isEmpty == false ||
            onboardingProfile.reflectionGoal.isEmpty == false ||
            onboardingProfile.personalStory.isEmpty == false
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
        var profile = onboardingProfile
        profile.preferredName = name
        persistOnboardingProfile(profile)
        refreshWidgetPayload()
    }

    func activatePremium(plan: PremiumPlanOption) {
        premiumBillingCycle = plan.cycle
        UserDefaults.standard.set(plan.cycle.rawValue, forKey: premiumBillingCycleKey)
        isPremium = true
    }

    func updateAgeRange(_ ageRange: String) {
        UserDefaults.standard.set(ageRange, forKey: "onboardingAgeRange")
        var profile = onboardingProfile
        profile.ageRange = ageRange
        persistOnboardingProfile(profile)
        refreshWidgetPayload()
    }

    func updateReflectionGoal(_ goal: String) {
        UserDefaults.standard.set(goal, forKey: "onboardingReflectionGoal")
        var profile = onboardingProfile
        profile.reflectionGoal = goal
        persistOnboardingProfile(profile)
        saveSnapshot()
    }

    func updateWidgetStylePreset(_ style: WidgetStylePreset) {
        widgetStylePreset = style
        UserDefaults.standard.set(style.rawValue, forKey: widgetStylePresetKey)
        refreshWidgetPayload()
    }

    func updateWidgetAccentColor(_ color: WidgetAccentColor) {
        widgetAccentColor = color
        UserDefaults.standard.set(color.rawValue, forKey: widgetAccentColorKey)
        refreshWidgetPayload()
    }

    func updateWidgetFontStyle(_ style: WidgetFontStyle) {
        widgetFontStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: widgetFontStyleKey)
        refreshWidgetPayload()
    }

    func setDemoDataEnabled(_ enabled: Bool) {
        guard enabled != isDemoDataEnabled else { return }

        let defaults = UserDefaults.standard
        if enabled {
            localStore.saveBackup(snapshot)
            let demo = demoSnapshot
            isDemoDataEnabled = true
            defaults.set(true, forKey: demoDataEnabledKey)
            apply(demo)
            localStore.save(demo)
            refreshWidgetPayload()
            return
        }

        let restored = localStore.loadBackup() ?? emptySnapshot
        isDemoDataEnabled = false
        defaults.set(false, forKey: demoDataEnabledKey)
        apply(restored)
        localStore.save(restored)
        localStore.deleteBackup()
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

    var activeWeeklyConversation: Conversation? {
        conversations.first {
            $0.reviewCadence == .weekly && $0.status == .active
        }
    }

    var activeMonthlyConversation: Conversation? {
        conversations.first {
            $0.reviewCadence == .monthly && $0.status == .active
        }
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
        journalCompanionTint
    }

    var journalCompanionTint: Color {
        latestJournalEntry?.mood.companionColor ?? .white
    }

    var companionPersonality: CompanionPersonality {
        companionRegulation.personality
    }

    var companionState: CompanionEmotionalState {
        companionRegulation.state
    }

    var companionCircleState: AICircleState {
        switch companionState {
        case .overwhelmed:
            .thinking
        case .activated:
            .responding
        case .steadying:
            .checkIn
        case .balanced:
            .attentive
        case .thriving:
            .settled
        }
    }

    var companionConfidence: Double {
        companionRegulation.confidence
    }

    var companionStateTimeline: [CompanionStatePoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let days = (-13...0).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
        let raw = days.map { regulationScore(upTo: $0) }
        let smoothed = smoothCompanionScores(raw)
        return zip(days, smoothed).map { day, score in
            let confidence = regulationConfidence(upTo: day)
            return CompanionStatePoint(
                date: day,
                score: score,
                confidence: confidence,
                state: mapState(from: score)
            )
        }
    }

    var companionRegulation: CompanionRegulationSnapshot {
        let timeline = companionStateTimeline
        let blended = timeline.last?.score ?? regulationScore(upTo: Date())
        let confidence = regulationConfidence(upTo: Date())
        let state = mapState(from: blended)
        let trend = companionTrend(from: timeline)

        let personality: CompanionPersonality
        switch state {
        case .overwhelmed, .activated:
            personality = .energetic
        case .steadying:
            personality = .analytic
        case .balanced, .thriving:
            personality = .calm
        }

        // Move from warm/high-alert tone to cooler calm tone.
        let frantic = Color(red: 0.94, green: 0.58, blue: 0.36)
        let calm = Color(red: 0.58, green: 0.82, blue: 0.98)
        let tint = interpolateColor(from: frantic, to: calm, t: blended)

        return CompanionRegulationSnapshot(
            score: blended,
            confidence: confidence,
            state: state,
            trend: trend,
            personality: personality,
            tint: tint
        )
    }

    var companionStateHeroText: String {
        let state = companionState
        let confidence = companionConfidence
        if confidence < 0.35 {
            return "Early signal: \(state.summary)"
        }
        switch companionRegulation.trend {
        case .improving:
            return "\(state.summary) Trend is improving."
        case .stable:
            return "\(state.summary) Trend is steady."
        case .regressing:
            return "\(state.summary) Tough week signal detected. We will dial support calmer and simpler."
        }
    }

    var signalClarityPercent: Int {
        Int((companionRegulation.score * 100).rounded())
    }

    var signalClarityDeltaWeek: Int {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -7, to: Date()) else { return 0 }
        let now = regulationScore(upTo: Date())
        let before = regulationScore(upTo: start)
        return Int(((now - before) * 100).rounded())
    }

    var companionDriversToday: [CompanionDriver] {
        let momentum = journalingMomentumScore(upTo: Date())
        let mood = recentMoodStabilityScore(upTo: Date())
        let consistency = streakConsistencyScore(upTo: Date())
        let calmRecovery = calmRecoveryScore(upTo: Date())
        let recovery = recoveryBehaviorScore

        return [
            CompanionDriver(
                name: "Check-in consistency",
                contribution: consistency,
                direction: consistency >= 0.55 ? "up" : "down",
                tip: "Do one short check-in daily. Even 30 seconds keeps this stable."
            ),
            CompanionDriver(
                name: "Recent mood trend",
                contribution: mood,
                direction: mood >= 0.55 ? "up" : "down",
                tip: "Tag your mood honestly and add one sentence about what helped or hurt it."
            ),
            CompanionDriver(
                name: "Calm sessions",
                contribution: calmRecovery,
                direction: calmRecovery >= 0.45 ? "up" : "down",
                tip: "Complete one guided breathing session for at least 1 minute."
            ),
            CompanionDriver(
                name: "Journaling momentum",
                contribution: momentum,
                direction: momentum >= 0.5 ? "up" : "down",
                tip: "Write small and often. Short entries beat waiting for a perfect one."
            ),
            CompanionDriver(
                name: "Follow-through",
                contribution: recovery,
                direction: recovery >= 0.4 ? "up" : "down",
                tip: "Mark one suggested next step as done to reinforce progress."
            )
        ]
    }

    var adaptiveFollowUpQuestion: String? {
        switch companionState {
        case .overwhelmed:
            return "Follow-up: What helped you feel even 5% safer or calmer today?"
        case .activated:
            return "Follow-up: Where did your stress peak, and what brought it down even a little?"
        case .steadying:
            return "Follow-up: What is one pattern you handled better than last week?"
        case .balanced:
            return "Follow-up: What habit is keeping you steady right now?"
        case .thriving:
            return "Follow-up: What is one small stretch goal you feel ready for this week?"
        }
    }

    var domainFollowUpQuestion: String? {
        guard let assessment = onboardingProfile.assessment else { return nil }
        let sortedDomains = assessment.domains.sorted { $0.score > $1.score }
        guard let top = sortedDomains.first else { return nil }

        switch top.domain.lowercased() {
        case "anxiety":
            return "Follow-up: What was one moment today where your worry dropped even slightly, and what helped?"
        case "mood":
            return "Follow-up: What gave you even a small lift in energy or mood today?"
        case "functioning":
            return "Follow-up: What made the day easier to get through, even by a small amount?"
        default:
            return "Follow-up: What boundary or pause helped your stress stay more manageable today?"
        }
    }

    func entries(on date: Date) -> [JournalEntry] {
        journalEntries
            .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }

    var activeReflectionGoals: [ReflectionGoal] {
        reflectionGoals
            .filter { $0.status == .active }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func activeGoals(for cadence: GoalCadence) -> [ReflectionGoal] {
        activeReflectionGoals.filter { ($0.cadence ?? .daily) == cadence }
    }

    func completedGoals(for cadence: GoalCadence) -> [ReflectionGoal] {
        completedReflectionGoals.filter { ($0.cadence ?? .daily) == cadence }
    }

    var longTermGoalTitle: String {
        let value = onboardingProfile.reflectionGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Build a steadier reflection habit" : value
    }

    var suggestedWeeklyGoalText: String? {
        guard hasWeeklyReview else { return nil }
        let value = weeklyReview.nextExperiment?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    var suggestedMonthlyGoalText: String? {
        guard let monthlyReview else { return nil }
        let value = monthlyReview.nextExperiment.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var completedReflectionGoals: [ReflectionGoal] {
        reflectionGoals
            .filter { $0.status == .completed }
            .sorted { ($0.feedbackAt ?? $0.createdAt) > ($1.feedbackAt ?? $1.createdAt) }
    }

    var completedReflectionGoalCount: Int {
        completedReflectionGoals.count
    }

    func searchEntries(query: String, mood: MoodLevel?, entryType: EntryType?) -> [JournalEntry] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return journalEntries
            .filter { entry in
                let matchesQuery = cleanQuery.isEmpty ||
                    entry.text.lowercased().contains(cleanQuery) ||
                    entry.themes.contains { $0.lowercased().contains(cleanQuery) } ||
                    entry.entryType.label.lowercased().contains(cleanQuery)
                let matchesMood = mood == nil || entry.mood == mood
                let matchesType = entryType == nil || entry.entryType == entryType
                return matchesQuery && matchesMood && matchesType
            }
            .sorted { $0.date > $1.date }
    }

    func monthlyStatsReview(containing date: Date) -> MonthlyReview? {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return nil }
        let entries = journalEntries.filter { $0.date >= interval.start && $0.date < interval.end }
        guard entries.isEmpty == false else { return nil }

        let activeDays = Set(entries.map { calendar.startOfDay(for: $0.date) }).count
        let averageMood = Double(entries.map(\.mood.score).reduce(0, +)) / Double(entries.count)
        let evidenceQuality: String
        if activeDays >= 12 || entries.count >= 18 {
            evidenceQuality = "solid"
        } else if activeDays >= 5 || entries.count >= 8 {
            evidenceQuality = "building"
        } else {
            evidenceQuality = "early"
        }

        let meaningfulThemes = entries
            .flatMap(\.themes)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { theme in
                guard theme.isEmpty == false else { return false }
                return EntryType.allCases.contains(where: { $0.label.caseInsensitiveCompare(theme) == .orderedSame }) == false
            }
        let themeCounts = Dictionary(grouping: meaningfulThemes, by: { $0 })
            .mapValues(\.count)
            .sorted { lhs, rhs in
                lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
            }
        let repeatedThemes = themeCounts.filter { $0.value >= 2 }
        let topThemes = repeatedThemes.prefix(4).map(\.key)
        let bestTheme = repeatedThemes.first
        let completedGoals = reflectionGoals.filter { goal in
            guard let feedbackAt = goal.feedbackAt else { return false }
            return feedbackAt >= interval.start && feedbackAt < interval.end && goal.status == .completed
        }
        let sortedEntries = entries.sorted { $0.date < $1.date }
        let lowMoodDays = Set(entries.filter { $0.mood.score <= 2 }.map { calendar.startOfDay(for: $0.date) }).count
        let highMoodDays = Set(entries.filter { $0.mood.score >= 4 }.map { calendar.startOfDay(for: $0.date) }).count
        let firstHalfAverage = averageMoodScore(for: sortedEntries.prefix(max(1, sortedEntries.count / 2)))
        let secondHalfAverage = averageMoodScore(for: sortedEntries.suffix(max(1, sortedEntries.count - sortedEntries.count / 2)))
        let delta = secondHalfAverage - firstHalfAverage

        let summary: String
        switch evidenceQuality {
        case "solid":
            summary = "\(activeDays) active days and \(entries.count) entries give this month a usable signal."
        case "building":
            summary = "\(activeDays) active days logged. Enough to show direction, but not enough for strong conclusions."
        default:
            summary = "\(activeDays) active day\(activeDays == 1 ? "" : "s") logged. Treat this month as a starting snapshot, not a review yet."
        }

        let direction: String
        if entries.count < 4 {
            direction = "Mood direction needs a few more entries before it is meaningful."
        } else if delta >= 0.4 {
            direction = "Mood is trending up compared with the start of the month."
        } else if delta <= -0.4 {
            direction = "Mood is trending down compared with the start of the month."
        } else {
            direction = "Mood is broadly steady across the logged entries."
        }

        let strongestSignal: String
        if let bestTheme {
            strongestSignal = "\(bestTheme.key) is the strongest repeated topic so far, showing up \(bestTheme.value) times."
        } else if lowMoodDays >= 2 || highMoodDays >= 2 {
            strongestSignal = "Mood data is the clearest signal so far: \(highMoodDays) higher-mood day\(highMoodDays == 1 ? "" : "s") and \(lowMoodDays) lower-mood day\(lowMoodDays == 1 ? "" : "s")."
        } else {
            strongestSignal = "No repeated topic is strong enough to call out yet."
        }

        let progress: String
        if completedGoals.isEmpty == false {
            progress = "You completed \(completedGoals.count) next step\(completedGoals.count == 1 ? "" : "s") this month."
        } else if entries.contains(where: { $0.entryType == .win }) {
            progress = "You logged at least one win this month. Marking next steps complete will make follow-through clearer."
        } else {
            progress = "No completed next steps recorded yet."
        }

        let experiment = bestTheme?.key == "Sleep"
            ? "Protect one consistent wind-down cue for the next 7 days."
            : bestTheme?.key == "Work"
                ? "Close or park one work loop before ending each day for a week."
                : evidenceQuality == "early"
                    ? "Log three more days this month before drawing conclusions."
                    : "Repeat one condition from your steadiest logged day this month."

        return MonthlyReview(
            id: UUID(),
            monthTitle: interval.start.formatted(.dateTime.month(.wide).year()),
            entryCount: entries.count,
            activeDays: activeDays,
            averageMood: averageMood,
            topThemes: topThemes,
            strongestPattern: strongestSignal,
            progress: progress,
            nextExperiment: experiment,
            dataQuality: evidenceQuality,
            summary: summary,
            moodRange: direction
        )
    }

    private func averageMoodScore<S: Sequence>(for entries: S) -> Double where S.Element == JournalEntry {
        let scores = entries.map(\.mood.score)
        guard scores.isEmpty == false else { return 0 }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    func latestEntry(on date: Date) -> JournalEntry? {
        journalEntries.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    var latestJournalEntry: JournalEntry? {
        journalEntries.max(by: { $0.date < $1.date })
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

    private var baselineRegulationFromAssessment: Double {
        guard let assessment = onboardingProfile.assessment else { return 0.45 }
        guard assessment.maxScore > 0 else { return 0.45 }
        // Higher assessment score => less regulated starting state.
        return clamp01(1.0 - (Double(assessment.totalScore) / Double(assessment.maxScore)))
    }

    private var journalingMomentumScore: Double {
        journalingMomentumScore(upTo: Date())
    }

    private func journalingMomentumScore(upTo date: Date) -> Double {
        let cal = Calendar.current
        let today = cal.startOfDay(for: date)
        let last7 = (-6...0).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
        let active = last7.filter { entries(on: $0).isEmpty == false }.count
        return clamp01(Double(active) / 7.0)
    }

    private var recentMoodStabilityScore: Double {
        recentMoodStabilityScore(upTo: Date())
    }

    private func recentMoodStabilityScore(upTo date: Date) -> Double {
        let recent = journalEntries
            .filter { $0.date <= date }
            .sorted { $0.date > $1.date }
            .prefix(12)
        guard recent.isEmpty == false else { return 0.42 }
        let avg = recent.map(\.mood.score).reduce(0, +) / recent.count
        return clamp01((Double(avg) - 1.0) / 4.0)
    }

    private var streakConsistencyScore: Double {
        streakConsistencyScore(upTo: Date())
    }

    private func streakConsistencyScore(upTo date: Date) -> Double {
        let goal = max(1, streakGoalDays)
        let current = streakDays(upTo: date)
        return clamp01(Double(min(current, goal)) / Double(goal))
    }

    private var recoveryBehaviorScore: Double {
        let completed = reflectionGoals.filter { $0.status == .completed }.count
        let denominator = max(1, reflectionGoals.count)
        return clamp01(Double(completed) / Double(denominator))
    }

    private func calmRecoveryScore(upTo date: Date) -> Double {
        let cal = Calendar.current
        let today = cal.startOfDay(for: date)
        let last7 = (-6...0).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
        let unique = Set(calmSessionDates.map { cal.startOfDay(for: $0) })
        let activeDays = last7.filter { unique.contains($0) }.count
        return clamp01(Double(activeDays) / 5.0)
    }

    private func regulationScore(upTo date: Date) -> Double {
        let baseline = baselineRegulationFromAssessment
        let momentum = journalingMomentumScore(upTo: date)
        let mood = recentMoodStabilityScore(upTo: date)
        let consistency = streakConsistencyScore(upTo: date)
        let recovery = recoveryBehaviorScore
        let calmRecovery = calmRecoveryScore(upTo: date)
        return clamp01((baseline * 0.38) + (momentum * 0.18) + (mood * 0.2) + (consistency * 0.1) + (recovery * 0.06) + (calmRecovery * 0.08))
    }

    private func smoothCompanionScores(_ raw: [Double]) -> [Double] {
        guard raw.isEmpty == false else { return [] }
        var out: [Double] = [raw[0]]
        let alpha = 0.34
        let maxStep = 0.08
        for idx in 1..<raw.count {
            let previous = out[idx - 1]
            let target = (alpha * raw[idx]) + ((1 - alpha) * previous)
            let delta = max(-maxStep, min(maxStep, target - previous))
            out.append(clamp01(previous + delta))
        }
        return out
    }

    private func companionTrend(from timeline: [CompanionStatePoint]) -> CompanionTrend {
        guard timeline.count >= 14 else { return .stable }
        let firstHalf = timeline.prefix(7).map(\.score).reduce(0, +) / 7.0
        let secondHalf = timeline.suffix(7).map(\.score).reduce(0, +) / 7.0
        let delta = secondHalf - firstHalf
        if delta > 0.045 { return .improving }
        if delta < -0.045 { return .regressing }
        return .stable
    }

    private func regulationConfidence(upTo date: Date) -> Double {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -13, to: cal.startOfDay(for: date)) ?? date
        let sample = journalEntries.filter { $0.date >= start && $0.date <= date }
        let activeDays = Set(sample.map { cal.startOfDay(for: $0.date) }).count
        let density = clamp01(Double(sample.count) / 20.0)
        let coverage = clamp01(Double(activeDays) / 14.0)
        return clamp01((density * 0.55) + (coverage * 0.45))
    }

    private func mapState(from score: Double) -> CompanionEmotionalState {
        switch score {
        case ..<0.35: .overwhelmed
        case ..<0.55: .activated
        case ..<0.65: .steadying
        case ..<0.82: .balanced
        default: .thriving
        }
    }

    private func streakDays(upTo date: Date) -> Int {
        let cal = Calendar.current
        let unique = Set(journalEntries.map { cal.startOfDay(for: $0.date) })
        var cursor = cal.startOfDay(for: date)
        var streak = 0
        while unique.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    private func clamp01(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private func interpolateColor(from: Color, to: Color, t: Double) -> Color {
        let tt = clamp01(t)
        let fromRGBA = UIColor(from).rgba
        let toRGBA = UIColor(to).rgba
        return Color(
            red: fromRGBA.r + ((toRGBA.r - fromRGBA.r) * tt),
            green: fromRGBA.g + ((toRGBA.g - fromRGBA.g) * tt),
            blue: fromRGBA.b + ((toRGBA.b - fromRGBA.b) * tt)
        )
    }

    func completeCalmSession(mode: BreathingMode, duration: TimeInterval) {
        guard duration >= 45 else { return }
        calmSessionDates.append(Date())
        let cutoff = Date().addingTimeInterval(-(21 * 24 * 60 * 60))
        calmSessionDates.removeAll { $0 < cutoff }
        let raw = calmSessionDates.map(\.timeIntervalSince1970)
        UserDefaults.standard.set(raw, forKey: calmSessionDatesKey)
        saveSnapshot()
    }

    func checkInCountThisWeek() -> Int {
        currentWeekDates.filter { day in
            journalEntries.contains { Calendar.current.isDate($0.date, inSameDayAs: day) }
        }.count
    }

    var hasWeeklyReview: Bool {
        weeklyReadiness.ready
    }

    var hasMonthlyReviewAccess: Bool {
        planTier == .premium
    }

    var monthlyReviewContextEntries: [JournalEntry] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -27, to: calendar.startOfDay(for: Date())) ?? Date()
        return journalEntries
            .filter { $0.date >= start && $0.date <= Date() }
            .sorted { $0.date < $1.date }
    }

    var hasMonthlyReview: Bool {
        guard hasMonthlyReviewAccess else { return false }
        let entries = monthlyReviewContextEntries
        let activeDays = Set(entries.map { Calendar.current.startOfDay(for: $0.date) }).count
        return activeDays >= 8 || entries.count >= 14
    }

    var monthlyReviewAvailabilityText: String {
        guard hasMonthlyReviewAccess else { return "Monthly reviews are Premium only." }
        guard hasMonthlyReview else {
            let entries = monthlyReviewContextEntries
            let days = Set(entries.map { Calendar.current.startOfDay(for: $0.date) }).count
            return "Monthly review unlocks after 8 active days or 14 entries in the last 4 weeks. Current: \(days) days, \(entries.count) entries."
        }
        return "Monthly review is ready from your last 4 weeks."
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
            ("Get one AI read and action", reviewedToday),
            ("Unlock your weekly pattern review", hasWeeklyReview)
        ]
    }

    var onboardingMissionProgressText: String {
        let mission = onboardingMission
        let doneCount = mission.filter(\.done).count
        return "\(doneCount)/\(mission.count) steps complete"
    }

    var baselineReassessmentStatusText: String {
        guard let completedAt = onboardingProfile.assessment?.completedAt else {
            return "No baseline saved yet."
        }
        let days = Calendar.current.dateComponents([.day], from: completedAt, to: Date()).day ?? 0
        if days >= 14 {
            return "Baseline refresh is due. Retake it to compare the last 2 weeks."
        }
        let remaining = max(0, 14 - days)
        return "Next baseline refresh in \(remaining) day\(remaining == 1 ? "" : "s")."
    }

    var isBaselineReassessmentDue: Bool {
        guard let completedAt = onboardingProfile.assessment?.completedAt else { return false }
        let days = Calendar.current.dateComponents([.day], from: completedAt, to: Date()).day ?? 0
        return days >= 14
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
        weeklyReview = weeklyReviewService.latestReview(from: journalEntries, profile: onboardingProfile, healthSummary: healthSummary, goals: reflectionGoals)
        applyAdaptiveAssessmentAdjustment(reason: "entry_update")
        selectedMood = mood
        saveSnapshot()
        return entry
    }

    func updateEntry(id: UUID, text: String, mood: MoodLevel, type: EntryType, date: Date) {
        guard let index = journalEntries.firstIndex(where: { $0.id == id }) else { return }
        let original = journalEntries[index]
        let themes = insightService.themes(for: text, entryType: type)

        journalEntries[index].date = date
        journalEntries[index].mood = mood
        journalEntries[index].entryType = type
        journalEntries[index].text = text
        journalEntries[index].themes = themes
        journalEntries[index].aiInsight = insightService.insight(for: journalEntries[index], recentEntries: journalEntries)

        dailyReviews.removeAll {
            $0.entryIDs.contains(id) ||
            Calendar.current.isDate($0.date, inSameDayAs: original.date) ||
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
        insights.removeAll {
            Calendar.current.isDate($0.date, inSameDayAs: original.date) ||
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }

        weeklyReview = weeklyReviewService.latestReview(from: journalEntries, profile: onboardingProfile, healthSummary: healthSummary, goals: reflectionGoals)
        applyAdaptiveAssessmentAdjustment(reason: "entry_edit")
        saveSnapshot()
    }

    func deleteEntry(id: UUID) {
        guard let entry = journalEntries.first(where: { $0.id == id }) else { return }
        journalEntries.removeAll { $0.id == id }
        dailyReviews.removeAll {
            $0.entryIDs.contains(id) || Calendar.current.isDate($0.date, inSameDayAs: entry.date)
        }
        insights.removeAll { Calendar.current.isDate($0.date, inSameDayAs: entry.date) }
        weeklyReview = weeklyReviewService.latestReview(from: journalEntries, profile: onboardingProfile, healthSummary: healthSummary, goals: reflectionGoals)
        applyAdaptiveAssessmentAdjustment(reason: "entry_delete")
        saveSnapshot()
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
        archiveStaleActiveGoals(before: date)
        let recentEntries = dailyContextEntries(for: date)
        let existingDayReview = dailyReviews.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
        let hasUsedAIDailyReview = existingDayReview?.source == "openai"
        let premiumGoalContext = dailyReviewGoalContext(includeArchived: true)
        let freeGoalContext = dailyReviewGoalContext(includeArchived: false)

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
                        goals: premiumGoalContext
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
                aiConnection = .unavailable
                return nil
            }
        } else if planTier == .premium {
            guard let local = insightService.dailyReview(
                for: date,
                entries: dayEntries,
                recentEntries: recentEntries,
                profile: onboardingProfile,
                healthSummary: healthSummary,
                goals: premiumGoalContext
            ) else { return nil }
            aiConnection = .connected(model: "openai")
            var localReview = local
            localReview.source = "local"
            review = localReview
        } else {
            guard let local = insightService.dailyReview(
                for: date,
                entries: dayEntries,
                recentEntries: recentEntries,
                profile: onboardingProfile,
                healthSummary: healthSummary,
                goals: freeGoalContext
            ) else { return nil }
            var localReview = local
            localReview.source = "local"
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
            aiConnection = .unavailable
            return nil
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
        weeklyReview = weeklyReviewService.latestReview(from: journalEntries, profile: onboardingProfile, healthSummary: summary, goals: reflectionGoals)
        saveSnapshot()
    }

    func refreshWeeklyReview() async {
        let scopedEntries = weeklyContextEntries()
        guard hasWeeklyReview else {
            weeklyReview = weeklyReviewService.latestReview(from: scopedEntries, profile: onboardingProfile, healthSummary: healthSummary, goals: reflectionGoals)
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
                aiConnection = .connected(model: "openai")
            }
        } catch {
            weeklyReview = weeklyReviewService.latestReview(from: scopedEntries, profile: onboardingProfile, healthSummary: healthSummary, goals: reflectionGoals)
            aiConnection = .unavailable
        }
        applyAdaptiveAssessmentAdjustment(reason: "weekly_review")
        saveSnapshot()
    }

    func refreshMonthlyReview() async {
        guard hasMonthlyReviewAccess else {
            monthlyReview = nil
            saveSnapshot()
            return
        }
        guard hasMonthlyReview else { return }

        onboardingProfile = .current
        do {
            if let review = try await apiService.monthlyReview(
                entries: monthlyReviewContextEntries,
                weeklyReviews: [weeklyReview],
                profile: onboardingProfile,
                healthSummary: healthSummary,
                goals: reflectionGoals,
                planTier: planTier
            ) {
                monthlyReview = review
                saveSnapshot()
            }
        } catch {
            aiConnection = .unavailable
        }
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
            conversation = Conversation(
                id: UUID(),
                title: "AI unavailable",
                date: Date(),
                preview: "AI check-in could not be generated. Try again when the service is available.",
                messages: [
                    ConversationMessage(
                        id: UUID(),
                        sender: .ai,
                        text: "AI check-in could not be generated. Try again when the service is available.",
                        date: Date()
                    )
                ],
                status: .ended,
                remainingTurns: 0,
                maxTurns: 0,
                deepeningUsed: false,
                phase: .core
            )
            }

        conversations.insert(conversation, at: 0)
        UserDefaults.standard.set(Date(), forKey: lastWeeklyCheckInAtKey)
        saveSnapshot()
        return conversation
    }

    func startMonthlyConversation() async -> Conversation {
        guard hasMonthlyReviewAccess else {
            return blockedConversation(title: "Monthly review", message: "Monthly reviews are Premium only.", cadence: .monthly)
        }
        guard hasMonthlyReview else {
            return blockedConversation(title: "Monthly review", message: monthlyReviewAvailabilityText, cadence: .monthly)
        }

        onboardingProfile = .current
        await refreshMonthlyReview()
        guard let monthlyReview else {
            return blockedConversation(title: "Monthly review", message: "Monthly review could not be generated right now.", cadence: .monthly)
        }

        let conversation: Conversation
        do {
            conversation = try await apiService.startMonthlyConversation(monthlyReview: monthlyReview, profile: onboardingProfile)
        } catch {
            conversation = blockedConversation(title: "AI unavailable", message: "AI monthly check-in could not be generated. Try again when the service is available.", cadence: .monthly)
        }

        conversations.insert(conversation, at: 0)
        saveSnapshot()
        return conversation
    }

    private func blockedConversation(title: String, message: String, cadence: ReviewCadence) -> Conversation {
        Conversation(
            id: UUID(),
            title: title,
            date: Date(),
            preview: message,
            messages: [ConversationMessage(id: UUID(), sender: .ai, text: message, date: Date())],
            status: .ended,
            remainingTurns: 0,
            maxTurns: 0,
            deepeningUsed: false,
            phase: .core,
            reviewCadence: cadence
        )
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

            let synthesized = synthesizeWeeklyGoal(from: updated, suggestion: suggestion)
            let isMonthly = updated.reviewCadence == .monthly
            let goal = addReflectionGoal(
                title: synthesized.title,
                reason: synthesized.reason,
                sourceConversationID: updated.id,
                durationDays: isMonthly ? 30 : 7
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
                updated.status = .ended
                updated.remainingTurns = 0
                reply = "AI reply could not be generated. I am stopping here instead of giving you a weaker local answer."
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

    private func synthesizeWeeklyGoal(from conversation: Conversation, suggestion: (title: String, reason: String)) -> (title: String, reason: String) {
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
            title = suggestion.title.hasPrefix("7-day") ? suggestion.title : "7-day focus plan"
            reason = "Agreed plan for the next 7 days: \(suggestion.reason)"
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
    func addReflectionGoal(title: String, reason: String, sourceConversationID: UUID? = nil, durationDays: Int = 3, cadence: GoalCadence = .daily) -> ReflectionGoal {
        let existing = reflectionGoals.first {
            $0.status == .active &&
            ($0.cadence ?? .daily) == cadence &&
            $0.title.caseInsensitiveCompare(title) == .orderedSame
        }
        if let existing {
            return existing
        }

        if cadence != .daily {
            for index in reflectionGoals.indices where reflectionGoals[index].status == .active && (reflectionGoals[index].cadence ?? .daily) == cadence {
                reflectionGoals[index].status = .archived
                if reflectionGoals[index].feedback == nil {
                    reflectionGoals[index].feedback = "replaced"
                    reflectionGoals[index].feedbackAt = Date()
                }
            }
        }

        let goal = ReflectionGoal(
            id: UUID(),
            title: title,
            reason: reason,
            createdAt: Date(),
            dueDate: Calendar.current.date(byAdding: .day, value: max(1, durationDays), to: Date()),
            status: .active,
            cadence: cadence,
            sourceConversationID: sourceConversationID,
            checkInPrompt: "How did this go: \(title.lowercased())?",
            feedback: nil,
            feedbackAt: nil
        )
        reflectionGoals.insert(goal, at: 0)
        if cadence == .daily {
            pruneActiveGoals(limit: 3)
        }
        saveSnapshot()
        return goal
    }

    @discardableResult
    func saveSuggestedReviewGoal(cadence: GoalCadence) -> ReflectionGoal? {
        switch cadence {
        case .daily:
            guard let review = latestDailyReview else { return nil }
            let title = review.suggestedGoalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let reason = review.suggestedGoalReason.trimmingCharacters(in: .whitespacesAndNewlines)
            guard title.isEmpty == false, reason.isEmpty == false else { return nil }
            return addReflectionGoal(title: title, reason: reason, durationDays: 3, cadence: .daily)
        case .weekly:
            guard let text = suggestedWeeklyGoalText else { return nil }
            return addReflectionGoal(
                title: weeklyGoalTitle(from: text),
                reason: text,
                durationDays: 7,
                cadence: .weekly
            )
        case .monthly:
            guard let text = suggestedMonthlyGoalText else { return nil }
            return addReflectionGoal(
                title: monthlyGoalTitle(from: text),
                reason: text,
                durationDays: 30,
                cadence: .monthly
            )
        }
    }

    func toggleGoal(_ goal: ReflectionGoal) {
        guard let index = reflectionGoals.firstIndex(where: { $0.id == goal.id }) else { return }
        reflectionGoals[index].status = reflectionGoals[index].status == .active ? .completed : .active
        if reflectionGoals[index].status == .completed, reflectionGoals[index].feedback == nil {
            reflectionGoals[index].feedback = "helped"
            reflectionGoals[index].feedbackAt = Date()
        } else if reflectionGoals[index].status == .active {
            reflectionGoals[index].feedback = nil
            reflectionGoals[index].feedbackAt = nil
        }
        weeklyReview = weeklyReviewService.latestReview(from: journalEntries, profile: onboardingProfile, healthSummary: healthSummary, goals: reflectionGoals)
        saveSnapshot()
    }

    func setGoalFeedback(_ goal: ReflectionGoal, feedback: String) {
        guard let index = reflectionGoals.firstIndex(where: { $0.id == goal.id }) else { return }
        reflectionGoals[index].feedback = feedback
        reflectionGoals[index].feedbackAt = Date()
        if feedback == "helped" {
            reflectionGoals[index].status = .completed
        }
        weeklyReview = weeklyReviewService.latestReview(from: journalEntries, profile: onboardingProfile, healthSummary: healthSummary, goals: reflectionGoals)
        saveSnapshot()
    }

    private func pruneActiveGoals(limit: Int) {
        let activeIndices = reflectionGoals.indices.filter { reflectionGoals[$0].status == .active }
        guard activeIndices.count > limit else { return }
        for index in activeIndices.dropFirst(limit) {
            reflectionGoals[index].status = .completed
            if reflectionGoals[index].feedback == nil {
                reflectionGoals[index].feedback = "replaced"
                reflectionGoals[index].feedbackAt = Date()
            }
        }
    }

    private func archiveStaleActiveGoals(before date: Date) {
        let cutoff = Calendar.current.startOfDay(for: date)
        var didChange = false

        for index in reflectionGoals.indices {
            guard reflectionGoals[index].status == .active else { continue }
            guard (reflectionGoals[index].cadence ?? .daily) == .daily else { continue }
            guard Calendar.current.startOfDay(for: reflectionGoals[index].createdAt) < cutoff else { continue }
            reflectionGoals[index].status = .archived
            if reflectionGoals[index].feedback == nil {
                reflectionGoals[index].feedback = "auto_cleared"
                reflectionGoals[index].feedbackAt = Date()
            }
            didChange = true
        }

        if didChange {
            weeklyReview = weeklyReviewService.latestReview(from: journalEntries, profile: onboardingProfile, healthSummary: healthSummary, goals: reflectionGoals)
        }
    }

    private func dailyReviewGoalContext(includeArchived: Bool) -> [ReflectionGoal] {
        let active = reflectionGoals.filter { $0.status == .active }
        let completed = Array(reflectionGoals
            .filter { $0.status == .completed }
            .sorted { ($0.feedbackAt ?? $0.createdAt) > ($1.feedbackAt ?? $1.createdAt) }
            .prefix(6))
        let archived = includeArchived
            ? Array(reflectionGoals
                .filter { $0.status == .archived }
                .sorted { ($0.feedbackAt ?? $0.createdAt) > ($1.feedbackAt ?? $1.createdAt) }
                .prefix(4))
            : []

        return active + completed + archived
    }

    private func weeklyGoalTitle(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("Next 7 days:") {
            return "This week's focus"
        }
        return "Weekly focus"
    }

    private func monthlyGoalTitle(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty == false {
            return "This month's focus"
        }
        return "Monthly focus"
    }

    func refreshAIConnection() async {
        aiConnection = .checking
        do {
            let health = try await apiService.health()
            aiConnection = health.ai == "configured" ? .connected(model: health.model) : .unconfigured(model: health.model)
        } catch {
            aiConnection = .unavailable
        }
    }

    func exportLocalData() -> URL? {
        try? localStore.export(snapshot)
    }

    func exportTherapistReport() -> URL? {
        try? localStore.exportTherapistReport(
            snapshot: snapshot,
            memorySignals: memorySignals,
            monthlyReview: currentMonthlyReview
        )
    }

    func deleteLocalData() {
        journalEntries = []
        insights = []
        conversations = []
        weeklyReview = weeklyReviewService.latestReview(from: [], goals: reflectionGoals)
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

    private func buildMemorySignals(from entries: [JournalEntry]) -> [MemorySignal] {
        let groupedThemes = Dictionary(grouping: entries.flatMap { entry in
            entry.themes.map { theme in (theme: theme, date: entry.date) }
        }, by: { $0.theme })

        let themeSignals = groupedThemes.compactMap { theme, values -> MemorySignal? in
            guard values.count >= 2 else { return nil }
            return MemorySignal(
                id: UUID(),
                title: "\(theme) keeps appearing",
                detail: "\(theme) appears across \(values.count) entries. Watch what makes it heavier or lighter.",
                count: values.count,
                lastSeen: values.map(\.date).max() ?? Date(),
                category: "Theme"
            )
        }

        let goalSignals = reflectionGoals.compactMap { goal -> MemorySignal? in
            guard let feedback = goal.feedback else { return nil }
            return MemorySignal(
                id: goal.id,
                title: goal.title,
                detail: "Feedback: \(feedback.replacingOccurrences(of: "_", with: " ")).",
                count: 1,
                lastSeen: goal.feedbackAt ?? goal.createdAt,
                category: "Goal"
            )
        }

        return (themeSignals + goalSignals)
            .sorted { lhs, rhs in
                lhs.count == rhs.count ? lhs.lastSeen > rhs.lastSeen : lhs.count > rhs.count
            }
            .prefix(12)
            .map { $0 }
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
            monthlyReview: monthlyReview,
            healthSummary: healthSummary,
            reflectionGoals: reflectionGoals,
            dailyReviews: dailyReviews
        )
    }

    private var demoSnapshot: AppSnapshot {
        Self.buildDemoSnapshot(using: weeklyReviewService)
    }

    private var emptySnapshot: AppSnapshot {
        AppSnapshot(
            selectedMood: .okay,
            journalEntries: [],
            insights: [],
            conversations: [],
            weeklyReview: weeklyReviewService.latestReview(from: [], goals: reflectionGoals),
            monthlyReview: nil,
            healthSummary: nil,
            reflectionGoals: [],
            dailyReviews: []
        )
    }

    private static func buildDemoSnapshot(using weeklyReviewService: MockWeeklyReviewService) -> AppSnapshot {
        let entries = MockData.entries
        return AppSnapshot(
            selectedMood: entries.first?.mood ?? .okay,
            journalEntries: entries,
            insights: MockData.insights,
            conversations: [],
            weeklyReview: weeklyReviewService.latestReview(from: entries),
            monthlyReview: nil,
            healthSummary: nil,
            reflectionGoals: [],
            dailyReviews: []
        )
    }

    private func saveSnapshot() {
        localStore.save(snapshot)
        refreshWidgetPayload()
        if isICloudSyncEnabled && isDemoDataEnabled == false {
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
        monthlyReview = snapshot.monthlyReview
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
        let recentEntries = recentWidgetEntries()
        let payload = WidgetAffirmationPayload(
            preferredName: onboardingProfile.preferredName,
            planTier: planTier == .premium ? .premium : .free,
            primaryText: widgetPrimaryText(),
            secondaryText: widgetSecondaryText(),
            affirmationText: affirmationOptions.isEmpty ? nil : affirmationOptions[normalizedIndex],
            affirmationOptions: affirmationOptions,
            affirmationIndex: normalizedIndex,
            stylePreset: widgetStylePreset,
            accentColor: widgetAccentColor,
            fontStyle: widgetFontStyle,
            enabledCategories: Array(widgetAffirmationCategories),
            issueContext: widgetIssueContext(),
            entryCount: recentEntries.count,
            currentStreak: currentStreakDays,
            averageMood: widgetAverageMoodScore(from: recentEntries),
            latestMood: (recentEntries.last ?? latestJournalEntry)?.mood.rawValue ?? "okay",
            recentMoodScores: recentWidgetMoodScores(from: recentEntries),
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

    private func recentWidgetEntries() -> [JournalEntry] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -29, to: Date()) ?? Date.distantPast
        return journalEntries
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
    }

    private func widgetAverageMoodScore(from recent: [JournalEntry]) -> Double {
        guard recent.isEmpty == false else { return 0 }
        let total = recent.reduce(0) { $0 + $1.mood.score }
        return Double(total) / Double(recent.count)
    }

    private func recentWidgetMoodScores(from recent: [JournalEntry]) -> [Int] {
        Array(recent.suffix(12)).map(\.mood.score)
    }

    private func widgetAffirmationOptions() -> [String] {
        let categories = widgetAffirmationCategories.isEmpty ? Set(WidgetAffirmationCategory.allCases) : widgetAffirmationCategories
        let preferred = onboardingProfile.preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let issue = widgetIssueContext().lowercased()
        let latestMood = latestJournalEntry?.mood ?? .okay
        let lastSleep = healthSummary?.lastNightSleep ?? latestJournalEntry?.sleepHours ?? 0
        let lowSleep = lastSleep > 0 && lastSleep < 6.25
        let lowerGoal = onboardingProfile.reflectionGoal.lowercased()

        let candidates = widgetAffirmationCandidates(
            categories: categories,
            preferredName: preferred,
            issue: issue,
            latestMood: latestMood,
            lowSleep: lowSleep,
            goal: lowerGoal
        )

        let sorted = candidates
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.text < rhs.text
                }
                return lhs.score > rhs.score
            }
            .map(\.text)

        if sorted.isEmpty {
            return ["You are allowed to take this one step at a time."]
        }

        var deduped: [String] = []
        for option in sorted where deduped.contains(option) == false {
            deduped.append(option)
        }
        return deduped
    }

    private func widgetAffirmationCandidates(
        categories: Set<WidgetAffirmationCategory>,
        preferredName: String,
        issue: String,
        latestMood: MoodLevel,
        lowSleep: Bool,
        goal: String
    ) -> [(text: String, score: Int)] {
        var candidates: [(text: String, score: Int)] = []

        func add(_ text: String, base: Int, category: WidgetAffirmationCategory? = nil, tags: [String] = []) {
            var score = base

            if let category, categories.contains(category) {
                score += 3
            }

            for tag in tags {
                if issue.contains(tag) {
                    score += 3
                }
                if goal.contains(tag) {
                    score += 2
                }
            }

            switch latestMood {
            case .terrible, .low:
                if category == .grounding || category == .rest || category == .stress {
                    score += 3
                }
            case .okay:
                if category == .focus || category == .confidence {
                    score += 1
                }
            case .good, .great:
                if category == .confidence || category == .focus {
                    score += 2
                }
            }

            if lowSleep && (category == .rest || tags.contains("sleep")) {
                score += 4
            }

            candidates.append((text: text, score: score))
        }

        add("You are safe in this moment.", base: 5, category: .grounding, tags: ["anxiety", "panic", "overwhelm"])
        add("Come back to this moment one breath at a time.", base: 5, category: .grounding, tags: ["anxiety", "stress", "overwhelm"])
        add("You can meet today gently and still make progress.", base: 5, category: .confidence)
        add(preferredName.isEmpty ? "You can handle this one step at a time." : "\(preferredName), you can handle this one step at a time.", base: 6, category: .confidence)
        add("You have already survived hard moments before.", base: 5, category: .confidence, tags: ["anxiety", "stress", "burnout"])
        add("One clear task is enough right now.", base: 5, category: .focus, tags: ["focus", "adhd", "attention", "work"])
        add("Small progress still counts.", base: 4, category: .focus, tags: ["focus", "adhd", "attention"])
        add("You only need to begin, not finish everything.", base: 4, category: .focus, tags: ["focus", "stress", "work"])
        add("Rest helps your mind and body recover.", base: 5, category: .rest, tags: ["sleep", "tired", "energy", "illness"])
        add("You do not need to earn recovery.", base: 5, category: .rest, tags: ["sleep", "rest", "burnout", "illness"])
        add("A slower pace can still be a good day.", base: 4, category: .rest, tags: ["energy", "illness", "tired"])
        add("You can let go of what is not urgent.", base: 5, category: .stress, tags: ["stress", "burnout", "pressure"])
        add("Pressure does not define your worth.", base: 5, category: .stress, tags: ["stress", "burnout", "work"])
        add("Doing one thing well is enough for today.", base: 6, category: .stress, tags: ["stress", "burnout", "focus"])

        if issue.contains("anxiety") {
            add("Anxiety is a feeling, not a verdict.", base: 10, category: .grounding, tags: ["anxiety"])
        }
        if issue.contains("sleep") {
            add("Protecting sleep is an act of care.", base: 10, category: .rest, tags: ["sleep"])
        }
        if issue.contains("stress") || issue.contains("burnout") {
            add("You can narrow the day and still do enough.", base: 10, category: .stress, tags: ["stress", "burnout"])
        }
        if issue.contains("focus") || issue.contains("adhd") || issue.contains("attention") {
            add("You can begin small and still make real progress.", base: 10, category: .focus, tags: ["focus", "adhd", "attention"])
        }
        if issue.contains("illness") || issue.contains("physical") || issue.contains("pain") {
            add("Your body may need care more than pressure right now.", base: 10, category: .rest, tags: ["illness", "physical", "pain"])
        }

        return candidates
    }

    private func widgetIssueContext() -> String {
        if onboardingProfile.focusAreas.isEmpty == false {
            return onboardingProfile.focusAreas.joined(separator: " · ")
        }
        return "General reflection"
    }
}

private extension UIColor {
    var rgba: (r: Double, g: Double, b: Double, a: Double) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}
