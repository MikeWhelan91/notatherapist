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
        case .feed: "Feed"
        case .weekly: "Weekly Review"
        case .analytics: "Analytics"
        }
    }
}

private struct InsightFeedView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        ScrollView {
            if appModel.insights.isEmpty {
                ContentUnavailableView(
                    "No insights yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Review a day after writing. Insights will appear here.")
                )
                .padding(.top, 80)
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    insightSection("Recent insights", filter: { $0.category == "Recent" })
                    insightSection("Keep in mind", filter: { $0.category == "Patterns" })
                    insightSection("Suggestions", filter: { $0.category == "Suggestions" })
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
                                        Text(insight.body)
                                            .font(.subheadline)
                                            .lineLimit(2)
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
                    description: Text("A review appears after a few days or several entries.")
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
    let review: WeeklyReview
    var embedded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                AICircleView(state: .checkIn, size: 48, strokeWidth: 2.2)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Weekly review")
                        .font(.headline)
                    Text(review.dateRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ReferenceCard {
                VStack(alignment: .leading, spacing: 0) {
                Text("Top patterns")
                    .font(.subheadline.weight(.semibold))
                    .padding(.bottom, 6)
                ForEach(review.patterns, id: \.self) { pattern in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "sparkle")
                            .font(.caption)
                        Text(pattern)
                            .font(.body)
                    }
                    .padding(.vertical, 5)
                }
                }
            }

            ReferenceCard {
                InsightSectionView(title: "Potential risk", bodyText: review.risk, symbol: InsightType.risk.symbol)
            }
            if review.healthPatterns.isEmpty == false {
                ReferenceCard {
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
                }
            }
            ReferenceCard {
                InsightSectionView(title: "Suggestion", bodyText: review.suggestion, symbol: InsightType.suggestion.symbol)
            }
        }
        .navigationTitle("Weekly review")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AnalyticsView: View {
    @EnvironmentObject private var appModel: AppViewModel

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
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "Mood trend")
                    ReferenceCard {
                Chart(sortedEntries) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Mood", entry.mood.score)
                    )
                    PointMark(
                        x: .value("Date", entry.date),
                        y: .value("Mood", entry.mood.score)
                    )
                }
                .chartYScale(domain: 1...5)
                .chartXAxis(.hidden)
                .frame(height: 150)
                    }
                }

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
            .padding(AppSpacing.page)
            }
        }
        .safeAreaPadding(.bottom, 86)
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

    private var entryTypeCounts: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for entry in appModel.journalEntries {
            counts[entry.entryType.label, default: 0] += 1
        }
        return counts.map { (name: $0.key, count: $0.value) }
            .sorted { $0.name < $1.name }
    }
}

#Preview {
    InsightsView()
        .environmentObject(AppViewModel())
}
