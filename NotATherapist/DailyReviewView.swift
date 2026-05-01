import SwiftUI

struct DailyReviewView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let review: DailyReview
    var embedded = false
    @State private var companionState: AICircleState = .thinking
    @State private var showHeader = false
    @State private var showSummary = false
    @State private var showReviewSection = false
    @State private var showSuggestedSection = false

    private var currentReview: DailyReview {
        appModel.dailyReview(on: review.date) ?? review
    }

    private var acceptedGoal: ReflectionGoal? {
        guard let goalID = currentReview.acceptedGoalID else { return nil }
        return appModel.reflectionGoals.first { $0.id == goalID }
    }

    private var bottomContentInset: CGFloat {
        embedded ? 12 : 180
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                VStack(spacing: 10) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Daily review")
                                .font(.headline)
                                .foregroundStyle(appModel.companionTint)
                            Text(currentReview.date.formatted(date: .complete, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(reviewSourceLabel)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        if embedded == false {
                            Button("Done") { dismiss() }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                        }
                    }

                    AICircleView(state: companionState, size: 94, strokeWidth: 3.1, tint: appModel.companionTint)
                }
                .padding(.top, -10)
                .padding(.bottom, 4)
                .opacity(showHeader ? 1 : 0)
                .offset(y: showHeader ? 0 : 12)

                Text(currentReview.summary)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 2)
                    .opacity(showSummary ? 1 : 0)
                    .offset(y: showSummary ? 0 : 10)

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "Review")
                        .foregroundStyle(appModel.companionTint)
                    VStack(spacing: 12) {
                        reviewBlock(title: "What stood out", body: currentReview.insight.emotionalRead, symbol: "sparkle.magnifyingglass")
                        Divider().background(AppSurface.stroke.opacity(0.55))
                        reviewBlock(title: "What came up most", body: currentReview.insight.pattern, symbol: InsightType.pattern.symbol)
                        Divider().background(AppSurface.stroke.opacity(0.55))
                        reviewBlock(title: "One useful next step", body: currentReview.insight.action, symbol: InsightType.action.symbol)
                        if appModel.isPremium, currentReview.evidenceStrength.isEmpty == false {
                            Divider().background(AppSurface.stroke.opacity(0.55))
                            reviewBlock(title: "Evidence strength", body: currentReview.evidenceStrength, symbol: "dial.medium")
                        }
                    }
                    .padding(.top, 2)
                }
                .opacity(showReviewSection ? 1 : 0)
                .offset(y: showReviewSection ? 0 : 10)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "flag")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(appModel.companionTint)
                        Text("Suggested next step")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(appModel.companionTint)
                    }
                    if currentReview.suggestedGoalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("No clear next step was suggested yet. Review again after another entry.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentReview.suggestedGoalTitle)
                                .font(.title3.weight(.semibold))
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
                .padding(.top, 2)
                .opacity(showSuggestedSection ? 1 : 0)
                .offset(y: showSuggestedSection ? 0 : 10)
            }
            .padding(AppSpacing.page)
            .padding(.bottom, bottomContentInset)
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: embedded ? 0 : 26) }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            guard showHeader == false else { return }
            Task {
                withAnimation(.spring(duration: 0.34, bounce: 0.12)) {
                    showHeader = true
                }
                try? await Task.sleep(for: .milliseconds(120))
                companionState = .responding
                withAnimation(.easeOut(duration: 0.28)) {
                    showSummary = true
                }
                try? await Task.sleep(for: .milliseconds(110))
                withAnimation(.easeOut(duration: 0.28)) {
                    showReviewSection = true
                }
                try? await Task.sleep(for: .milliseconds(110))
                withAnimation(.easeOut(duration: 0.28)) {
                    showSuggestedSection = true
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

    private func reviewBlock(title: String, body: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                    .frame(width: 18)
                    .foregroundStyle(appModel.companionTint)
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(appModel.companionTint)
            }
            Text(body)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
