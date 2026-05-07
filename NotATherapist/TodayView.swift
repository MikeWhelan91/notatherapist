import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var router: AppRouter
    @State private var circleState: AICircleState = .idle
    @State private var companionLensFocusActive = false
    @State private var companionBusy = false
    @State private var showingNewEntry = false
    @State private var showingWeekly = false
    @State private var showingSettings = false
    @State private var activeDailyReview: DailyReview?
    @State private var isReviewingToday = false
    @State private var showingHistory = false
    @State private var showingReviewModeChoice = false
    @State private var collapsedGoalIDs: Set<UUID> = []
    @State private var missionRevealCount = 0
    @State private var confettiTrigger = 0
    @State private var lastMissionDoneCount = 0
    @State private var lastStreakValue = 0
    @State private var companionTrigger = 0
    @State private var selectedCompanionDriver: AppViewModel.CompanionDriver?
    @State private var selectedGoalScope: GoalCadence = .daily

    private enum DriverAction {
        case openCheckIn
        case openCalm
        case openGoals
    }

    private var todayEntries: [JournalEntry] {
        appModel.entries(on: Date())
    }

    private var todayReview: DailyReview? {
        appModel.dailyReview(on: Date())
    }

    private var hasNewEntriesSinceTodayReview: Bool {
        guard let review = todayReview else { return todayEntries.isEmpty == false }
        let currentIDs = Set(todayEntries.map(\.id))
        return currentIDs != Set(review.entryIDs)
    }

    private var canRunTodayReview: Bool {
        guard todayEntries.isEmpty == false else { return false }
        if appModel.planTier == .premium {
            return true
        }
        return todayReview == nil || hasNewEntriesSinceTodayReview
    }

    private var todayReviewHint: String {
        if appModel.planTier == .premium {
            if todayReview?.source == "openai" {
                return "Deep review already used today. You can still refresh locally as often as you want."
            }
            return "Run today's review. The first pass is deeper; later refreshes are local."
        }
        if todayReview == nil {
            return "Run a short review when you are finished writing."
        }
        return hasNewEntriesSinceTodayReview
            ? "You added a new entry. Run review again to refresh today's guidance."
            : "Add another entry to refresh today's review."
    }

    private enum NextActionKind {
        case writeEntry
        case reviewToday
        case openWeekly
        case keepStreak
    }

    private var nextAction: (kind: NextActionKind, title: String, subtitle: String, cta: String) {
        if todayEntries.isEmpty {
            return (.writeEntry, "Your fastest win", "Start with a 30-second check-in to keep momentum.", "Write check-in")
        }
        if todayReview == nil {
            return (.reviewToday, "Lock in today", "You already wrote. Review now to turn it into guidance.", "Review today")
        }
        if appModel.hasWeeklyReview {
            return (.openWeekly, "Weekly insight is ready", "See this week as one story, not disconnected entries.", "Open weekly review")
        }
        return (.keepStreak, "Keep momentum", "Your weekly unlock is close. Stay consistent tomorrow.", "View history")
    }

    private var nextActionTimeHint: String {
        switch nextAction.kind {
        case .writeEntry: "~30 sec"
        case .reviewToday: "~20 sec"
        case .openWeekly: "~2 min"
        case .keepStreak: "~10 sec"
        }
    }

    private var visibleDailyGoals: [ReflectionGoal] {
        appModel.activeGoals(for: .daily)
            .filter { collapsedGoalIDs.contains($0.id) == false }
            .prefix(3)
            .map { $0 }
    }

    private var visibleWeeklyGoals: [ReflectionGoal] {
        Array(appModel.activeGoals(for: .weekly).prefix(1))
    }

    private var visibleMonthlyGoals: [ReflectionGoal] {
        Array(appModel.activeGoals(for: .monthly).prefix(1))
    }

    private var shouldShowGoalsSection: Bool {
        visibleDailyGoals.isEmpty == false ||
        visibleWeeklyGoals.isEmpty == false ||
        visibleMonthlyGoals.isEmpty == false ||
        appModel.suggestedWeeklyGoalText != nil ||
        appModel.suggestedMonthlyGoalText != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    HStack {
                        Spacer()
                        AICircleView(
                            state: circleState,
                            size: 104,
                            strokeWidth: 3.2,
                            tint: appModel.companionTint,
                            lensFocusActive: companionLensFocusActive,
                            personality: appModel.companionPersonality,
                            trigger: companionTrigger
                        )
                        Spacer()
                    }
                    .padding(.top, 2)

                    ReferenceCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Companion state")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int((appModel.companionConfidence * 100).rounded()))% confidence")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            Text(appModel.companionState.title)
                                .font(.title3.weight(.bold))
                            Text(appModel.companionStateHeroText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ReferenceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Signal clarity")
                                    .font(.subheadline.weight(.semibold))
                                ExplainerButton(
                                    title: "Signal clarity",
                                    body: "Signal clarity is how much useful recent evidence the app has. It is not a score of you.",
                                    bullets: [
                                        "Check-ins, reviews, calm sessions, and action feedback make it clearer.",
                                        "Higher clarity means suggestions can be more specific.",
                                        "Lower clarity means the app will keep advice simpler and less certain."
                                    ]
                                )
                                Spacer()
                                Text("\(appModel.signalClarityPercent)%")
                                    .font(.subheadline.weight(.bold))
                            }
                            ProgressView(value: Double(appModel.signalClarityPercent), total: 100)
                                .tint(appModel.companionTint)
                            Text("Higher clarity means the app has enough recent evidence to make sharper suggestions.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ReferenceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Why it changed today")
                                .font(.subheadline.weight(.semibold))
                            ForEach(appModel.companionDriversToday.prefix(4)) { driver in
                                Button {
                                    selectedCompanionDriver = driver
                                } label: {
                                    HStack {
                                        Text(driver.name)
                                            .font(.caption)
                                        Spacer()
                                        Text("\(Int((driver.contribution * 100).rounded()))%")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(driver.direction == "up" ? Color.green : Color.orange)
                                        Image(systemName: "info.circle")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("How are you feeling?")
                            .font(.subheadline.weight(.semibold))
                        MoodSelectorView(selectedMood: $appModel.selectedMood)
                    }

                    ReferenceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(nextAction.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(nextActionTimeHint)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            Text(nextAction.subtitle)
                                .font(.subheadline.weight(.semibold))

                            Button {
                                companionTrigger += 1
                                runNextAction()
                            } label: {
                                Label(nextAction.cta, systemImage: nextActionSymbol)
                            }
                            .buttonStyle(PrimaryCapsuleButtonStyle())
                            .disabled(isReviewingToday)
                        }
                    }

                    if appModel.onboardingMission.filter(\.done).count < appModel.onboardingMission.count {
                        ReferenceCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Your first 3-day mission")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(appModel.onboardingMissionProgressText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                ProgressView(value: missionProgressRatio)
                                    .tint(.primary)
                                    .animation(.easeOut(duration: 0.28), value: missionProgressRatio)

                                ForEach(Array(appModel.onboardingMission.enumerated()), id: \.offset) { _, step in
                                    HStack(spacing: 8) {
                                        Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(step.done ? .primary : .secondary)
                                        Text(step.title)
                                            .font(.caption)
                                            .foregroundStyle(step.done ? .primary : .secondary)
                                    }
                                    .opacity(missionRevealCount > 0 ? 1 : 0)
                                    .offset(y: missionRevealCount > 0 ? 0 : 8)
                                    .animation(.easeOut(duration: 0.28), value: missionRevealCount)
                                }
                            }
                        }
                        .onAppear {
                            missionRevealCount = 0
                            withAnimation(.easeOut(duration: 0.22)) {
                                missionRevealCount = 1
                            }
                        }
                    }

                    ReferenceCard {
                        HStack(spacing: 12) {
                            Image(systemName: todayEntries.isEmpty ? "book.closed" : "book")
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(todayEntries.count == 0 ? "No entries today" : "\(todayEntries.count) \(todayEntries.count == 1 ? "entry" : "entries") today")
                                    .font(.subheadline.weight(.semibold))
                                Text(todayReview == nil ? "Save what matters. Review when the day feels done." : "Today has been reviewed.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }

                    if shouldShowGoalsSection {
                        nextStepsSection
                    }

                    if let todayReview {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(title: "Today's review")
                            Button {
                                activeDailyReview = todayReview
                            } label: {
                                ReferenceCard {
                                    HStack(alignment: .center, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(todayReview.summary)
                                                .font(.subheadline.weight(.semibold))
                                            Text(todayReview.insight.action)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if appModel.journalEntries.isEmpty {
                        ReferenceCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Start with one entry.")
                                    .font(.subheadline.weight(.semibold))
                                Text("Reviews and stats appear after you write.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else if todayEntries.isEmpty == false {
                        ReferenceCard {
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(todayReview == nil ? "Ready to review today." : "Review status")
                                        .font(.subheadline.weight(.semibold))
                                    Text(todayReviewHint)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Button {
                                    guard canRunTodayReview else { return }
                                    if shouldPromptForReviewMode {
                                        showingReviewModeChoice = true
                                    } else {
                                        runTodayReview(preferLocal: appModel.planTier == .premium && todayReview?.source == "openai")
                                    }
                                } label: {
                                    Label(
                                        isReviewingToday
                                            ? "Reviewing"
                                            : (canRunTodayReview
                                                ? ((appModel.planTier == .premium && todayReview?.source == "openai") ? "Refresh review" : "Review today")
                                                : "Review unavailable"),
                                        systemImage: "sparkle.magnifyingglass"
                                    )
                                }
                                .buttonStyle(PrimaryCapsuleButtonStyle())
                                .disabled(isReviewingToday || canRunTodayReview == false)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(title: "This week")
                        StreakCardView(
                            currentWeekDates: appModel.currentWeekDates,
                            entriesForDate: { appModel.entries(on: $0) },
                            checkedInCount: appModel.checkInCountThisWeek(),
                            currentStreakDays: appModel.currentStreakDays,
                            longestStreakDays: appModel.longestStreakDays,
                            streakGoalDays: appModel.streakGoalDays
                        )
                    }

                    if let followUp = appModel.adaptiveFollowUpQuestion {
                        ReferenceCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Adaptive follow-up", systemImage: "waveform.path.ecg")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Text(followUp)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    ExplainerButton(
                                        title: "Adaptive follow-up",
                                        body: "This question is chosen from your baseline, recent mood, and repeated signals. Answering it gives the next review better evidence.",
                                        bullets: [
                                            "It changes as your entries change.",
                                            "It is designed to improve the next entry, not diagnose anything.",
                                            "Short answers still help."
                                        ]
                                    )
                                }
                                Text("Answer this in your next entry. It helps tune your baseline over time.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if appModel.isBaselineReassessmentDue {
                        ReferenceCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Baseline refresh", systemImage: "calendar.badge.clock")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Text("Retake your 2-week baseline")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    ExplainerButton(
                                        title: "Baseline refresh",
                                        body: "The intake asks about the last 2 weeks, so refreshing every 14 days gives a cleaner before-and-after comparison.",
                                        bullets: [
                                            "It updates your strongest domains.",
                                            "Weekly reports compare against the refreshed baseline.",
                                            "It is a reflection baseline, not a diagnosis."
                                        ]
                                    )
                                }
                                Text(appModel.baselineReassessmentStatusText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button {
                                    showingSettings = true
                                } label: {
                                    Label("Open profile", systemImage: "arrow.right.circle")
                                }
                                .buttonStyle(CompactIconButtonStyle())
                            }
                        }
                    }

                    if appModel.hasWeeklyReview {
                        ReferenceCard {
                            HStack(spacing: 12) {
                                AICircleView(state: .checkIn, size: 42, strokeWidth: 2.1, tint: .white)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Your weekly review is ready.")
                                        .font(.subheadline.weight(.semibold))
                                    Text(appModel.weeklyCheckInAvailabilityText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    showingWeekly = true
                                } label: {
                                    Text("Review")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(appModel.selectedMood.companionColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .disabled(appModel.isWeeklyCheckInAvailableNow == false)
                            }
                        }
                    } else {
                        ReferenceCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 12) {
                                    AICircleView(state: .attentive, size: 42, strokeWidth: 2.1, tint: appModel.companionTint)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Weekly check-in is building")
                                            .font(.subheadline.weight(.semibold))
                                        Text(appModel.weeklyUnlockProgressText)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }

                                ProgressView(value: appModel.weeklyUnlockProgressRatio)
                                    .tint(.primary)
                            }
                        }
                    }
                }
                .padding(AppSpacing.page)
                .padding(.bottom, 86)
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingNewEntry) {
                NewEntryView(initialMood: .okay)
                    .presentationCornerRadius(28)
            }
            .sheet(isPresented: $showingHistory) {
                NavigationStack {
                    JournalHistoryView()
                }
                .presentationCornerRadius(28)
            }
            .sheet(isPresented: $showingWeekly) {
                NavigationStack {
                    WeeklyReviewView(review: appModel.weeklyReview)
                }
                .presentationCornerRadius(28)
            }
            .sheet(item: $activeDailyReview) { review in
                NavigationStack {
                    DailyReviewView(review: review)
                }
                .presentationCornerRadius(28)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .presentationDetents([.medium])
                    .presentationCornerRadius(28)
            }
            .sheet(item: $selectedCompanionDriver) { driver in
                NavigationStack {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(driver.name)
                            .font(.title3.weight(.bold))
                        Text("Current contribution: \(Int((driver.contribution * 100).rounded()))%")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(driver.direction == "up" ? .green : .orange)
                        Text(driver.tip)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Button {
                            performDriverAction(for: driver)
                        } label: {
                            Label(driverActionTitle(for: driver), systemImage: "arrow.right.circle.fill")
                        }
                        .buttonStyle(PrimaryCapsuleButtonStyle())
                        Spacer()
                    }
                    .padding(AppSpacing.page)
                    .navigationTitle("Improve this")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationCornerRadius(28)
            }
            .confirmationDialog(
                "Choose review type",
                isPresented: $showingReviewModeChoice,
                titleVisibility: .visible
            ) {
                Button("Deep review") {
                    runTodayReview(preferLocal: false)
                }
                Button("Local review") {
                    runTodayReview(preferLocal: true)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Deep review is limited to once per day. Local review is instant and unlimited.")
            }
            .onAppear { circleState = appModel.companionCircleState }
            .onAppear {
                lastMissionDoneCount = appModel.onboardingMission.filter(\.done).count
                lastStreakValue = appModel.currentStreakDays
            }
            .task {
                circleState = appModel.companionCircleState
                companionLensFocusActive = false
                while !Task.isCancelled {
                    let wait = UInt64(Int.random(in: 3_600_000_000...6_200_000_000))
                    try? await Task.sleep(nanoseconds: wait)
                    guard !Task.isCancelled else { return }
                    guard companionBusy == false else { continue }

                    if Bool.random() {
                        companionLensFocusActive = true
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        companionLensFocusActive = false
                    }

                    circleState = appModel.companionCircleState
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    if companionBusy == false {
                        circleState = appModel.companionCircleState
                    }
                }
            }
            .onChange(of: appModel.selectedMood) {
                companionBusy = true
                circleState = .responding
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    circleState = appModel.companionCircleState
                    companionBusy = false
                }
            }
            .onChange(of: appModel.companionState) {
                guard companionBusy == false else { return }
                circleState = appModel.companionCircleState
            }
            .onChange(of: appModel.onboardingMission.filter(\.done).count) { oldValue, newValue in
                guard newValue > oldValue else { return }
                fireConfetti()
                lastMissionDoneCount = newValue
            }
            .onChange(of: appModel.currentStreakDays) { oldValue, newValue in
                guard newValue > oldValue else { return }
                let reachedGoalNow = newValue >= appModel.streakGoalDays && oldValue < appModel.streakGoalDays
                let milestoneStep = newValue % 3 == 0
                if reachedGoalNow || milestoneStep {
                    fireConfetti()
                }
                lastStreakValue = newValue
            }
            .overlay {
                ConfettiOverlayView(trigger: confettiTrigger)
            }
        }
    }

    private var missionProgressRatio: Double {
        let mission = appModel.onboardingMission
        guard mission.isEmpty == false else { return 0 }
        let doneCount = mission.filter(\.done).count
        return Double(doneCount) / Double(mission.count)
    }

    private var nextActionSymbol: String {
        switch nextAction.kind {
        case .writeEntry: "pencil"
        case .reviewToday: "sparkle.magnifyingglass"
        case .openWeekly: "chart.line.uptrend.xyaxis"
        case .keepStreak: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        }
    }

    private var shouldPromptForReviewMode: Bool {
        appModel.planTier == .premium && todayReview?.source != "openai"
    }

    private var nextStepsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(title: "Goal focus")
                Spacer()
                Text(selectedGoalScopeTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Picker("Goal scope", selection: $selectedGoalScope) {
                ForEach(GoalCadence.allCases) { scope in
                    Text(scope.label).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            ReferenceCard {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedGoalScopeTitle)
                            .font(.subheadline.weight(.semibold))
                        Text(selectedGoalScopeDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    goalsTabContent
                }
            }
        }
    }

    private var selectedGoalScopeTitle: String {
        switch selectedGoalScope {
        case .daily:
            "Daily next steps"
        case .weekly:
            "Weekly focus"
        case .monthly:
            "Monthly focus"
        }
    }

    private var selectedGoalScopeDetail: String {
        switch selectedGoalScope {
        case .daily:
            return "Small actions you can finish today."
        case .weekly:
            return "The one focus this week is built around."
        case .monthly:
            return "The broader direction this month is working toward."
        }
    }

    @ViewBuilder
    private var goalsTabContent: some View {
        switch selectedGoalScope {
        case .daily:
            if visibleDailyGoals.isEmpty {
                goalEmptyState(
                    title: "No daily next step yet",
                    detail: "Run a daily review after writing and Anchor will suggest the smallest next move."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(visibleDailyGoals) { goal in
                        ReflectionGoalRow(
                            goal: goal,
                            action: {
                                withAnimation(.snappy(duration: 0.22)) {
                                    appModel.toggleGoal(goal)
                                }
                            },
                            onCollapse: {
                                withAnimation(.snappy(duration: 0.22)) {
                                    _ = collapsedGoalIDs.insert(goal.id)
                                }
                            }
                        )

                        if goal.id != visibleDailyGoals.last?.id {
                            Divider()
                        }
                    }
                }
            }
        case .weekly:
            if let goal = visibleWeeklyGoals.first {
                VStack(spacing: 0) {
                    ReflectionGoalRow(
                        goal: goal,
                        action: { appModel.toggleGoal(goal) },
                        onCollapse: {},
                        showsCollapse: false
                    )
                }
            } else if let suggestion = appModel.suggestedWeeklyGoalText {
                suggestedGoalCard(
                    title: "This week's focus",
                    detail: suggestion,
                    buttonTitle: "Use weekly goal"
                ) {
                    _ = appModel.saveSuggestedReviewGoal(cadence: .weekly)
                }
            } else {
                goalEmptyState(
                    title: "No weekly goal yet",
                    detail: "Weekly reviews can turn this week’s pattern into one concrete focus."
                )
            }
        case .monthly:
            if let goal = visibleMonthlyGoals.first {
                VStack(spacing: 0) {
                    ReflectionGoalRow(
                        goal: goal,
                        action: { appModel.toggleGoal(goal) },
                        onCollapse: {},
                        showsCollapse: false
                    )
                }
            } else if let suggestion = appModel.suggestedMonthlyGoalText {
                suggestedGoalCard(
                    title: "This month's focus",
                    detail: suggestion,
                    buttonTitle: "Use monthly focus"
                ) {
                    _ = appModel.saveSuggestedReviewGoal(cadence: .monthly)
                }
            } else {
                goalEmptyState(
                    title: "No monthly focus yet",
                    detail: appModel.hasMonthlyReviewAccess ? "Monthly reviews turn the wider pattern into one focus for the month." : "Monthly focus unlocks with Premium monthly reviews."
                )
            }
        }
    }

    private func goalEmptyState(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private func suggestedGoalCard(title: String, detail: String, buttonTitle: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(buttonTitle, action: action)
                .buttonStyle(CompactIconButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private func runNextAction() {
        switch nextAction.kind {
        case .writeEntry:
            showingNewEntry = true
        case .reviewToday:
            guard isReviewingToday == false else { return }
            guard canRunTodayReview else { return }
            if shouldPromptForReviewMode {
                showingReviewModeChoice = true
            } else {
                runTodayReview(preferLocal: appModel.planTier == .premium && todayReview?.source == "openai")
            }
        case .openWeekly:
            showingWeekly = true
        case .keepStreak:
            showingHistory = true
        }
    }

    private func fireConfetti() {
        confettiTrigger += 1
    }

    private func runTodayReview(preferLocal: Bool) {
        guard isReviewingToday == false else { return }
        isReviewingToday = true
        companionBusy = true
        circleState = .thinking
        Task {
            if let review = await appModel.reviewDay(Date(), preferLocal: preferLocal) {
                activeDailyReview = review
            }
            isReviewingToday = false
            circleState = .responding
            try? await Task.sleep(for: .milliseconds(450))
            circleState = appModel.companionCircleState
            companionBusy = false
        }
    }

    private func driverAction(for driver: AppViewModel.CompanionDriver) -> DriverAction {
        switch driver.name {
        case "Calm sessions":
            return .openCalm
        case "Follow-through":
            return .openGoals
        default:
            return .openCheckIn
        }
    }

    private func driverActionTitle(for driver: AppViewModel.CompanionDriver) -> String {
        switch driverAction(for: driver) {
        case .openCheckIn:
            return "Start check-in now"
        case .openCalm:
            return "Open Calm now"
        case .openGoals:
            return "Open next steps"
        }
    }

    private func performDriverAction(for driver: AppViewModel.CompanionDriver) {
        selectedCompanionDriver = nil
        switch driverAction(for: driver) {
        case .openCheckIn:
            showingNewEntry = true
        case .openCalm:
            router.selectedTab = .calm
        case .openGoals:
            router.selectedTab = .journal
            showingHistory = true
        }
    }

}

private struct StreakCardView: View {
    let currentWeekDates: [Date]
    let entriesForDate: (Date) -> [JournalEntry]
    let checkedInCount: Int
    let currentStreakDays: Int
    let longestStreakDays: Int
    let streakGoalDays: Int

    private var progress: Double {
        guard streakGoalDays > 0 else { return 0 }
        return min(1, Double(currentStreakDays) / Double(streakGoalDays))
    }

    private var milestoneText: String {
        if currentStreakDays >= streakGoalDays {
            return "Goal reached. Keep the streak alive."
        }
        if currentStreakDays == 0 {
            return "Start a new streak with one entry today."
        }
        if currentStreakDays >= max(2, streakGoalDays / 2) {
            return "You are building momentum."
        }
        return "Consistency is taking shape."
    }

    var body: some View {
        ReferenceCard {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(AppSurface.stroke, lineWidth: 5)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Color.primary, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.35), value: progress)
                        VStack(spacing: 1) {
                            Text("\(currentStreakDays)")
                                .font(.headline.weight(.bold))
                            Text("days")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 54, height: 54)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Streak progress \(min(currentStreakDays, streakGoalDays))/\(streakGoalDays)")
                            .font(.subheadline.weight(.semibold))
                        Text(milestoneText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Best \(longestStreakDays)d")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppSurface.fill, in: Capsule())
                        .overlay {
                            Capsule().stroke(AppSurface.stroke, lineWidth: 0.5)
                        }
                }

                HStack(spacing: 8) {
                    ForEach(currentWeekDates, id: \.self) { date in
                        let checked = entriesForDate(date).isEmpty == false
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(checked ? Color.primary : Color.clear)
                                .frame(width: 20, height: 14)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(AppSurface.stroke, lineWidth: 0.5)
                                }
                            Text(String(date.shortDay.prefix(1)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 1)

                Text("\(checkedInCount) of 7 days checked in this week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

}

private struct ReflectionGoalRow: View {
    let goal: ReflectionGoal
    let action: () -> Void
    let onCollapse: () -> Void
    var showsCollapse: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: goal.status == .completed ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(.primary)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(goalCadenceTitle)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppSurface.fill, in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(AppSurface.stroke, lineWidth: 0.5)
                            }
                        Text(goal.title)
                            .font(.subheadline.weight(.semibold))
                            .strikethrough(goal.status == .completed)
                        Text(goal.status == .completed ? "Logged as done" : goal.reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            if showsCollapse {
                Button(action: onCollapse) {
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 9)
    }

    private var goalCadenceTitle: String {
        switch goal.cadence ?? .daily {
        case .daily:
            "Daily"
        case .weekly:
            "Weekly"
        case .monthly:
            "Monthly"
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @EnvironmentObject private var notificationService: NotificationService
    @StateObject private var voiceModelManager = VoiceModelManager.shared
    @State private var exportURL: URL?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ProfileSettingsPage()
                    } label: {
                        SettingsNavigationRow(
                            title: "Profile",
                            detail: profileSummary,
                            symbol: "person.crop.circle"
                        )
                    }
                } header: {
                    Text("Personal")
                }

                Section {
                    NavigationLink {
                        PlanSettingsPage()
                    } label: {
                        SettingsNavigationRow(
                            title: "Plan",
                            detail: appModel.planTier == .premium ? "Premium active" : "Free plan",
                            symbol: "sparkles.rectangle.stack"
                        )
                    }
                } header: {
                    Text("Plan")
                }

                Section {
                    NavigationLink {
                        VoiceSettingsPage()
                    } label: {
                        SettingsNavigationRow(
                            title: "Voice journaling",
                            detail: voiceModelManager.statusLabel,
                            symbol: "mic"
                        )
                    }

                    NavigationLink {
                        WidgetSettingsPage()
                    } label: {
                        SettingsNavigationRow(
                            title: "Widgets",
                            detail: "\(appModel.widgetAccentColor.label) accent, \(appModel.widgetFontStyle.label) font",
                            symbol: "square.grid.2x2"
                        )
                    }

                    NavigationLink {
                        ReminderSettingsPage()
                    } label: {
                        SettingsNavigationRow(
                            title: "Reminders",
                            detail: notificationService.isDailyReminderEnabled || notificationService.isWeeklyReminderEnabled ? "Configured" : "Off",
                            symbol: "bell"
                        )
                    }

                    NavigationLink {
                        HealthSettingsPage()
                    } label: {
                        SettingsNavigationRow(
                            title: "Apple Health",
                            detail: healthKitManager.summary == nil ? "Not connected" : "Connected",
                            symbol: "heart.text.square"
                        )
                    }
                } header: {
                    Text("Features")
                }

                Section {
                    Toggle(
                        "Use demo data",
                        isOn: Binding(
                            get: { appModel.isDemoDataEnabled },
                            set: { appModel.setDemoDataEnabled($0) }
                        )
                    )
                } footer: {
                    Text("Temporarily swaps in sample entries and restores your real data when turned off.")
                }

                Section("iCloud sync") {
                    Toggle(
                        "Sync journal data",
                        isOn: Binding(
                            get: { appModel.isICloudSyncEnabled },
                            set: { enabled in
                                appModel.isICloudSyncEnabled = enabled
                                Task {
                                    if enabled {
                                        await appModel.refreshICloudStatus()
                                        await appModel.pushToICloud()
                                    }
                                }
                            }
                        )
                    )
                    .tint(.green)

                    LabeledContent("Status", value: appModel.iCloudSyncState.label)

                    Text("Uses your Apple Account and the app's private iCloud database for journal data only. Health data stays on this device. No app account is created.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Privacy") {
                    Text("Your journal stays on this device unless you turn on iCloud sync. Health data stays on-device. Reviews are sent only when you ask for one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Export local data") {
                        exportURL = appModel.exportLocalData()
                    }

                    if appModel.isPremium {
                        Button("Export wellbeing report") {
                            exportURL = appModel.exportTherapistReport()
                        }
                    } else {
                        Button("Unlock wellbeing report export") {
                            router.presentPaywall(.settings)
                        }
                    }

                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Share export", systemImage: "square.and.arrow.up")
                        }
                    }

                    Button("Delete journal data", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }

                Section("Legal") {
                    Link(destination: URL(string: "https://getsolutions.app/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Link(destination: URL(string: "https://getsolutions.app/terms")!) {
                        Label("Terms of Use", systemImage: "doc.text")
                    }
                }
            }
            .tint(.green)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await notificationService.refreshAuthorizationStatus()
                await appModel.refreshICloudStatus()
                await healthKitManager.refreshIfPossible()
                appModel.updateHealthSummary(healthKitManager.summary)
            }
            .sheet(isPresented: $showingDeleteConfirmation) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Delete journal data?")
                        .font(.headline)
                    Text("This removes entries, reviews, goals, conversations, summaries, and saved Health context from this device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button("Delete journal data", role: .destructive) {
                        appModel.deleteLocalData()
                        exportURL = nil
                        showingDeleteConfirmation = false
                    }
                    .buttonStyle(PrimaryCapsuleButtonStyle())

                    Button {
                        showingDeleteConfirmation = false
                    } label: {
                        Text("Cancel")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(AppSpacing.page)
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.visible)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var isVoiceModelDownloading: Bool {
        if case .downloading = voiceModelManager.status { return true }
        return false
    }

    private var profileSummary: String {
        let name = appModel.onboardingProfile.preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let age = appModel.onboardingProfile.ageRange.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (name.isEmpty, age.isEmpty) {
        case (false, false):
            return "\(name) · \(age)"
        case (false, true):
            return name
        case (true, false):
            return age
        case (true, true):
            return "Name and age range"
        }
    }
}

private struct SettingsNavigationRow: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ProfileSettingsPage: View {
    @EnvironmentObject private var appModel: AppViewModel

    private let ageRanges = [
        "Under 18", "18-24", "25-34", "35-44", "45-54", "55-64", "65+", "Prefer not to say"
    ]

    var body: some View {
        List {
            Section {
                TextField(
                    "Name or nickname",
                    text: Binding(
                        get: { appModel.onboardingProfile.preferredName },
                        set: { appModel.updatePreferredName($0) }
                    )
                )
                .textInputAutocapitalization(.words)

                Picker(
                    "Age range",
                    selection: Binding(
                        get: { appModel.onboardingProfile.ageRange.isEmpty ? "Prefer not to say" : appModel.onboardingProfile.ageRange },
                        set: { appModel.updateAgeRange($0 == "Prefer not to say" ? "" : $0) }
                    )
                ) {
                    ForEach(ageRanges, id: \.self) { range in
                        Text(range).tag(range)
                    }
                }

                TextField(
                    "Main goal",
                    text: Binding(
                        get: { appModel.onboardingProfile.reflectionGoal },
                        set: { appModel.updateReflectionGoal($0) }
                    ),
                    axis: .vertical
                )
            } header: {
                Text("Personal details")
            } footer: {
                Text("These details are used to tailor examples, pacing, and the goals Anchor suggests.")
            }
        }
        .tint(.green)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PlanSettingsPage: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            planStatusSection
            planDetailsSection
        }
        .tint(.green)
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await appModel.prepareSubscriptions()
        }
    }

    private var planStatusSection: some View {
        Section {
            LabeledContent("Current plan", value: appModel.isPremium ? "Premium" : "Free")
            LabeledContent("Billing", value: billingLabel)

            Button(appModel.isPremium ? "Manage premium" : "See premium plans") {
                if appModel.isPremium, let url = appModel.manageSubscriptionsURL {
                    openURL(url)
                } else {
                    router.presentPaywall(.settings)
                }
            }

            Button(appModel.restoreInFlight ? "Restoring purchase..." : "Restore purchases") {
                Task {
                    await appModel.restorePurchases()
                }
            }
            .disabled(appModel.restoreInFlight)
        } header: {
            Text("Subscription")
        } footer: {
            if let message = appModel.subscriptionErrorMessage, message.isEmpty == false {
                Text(message)
            } else {
                Text("Subscriptions are managed through the App Store. Restores refresh your current entitlement on this device.")
            }
        }
    }

    private var planDetailsSection: some View {
        Section("Included in Premium") {
            planRow("Deeper AI daily review", "One stronger AI read per day with better evidence and a clearer next step.")
            planRow("Expanded weekly AI report", "See what changed, what got completed, and whether you moved toward your goal.")
            planRow("Monthly review and conversation", "A wider 4-week pattern read with a deeper follow-up conversation.")
            planRow("Health-aware patterns", "Sleep and step trends folded in when they actually help explain the pattern.")
            planRow("Structured wellbeing report export", "Share a cleaner summary of entries, reviews, goals, and recurring signals.")
        }
    }

    private var billingLabel: String {
        guard appModel.isPremium else { return "Not subscribed" }
        switch appModel.premiumBillingCycle {
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .annual:
            return "Yearly"
        }
    }

    private func planRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct VoiceSettingsPage: View {
    @StateObject private var voiceModelManager = VoiceModelManager.shared

    var body: some View {
        List {
            Section {
                LabeledContent("Status", value: voiceModelManager.statusLabel)

                switch voiceModelManager.status {
                case .downloading(let progress):
                    ProgressView(value: progress)
                case .failed(let message):
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                default:
                    EmptyView()
                }

                Button {
                    Task { await voiceModelManager.downloadTinyModel() }
                } label: {
                    Label(voiceModelManager.isVoiceEnabled ? "Voice model downloaded" : "Download voice model", systemImage: voiceModelManager.isVoiceEnabled ? "checkmark.circle.fill" : "arrow.down.circle")
                }
                .disabled(voiceModelManager.isVoiceEnabled || isVoiceModelDownloading)

                if voiceModelManager.isVoiceEnabled {
                    Button("Disable voice journaling", role: .destructive) {
                        voiceModelManager.disableVoice()
                    }
                }
            } header: {
                Text("Voice journaling")
            } footer: {
                Text("Voice is optional. The model downloads once and stays on this device.")
            }
        }
        .tint(.green)
        .navigationTitle("Voice")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isVoiceModelDownloading: Bool {
        if case .downloading = voiceModelManager.status { return true }
        return false
    }
}

private struct WidgetSettingsPage: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        List {
            Section("Appearance") {
                Picker(
                    "Accent",
                    selection: Binding(
                        get: { appModel.widgetAccentColor },
                        set: { appModel.updateWidgetAccentColor($0) }
                    )
                ) {
                    ForEach(WidgetAccentColor.allCases) { color in
                        Text(color.label).tag(color)
                    }
                }

                Picker(
                    "Affirmation font",
                    selection: Binding(
                        get: { appModel.widgetFontStyle },
                        set: { appModel.updateWidgetFontStyle($0) }
                    )
                ) {
                    ForEach(WidgetFontStyle.allCases) { font in
                        Text(font.label).tag(font)
                    }
                }
            }

            Section {
                ForEach(WidgetAffirmationCategory.allCases) { category in
                    Toggle(
                        category.label,
                        isOn: Binding(
                            get: { appModel.widgetAffirmationCategories.contains(category) },
                            set: { appModel.setWidgetAffirmationCategory(category, enabled: $0) }
                        )
                    )
                    .tint(.green)
                }
            } header: {
                Text("Affirmation topics")
            } footer: {
                Text("These topics influence which affirmation lines are shown.")
            }

            Section {
                Button {
                    appModel.cycleWidgetAffirmation()
                } label: {
                    Label("Next affirmation now", systemImage: "arrow.triangle.2.circlepath")
                }
            }
        }
        .tint(.green)
        .navigationTitle("Widgets")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ReminderSettingsPage: View {
    @EnvironmentObject private var notificationService: NotificationService

    var body: some View {
        List {
            Section {
                Toggle(
                    "Daily mood reminder",
                    isOn: Binding(
                        get: { notificationService.isDailyReminderEnabled },
                        set: { enabled in
                            Task { await notificationService.setDailyReminderEnabled(enabled) }
                        }
                    )
                )
                .tint(.green)

                DatePicker(
                    "Time",
                    selection: Binding(
                        get: { notificationService.dailyReminderTime },
                        set: { time in
                            Task { await notificationService.updateDailyReminderTime(time) }
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .disabled(notificationService.isDailyReminderEnabled == false)
            } header: {
                Text("Daily reminder")
            }

            Section {
                Toggle(
                    "Notify when review is ready",
                    isOn: Binding(
                        get: { notificationService.isWeeklyReminderEnabled },
                        set: { enabled in
                            Task { await notificationService.setWeeklyReminderEnabled(enabled) }
                        }
                    )
                )
                .tint(.green)

                Picker(
                    "Day",
                    selection: Binding(
                        get: { notificationService.weeklyReminderWeekday },
                        set: { weekday in
                            Task { await notificationService.updateWeeklyReminderWeekday(weekday) }
                        }
                    )
                ) {
                    ForEach(ReminderWeekday.allCases) { weekday in
                        Text(weekday.label).tag(weekday.rawValue)
                    }
                }
                .disabled(notificationService.isWeeklyReminderEnabled == false)

                DatePicker(
                    "Time",
                    selection: Binding(
                        get: { notificationService.weeklyReminderTime },
                        set: { time in
                            Task { await notificationService.updateWeeklyReminderTime(time) }
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .disabled(notificationService.isWeeklyReminderEnabled == false)
            } header: {
                Text("Weekly check-in reminder")
            }

            Section {
                LabeledContent("Status", value: notificationService.authorizationLabel)
                if notificationService.authorizationStatus == .denied {
                    Button("Open iOS Settings") {
                        notificationService.openAppSettings()
                    }
                }
            } header: {
                Text("Permission")
            }
        }
        .tint(.green)
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await notificationService.refreshAuthorizationStatus()
        }
    }
}

private struct HealthSettingsPage: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var healthKitManager: HealthKitManager

    var body: some View {
        List {
            Section {
                LabeledContent("Status", value: healthKitManager.summary == nil ? "Not connected" : "Connected")
                LabeledContent("Data window", value: "Last 14 days")

                if let summary = healthKitManager.summary {
                    LabeledContent("Last night sleep", value: summary.lastNightSleep.cleanHours)
                    LabeledContent("Average sleep", value: summary.averageSleep.cleanHours)
                    LabeledContent("Average steps", value: summary.averageSteps.formatted())
                    LabeledContent("Step trend", value: summary.trend.rawValue.capitalized)
                }

                Button(healthKitManager.summary == nil ? "Connect Apple Health" : "Refresh Apple Health") {
                    Task {
                        await healthKitManager.requestPermissionsAndRefresh()
                        appModel.updateHealthSummary(healthKitManager.summary)
                    }
                }
            } header: {
                Text("Apple Health")
            } footer: {
                Text(healthFooterText)
            }
        }
        .tint(.green)
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await healthKitManager.refreshIfPossible()
            appModel.updateHealthSummary(healthKitManager.summary)
        }
    }

    private var healthFooterText: String {
        #if targetEnvironment(simulator)
        return "Simulator builds use sample Health data. On device, this page reads sleep and steps from the last 14 days."
        #else
        return "This page reads sleep and steps from the last 14 days to add context to reviews and insights."
        #endif
    }
}

struct InsightDetailView: View {
    let insight: Insight

    var body: some View {
        List {
            Section {
                InsightSectionView(title: insight.title, bodyText: insight.body, symbol: insight.type.symbol)
                Text(insight.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(insight.type.label)
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview {
    TodayView()
        .environmentObject(AppViewModel())
        .environmentObject(NotificationService.shared)
}
