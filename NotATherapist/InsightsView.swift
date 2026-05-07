import Charts
import DGCharts
import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear
                            .frame(height: 1)
                            .id("insights-top")
                        CompanionTabHeader(title: "Insights", state: appModel.companionCircleState, tint: appModel.journalCompanionTint, showsCircle: true)
                        ProfessionalInsightsDashboard()
                            .padding(.horizontal, AppSpacing.page)
                            .padding(.bottom, 92)
                    }
                }
                .onChange(of: router.selectedTab) { _, tab in
                    guard tab == .insights else { return }
                    proxy.scrollTo("insights-top", anchor: .top)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: router.selectedTab) { _, tab in
                guard tab == .insights else { return }
            }
        }
    }
}

private struct ProfessionalInsightsDashboard: View {
    private enum InsightPeriod: String, CaseIterable, Identifiable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"

        var id: String { rawValue }
    }

    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var router: AppRouter
    @State private var selectedPeriod: InsightPeriod = .daily
    @State private var displayedMonthDate: Date?
    @State private var selectedCalendarDate: Date?
    @State private var weeklyNotesExpanded = false
    @State private var monthlyNotesExpanded = false
    @State private var showingCompletedGoals = false

    private var entries: [JournalEntry] {
        appModel.journalEntries.sorted { $0.date < $1.date }
    }

    private var last30: [JournalEntry] {
        guard let latest = entries.last?.date,
              let lower = Calendar.current.date(byAdding: .day, value: -29, to: latest) else {
            return entries
        }
        return entries.filter { $0.date >= lower }
    }

    private var averageMood: Double {
        guard last30.isEmpty == false else { return 0 }
        return Double(last30.reduce(0) { $0 + $1.mood.score }) / Double(last30.count)
    }

    private var activeDays: Int {
        Set(last30.map { Calendar.current.startOfDay(for: $0.date) }).count
    }

    private var latestMonthDate: Date {
        entries.last?.date ?? Date()
    }

    private var last7DayInterval: DateInterval {
        let calendar = Calendar.current
        let endDate = latestMonthDate
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: endDate)) ?? endDate
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        return DateInterval(start: start, end: end)
    }

    private var currentWeekInterval: DateInterval {
        Calendar.current.dateInterval(of: .weekOfYear, for: latestMonthDate) ?? last7DayInterval
    }

    private var currentMonthInterval: DateInterval {
        Calendar.current.dateInterval(of: .month, for: calendarMonthDate) ?? last7DayInterval
    }

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView(
                "No data yet",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Write a few entries to unlock trends.")
            )
            .padding(.top, 80)
        } else {
            VStack(alignment: .leading, spacing: 22) {
                header
                metricStrip
                periodPicker
                periodContent
            }
            .onAppear {
                displayedMonthDate = displayedMonthDate ?? latestMonthDate
                selectedCalendarDate = selectedCalendarDate ?? latestMonthDate
            }
        }
    }

    private var header: some View {
        VStack(alignment: .center, spacing: 5) {
            Text("Mood and journal stats")
                .font(.title2.weight(.bold))
            Text(insightSummaryLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var insightSummaryLine: String {
        if let latest = appModel.latestDailyReview {
            return readableReviewText(latest.summary)
        }
        if appModel.hasWeeklyReview, appModel.weeklyReview.suggestion.isEmpty == false {
            return readableReviewText(appModel.weeklyReview.suggestion)
        }
        return "Mood, journal, and review signals."
    }

    private var metricStrip: some View {
        HStack(spacing: 10) {
            insightMetric("Entries", "\(last30.count)")
            insightMetric("Logged days", "\(activeDays)")
            insightMetric("Avg mood", averageMood == 0 ? "-" : String(format: "%.1f", averageMood))
            Button {
                showingCompletedGoals = true
            } label: {
                insightMetric("Completed", "\(appModel.completedReflectionGoalCount)")
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingCompletedGoals) {
            NavigationStack {
                CompletedNextStepsView(goals: appModel.completedReflectionGoals)
            }
            .presentationCornerRadius(28)
        }
    }

    private func insightMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .frame(height: 26, alignment: .bottom)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: 52, alignment: .top)
        .padding(.top, 8)
        .padding(.bottom, 5)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppSurface.stroke).frame(height: 1)
        }
    }

    private var periodPicker: some View {
        Picker("Insights range", selection: $selectedPeriod) {
            ForEach(InsightPeriod.allCases) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var periodContent: some View {
        switch selectedPeriod {
        case .daily:
            dailyInsights
        case .weekly:
            weeklyInsights
        case .monthly:
            monthlyInsights
        }
    }

    private var dailyInsights: some View {
        VStack(alignment: .leading, spacing: 22) {
            dailyReviewSummary
            dailyGoalInsights
            dailyCalmInsights
            moodCalendar
            moodTrend
            moodBreakdown
        }
    }

    private var weeklyInsights: some View {
        VStack(alignment: .leading, spacing: 22) {
            if weeklyInsightsUnlocked {
                weeklyOverview
            } else {
                LockedInsightPreview(
                    title: "Weekly review",
                    detail: weeklyLockedDetail,
                    systemImage: "calendar.badge.clock",
                    premiumOnly: false
                ) {
                    lockedWeeklyPreview
                }
            }
        }
        .task {
            await appModel.refreshWeeklyReview()
        }
    }

    private var monthlyInsights: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let review = appModel.monthlyReview {
                monthlyOverview(review)
            } else {
                LockedInsightPreview(
                    title: "Monthly review",
                    detail: monthlyLockedDetail,
                    systemImage: appModel.hasMonthlyReviewAccess ? "calendar" : "lock.fill",
                    premiumOnly: appModel.hasMonthlyReviewAccess == false,
                    buttonTitle: appModel.hasMonthlyReviewAccess ? nil : "Unlock Premium",
                    action: appModel.hasMonthlyReviewAccess ? nil : { router.presentPaywall(.monthlyReview) }
                ) {
                    lockedMonthlyPreview
                }
            }
        }
    }

    private var weeklyInsightsUnlocked: Bool {
        appModel.hasWeeklyReview && (
            appModel.weeklyReview.patterns.isEmpty == false ||
            appModel.weeklyReview.nextExperiment?.isEmpty == false ||
            appModel.weeklyReview.progressSignal?.isEmpty == false ||
            appModel.weeklyReview.goalFollowThrough.isEmpty == false
        )
    }

    private var weeklyLockedDetail: String {
        let readiness = appModel.weeklyReadiness
        if readiness.ready { return "Weekly review ready." }
        return "\(readiness.dayCount)/3 active days"
    }

    private var monthlyLockedDetail: String {
        guard appModel.hasMonthlyReviewAccess else { return "Premium only." }
        let entries = appModel.monthlyReviewContextEntries
        let days = Set(entries.map { Calendar.current.startOfDay(for: $0.date) }).count
        return "\(days)/8 days • \(entries.count)/14 entries"
    }

    private var dailyReviewSummary: some View {
        InsightSummaryBlock(
            title: "Latest daily review",
            value: latestDailyReviewValue,
            detail: latestDailyReviewDetail,
            symbol: "checkmark.seal",
            tint: appModel.journalCompanionTint
        )
    }

    private var weeklyReviewSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            InsightSummaryBlock(
                title: appModel.hasWeeklyReview ? "Weekly review" : "Weekly review building",
                value: weeklyReviewValue,
                detail: weeklyReviewDetail,
                symbol: "calendar.badge.clock",
                tint: appModel.hasWeeklyReview ? MoodLevel.good.companionColor : .secondary
            )

            if appModel.hasWeeklyReview {
                VStack(alignment: .leading, spacing: 10) {
                    if appModel.weeklyReview.patterns.isEmpty == false {
                        insightList(title: "This week", items: Array(appModel.weeklyReview.patterns.prefix(3)))
                    }
                    if appModel.weeklyReview.goalFollowThrough.isEmpty == false {
                        insightText(title: "Goal follow-through", text: appModel.weeklyReview.goalFollowThrough)
                    }
                    if let experiment = appModel.weeklyReview.nextExperiment, experiment.isEmpty == false {
                        insightText(title: "Next focus", text: experiment)
                    }
                }
            }
        }
    }

    private var weeklyOverview: some View {
        VStack(alignment: .leading, spacing: 18) {
            weeklyGoalInsights
            weeklyCalmInsights
            ReviewSignalStrip(items: [
                ReviewSignal(label: "Entries", value: "\(last30.count)"),
                ReviewSignal(label: "Days", value: "\(activeDays)"),
                ReviewSignal(label: "Mood", value: averageMood == 0 ? "-" : String(format: "%.1f", averageMood)),
                ReviewSignal(label: "Reviews", value: "\(appModel.dailyReviews.count)")
            ])
            weekdayPattern
            themeImpact
            ReviewNotesDisclosure(title: "Weekly notes", isExpanded: $weeklyNotesExpanded) {
                weeklyReviewSummary
            }
        }
    }

    private func monthlyOverview(_ review: MonthlyReview) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            monthlyGoalInsights(review)
            monthlyCalmInsights
            ReviewSignalStrip(items: [
                ReviewSignal(label: "Entries", value: "\(review.entryCount)"),
                ReviewSignal(label: "Days", value: "\(review.activeDays)"),
                ReviewSignal(label: "Mood", value: String(format: "%.1f", review.averageMood)),
                ReviewSignal(label: "Topics", value: "\(review.topThemes.count)")
            ])
            moodTrend
            moodBreakdown
            ReviewNotesDisclosure(title: "Monthly notes", isExpanded: $monthlyNotesExpanded) {
                monthlyReviewSummary(review)
            }
        }
    }

    private var dailyGoalInsights: some View {
        let momentum = dailyGoalMomentumPoints
        let outcome = goalOutcomeSummary(in: last7DayInterval)
        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Goal momentum")
            Text(dailyGoalLeadText(completed: outcome.completed, active: outcome.active, cleared: outcome.cleared))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ReferenceCard {
                VStack(alignment: .leading, spacing: 14) {
                    if momentum.reduce(0, { $0 + $1.completed }) > 0 {
                        DGGoalMomentumChart(points: momentum)
                            .frame(height: 168)
                    } else {
                        Text("Complete a suggested next step and Anchor will start charting your daily goal follow-through.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    GoalOutcomeLegend(summary: outcome)
                }
            }
        }
    }

    private var dailyCalmInsights: some View {
        calmInsightsSection(
            title: "Calm response",
            interval: last7DayInterval,
            leadingText: calmLeadText(in: last7DayInterval, timeframe: "the last 7 days"),
            emptyText: "Run a Calm reset and Anchor will start showing which ones help you settle fastest."
        )
    }

    private var weeklyGoalInsights: some View {
        let cadenceMetrics = goalCadenceMetrics(in: currentWeekInterval)
        let outcome = goalOutcomeSummary(in: currentWeekInterval)
        let completedThisWeek = appModel.completedGoals(in: currentWeekInterval).prefix(3)

        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Goal progress")
            Text(readableReviewText(appModel.weeklyReview.goalFollowThrough.isEmpty ? appModel.weeklyReview.suggestion : appModel.weeklyReview.goalFollowThrough))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            goalChartsLayout(metrics: cadenceMetrics, outcome: outcome)

            if completedThisWeek.isEmpty == false {
                insightList(
                    title: "Completed this week",
                    items: completedThisWeek.map {
                        "\($0.title) (\(($0.feedbackAt ?? $0.createdAt).formatted(.dateTime.weekday(.wide).day().month(.abbreviated))))"
                    }
                )
            }
        }
    }

    private var weeklyCalmInsights: some View {
        calmInsightsSection(
            title: "Calm response",
            interval: currentWeekInterval,
            leadingText: calmLeadText(in: currentWeekInterval, timeframe: "this week"),
            emptyText: "No Calm sessions logged this week yet."
        )
    }

    private func monthlyGoalInsights(_ review: MonthlyReview) -> some View {
        let cadenceMetrics = goalCadenceMetrics(in: currentMonthInterval)
        let outcome = goalOutcomeSummary(in: currentMonthInterval)
        let completedThisMonth = appModel.completedGoals(in: currentMonthInterval).prefix(4)
        let lead = [
            review.goalFollowThrough,
            review.progressSignal ?? "",
            review.progress
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first(where: { $0.isEmpty == false }) ?? "Anchor is reading the month against your long-term goal and the steps you actually completed."

        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Goal progress")
            Text(readableReviewText(lead))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            goalChartsLayout(metrics: cadenceMetrics, outcome: outcome)

            if completedThisMonth.isEmpty == false {
                insightList(
                    title: "Completed this month",
                    items: completedThisMonth.map {
                        "\($0.title) (\(($0.feedbackAt ?? $0.createdAt).formatted(.dateTime.weekday(.wide).day().month(.abbreviated))))"
                    }
                )
            }
        }
    }

    private var monthlyCalmInsights: some View {
        calmInsightsSection(
            title: "Calm response",
            interval: currentMonthInterval,
            leadingText: calmLeadText(in: currentMonthInterval, timeframe: "this month"),
            emptyText: "No Calm sessions logged this month yet."
        )
    }

    private func goalChartsLayout(metrics: [GoalCadenceMetric], outcome: GoalOutcomeSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ReferenceCard {
                VStack(alignment: .leading, spacing: 12) {
                    DGGoalCadenceChart(metrics: metrics)
                        .frame(height: 184)
                    GoalOutcomeLegend(summary: outcome)
                }
            }

            ReferenceCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Outcome mix")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(goalOutcomeHeadline(outcome))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    DGGoalOutcomeDonutChart(summary: outcome)
                        .frame(height: 188)
                }
            }
        }
    }

    private func calmInsightsSection(title: String, interval: DateInterval, leadingText: String, emptyText: String) -> some View {
        let sessions = calmSessions(in: interval)
        let pathwayMetrics = calmPathwayMetrics(in: interval)
        let helpfulness = calmHelpfulnessSummary(in: interval)
        let averageDuration = sessions.isEmpty ? 0 : sessions.reduce(0) { $0 + $1.duration } / Double(sessions.count)

        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle(title)
            Text(leadingText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ReferenceCard {
                if sessions.isEmpty {
                    Text(emptyText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            insightMetric("Sessions", "\(sessions.count)")
                            insightMetric("Helpful", "\(helpfulness.helpfulPercentage)%")
                            insightMetric("Avg length", calmDurationLabel(averageDuration))
                        }

                        DGCalmPathwayChart(metrics: pathwayMetrics)
                            .frame(height: 176)

                        DGCalmHelpfulnessDonutChart(summary: helpfulness)
                            .frame(height: 176)
                    }
                }
            }
        }
    }

    private func monthlyReviewSummary(_ review: MonthlyReview) -> some View {
        let completedGoals = appModel.completedGoalsLast(days: 31)
        return VStack(alignment: .leading, spacing: 10) {
            InsightSummaryBlock(
                title: "Month in review",
                value: String(format: "%.1f avg", review.averageMood),
                detail: readableReviewText(review.summary.isEmpty ? review.strongestPattern : review.summary),
                symbol: "calendar",
                tint: MoodLevel.great.companionColor
            )
            insightList(title: "Progress toward your goal", items: [
                review.goalFollowThrough,
                review.progressSignal ?? review.progress,
                review.baselineComparison ?? review.moodRange
            ].filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false })

            if completedGoals.isEmpty == false {
                insightList(
                    title: "Completed this month",
                    items: completedGoals.prefix(4).map {
                        "\($0.title) (\(($0.feedbackAt ?? $0.createdAt).formatted(.dateTime.weekday(.wide).day().month(.abbreviated))))"
                    }
                )
            }

            insightList(
                title: review.monthTitle,
                items: [
                    review.strongestPattern,
                    review.primaryLoop ?? "",
                    review.patternShift,
                    "Next focus: \(review.nextExperiment)"
                ].filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false } + Array(review.topThemes.prefix(3))
            )
        }
    }

    private func insightList(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(title)
            VStack(alignment: .leading, spacing: 7) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 9) {
                        Circle()
                            .fill(appModel.journalCompanionTint)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(readableReviewText(item))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                            .lineSpacing(1)
                    }
                }
            }
        }
    }

    private func insightText(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle(title)
            Text(readableReviewText(text))
                .textSelection(.enabled)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var latestDailyReviewValue: String {
        guard let review = appModel.latestDailyReview else { return "Not reviewed" }
        if Calendar.current.isDateInToday(review.date) { return "Today" }
        return review.date.formatted(.dateTime.day().month(.abbreviated))
    }

    private var latestDailyReviewDetail: String {
        guard let review = appModel.latestDailyReview else {
            return "Run a daily review after journaling to capture the clearest signal from the day."
        }
        let action = review.insight.action.trimmingCharacters(in: .whitespacesAndNewlines)
        return action.isEmpty ? review.summary : action
    }

    private var weeklyReviewValue: String {
        appModel.hasWeeklyReview ? "Ready" : "Building"
    }

    private var weeklyReviewDetail: String {
        if appModel.hasWeeklyReview {
            if let experiment = appModel.weeklyReview.nextExperiment, experiment.isEmpty == false {
                return experiment
            }
            if appModel.weeklyReview.suggestion.isEmpty == false {
                return appModel.weeklyReview.suggestion
            }
        }
        return appModel.weeklyUnlockProgressText
    }

    private var dailyGoalMomentumPoints: [GoalMomentumPoint] {
        let calendar = Calendar.current
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: last7DayInterval.start) else { return nil }
            let dayStart = calendar.startOfDay(for: date)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let dayInterval = DateInterval(start: dayStart, end: nextDay)
            let completed = appModel.completedGoals(in: dayInterval, cadence: .daily).count
            return GoalMomentumPoint(
                label: date.formatted(.dateTime.weekday(.abbreviated)),
                completed: completed
            )
        }
    }

    private func calmSessions(in interval: DateInterval) -> [CalmSessionLog] {
        appModel.calmSessions
            .filter { interval.contains($0.endedAt) }
            .sorted { $0.endedAt < $1.endedAt }
    }

    private func calmPathwayMetrics(in interval: DateInterval) -> [CalmPathwayMetric] {
        let sessions = calmSessions(in: interval)
        return CalmPathway.allCases.map { pathway in
            let matching = sessions.filter { $0.pathway == pathway }
            let totalDuration = matching.reduce(0) { $0 + $1.duration }
            return CalmPathwayMetric(
                pathway: pathway,
                count: matching.count,
                averageDuration: matching.isEmpty ? 0 : totalDuration / Double(matching.count)
            )
        }
        .filter { $0.count > 0 }
    }

    private func calmHelpfulnessSummary(in interval: DateInterval) -> CalmHelpfulnessSummary {
        let sessions = calmSessions(in: interval)
        let yes = sessions.filter { $0.helpfulness == .yes }.count
        let aBit = sessions.filter { $0.helpfulness == .aBit }.count
        let notReally = sessions.filter { $0.helpfulness == .notReally }.count
        return CalmHelpfulnessSummary(yes: yes, aBit: aBit, notReally: notReally)
    }

    private func calmLeadText(in interval: DateInterval, timeframe: String) -> String {
        let sessions = calmSessions(in: interval)
        guard sessions.isEmpty == false else { return "No Calm signal yet for \(timeframe)." }

        let helpfulness = calmHelpfulnessSummary(in: interval)
        let pathwayMetrics = calmPathwayMetrics(in: interval)
        let topPathway = pathwayMetrics.max(by: { $0.count < $1.count })?.pathway.title.lowercased() ?? "reset"

        if helpfulness.yes > 0 {
            return "You used Calm \(sessions.count) time\(sessions.count == 1 ? "" : "s") \(timeframe), and \(helpfulness.yes) session\(helpfulness.yes == 1 ? "" : "s") clearly helped. \(topPathway.capitalized) is the most-used reset."
        }
        if helpfulness.aBit > 0 {
            return "You used Calm \(sessions.count) time\(sessions.count == 1 ? "" : "s") \(timeframe). The clearest signal so far is partial help, with \(topPathway) showing up most."
        }
        return "You used Calm \(sessions.count) time\(sessions.count == 1 ? "" : "s") \(timeframe), but you have not marked a session as clearly helpful yet."
    }

    private func calmDurationLabel(_ duration: TimeInterval) -> String {
        let seconds = Int(duration.rounded())
        if seconds >= 60 {
            let minutes = seconds / 60
            let remainder = seconds % 60
            return remainder == 0 ? "\(minutes)m" : "\(minutes)m \(remainder)s"
        }
        return "\(seconds)s"
    }

    private func goalCadenceMetrics(in interval: DateInterval) -> [GoalCadenceMetric] {
        GoalCadence.allCases.map { cadence in
            let relevant = appModel.reflectionGoals.filter { ($0.cadence ?? .daily) == cadence }
            let completed = relevant.filter { goal in
                goal.status == .completed &&
                goal.feedbackAt.map(interval.contains) == true
            }.count
            let cleared = relevant.filter { goal in
                goal.status == .archived &&
                goal.feedbackAt.map(interval.contains) == true
            }.count
            let active = relevant.filter { goal in
                guard goal.status == .active else { return false }
                if let dueDate = goal.dueDate {
                    return goal.createdAt < interval.end && dueDate >= interval.start
                }
                return goal.createdAt < interval.end
            }.count
            return GoalCadenceMetric(cadence: cadence, completed: completed, active: active, cleared: cleared)
        }
    }

    private func goalOutcomeSummary(in interval: DateInterval) -> GoalOutcomeSummary {
        let metrics = goalCadenceMetrics(in: interval)
        return GoalOutcomeSummary(
            completed: metrics.reduce(0) { $0 + $1.completed },
            active: metrics.reduce(0) { $0 + $1.active },
            cleared: metrics.reduce(0) { $0 + $1.cleared }
        )
    }

    private func dailyGoalLeadText(completed: Int, active: Int, cleared: Int) -> String {
        if completed > 0 {
            return "You completed \(completed) daily \(completed == 1 ? "next step" : "next steps") in the last 7 days. Anchor uses that follow-through as evidence when it suggests what to do next."
        }
        if active > 0 {
            return "You have \(active) active \(active == 1 ? "next step" : "next steps") in play. Completing even one gives Anchor a clearer signal about what is actually helping."
        }
        if cleared > 0 {
            return "Some recent next steps were cleared before completion. That still matters because Anchor can learn which suggestions were too broad or easy to drop."
        }
        return "Daily next steps become more useful once Anchor can see whether they were completed, cleared, or left active."
    }

    private func goalOutcomeHeadline(_ summary: GoalOutcomeSummary) -> String {
        let total = max(1, summary.total)
        let completion = Int((Double(summary.completed) / Double(total) * 100).rounded())
        return "\(completion)% completed"
    }

    private var moodCalendar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle("Mood calendar")
                Spacer()
                HStack(spacing: 6) {
                    Button {
                        moveCalendarMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.bold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Text(calendarMonthDate.formatted(.dateTime.month(.wide).year()))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 92)

                    Button {
                        moveCalendarMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(canMoveCalendarForward ? .secondary : .tertiary)
                    .disabled(canMoveCalendarForward == false)
                }
            }
            VStack(spacing: 7) {
                HStack {
                    ForEach(Calendar.current.shortWeekdaySymbols, id: \.self) { day in
                        Text(day.prefix(1))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 7), spacing: 7) {
                    ForEach(monthCells, id: \.id) { cell in
                        MoodCalendarDayCell(
                            cell: cell,
                            selectedDate: selectedCalendarDate,
                            onSelect: selectCalendarCell
                        )
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        if value.translation.width < -44 {
                            moveCalendarMonth(by: 1)
                        } else if value.translation.width > 44 {
                            moveCalendarMonth(by: -1)
                        }
                    }
            )
            .animation(.easeInOut(duration: 0.18), value: calendarMonthDate)
            if monthEntryCount == 0 {
                Text("No entries in this month yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(monthEntryCount) \(monthEntryCount == 1 ? "entry" : "entries") this month")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            selectedDaySummary
            moodLegend
        }
    }

    private var calendarMonthDate: Date {
        displayedMonthDate ?? latestMonthDate
    }

    private var canMoveCalendarForward: Bool {
        let calendar = Calendar.current
        guard let next = calendar.date(byAdding: .month, value: 1, to: calendarMonthDate) else { return false }
        return calendar.startOfMonth(for: next) <= calendar.startOfMonth(for: Date())
    }

    private func moveCalendarMonth(by offset: Int) {
        guard offset != 0 else { return }
        let calendar = Calendar.current
        guard let target = calendar.date(byAdding: .month, value: offset, to: calendarMonthDate) else { return }
        if offset > 0, calendar.startOfMonth(for: target) > calendar.startOfMonth(for: Date()) {
            return
        }
        withAnimation(.easeInOut(duration: 0.18)) {
            displayedMonthDate = target
            selectedCalendarDate = preferredSelectionDate(in: target)
        }
    }

    private func preferredSelectionDate(in month: Date) -> Date {
        let calendar = Calendar.current
        let monthStart = calendar.startOfMonth(for: month)
        let monthEntries = entries.filter { calendar.isDate($0.date, equalTo: monthStart, toGranularity: .month) }
        if let latest = monthEntries.max(by: { $0.date < $1.date }) {
            return latest.date
        }
        return monthStart
    }

    private var monthEntryCount: Int {
        let calendar = Calendar.current
        return entries.filter { calendar.isDate($0.date, equalTo: calendarMonthDate, toGranularity: .month) }.count
    }

    private var moodTrend: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Mood trend")
            Chart(last30) { entry in
                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("Mood", entry.mood.score)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(appModel.journalCompanionTint)
                AreaMark(
                    x: .value("Date", entry.date),
                    y: .value("Mood", entry.mood.score)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(appModel.journalCompanionTint.opacity(0.10))
                PointMark(x: .value("Date", entry.date), y: .value("Mood", entry.mood.score))
                    .foregroundStyle(entry.mood.companionColor)
            }
            .chartYScale(domain: 1...5)
            .chartXScale(range: .plotDimension(padding: 20))
            .chartYAxis {
                AxisMarks(values: [1, 2, 3, 4, 5]) { AxisGridLine(); AxisValueLabel() }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { AxisValueLabel(format: .dateTime.day().month(.abbreviated)) }
            }
            .frame(height: 188)
        }
        .padding(.bottom, 8)
    }

    private var moodBreakdown: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()
                .background(AppSurface.stroke.opacity(0.65))
                .padding(.bottom, 6)
            sectionTitle("Mood distribution")
            Chart(moodCounts, id: \.mood) { item in
                SectorMark(angle: .value("Count", item.count), innerRadius: .ratio(0.58), angularInset: 2)
                    .foregroundStyle(item.mood.companionColor)
            }
            .frame(height: 190)
            VStack(spacing: 7) {
                ForEach(moodCounts, id: \.mood) { item in
                    HStack {
                        Circle().fill(item.mood.companionColor).frame(width: 9, height: 9)
                        Text(item.mood.label).font(.caption)
                        Spacer()
                        Text("\(item.count)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var weekdayPattern: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Day-of-week mood")
            if weekdayAveragesWithEntries.isEmpty {
                    Text("Log on a few different days and Anchor will compare which weekdays tend to feel steadier or heavier.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                weekdayBars
                if let strongest = weekdayAveragesWithEntries.max(by: { $0.average < $1.average }),
                   let weakest = weekdayAveragesWithEntries.min(by: { $0.average < $1.average }) {
                if strongest.weekday == weakest.weekday {
                        Text("\(strongest.name) is your only logged weekday so far. More entries will make this meaningful.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(strongest.name) currently trends strongest on average; \(weakest.name) trends lowest.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var weekdayBars: some View {
        VStack(spacing: 7) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(weekdayAverages, id: \.weekday) { item in
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(AppSurface.fill.opacity(0.55))
                                .frame(width: 12, height: 84)
                            if item.count > 0 {
                                Capsule()
                                    .fill(item.average >= averageMood ? MoodLevel.great.companionColor : MoodLevel.low.companionColor)
                                    .frame(width: 12, height: max(12, CGFloat(item.average / 5) * 84))
                            }
                        }
                        Text(item.shortName.prefix(1))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(item.count > 0 ? .secondary : .tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            HStack {
                Text("Lower")
                Spacer()
                Text("Average mood")
                Spacer()
                Text("Higher")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
        }
        .frame(height: 122)
    }

    private var themeImpact: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("What shows up with mood")
            if themeStats.isEmpty {
                Text("Add a few more entries with themes and Anchor will rank what tends to appear with higher and lower mood.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(themeStats.prefix(5), id: \.theme) { item in
                        HStack(spacing: 10) {
                            Text(item.theme)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(item.count)x")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                            Text(String(format: "%.1f", item.average))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(item.average >= averageMood ? MoodLevel.great.companionColor : MoodLevel.low.companionColor)
                        }
                        .padding(.vertical, 8)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(AppSurface.stroke.opacity(0.6)).frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private var lockedWeeklyPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            ReviewSignalStrip(items: [
                ReviewSignal(label: "Entries", value: "12"),
                ReviewSignal(label: "Days", value: "5"),
                ReviewSignal(label: "Mood", value: "3.4"),
                ReviewSignal(label: "Review", value: "Ready")
            ])
            weekdayBars
                .frame(height: 118)
        }
    }

    private func readableReviewText(_ text: String) -> String {
        readableReviewCopy(text)
    }

    private var lockedMonthlyPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            ReviewSignalStrip(items: [
                ReviewSignal(label: "Entries", value: "32"),
                ReviewSignal(label: "Days", value: "14"),
                ReviewSignal(label: "Mood", value: "3.6"),
                ReviewSignal(label: "Goal", value: "30d")
            ])
            Chart(sampleLockedTrend) { point in
                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Mood", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.white.opacity(0.68))
                AreaMark(
                    x: .value("Day", point.day),
                    y: .value("Mood", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.white.opacity(0.12))
            }
            .chartYScale(domain: 1...5)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 120)
        }
    }

    private var sampleLockedTrend: [LockedTrendPoint] {
        [
            LockedTrendPoint(day: 1, value: 2.6),
            LockedTrendPoint(day: 6, value: 3.2),
            LockedTrendPoint(day: 11, value: 3.0),
            LockedTrendPoint(day: 17, value: 3.8),
            LockedTrendPoint(day: 23, value: 3.4),
            LockedTrendPoint(day: 28, value: 4.0)
        ]
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
    }

    private var moodCounts: [(mood: MoodLevel, count: Int)] {
        MoodLevel.allCases.map { mood in
            (mood, last30.filter { $0.mood == mood }.count)
        }
    }

    private var entriesByDay: [(day: Date, count: Int)] {
        let grouped = Dictionary(grouping: last30) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.map { ($0.key, $0.value.count) }.sorted { $0.day < $1.day }
    }

    private var monthCells: [MoodCalendarCell] {
        let calendar = Calendar.current
        let monthInterval = calendar.dateInterval(of: .month, for: calendarMonthDate)
        guard let start = monthInterval?.start,
              let daysRange = calendar.range(of: .day, in: .month, for: start) else {
            return []
        }

        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        let weekdayOffset = calendar.component(.weekday, from: start) - calendar.firstWeekday
        let leading = (weekdayOffset + 7) % 7
        var cells: [MoodCalendarCell] = (0..<leading).map { _ in .empty(UUID()) }

        for offset in 0..<daysRange.count {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let dayEntries = grouped[calendar.startOfDay(for: date)] ?? []
            let latest = dayEntries.max { $0.date < $1.date }
            cells.append(.day(date: date, mood: latest?.mood, count: dayEntries.count))
        }

        while cells.count % 7 != 0 {
            cells.append(.empty(UUID()))
        }
        return cells
    }

    private var moodLegend: some View {
        HStack(spacing: 9) {
            ForEach(MoodLevel.allCases) { mood in
                HStack(spacing: 4) {
                    Circle()
                        .fill(mood.companionColor)
                        .frame(width: 7, height: 7)
                    Text(mood.shortLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedDaySummary: some View {
        let summary = selectedCalendarSummary
        return HStack(spacing: 10) {
            Circle()
                .fill(summary.mood?.companionColor ?? AppSurface.stroke)
                .frame(width: 10, height: 10)
            Text(summary.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
            Text(summary.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppSurface.stroke.opacity(0.65), lineWidth: 1)
        }
    }

    private var weekdayAverages: [WeekdayMoodAverage] {
        let calendar = Calendar.current
        return calendar.weekdaySymbols.enumerated().map { index, name in
            let weekday = index + 1
            let matching = last30.filter { calendar.component(.weekday, from: $0.date) == weekday }
            let average = matching.isEmpty ? 0 : Double(matching.reduce(0) { $0 + $1.mood.score }) / Double(matching.count)
            return WeekdayMoodAverage(weekday: weekday, name: name, shortName: String(name.prefix(3)), average: average, count: matching.count)
        }
    }

    private var weekdayAveragesWithEntries: [WeekdayMoodAverage] {
        weekdayAverages.filter { $0.count > 0 }
    }

    private var selectedCalendarSummary: CalendarSelectionSummary {
        let calendar = Calendar.current
        let selectedDate = selectedCalendarDate ?? latestMonthDate
        let day = calendar.startOfDay(for: selectedDate)
        let dayEntries = entries
            .filter { calendar.isDate($0.date, inSameDayAs: day) }
            .sorted { $0.date < $1.date }
        let latest = dayEntries.last
        let title = day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        if let latest {
            return CalendarSelectionSummary(
                title: title,
                detail: "\(latest.mood.label) mood, \(dayEntries.count) \(dayEntries.count == 1 ? "entry" : "entries")",
                mood: latest.mood
            )
        }
        return CalendarSelectionSummary(title: title, detail: "No entry logged", mood: nil)
    }

    private func selectCalendarCell(_ cell: MoodCalendarCell) {
        guard case .day(let date, _, _) = cell else { return }
        withAnimation(.easeOut(duration: 0.16)) {
            selectedCalendarDate = date
        }
    }

    private var themeStats: [ThemeMoodStat] {
        var buckets: [String: [Int]] = [:]
        for entry in last30 {
            for theme in entry.themes where theme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                buckets[theme, default: []].append(entry.mood.score)
            }
        }
        return buckets.map { theme, scores in
            ThemeMoodStat(theme: theme, count: scores.count, average: Double(scores.reduce(0, +)) / Double(scores.count))
        }
        .filter { $0.count >= 2 }
        .sorted {
            if $0.count == $1.count { return $0.average > $1.average }
            return $0.count > $1.count
        }
    }
}

private enum MoodCalendarCell {
    case empty(UUID)
    case day(date: Date, mood: MoodLevel?, count: Int)

    var id: String {
        switch self {
        case .empty(let id): id.uuidString
        case .day(let date, _, _): date.ISO8601Format()
        }
    }
}

private struct MoodCalendarDayCell: View {
    let cell: MoodCalendarCell
    let selectedDate: Date?
    let onSelect: (MoodCalendarCell) -> Void

    var body: some View {
        switch cell {
        case .empty:
            Color.clear
                .aspectRatio(1, contentMode: .fit)
        case .day(let date, let mood, let count):
            Button {
                onSelect(cell)
            } label: {
                dayView(date: date, mood: mood, count: count)
            }
            .buttonStyle(.plain)
        }
    }

    private func dayView(date: Date, mood: MoodLevel?, count: Int) -> some View {
        let fill = mood?.companionColor ?? AppSurface.stroke.opacity(0.75)
        let selected = isSelected(date)
        let background = selected
            ? (mood?.companionColor.opacity(0.28) ?? Color.white.opacity(0.12))
            : (mood?.companionColor.opacity(0.12) ?? Color.white.opacity(0.035))
        let dayNumber = Calendar.current.component(.day, from: date)

        return VStack(spacing: 3) {
            Text("\(dayNumber)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(mood == nil ? Color.secondary.opacity(0.52) : Color.white)
            moodDot(fill: fill, count: count)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(selected ? (mood?.companionColor ?? Color.white).opacity(0.9) : Color.clear, lineWidth: 1.2)
        }
        .accessibilityLabel(accessibilityLabel(date: date, mood: mood, count: count))
    }

    private func moodDot(fill: Color, count: Int) -> some View {
        Circle()
            .fill(fill)
            .frame(width: 9, height: 9)
            .overlay {
                if count > 1 {
                    Circle().stroke(Color.white.opacity(0.65), lineWidth: 1)
                }
            }
    }

    private func isSelected(_ date: Date) -> Bool {
        guard let selectedDate else { return false }
        return Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }

    private func accessibilityLabel(date: Date, mood: MoodLevel?, count: Int) -> String {
        if let mood {
            return "\(date.formatted(date: .abbreviated, time: .omitted)), \(mood.label), \(count) entries"
        }
        return "\(date.formatted(date: .abbreviated, time: .omitted)), no entry"
    }
}

private struct WeekdayMoodAverage {
    let weekday: Int
    let name: String
    let shortName: String
    let average: Double
    let count: Int
}

private struct ThemeMoodStat {
    let theme: String
    let count: Int
    let average: Double
}

private struct CalendarSelectionSummary {
    let title: String
    let detail: String
    let mood: MoodLevel?
}

private struct GoalMomentumPoint: Identifiable {
    let id = UUID()
    let label: String
    let completed: Int
}

private struct GoalCadenceMetric: Identifiable {
    let cadence: GoalCadence
    let completed: Int
    let active: Int
    let cleared: Int

    var id: GoalCadence { cadence }
}

private struct GoalOutcomeSummary {
    let completed: Int
    let active: Int
    let cleared: Int

    var total: Int {
        completed + active + cleared
    }
}

private struct CalmPathwayMetric: Identifiable {
    let pathway: CalmPathway
    let count: Int
    let averageDuration: TimeInterval

    var id: CalmPathway { pathway }
}

private struct CalmHelpfulnessSummary {
    let yes: Int
    let aBit: Int
    let notReally: Int

    var total: Int {
        yes + aBit + notReally
    }

    var helpfulPercentage: Int {
        guard total > 0 else { return 0 }
        return Int((Double(yes + aBit) / Double(total) * 100).rounded())
    }
}

private struct GoalOutcomeLegend: View {
    let summary: GoalOutcomeSummary

    var body: some View {
        HStack(spacing: 14) {
            goalLegendItem("Completed", value: summary.completed, color: .goalCompleted)
            goalLegendItem("Active", value: summary.active, color: .goalActive)
            goalLegendItem("Cleared", value: summary.cleared, color: .goalCleared)
        }
    }

    private func goalLegendItem(_ title: String, value: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.caption2.weight(.bold))
        }
    }
}

private struct DGGoalMomentumChart: UIViewRepresentable {
    let points: [GoalMomentumPoint]

    func makeUIView(context: Context) -> BarChartView {
        let chart = BarChartView()
        chart.backgroundColor = .clear
        chart.legend.enabled = false
        chart.doubleTapToZoomEnabled = false
        chart.scaleXEnabled = false
        chart.scaleYEnabled = false
        chart.pinchZoomEnabled = false
        chart.dragEnabled = false
        chart.setScaleEnabled(false)
        chart.highlightPerTapEnabled = false
        chart.highlightPerDragEnabled = false
        chart.drawValueAboveBarEnabled = false
        chart.drawBarShadowEnabled = false
        chart.drawGridBackgroundEnabled = false
        chart.minOffset = 0

        let xAxis = chart.xAxis
        xAxis.drawGridLinesEnabled = false
        xAxis.labelPosition = .bottom
        xAxis.labelTextColor = .secondaryLabel
        xAxis.axisLineColor = .clear
        xAxis.granularity = 1

        let leftAxis = chart.leftAxis
        leftAxis.axisMinimum = 0
        leftAxis.granularity = 1
        leftAxis.drawGridLinesEnabled = true
        leftAxis.gridColor = UIColor.white.withAlphaComponent(0.08)
        leftAxis.labelTextColor = .secondaryLabel
        leftAxis.axisLineColor = .clear

        chart.rightAxis.enabled = false
        return chart
    }

    func updateUIView(_ chart: BarChartView, context: Context) {
        let entries = points.enumerated().map { index, point in
            BarChartDataEntry(x: Double(index), y: Double(point.completed))
        }
        let set = BarChartDataSet(entries: entries, label: "")
        set.colors = [UIColor.goalCompleted]
        set.drawValuesEnabled = false
        set.highlightEnabled = false

        let data = BarChartData(dataSet: set)
        data.barWidth = 0.58
        chart.data = data
        chart.xAxis.valueFormatter = IndexAxisValueFormatter(values: points.map(\.label))
        let maxValue = max(2, points.map(\.completed).max() ?? 0)
        chart.leftAxis.axisMaximum = Double(maxValue) + 0.5
        chart.animate(yAxisDuration: 0.55, easingOption: .easeOutQuart)
    }
}

private struct DGGoalCadenceChart: UIViewRepresentable {
    let metrics: [GoalCadenceMetric]

    func makeUIView(context: Context) -> BarChartView {
        let chart = BarChartView()
        chart.backgroundColor = .clear
        chart.legend.enabled = false
        chart.doubleTapToZoomEnabled = false
        chart.scaleXEnabled = false
        chart.scaleYEnabled = false
        chart.pinchZoomEnabled = false
        chart.dragEnabled = false
        chart.setScaleEnabled(false)
        chart.highlightPerTapEnabled = false
        chart.highlightPerDragEnabled = false
        chart.drawValueAboveBarEnabled = false
        chart.drawBarShadowEnabled = false
        chart.drawGridBackgroundEnabled = false
        chart.minOffset = 0

        let xAxis = chart.xAxis
        xAxis.drawGridLinesEnabled = false
        xAxis.labelPosition = .bottom
        xAxis.labelTextColor = .secondaryLabel
        xAxis.axisLineColor = .clear
        xAxis.granularity = 1

        let leftAxis = chart.leftAxis
        leftAxis.axisMinimum = 0
        leftAxis.granularity = 1
        leftAxis.drawGridLinesEnabled = true
        leftAxis.gridColor = UIColor.white.withAlphaComponent(0.08)
        leftAxis.labelTextColor = .secondaryLabel
        leftAxis.axisLineColor = .clear

        chart.rightAxis.enabled = false
        return chart
    }

    func updateUIView(_ chart: BarChartView, context: Context) {
        let entries = metrics.enumerated().map { index, item in
            BarChartDataEntry(
                x: Double(index),
                yValues: [
                    Double(item.completed),
                    Double(item.active),
                    Double(item.cleared)
                ]
            )
        }

        let set = BarChartDataSet(entries: entries, label: "")
        set.colors = [
            UIColor.goalCompleted,
            UIColor.goalActive,
            UIColor.goalCleared
        ]
        set.stackLabels = ["Completed", "Active", "Cleared"]
        set.drawValuesEnabled = false
        set.highlightEnabled = false

        let data = BarChartData(dataSet: set)
        data.barWidth = 0.48
        chart.data = data
        chart.xAxis.valueFormatter = IndexAxisValueFormatter(values: metrics.map { $0.cadence.label })
        let maxValue = max(2, metrics.map { $0.completed + $0.active + $0.cleared }.max() ?? 0)
        chart.leftAxis.axisMaximum = Double(maxValue) + 0.5
        chart.animate(yAxisDuration: 0.6, easingOption: .easeOutQuart)
    }
}

private struct DGGoalOutcomeDonutChart: UIViewRepresentable {
    let summary: GoalOutcomeSummary

    func makeUIView(context: Context) -> PieChartView {
        let chart = PieChartView()
        chart.backgroundColor = .clear
        chart.legend.enabled = false
        chart.usePercentValuesEnabled = false
        chart.drawEntryLabelsEnabled = false
        chart.rotationEnabled = false
        chart.highlightPerTapEnabled = false
        chart.transparentCircleColor = .clear
        chart.holeColor = .clear
        chart.holeRadiusPercent = 0.64
        chart.transparentCircleRadiusPercent = 0
        chart.drawCenterTextEnabled = true
        chart.minOffset = 0
        return chart
    }

    func updateUIView(_ chart: PieChartView, context: Context) {
        let entries = [
            PieChartDataEntry(value: Double(max(summary.completed, 0)), label: "Completed"),
            PieChartDataEntry(value: Double(max(summary.active, 0)), label: "Active"),
            PieChartDataEntry(value: Double(max(summary.cleared, 0)), label: "Cleared")
        ]
        .filter { $0.value > 0 }

        if entries.isEmpty {
            chart.data = nil
            chart.centerAttributedText = centerText(title: "No goals", subtitle: "yet")
            return
        }

        let set = PieChartDataSet(entries: entries, label: "")
        set.colors = [UIColor.goalCompleted, UIColor.goalActive, UIColor.goalCleared]
        set.sliceSpace = 3
        set.selectionShift = 0
        set.drawValuesEnabled = false

        let data = PieChartData(dataSet: set)
        data.setDrawValues(false)
        chart.data = data

        let completionRate = summary.total == 0 ? 0 : Int((Double(summary.completed) / Double(summary.total) * 100).rounded())
        chart.centerAttributedText = centerText(title: "\(completionRate)%", subtitle: "completed")
        chart.animate(xAxisDuration: 0.55, easingOption: .easeOutQuart)
    }

    private func centerText(title: String, subtitle: String) -> NSAttributedString {
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let result = NSMutableAttributedString(string: title, attributes: valueAttributes)
        result.append(NSAttributedString(string: "\n\(subtitle)", attributes: subtitleAttributes))
        return result
    }
}

private struct DGCalmPathwayChart: UIViewRepresentable {
    let metrics: [CalmPathwayMetric]

    func makeUIView(context: Context) -> BarChartView {
        let chart = BarChartView()
        chart.backgroundColor = .clear
        chart.legend.enabled = false
        chart.doubleTapToZoomEnabled = false
        chart.scaleXEnabled = false
        chart.scaleYEnabled = false
        chart.pinchZoomEnabled = false
        chart.dragEnabled = false
        chart.setScaleEnabled(false)
        chart.highlightPerTapEnabled = false
        chart.highlightPerDragEnabled = false
        chart.drawValueAboveBarEnabled = false
        chart.drawBarShadowEnabled = false
        chart.drawGridBackgroundEnabled = false
        chart.minOffset = 0

        let xAxis = chart.xAxis
        xAxis.drawGridLinesEnabled = false
        xAxis.labelPosition = .bottom
        xAxis.labelTextColor = .secondaryLabel
        xAxis.axisLineColor = .clear
        xAxis.granularity = 1
        xAxis.labelCount = metrics.count

        let leftAxis = chart.leftAxis
        leftAxis.axisMinimum = 0
        leftAxis.granularity = 1
        leftAxis.drawGridLinesEnabled = true
        leftAxis.gridColor = UIColor.white.withAlphaComponent(0.08)
        leftAxis.labelTextColor = .secondaryLabel
        leftAxis.axisLineColor = .clear

        chart.rightAxis.enabled = false
        return chart
    }

    func updateUIView(_ chart: BarChartView, context: Context) {
        let entries = metrics.enumerated().map { index, item in
            BarChartDataEntry(x: Double(index), y: Double(item.count))
        }
        let set = BarChartDataSet(entries: entries, label: "")
        set.colors = metrics.map { UIColor($0.pathway.accentMood.interfaceAccentColor) }
        set.drawValuesEnabled = false
        set.highlightEnabled = false

        let data = BarChartData(dataSet: set)
        data.barWidth = 0.52
        chart.data = data
        chart.xAxis.valueFormatter = IndexAxisValueFormatter(values: metrics.map { $0.pathway.shortLabel })
        chart.leftAxis.axisMaximum = Double(max(2, metrics.map(\.count).max() ?? 0)) + 0.5
        chart.animate(yAxisDuration: 0.55, easingOption: .easeOutQuart)
    }
}

private struct DGCalmHelpfulnessDonutChart: UIViewRepresentable {
    let summary: CalmHelpfulnessSummary

    func makeUIView(context: Context) -> PieChartView {
        let chart = PieChartView()
        chart.backgroundColor = .clear
        chart.holeRadiusPercent = 0.58
        chart.transparentCircleRadiusPercent = 0
        chart.drawEntryLabelsEnabled = false
        chart.usePercentValuesEnabled = false
        chart.legend.enabled = false
        chart.rotationEnabled = false
        chart.highlightPerTapEnabled = false
        chart.chartDescription.enabled = false
        return chart
    }

    func updateUIView(_ chart: PieChartView, context: Context) {
        let entries = [
            PieChartDataEntry(value: Double(summary.yes), label: "Yes"),
            PieChartDataEntry(value: Double(summary.aBit), label: "A bit"),
            PieChartDataEntry(value: Double(summary.notReally), label: "Not really")
        ]
        .filter { $0.value > 0 }

        if entries.isEmpty {
            chart.data = nil
            chart.centerAttributedText = NSAttributedString(
                string: "No feedback yet",
                attributes: [
                    .foregroundColor: UIColor.secondaryLabel,
                    .font: UIFont.systemFont(ofSize: 14, weight: .medium)
                ]
            )
            return
        }

        let set = PieChartDataSet(entries: entries, label: "")
        set.colors = [
            UIColor(MoodLevel.great.interfaceAccentColor),
            UIColor(MoodLevel.good.interfaceAccentColor),
            UIColor(MoodLevel.low.interfaceAccentColor)
        ]
        set.drawValuesEnabled = false
        set.selectionShift = 0

        chart.data = PieChartData(dataSet: set)
        chart.centerAttributedText = NSAttributedString(
            string: "\(summary.helpfulPercentage)%\nhelpful",
            attributes: [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
            ]
        )
        chart.animate(yAxisDuration: 0.5, easingOption: .easeOutQuart)
    }
}

private extension UIColor {
    static let goalCompleted = UIColor(red: 0.36, green: 0.76, blue: 0.56, alpha: 1)
    static let goalActive = UIColor(red: 0.78, green: 0.80, blue: 0.84, alpha: 1)
    static let goalCleared = UIColor(red: 0.86, green: 0.60, blue: 0.34, alpha: 1)
}

private extension Color {
    static let goalCompleted = Color(uiColor: .goalCompleted)
    static let goalActive = Color(uiColor: .goalActive)
    static let goalCleared = Color(uiColor: .goalCleared)
}

private struct LockedTrendPoint: Identifiable {
    let id = UUID()
    let day: Int
    let value: Double
}

private struct ReviewSignal {
    let label: String
    let value: String
}

private struct ReviewSignalStrip: View {
    let items: [ReviewSignal]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 4) {
                    Text(item.value)
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(item.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppSurface.stroke.opacity(0.65)).frame(height: 1)
        }
    }
}

private struct ReviewNotesDisclosure<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder var content: Content

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(.top, 10)
        } label: {
            Text(title)
                .font(.headline.weight(.semibold))
        }
        .tint(.secondary)
    }
}

private struct LockedInsightPreview<Content: View>: View {
    let title: String
    let detail: String
    let systemImage: String
    let premiumOnly: Bool
    var buttonTitle: String? = nil
    var action: (() -> Void)? = nil
    @ViewBuilder var preview: Content

    var body: some View {
        ZStack {
            preview
                .blur(radius: 7)
                .opacity(0.5)
                .allowsHitTesting(false)

            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                Text(title)
                    .font(.headline.weight(.bold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if premiumOnly {
                    Text("Premium")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.12), in: Capsule())
                }
                if let buttonTitle, let action {
                    Button(buttonTitle) {
                        action()
                    }
                    .buttonStyle(PrimaryCapsuleButtonStyle())
                    .padding(.top, 4)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppSurface.stroke.opacity(0.65), lineWidth: 0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}

private struct InsightSummaryBlock: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(title, systemImage: symbol)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(tint)
                Spacer()
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

private struct CompletedNextStepsView: View {
    @Environment(\.dismiss) private var dismiss

    let goals: [ReflectionGoal]

    var body: some View {
        List {
            if goals.isEmpty {
                Section {
                    Text("No completed next steps yet.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(goals) { goal in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(goal.title)
                                .font(.subheadline.weight(.semibold))
                            Text(goal.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(completedGoalDateText(goal))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Completed next steps")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Completed next steps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private func completedGoalDateText(_ goal: ReflectionGoal) -> String {
        let date = goal.feedbackAt ?? goal.createdAt
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

private struct IntelligenceRow: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Text(value)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppSurface.stroke.opacity(0.55)).frame(height: 1)
        }
    }
}

private enum InsightTab: String, CaseIterable, Identifiable {
    case feed
    case weekly
    case analytics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .feed: "Highlights"
        case .weekly: "Weekly"
        case .analytics: "Trends"
        }
    }
}

private struct InsightFeedView: View {
    @EnvironmentObject private var appModel: AppViewModel

    private var stories: [InsightStory] {
        var output: [InsightStory] = []
        if let firstPattern = appModel.weeklyReview.primaryLoop, firstPattern.isEmpty == false {
            output.append(.init(title: "Primary loop", subtitle: firstPattern, symbol: "point.3.connected.trianglepath.dotted", tint: .cyan, kind: "Pattern"))
        }
        if let progress = appModel.weeklyReview.progressSignal, progress.isEmpty == false {
            output.append(.init(title: "Progress", subtitle: progress, symbol: "arrow.up.right.circle", tint: .green, kind: "Shift"))
        }
        if let baseline = appModel.weeklyReview.baselineComparison, baseline.isEmpty == false {
            output.append(.init(title: "Baseline", subtitle: baseline, symbol: "chart.line.uptrend.xyaxis", tint: .purple, kind: "Trend"))
        }
        if let experiment = appModel.weeklyReview.nextExperiment, experiment.isEmpty == false {
            output.append(.init(title: "Next focus", subtitle: experiment, symbol: "checkmark.seal", tint: .orange, kind: "Action"))
        }
        output.append(contentsOf: appModel.insights.prefix(6).map {
            InsightStory(title: $0.title, subtitle: $0.body, symbol: $0.type.symbol, tint: .white, kind: $0.category)
        })
        output.append(contentsOf: appModel.localSignals.prefix(4).map {
            InsightStory(title: $0.title, subtitle: $0.body, symbol: $0.type.symbol, tint: AppTheme.accent, kind: "On-device")
        })
        return Array(output.prefix(10))
    }

    var body: some View {
        ScrollView {
            if appModel.hasInsightContent == false {
                ContentUnavailableView(
                    "No insights yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Review a day after writing. Insights will appear here.")
                )
                .padding(.top, 80)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Key insights")
                                .font(.title3.weight(.bold))
                            Text("The clearest patterns from your recent entries and reviews.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        ExplainerButton(
                            title: "Key insights",
                            body: "These are the clearest patterns Anchor can explain from your recent journal activity.",
                            bullets: [
                                "Repeated signals are shown before one-off notes.",
                                "Daily reviews add emotional reads, reframes, and actions.",
                                "Weekly reports add broader patterns when enough entries exist."
                            ]
                        )
                    }

                    VStack(spacing: 10) {
                        ForEach(stories.prefix(6)) { story in
                            ReferenceCard {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: story.symbol)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(story.tint)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack {
                                            Text(story.title)
                                                .font(.subheadline.weight(.semibold))
                                            Spacer()
                                            Text(story.kind)
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.tertiary)
                                        }
                                        Text(story.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }

                    if appModel.isPremium == false {
                        ReferenceCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Premium report preview", systemImage: "lock.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text("Premium adds a weekly pattern report with baseline comparison, action feedback, and next experiments.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(AppSpacing.page)
            }
        }
        .safeAreaPadding(.bottom, 86)
    }
}

private struct InsightStory: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let kind: String
}

private struct InsightStoryCard: View {
    let story: InsightStory
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            story.tint.opacity(0.28),
                            Color.white.opacity(0.08),
                            Color.black.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                }

            InsightOrbitalMark(tint: story.tint)
                .frame(width: 220, height: 220)
                .offset(x: 118, y: -126)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.88)

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label(story.kind, systemImage: story.symbol)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 11)
                        .frame(height: 32)
                        .background(Color.white.opacity(0.12), in: Capsule())
                    Spacer()
                }
                Spacer()
                Text(story.title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                Text(story.subtitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                appeared = true
            }
        }
    }
}

private struct InsightOrbitalMark: View {
    let tint: Color

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(tint.opacity(0.2 + Double(index) * 0.11), lineWidth: 2)
                    .rotationEffect(.degrees(Double(index) * 23))
                    .padding(CGFloat(index) * 18)
            }
            Circle()
                .fill(tint.opacity(0.24))
                .frame(width: 54, height: 54)
        }
    }
}

