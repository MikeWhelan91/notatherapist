import SwiftUI

struct DailyReviewView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let review: DailyReview
    var embedded = false

    private var currentReview: DailyReview {
        appModel.dailyReview(on: review.date) ?? review
    }

    private var acceptedGoal: ReflectionGoal? {
        guard let goalID = currentReview.acceptedGoalID else { return nil }
        return appModel.reflectionGoals.first { $0.id == goalID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                HStack(spacing: 14) {
                    AICircleView(state: .responding, size: 72, strokeWidth: 2.8)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily review")
                            .font(.headline)
                        Text(currentReview.date.formatted(date: .complete, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(reviewSourceLabel)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                ReferenceCard {
                    Text(currentReview.summary)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "Review")
                    VStack(spacing: 10) {
                        ReferenceCard {
                            InsightSectionView(title: "What stood out", bodyText: currentReview.insight.emotionalRead, symbol: "sparkle.magnifyingglass")
                        }
                        ReferenceCard {
                            InsightSectionView(title: "What came up most", bodyText: currentReview.insight.pattern, symbol: InsightType.pattern.symbol)
                        }
                        ReferenceCard {
                            InsightSectionView(title: "One useful next step", bodyText: currentReview.insight.action, symbol: InsightType.action.symbol)
                        }
                    }
                }

                ReferenceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Suggested next step")
                            .font(.subheadline.weight(.semibold))
                        if currentReview.suggestedGoalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("No clear next step was suggested yet. Review again after another entry.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentReview.suggestedGoalTitle)
                                    .font(.body.weight(.semibold))
                                Text(currentReview.suggestedGoalReason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let acceptedGoal {
                                Label("\(acceptedGoal.title) was saved in Next steps.", systemImage: "checkmark.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            } else {
                                HStack(spacing: 10) {
                                    Button {
                                        withAnimation(.snappy(duration: 0.22)) {
                                            _ = appModel.acceptGoal(from: currentReview)
                                        }
                                    } label: {
                                        Label("Save next step", systemImage: "plus")
                                    }
                                    .buttonStyle(PrimaryCapsuleButtonStyle())

                                    Button("Skip for now") {}
                                        .buttonStyle(.plain)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(AppSpacing.page)
            .padding(.bottom, embedded ? 12 : 240)
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: embedded ? 0 : 10) }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if embedded == false {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var reviewSourceLabel: String {
        switch currentReview.source {
        case "openai":
            "AI daily review"
        case "fallback":
            "Local review"
        default:
            appModel.planTier.dailyReviewLabel
        }
    }
}

#Preview {
    NavigationStack {
        if let review = MockAIInsightService().dailyReview(for: Date(), entries: MockData.entries) {
            DailyReviewView(review: review)
                .environmentObject(AppViewModel(seedWithMockData: true))
        }
    }
}
