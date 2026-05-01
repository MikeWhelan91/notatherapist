import Charts
import SwiftUI

struct InsightsView: View {
    @State private var selection: InsightTab = .feed

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
            .navigationTitle("Insights")
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
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    insightSection("Today & recent", filter: { $0.category == "Recent" })
                    insightSection("Patterns to watch", filter: { $0.category == "Patterns" })
                    insightSection("Try next", filter: { $0.category == "Suggestions" })
                    localSignalsSection
                }
                .padding(AppSpacing.page)
            }
        }
        .safeAreaPadding(.bottom, 86)
    }

    private func insightSection(_ title: String, filter: @escaping (Insight) -> Bool) -> some View {
        let filtered = appModel.insights.filter(filter).sorted { $0.date > $1.date }
        return VStack(alignment: .leading, spacing: 8) {
            if filtered.isEmpty == false {
                SectionLabel(title: title)
                VStack(spacing: 10) {
                    ForEach(filtered) { insight in
                        NavigationLink {
                            InsightDetailView(insight: insight)
                        } label: {
                            ReferenceCard {
                                HStack(spacing: 12) {
                                    Image(systemName: insight.type.symbol)
                                        .font(.body)
                                        .frame(width: 28)
                                        .foregroundStyle(.primary)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(insight.title)
                                            .font(.subheadline.weight(.semibold))
                                            .lineLimit(1)
                                        Text(insight.body)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(insight.date.compactDate)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
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
            }
        }
    }

    private var localSignalsSection: some View {
        let signals = appModel.localSignals
        return VStack(alignment: .leading, spacing: 8) {
            if signals.isEmpty == false {
                SectionLabel(title: "What I am noticing")
                VStack(spacing: 10) {
                    ForEach(signals) { insight in
                        ReferenceCard {
                            HStack(spacing: 12) {
                                Image(systemName: insight.type.symbol)
                                    .font(.body)
                                    .frame(width: 28)
                                    .foregroundStyle(.primary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(insight.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(insight.body)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
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
                    Text(appModel.isPremium ? "Weekly review" : "Weekly insight")
                        .font(.headline)
                    Text(review.dateRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(appModel.planTier.weeklyReviewLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Top patterns")
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
                InsightSectionView(title: "Watchpoint", bodyText: review.risk, symbol: InsightType.risk.symbol)
                Divider().background(AppSurface.stroke.opacity(0.55))
            }
            if appModel.isPremium, review.patternShift.isEmpty == false {
                InsightSectionView(title: "Pattern shift", bodyText: review.patternShift, symbol: "arrow.left.arrow.right")
                Divider().background(AppSurface.stroke.opacity(0.55))
            }
            if appModel.isPremium, review.goalFollowThrough.isEmpty == false {
                InsightSectionView(title: "Goal follow-through", bodyText: review.goalFollowThrough, symbol: "flag.checkered")
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
            InsightSectionView(title: "Suggestion", bodyText: review.suggestion, symbol: InsightType.suggestion.symbol)
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
                        Text("Unlock deeper weekly synthesis with Premium mode.")
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
    @EnvironmentObject private var appModel: AppViewModel
    @State private var showMoreAnalytics = false

    private var sortedEntries: [JournalEntry] {
        appModel.journalEntries.sorted { $0.date < $1.date }
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

    private var localSignalSummary: some View {
        let signals = appModel.localSignals
        return Group {
            if signals.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "What Anchor can see offline")
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
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Mood trend")
            ReferenceCard {
                Chart(sortedEntries) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Mood", entry.mood.score)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.white.opacity(0.75))
                    PointMark(
                        x: .value("Date", entry.date),
                        y: .value("Mood", entry.mood.score)
                    )
                    .foregroundStyle(entry.mood.companionColor)
                    .symbolSize(52)
                }
                .chartYScale(domain: 1...5)
                .chartXAxis(.hidden)
                .frame(height: 150)
            }
        }
    }

    private var checkInConsistencyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Check-in consistency")
            ReferenceCard {
                Chart(appModel.currentWeekDates, id: \.self) { date in
                    BarMark(
                        x: .value("Day", date.shortDay),
                        y: .value("Checked in", appModel.entries(on: date).isEmpty ? 0 : 1)
                    )
                    .foregroundStyle(Color.primary)
                }
                .chartYAxis(.hidden)
                .frame(height: 120)
            }
        }
    }

    private var moodDistributionChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Mood spread")
            ReferenceCard {
                Chart(moodCounts, id: \.name) { item in
                    BarMark(
                        x: .value("Mood", item.name),
                        y: .value("Entries", item.count)
                    )
                    .foregroundStyle(moodColor(for: item.name))
                }
                .chartYAxis(.hidden)
                .frame(height: 120)
            }
        }
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
                    .foregroundStyle(Color.primary)
                }
                .frame(height: 140)
            }
        }
    }

    private var entryTypeBreakdownChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Entry type breakdown")
            ReferenceCard {
                Chart(entryTypeCounts, id: \.name) { item in
                    BarMark(
                        x: .value("Type", item.name),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(Color.primary)
                }
                .frame(height: 130)
            }
        }
    }

    private var reviewCadenceChart: some View {
        Group {
            if appModel.dailyReviews.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "Review cadence")
                    ReferenceCard {
                        Chart(appModel.dailyReviews.sorted { $0.date < $1.date }) { review in
                            BarMark(
                                x: .value("Date", review.date.compactDate),
                                y: .value("Reviewed", 1)
                            )
                            .foregroundStyle(Color.primary)
                        }
                        .chartYAxis(.hidden)
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
                    SectionLabel(title: "Health context")
                    ReferenceCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Chart(entries) { entry in
                                if let sleep = entry.sleepHours {
                                    PointMark(
                                        x: .value("Sleep", sleep),
                                        y: .value("Mood", entry.mood.score)
                                    )
                                    .foregroundStyle(Color.primary)
                                }
                            }
                            .chartYScale(domain: 1...5)
                            .frame(height: 130)

                            Text("Sleep and steps stay quiet here. They only add context when there is enough data.")
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
}

#Preview {
    InsightsView()
        .environmentObject(AppViewModel())
}