private struct WeeklyReviewContainerView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        ScrollView {
            if appModel.hasWeeklyReview {
                WeeklyReviewView(review: appModel.weeklyReview, embedded: true)
                    .padding(AppSpacing.page)
            } else {
                ContentUnavailableView(
                    "No weekly review yet",
                    systemImage: "calendar.badge.clock",
                    description: Text(appModel.weeklyUnlockProgressText)
                )
                .padding(.top, 80)
            }
        }
        .safeAreaPadding(.bottom, 86)
        .task {
            await appModel.refreshWeeklyReview()
        }
    }
}

struct WeeklyReviewView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var router: AppRouter
    let review: WeeklyReview
    var embedded = false

    private var completedWeeklyGoals: [ReflectionGoal] {
        appModel.completedGoalsLast(days: 7)
    }

    private var premiumProgressText: String? {
        let candidates = [
            review.goalFollowThrough,
            review.progressSignal ?? "",
            review.baselineComparison ?? ""
        ]
        for candidate in candidates {
            let cleaned = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty == false {
                return readableReviewCopy(cleaned)
            }
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                AICircleView(state: .checkIn, size: 48, strokeWidth: 2.2, tint: .white)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(appModel.isPremium ? "Weekly review" : "Weekly insight")
                            .font(.headline)
                        ExplainerButton(
                            title: "Weekly pattern report",
                            body: "Weekly review compresses several days into one pattern report so the app can compare change over time.",
                            bullets: [
                                "Free keeps this short and practical.",
                                "Premium adds baseline comparison, deeper goal feedback, and a richer 7-day experiment.",
                                "It only unlocks after enough entries to reduce guesswork."
                            ],
                            symbol: "questionmark.circle"
                        )
                    }
                    Text(review.dateRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(appModel.planTier.weeklyReviewLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("This week")
                    .font(.subheadline.weight(.semibold))
                if review.patterns.isEmpty {
                    Text("There is not enough repeated evidence for a weekly conclusion yet.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(review.patterns, id: \.self) { pattern in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: "sparkle")
                                .font(.caption)
                            Text(readableReviewCopy(pattern))
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            Divider().background(AppSurface.stroke.opacity(0.55))

            if let premiumProgressText, appModel.isPremium {
                InsightSectionView(title: "Goal progress", bodyText: premiumProgressText, symbol: "flag.checkered")
                Divider().background(AppSurface.stroke.opacity(0.55))
            }

            if appModel.isPremium, completedWeeklyGoals.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completed this week")
                        .font(.subheadline.weight(.semibold))
                    ForEach(completedWeeklyGoals.prefix(3)) { goal in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(goal.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(goal.feedbackAt?.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)) ?? "Completed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Divider().background(AppSurface.stroke.opacity(0.55))
            }

            if appModel.isPremium, review.patternShift.isEmpty == false {
                InsightSectionView(title: "What changed", bodyText: readableReviewCopy(review.patternShift), symbol: "arrow.left.arrow.right")
                Divider().background(AppSurface.stroke.opacity(0.55))
            }
            if appModel.isPremium, let baselineComparison = review.baselineComparison, baselineComparison.isEmpty == false {
                InsightSectionView(title: "Compared with your baseline", bodyText: readableReviewCopy(baselineComparison), symbol: "chart.line.uptrend.xyaxis")
                Divider().background(AppSurface.stroke.opacity(0.55))
            }
            if appModel.isPremium, let primaryLoop = review.primaryLoop, primaryLoop.isEmpty == false {
                InsightSectionView(title: "Main loop to watch", bodyText: readableReviewCopy(primaryLoop), symbol: "point.3.connected.trianglepath.dotted")
                Divider().background(AppSurface.stroke.opacity(0.55))
            }
            if appModel.isPremium, review.risk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                InsightSectionView(title: "Watch next", bodyText: readableReviewCopy(review.risk), symbol: InsightType.risk.symbol)
                Divider().background(AppSurface.stroke.opacity(0.55))
            }
            if appModel.isPremium, review.healthPatterns.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Health-aware signals")
                        .font(.subheadline.weight(.semibold))
                    ForEach(review.healthPatterns, id: \.self) { pattern in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: pattern.lowercased().contains("sleep") ? "moon" : "figure.walk")
                                .font(.caption)
                            Text(readableReviewCopy(pattern))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Divider().background(AppSurface.stroke.opacity(0.55))
            }
            InsightSectionView(title: "Next focus", bodyText: readableReviewCopy(review.nextExperiment ?? review.suggestion), symbol: InsightType.suggestion.symbol)
            if appModel.isPremium, let suggestedTemplate = review.suggestedTemplate, suggestedTemplate.isEmpty == false {
                Divider().background(AppSurface.stroke.opacity(0.55))
                InsightSectionView(title: "Suggested template", bodyText: readableReviewCopy(suggestedTemplate), symbol: "square.text.square")
            }
            if appModel.isPremium, let researchPrompt = review.researchPrompt, researchPrompt.isEmpty == false {
                Divider().background(AppSurface.stroke.opacity(0.55))
                InsightSectionView(title: "Learn more", bodyText: readableReviewCopy(researchPrompt), symbol: "book")
            }
            if appModel.isPremium == false {
                ReferenceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Premium preview", systemImage: "lock.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Goal progress over time")
                            .font(.subheadline.weight(.semibold))
                            .redacted(reason: .placeholder)
                        Text("What changed from your baseline")
                            .font(.subheadline.weight(.semibold))
                            .redacted(reason: .placeholder)
                        Text("Unlock completed-goal references, baseline comparison, and deeper weekly progress tracking.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Unlock Premium") {
                            router.presentPaywall(.weeklyReview)
                        }
                        .buttonStyle(PrimaryCapsuleButtonStyle())
                        .padding(.top, 4)
                    }
                }
            }
        }
        .navigationTitle(appModel.isPremium ? "Weekly review" : "Weekly insight")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func readableReviewCopy(_ text: String) -> String {
    let pattern = #"\b(\d{4})-(\d{2})-(\d{2})\b"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return text
            .replacingOccurrences(of: "Next 7 days:", with: "For this week:")
            .replacingOccurrences(of: "Next experiment", with: "Next focus")
    }

    let formatter = DateFormatter()
    formatter.calendar = Calendar.current
    formatter.locale = Locale.current
    formatter.dateFormat = "yyyy-MM-dd"

    let mutable = NSMutableString(string: text)
    let baseText = String(mutable)
    let matches = regex.matches(in: baseText, range: NSRange(location: 0, length: mutable.length)).reversed()
    for match in matches {
        let raw = mutable.substring(with: match.range)
        guard let date = formatter.date(from: raw) else { continue }
        mutable.replaceCharacters(in: match.range, with: date.longReadableDate)
    }

    return String(mutable)
        .replacingOccurrences(of: "Next 7 days:", with: "For this week:")
        .replacingOccurrences(of: "Next experiment", with: "Next focus")
}

