import Charts
import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var router: AppRouter
    @State private var selection: InsightTab = .feed

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 1)
                        .id("insights-top")
                    CompanionTabHeader(title: "Insights", state: .checkIn, tint: appModel.journalCompanionTint)

                    Picker("Insights view", selection: $selection) {
                        ForEach(InsightTab.allCases) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.page)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    switch selection {
                    case .feed:
                        InsightFeedView()
                    case .weekly:
                        WeeklyReviewContainerView()
                    case .analytics:
                        AnalyticsView()
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
            output.append(.init(title: "Next experiment", subtitle: experiment, symbol: "checkmark.seal", tint: .orange, kind: "Action"))
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
    let review: WeeklyReview
    var embedded = false

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
                                "Premium adds baseline comparison, goal feedback, and a 7-day experiment.",
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
                Text("Top patterns this week")
                    .font(.subheadline.weight(.semibold))
                ForEach(review.patterns, id: \.self) { pattern in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "sparkle")
                            .font(.caption)
                        Text(pattern)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 5)
                }
            }
            Divider().background(AppSurface.stroke.opacity(0.55))

            if appModel.isPremium {
                InsightSectionView(title: "Watch next", bodyText: review.risk, symbol: InsightType.risk.symbol)
                Divider().background(AppSurface.stroke.opacity(0.55))
            }
            if appModel.isPremium, review.patternShift.isEmpty == false {
                InsightSectionView(title: "What changed", bodyText: review.patternShift, symbol: "arrow.left.arrow.right")
                Divider().background(AppSurface.stroke.opacity(0.55))
            }
            if appModel.isPremium, let primaryLoop = review.primaryLoop, primaryLoop.isEmpty == false {
                InsightSectionView(title: "Primary loop", bodyText: primaryLoop, symbol: "point.3.connected.trianglepath.dotted")
                Divider().background(AppSurface.stroke.opacity(0.55))
            }
            if appModel.isPremium, let progressSignal = review.progressSignal, progressSignal.isEmpty == false {
                InsightSectionView(title: "Progress", bodyText: progressSignal, symbol: "arrow.up.right.circle")
                Divider().background(AppSurface.stroke.opacity(0.55))
            }
            if appModel.isPremium, review.goalFollowThrough.isEmpty == false {
                InsightSectionView(title: "How goals went", bodyText: review.goalFollowThrough, symbol: "flag.checkered")
                Divider().background(AppSurface.stroke.opacity(0.55))
            }
            if appModel.isPremium, let baselineComparison = review.baselineComparison, baselineComparison.isEmpty == false {
                InsightSectionView(title: "Baseline comparison", bodyText: baselineComparison, symbol: "chart.line.uptrend.xyaxis")
                Divider().background(AppSurface.stroke.opacity(0.55))
            }
            if appModel.isPremium, review.healthPatterns.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Health patterns")
                        .font(.subheadline.weight(.semibold))
                    ForEach(review.healthPatterns, id: \.self) { pattern in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: pattern.lowercased().contains("sleep") ? "moon" : "figure.walk")
                                .font(.caption)
                            Text(pattern)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Divider().background(AppSurface.stroke.opacity(0.55))
            }
            InsightSectionView(title: "Try this", bodyText: review.nextExperiment ?? review.suggestion, symbol: InsightType.suggestion.symbol)
            if appModel.isPremium, let suggestedTemplate = review.suggestedTemplate, suggestedTemplate.isEmpty == false {
                Divider().background(AppSurface.stroke.opacity(0.55))
                InsightSectionView(title: "Suggested template", bodyText: suggestedTemplate, symbol: "square.text.square")
            }
            if appModel.isPremium, let researchPrompt = review.researchPrompt, researchPrompt.isEmpty == false {
                Divider().background(AppSurface.stroke.opacity(0.55))
                InsightSectionView(title: "Learn more", bodyText: researchPrompt, symbol: "book")
            }
            if appModel.isPremium == false {
                ReferenceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Premium preview", systemImage: "lock.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Pattern shifts week-to-week")
                            .font(.subheadline.weight(.semibold))
                            .redacted(reason: .placeholder)
                        Text("Goal follow-through summary")
                            .font(.subheadline.weight(.semibold))
                            .redacted(reason: .placeholder)
                        Text("Unlock baseline comparison, next experiments, and a richer weekly pattern report.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(appModel.isPremium ? "Weekly review" : "Weekly insight")
        .navigationBarTitleDisplayMode(.inline)
    }
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
                            Text(review.strongestPattern)
                                .font(.subheadline)
                            Text(review.progress)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Try next: \(review.nextExperiment)")
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

#Preview {
    InsightsView()
        .environmentObject(AppViewModel())
}
