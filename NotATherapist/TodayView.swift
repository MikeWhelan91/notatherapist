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
    @State private var missionRevealCount = 0
    @State private var confettiTrigger = 0
    @State private var lastMissionDoneCount = 0
    @State private var lastStreakValue = 0
    @State private var companionTrigger = 0
    @State private var selectedCompanionDriver: AppViewModel.CompanionDriver?

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

                    if appModel.reflectionGoals.isEmpty == false {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(title: "Agreed next steps")
                            ReferenceCard {
                                VStack(spacing: 0) {
                                    ForEach(appModel.reflectionGoals.prefix(3)) { goal in
                                        ReflectionGoalRow(goal: goal) {
                                            withAnimation(.snappy(duration: 0.22)) {
                                                appModel.toggleGoal(goal)
                                            }
                                        }

                                        if goal.id != appModel.reflectionGoals.prefix(3).last?.id {
                                            Divider()
                                        }
                                    }
                                }
                            }
                        }
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
                                Text("Reviews and patterns appear after you write.")
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
                                        body: "This question is chosen from your baseline, recent mood, and repeated patterns. Answering it gives the next review better evidence.",
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
                                    Text("I noticed a few patterns.")
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
                NewEntryView(initialMood: appModel.selectedMood)
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
            .onAppear { circleState = .idle }
            .onAppear {
                lastMissionDoneCount = appModel.onboardingMission.filter(\.done).count
                lastStreakValue = appModel.currentStreakDays
            }
            .task {
                circleState = .attentive
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

                    let ambient: [AICircleState]
                    switch appModel.companionState {
                    case .overwhelmed:
                        ambient = [.thinking, .responding, .checkIn, .listening]
                    case .activated:
                        ambient = [.responding, .checkIn, .listening, .attentive]
                    case .steadying:
                        ambient = [.checkIn, .listening, .attentive]
                    case .balanced:
                        ambient = [.attentive, .listening, .checkIn]
                    case .thriving:
                        ambient = [.settled, .attentive, .listening]
                    }
                    circleState = ambient.randomElement() ?? .attentive
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    if companionBusy == false {
                        circleState = .attentive
                    }
                }
            }
            .onChange(of: appModel.selectedMood) {
                companionBusy = true
                circleState = .responding
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    circleState = .attentive
                    companionBusy = false
                }
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
            circleState = .attentive
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: goal.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.title)
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(goal.status == .completed)
                    Text(goal.status == .completed ? "Logged as done" : goal.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @EnvironmentObject private var notificationService: NotificationService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var exportURL: URL?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("AI connection")
                        Spacer()
                        Text(appModel.aiConnection.label)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task { await appModel.refreshAIConnection() }
                    } label: {
                        Label("Check connection", systemImage: "arrow.clockwise")
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("Your entries stay on your phone. AI is used only when you ask for a review.")
                }

                Section {
                    TextField(
                        "Name or nickname",
                        text: Binding(
                            get: { appModel.onboardingProfile.preferredName },
                            set: { appModel.updatePreferredName($0) }
                        )
                    )
                    .textInputAutocapitalization(.words)

                    HStack {
                        Text("Age range")
                        Spacer()
                        Text(appModel.onboardingProfile.ageRange.isEmpty ? "Not set" : appModel.onboardingProfile.ageRange)
                            .foregroundStyle(.secondary)
                    }

                    Button(appModel.isBaselineReassessmentDue ? "Retake 2-week baseline" : "Review onboarding answers") {
                        hasCompletedOnboarding = false
                        dismiss()
                    }
                } header: {
                    Text("Profile")
                } footer: {
                    Text(appModel.baselineReassessmentStatusText)
                }

                Section {
                    Toggle(
                        "Premium mode",
                        isOn: Binding(
                            get: { appModel.isPremium },
                            set: { appModel.isPremium = $0 }
                        )
                    )

                    HStack(alignment: .firstTextBaseline) {
                        Text("Current tier")
                        Spacer()
                        Text(appModel.planTier.label)
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Text("Daily review")
                        Spacer()
                        Text(appModel.planTier.dailyReviewLabel)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Text("Daily context")
                        Spacer()
                        Text(appModel.planTier.dailyContextLabel)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Text("Weekly reviews")
                        Spacer()
                        Text(appModel.planTier.weeklyReviewLabel)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Text("Weekly memory")
                        Spacer()
                        Text(appModel.planTier.weeklyContextLabel)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Plan")
                } footer: {
                    Text("Free includes local daily reflection and weekly summaries. Premium adds deeper analysis, baseline comparison, and richer week-to-week reports.")
                }

                Section {
                    Picker(
                        "Widget style",
                        selection: Binding(
                            get: { appModel.widgetStylePreset },
                            set: { appModel.updateWidgetStylePreset($0) }
                        )
                    ) {
                        ForEach(WidgetStylePreset.allCases, id: \.rawValue) { style in
                            Text(style.label).tag(style)
                        }
                    }

                    ForEach(WidgetAffirmationCategory.allCases) { category in
                        Toggle(
                            category.label,
                            isOn: Binding(
                                get: { appModel.widgetAffirmationCategories.contains(category) },
                                set: { appModel.setWidgetAffirmationCategory(category, enabled: $0) }
                            )
                        )
                    }

                    Button {
                        appModel.cycleWidgetAffirmation()
                    } label: {
                        Label("Next affirmation now", systemImage: "arrow.triangle.2.circlepath")
                    }
                } header: {
                    Text("Widget personalization")
                } footer: {
                    Text("These settings affect both Home Screen and Lock Screen widget text and style.")
                }

                Section("Scope") {
                    Text("This is a reflection tool. It is not therapy, and it does not diagnose, treat, cure, or replace professional help.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Apple Health") {
                    LabeledContent("Status", value: healthKitManager.summary == nil ? "Off" : "Connected")

                    if let summary = healthKitManager.summary {
                        LabeledContent("Context", value: "\(summary.lastNightSleep.cleanHours) sleep · \(summary.averageSteps.formatted()) avg steps")
                            .font(.subheadline)
                        Text("Used only to add extra context to your summaries.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button(healthKitManager.summary == nil ? "Connect Apple Health" : "Refresh Health context") {
                        Task {
                            await healthKitManager.requestPermissionsAndRefresh()
                            appModel.updateHealthSummary(healthKitManager.summary)
                        }
                    }
                }

                Section("iCloud") {
                    Toggle(
                        "Sync with iCloud",
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

                    LabeledContent("Status", value: appModel.iCloudSyncState.label)

                    HStack {
                        Button("Pull from iCloud") {
                            Task {
                                await appModel.pullFromICloud()
                            }
                        }
                        .disabled(appModel.isICloudSyncEnabled == false)

                        Spacer()

                        Button("Push now") {
                            Task {
                                await appModel.pushToICloud()
                            }
                        }
                        .disabled(appModel.isICloudSyncEnabled == false)
                    }

                    Text("Uses your Apple Account and the app's private iCloud database. No app account is created.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Weekly review reminder") {
                    Toggle(
                        "Daily mood reminder",
                        isOn: Binding(
                            get: { notificationService.isDailyReminderEnabled },
                            set: { enabled in
                                Task {
                                    await notificationService.setDailyReminderEnabled(enabled)
                                }
                            }
                        )
                    )

                    DatePicker(
                        "Daily time",
                        selection: Binding(
                            get: { notificationService.dailyReminderTime },
                            set: { time in
                                Task {
                                    await notificationService.updateDailyReminderTime(time)
                                }
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(notificationService.isDailyReminderEnabled == false)

                    Toggle(
                        "Notify when review is ready",
                        isOn: Binding(
                            get: { notificationService.isWeeklyReminderEnabled },
                            set: { enabled in
                                Task {
                                    await notificationService.setWeeklyReminderEnabled(enabled)
                                }
                            }
                        )
                    )

                    Picker(
                        "Day",
                        selection: Binding(
                            get: { notificationService.weeklyReminderWeekday },
                            set: { weekday in
                                Task {
                                    await notificationService.updateWeeklyReminderWeekday(weekday)
                                }
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
                                Task {
                                    await notificationService.updateWeeklyReminderTime(time)
                                }
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(notificationService.isWeeklyReminderEnabled == false)

                    LabeledContent("Permission", value: notificationService.authorizationLabel)

                    if notificationService.authorizationStatus == .denied {
                        Button("Open iOS Settings") {
                            notificationService.openAppSettings()
                        }
                    }
                }

                Section("Privacy") {
                    Text("Your journal is stored on this device. Reviews are sent only when you ask for one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Export local data") {
                        exportURL = appModel.exportLocalData()
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
            }
            .tint(AppTheme.accent)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await notificationService.refreshAuthorizationStatus()
                await appModel.refreshAIConnection()
                await appModel.refreshICloudStatus()
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