private struct AnalyticsView: View {
    private enum TrendWindow: String, CaseIterable, Identifiable {
        case week = "7D"
        case month = "30D"
        case all = "All"
        var id: String { rawValue }
    }

    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var router: AppRouter
    @State private var showMoreAnalytics = false
    @State private var selectedMoodDate: Date?
    @State private var selectedMoodAngle: Double?
    @State private var selectedEntryTypeAngle: Double?
    @State private var trendWindow: TrendWindow = .month
    @State private var selectedDriverTip: AppViewModel.CompanionDriver?

    private var sortedEntries: [JournalEntry] {
        appModel.journalEntries.sorted { $0.date < $1.date }
    }

    private var filteredEntries: [JournalEntry] {
        guard let latest = sortedEntries.last else { return [] }
        let cal = Calendar.current
        let lowerBound: Date? = switch trendWindow {
        case .week: cal.date(byAdding: .day, value: -6, to: latest.date)
        case .month: cal.date(byAdding: .day, value: -29, to: latest.date)
        case .all: nil
        }
        guard let lowerBound else { return sortedEntries }
        return sortedEntries.filter { $0.date >= lowerBound }
    }

    var body: some View {
        ScrollView {
            if sortedEntries.isEmpty {
                ContentUnavailableView(
                    "No analytics yet",
                    systemImage: "chart.bar",
                    description: Text("Trends appear after you have a few entries.")
                )
                .padding(.top, 80)
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    analyticsSummary
                    monthlyReviewSection
                    memorySignalsSection
                    signalClarityDeltaSummary
                    signalClarityChart
                    signalClarityHistorySection
                    localSignalSummary
                    moodTrendChart
                    checkInConsistencyChart
                    moodDistributionChart
                    DisclosureGroup(showMoreAnalytics ? "Hide detailed analytics" : "Show detailed analytics", isExpanded: $showMoreAnalytics) {
                        VStack(alignment: .leading, spacing: AppSpacing.section) {
                            topThemesChart
                            entryTypeBreakdownChart
                            reviewCadenceChart
                            healthContextChart
                        }
                        .padding(.top, 8)
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(AppSpacing.page)
            }
        }
        .safeAreaPadding(.bottom, 86)
    }

    private var analyticsSummary: some View {
        ReferenceCard {
            HStack(spacing: 12) {
                metric("Entries", value: "\(sortedEntries.count)")
                Divider()
                metric("Days", value: "\(uniqueDayCount)")
                Divider()
                metric("Mood", value: averageMoodLabel)
                Divider()
                metric("Reviews", value: "\(appModel.dailyReviews.count)")
            }
        }
    }

    private var monthlyReviewSection: some View {
        Group {
            if let review = appModel.currentMonthlyReview {
                let completedGoals = appModel.completedGoalsLast(days: 31)
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "Month in review")
                    ReferenceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(review.monthTitle)
                                    .font(.headline)
                                Spacer()
                                Text("\(review.activeDays) days")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            if review.goalFollowThrough.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                                Text(review.goalFollowThrough)
                                    .font(.subheadline)
                            } else {
                                Text(review.strongestPattern)
                                    .font(.subheadline)
                            }
                            if let baselineComparison = review.baselineComparison, baselineComparison.isEmpty == false {
                                Text(baselineComparison)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if review.moodRange.isEmpty == false {
                                Text(review.moodRange)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(review.progress)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if completedGoals.isEmpty == false {
                                Text("Completed this month: \(completedGoals.prefix(3).map(\.title).joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Next focus: \(review.nextExperiment)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                            if review.topThemes.isEmpty == false {
                                Text(review.topThemes.joined(separator: " · "))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var memorySignalsSection: some View {
        let signals = appModel.memorySignals
        return Group {
            if signals.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "Long-term memory")
                    ReferenceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(signals.prefix(4)) { signal in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: signal.category == "Goal" ? "flag.checkered" : "point.3.connected.trianglepath.dotted")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.accent)
                                        .frame(width: 18)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(signal.title)
                                            .font(.caption.weight(.semibold))
                                        Text(signal.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var signalClarityChart: some View {
        let points = appModel.companionStateTimeline
        let latest = points.last
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Signal clarity timeline")
            ReferenceCard {
                VStack(alignment: .leading, spacing: 8) {
                    Chart(points) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("State score", point.score)
                        )
                        .foregroundStyle(AppTheme.accent.opacity(0.18))

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("State score", point.score)
                        )
                        .foregroundStyle(AppTheme.accent)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("State score", point.score)
                        )
                        .foregroundStyle(point.state == latest?.state ? .white : AppTheme.accentSoft)
                        .symbolSize(point.state == latest?.state ? 82 : 42)
                    }
                    .chartYScale(domain: 0...1)
                    .chartYAxis {
                        AxisMarks(values: [0, 0.25, 0.5, 0.75, 1]) {
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 3)) {
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .frame(height: 150)

                    if let latest {
                        HStack {
                            Text("Now: \(latest.state.title)")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text("Confidence \(Int((latest.confidence * 100).rounded()))%")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var signalClarityDeltaSummary: some View {
        let delta = appModel.signalClarityDeltaWeek
        let direction = delta >= 0 ? "Improving" : "Regressing"
        let symbol = delta >= 0 ? "arrow.up.right" : "arrow.down.right"
        let tint: Color = delta >= 0 ? .green : .orange
        return ReferenceCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Weekly clarity delta", systemImage: symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                    Spacer()
                    Text("\(delta >= 0 ? "+" : "")\(delta)%")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(tint)
                }
                Text("\(direction) over the last 7 days based on mood trend, check-in consistency, calm sessions, and follow-through.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(appModel.companionDriversToday) { driver in
                            Button {
                                selectedDriverTip = driver
                            } label: {
                                Text(driver.name)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(AppSurface.fill, in: Capsule())
                                    .overlay {
                                        Capsule().stroke(AppSurface.stroke, lineWidth: 0.5)
                                    }
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Button("Start check-in") {
                        router.selectedTab = .journal
                    }
                    .buttonStyle(CompactIconButtonStyle())

                    Button("Open Calm") {
                        router.selectedTab = .calm
                    }
                    .buttonStyle(CompactIconButtonStyle())
                }
            }
        }
        .sheet(item: $selectedDriverTip) { driver in
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
                        selectedDriverTip = nil
                        if driver.name == "Calm sessions" {
                            router.selectedTab = .calm
                        } else {
                            router.selectedTab = .journal
                        }
                    } label: {
                        Label(driver.name == "Calm sessions" ? "Open Calm now" : "Start check-in now", systemImage: "arrow.right.circle.fill")
                    }
                    .buttonStyle(PrimaryCapsuleButtonStyle())
                    Spacer()
                }
                .padding(AppSpacing.page)
                .navigationTitle("Recovery action")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationCornerRadius(28)
        }
    }

    private var signalClarityHistorySection: some View {
        let timeline = appModel.companionStateTimeline
        let sorted = timeline.sorted { $0.date < $1.date }
        let latest = sorted.last?.score ?? 0
        let sevenDayStart = max(0, sorted.count - 7)
        let thirtyDayStart = max(0, sorted.count - 14)
        let sevenDayBase = sorted.indices.contains(sevenDayStart) ? sorted[sevenDayStart].score : latest
        let thirtyDayBase = sorted.indices.contains(thirtyDayStart) ? sorted[thirtyDayStart].score : latest
        let sevenDelta = Int(((latest - sevenDayBase) * 100).rounded())
        let thirtyDelta = Int(((latest - thirtyDayBase) * 100).rounded())

        let checkpoints = [
            ("7-day shift", sevenDelta),
            ("30-day shift", thirtyDelta)
        ]

        let milestones = sorted.compactMap { point -> String? in
            let score = Int((point.score * 100).rounded())
            if point.state == .thriving && score >= 82 {
                return "\(point.date.compactDate): Entered thriving range (\(score)%)"
            }
            if point.state == .overwhelmed && score <= 25 {
                return "\(point.date.compactDate): High strain period detected (\(score)%)"
            }
            return nil
        }

        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Signal history")
            ReferenceCard {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(checkpoints, id: \.0) { item in
                        HStack {
                            Text(item.0)
                                .font(.caption)
                            Spacer()
                            Text("\(item.1 >= 0 ? "+" : "")\(item.1)%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(item.1 >= 0 ? .green : .orange)
                        }
                    }

                    Divider().background(AppSurface.stroke.opacity(0.55))

                    Text("Notable events")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if milestones.isEmpty {
                        Text("No major state flips yet. Keep logging and using Calm to build a clearer trajectory.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(milestones.prefix(3).enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var localSignalSummary: some View {
        let signals = appModel.localSignals
        return Group {
            if signals.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "What the app can detect on your phone")
                    ReferenceCard {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(signals.prefix(3)) { signal in
                                Label(signal.body, systemImage: signal.type.symbol)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var moodTrendChart: some View {
        let selectedEntry = selectedEntryForDate
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(title: "Mood over time")
                Spacer()
                Picker("Window", selection: $trendWindow) {
                    ForEach(TrendWindow.allCases) { window in
                        Text(window.rawValue).tag(window)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)
            }
            ReferenceCard {
                VStack(alignment: .leading, spacing: 8) {
                    Chart(filteredEntries) { entry in
                    LineMark(
                        x: .value("Day", entry.date),
                        y: .value("Mood score", entry.mood.score)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(AppTheme.accent)
                    PointMark(
                        x: .value("Day", entry.date),
                        y: .value("Mood score", entry.mood.score)
                    )
                        .foregroundStyle(entry.mood.companionColor.opacity(isSelectedMoodEntry(entry) ? 1 : 0.55))
                        .symbolSize(isSelectedMoodEntry(entry) ? 92 : 46)
                    if isSelectedMoodEntry(entry) {
                        RuleMark(x: .value("Selected day", entry.date))
                            .foregroundStyle(.white.opacity(0.28))
                    }
                }
                    .chartYScale(domain: 1...5)
                    .chartYAxis {
                        AxisMarks(values: [1, 2, 3, 4, 5]) {
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: max(1, sortedEntries.count / 4))) {
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartXSelection(value: $selectedMoodDate)
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            if let selectedEntry,
                               let px = proxy.position(forX: selectedEntry.date),
                               let py = proxy.position(forY: selectedEntry.mood.score) {
                                let frame = geo[proxy.plotFrame!]
                                let anchorX = frame.origin.x + px
                                let anchorY = frame.origin.y + py
                                let preferred = CGPoint(x: anchorX, y: anchorY - 28)
                                let safe = tooltipPosition(
                                    preferred: preferred,
                                    frame: frame,
                                    tooltipSize: CGSize(width: 122, height: 52),
                                    margin: 8
                                )
                                moodTooltip(for: selectedEntry)
                                    .position(safe)
                            }
                        }
                    }
                    .frame(height: 150)
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: selectedMoodDate)
    }

    private var checkInConsistencyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "This week's check-ins")
            ReferenceCard {
                Chart(appModel.currentWeekDates, id: \.self) { date in
                    BarMark(
                        x: .value("Day", date.shortDay),
                        y: .value("Check-in done", appModel.entries(on: date).isEmpty ? 0 : 1)
                    )
                    .foregroundStyle(AppTheme.accent.gradient)
                }
                .chartYScale(domain: 0...1.2)
                .chartYAxis {
                    AxisMarks(values: [0, 1]) {
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 120)
            }
        }
    }

    private var moodDistributionChart: some View {
        let total = max(1, moodCounts.map(\.count).reduce(0, +))
        let selectedMoodSlice = selectedMoodCount
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Mood breakdown")
            ReferenceCard {
                VStack(alignment: .leading, spacing: 10) {
                    Chart(moodCounts.filter { $0.count > 0 }, id: \.name) { item in
                        SectorMark(
                            angle: .value("Entries", item.count),
                            innerRadius: .ratio(selectedMoodSlice?.name == item.name ? 0.52 : 0.58),
                            outerRadius: .ratio(selectedMoodSlice?.name == item.name ? 1.0 : 0.94),
                            angularInset: 2
                        )
                        .foregroundStyle(moodColor(for: item.name))
                        .annotation(position: .overlay) {
                            if selectedMoodSlice?.name == item.name {
                                donutTooltip(
                                    title: item.name,
                                    value: "\(item.count) (\(Int((Double(item.count) / Double(total) * 100).rounded()))%)"
                                )
                            }
                        }
                    }
                    .chartAngleSelection(value: $selectedMoodAngle)
                    .chartLegend(.hidden)
                    .frame(height: 170)

                    ForEach(moodCounts.filter { $0.count > 0 }, id: \.name) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(moodColor(for: item.name))
                                .frame(width: 8, height: 8)
                            Text(item.name)
                                .font(.caption)
                            Spacer()
                            Text("\(item.count) (\(Int((Double(item.count) / Double(total) * 100).rounded()))%)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selectedMoodSlice?.name == item.name ? .primary : .secondary)
                        }
                        .opacity(selectedMoodSlice == nil || selectedMoodSlice?.name == item.name ? 1 : 0.6)
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: selectedMoodAngle)
    }

    private var topThemesChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Top themes")
            ReferenceCard {
                Chart(themeCounts, id: \.name) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Theme", item.name)
                    )
                    .foregroundStyle(AppTheme.accent.gradient)
                }
                .frame(height: 140)
            }
        }
    }

    private var entryTypeBreakdownChart: some View {
        let total = max(1, entryTypeCounts.map(\.count).reduce(0, +))
        let selectedEntryTypeSlice = selectedEntryTypeCount
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Entry type mix")
            ReferenceCard {
                VStack(alignment: .leading, spacing: 10) {
                    Chart(entryTypeCounts, id: \.name) { item in
                        SectorMark(
                            angle: .value("Count", item.count),
                            innerRadius: .ratio(selectedEntryTypeSlice?.name == item.name ? 0.52 : 0.6),
                            outerRadius: .ratio(selectedEntryTypeSlice?.name == item.name ? 1.0 : 0.94),
                            angularInset: 2
                        )
                        .foregroundStyle(by: .value("Type", item.name))
                        .annotation(position: .overlay) {
                            if selectedEntryTypeSlice?.name == item.name {
                                donutTooltip(
                                    title: item.name,
                                    value: "\(item.count) (\(Int((Double(item.count) / Double(total) * 100).rounded()))%)"
                                )
                            }
                        }
                    }
                    .chartAngleSelection(value: $selectedEntryTypeAngle)
                    .chartForegroundStyleScale(
                        domain: entryTypeCounts.map(\.name),
                        range: [AppTheme.accent, AppTheme.accentSoft, .white, Color(red: 0.67, green: 0.81, blue: 1.0)]
                    )
                    .chartLegend(position: .bottom, spacing: 12)
                    .frame(height: 190)

                    ForEach(entryTypeCounts, id: \.name) { item in
                        HStack {
                            Text(item.name)
                                .font(.caption)
                            Spacer()
                            Text("\(item.count) (\(Int((Double(item.count) / Double(total) * 100).rounded()))%)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selectedEntryTypeSlice?.name == item.name ? .primary : .secondary)
                        }
                        .opacity(selectedEntryTypeSlice == nil || selectedEntryTypeSlice?.name == item.name ? 1 : 0.6)
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: selectedEntryTypeAngle)
    }

    private var reviewCadenceChart: some View {
        Group {
            if appModel.dailyReviews.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "Review history")
                    ReferenceCard {
                        Chart(appModel.dailyReviews.sorted { $0.date < $1.date }) { review in
                            BarMark(
                                x: .value("Date", review.date),
                                y: .value("Reviewed", 1)
                            )
                            .foregroundStyle(AppTheme.accent.gradient)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: max(1, appModel.dailyReviews.count / 4))) {
                                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            }
                        }
                        .chartYAxis {
                            AxisMarks(values: [0, 1]) {
                                AxisGridLine()
                                AxisValueLabel()
                            }
                        }
                        .frame(height: 110)
                    }
                }
            }
        }
    }

    private var healthContextChart: some View {
        let entries = sortedEntries.filter { $0.sleepHours != nil }
        return Group {
            if entries.count >= 2 {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "Sleep and mood")
                    ReferenceCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Chart(entries) { entry in
                                if let sleep = entry.sleepHours {
                                    PointMark(
                                        x: .value("Sleep hours", sleep),
                                        y: .value("Mood score", entry.mood.score)
                                    )
                                    .foregroundStyle(AppTheme.accent.gradient)
                                }
                            }
                            .chartYScale(domain: 1...5)
                            .chartYAxis {
                                AxisMarks(values: [1, 2, 3, 4, 5]) {
                                    AxisGridLine()
                                    AxisValueLabel()
                                }
                            }
                            .frame(height: 130)

                            Text("This chart is here for context only. It does not diagnose anything.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var uniqueDayCount: Int {
        Set(sortedEntries.map { Calendar.current.startOfDay(for: $0.date) }).count
    }

    private var averageMoodLabel: String {
        guard sortedEntries.isEmpty == false else { return "-" }
        let total = sortedEntries.map(\.mood.score).reduce(0, +)
        let average = Double(total) / Double(sortedEntries.count)
        return String(format: "%.1f", average)
    }

    private var themeCounts: [(name: String, count: Int)] {
        let themes = appModel.journalEntries.flatMap(\.themes)
        var counts: [String: Int] = [:]
        for theme in themes {
            counts[theme, default: 0] += 1
        }
        let mapped: [(name: String, count: Int)] = counts.map { key, value in
            (name: key, count: value)
        }
        return Array(mapped.sorted { $0.count > $1.count }.prefix(5))
    }

    private var moodCounts: [(name: String, count: Int)] {
        MoodLevel.allCases.map { mood in
            (name: mood.label, count: sortedEntries.filter { $0.mood == mood }.count)
        }
    }

    private var entryTypeCounts: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for entry in appModel.journalEntries {
            counts[entry.entryType.label, default: 0] += 1
        }
        return counts.map { (name: $0.key, count: $0.value) }
            .sorted { $0.name < $1.name }
    }

    private func moodColor(for label: String) -> Color {
        MoodLevel.allCases.first(where: { $0.label == label })?.companionColor ?? .white
    }

    private var selectedEntryForDate: JournalEntry? {
        guard let selectedMoodDate else { return nil }
        let cal = Calendar.current
        return filteredEntries.min(by: {
            abs($0.date.timeIntervalSince(selectedMoodDate)) < abs($1.date.timeIntervalSince(selectedMoodDate))
        }).flatMap { nearest in
            cal.isDate(nearest.date, equalTo: selectedMoodDate, toGranularity: .day) ? nearest : nil
        }
    }

    private func isSelectedMoodEntry(_ entry: JournalEntry) -> Bool {
        guard let selected = selectedEntryForDate else { return false }
        return entry.id == selected.id
    }

    private var selectedMoodCount: (name: String, count: Int)? {
        guard let selectedMoodAngle else { return nil }
        return resolveAngleSelection(selectedMoodAngle, in: moodCounts.filter { $0.count > 0 })
    }

    private var selectedEntryTypeCount: (name: String, count: Int)? {
        guard let selectedEntryTypeAngle else { return nil }
        return resolveAngleSelection(selectedEntryTypeAngle, in: entryTypeCounts)
    }

    private func resolveAngleSelection(_ angle: Double, in values: [(name: String, count: Int)]) -> (name: String, count: Int)? {
        guard values.isEmpty == false else { return nil }
        let target = angle
        var running = 0.0
        for value in values {
            running += Double(value.count)
            if target <= running { return value }
        }
        return values.last
    }

    private func moodTooltip(for entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.date.formatted(.dateTime.month(.abbreviated).day()))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(entry.mood.label) · \(entry.mood.score)/5")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 0.5)
        }
    }

    private func donutTooltip(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 0.5)
        }
    }

    private func tooltipPosition(preferred: CGPoint, frame: CGRect, tooltipSize: CGSize, margin: CGFloat) -> CGPoint {
        let halfW = tooltipSize.width / 2
        let halfH = tooltipSize.height / 2
        let minX = frame.minX + halfW + margin
        let maxX = frame.maxX - halfW - margin
        let minY = frame.minY + halfH + margin
        let maxY = frame.maxY - halfH - margin

        return CGPoint(
            x: min(max(preferred.x, minX), maxX),
            y: min(max(preferred.y, minY), maxY)
        )
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? startOfDay(for: date)
    }
}

#Preview {
    InsightsView()
        .environmentObject(AppViewModel())
}
