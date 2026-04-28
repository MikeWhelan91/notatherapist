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
                            InsightSectionView(title: "Theme", bodyText: currentReview.insight.pattern, symbol: InsightType.pattern.symbol)
                        }
                        ReferenceCard {
                            InsightSectionView(title: "One useful next step", bodyText: currentReview.insight.action, symbol: InsightType.action.symbol)
                        }
                    }
                }

                ReferenceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Carry this forward?")
                            .font(.subheadline.weight(.semibold))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentReview.suggestedGoalTitle)
                                .font(.body.weight(.semibold))
                            Text(currentReview.suggestedGoalReason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let acceptedGoal {
                            Label("\(acceptedGoal.title) is on Today.", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        } else {
                            Button {
                                withAnimation(.snappy(duration: 0.22)) {
                                    _ = appModel.acceptGoal(from: currentReview)
                                }
                            } label: {
                                Label("Add next step", systemImage: "plus")
                            }
                            .buttonStyle(PrimaryCapsuleButtonStyle())
                        }
                    }
                }
            }
            .padding(AppSpacing.page)
            .padding(.bottom, embedded ? 0 : 24)
        }
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
}

#Preview {
    NavigationStack {
        if let review = MockAIInsightService().dailyReview(for: Date(), entries: MockData.entries) {
            DailyReviewView(review: review)
                .environmentObject(AppViewModel(seedWithMockData: true))
        }
    }
}
