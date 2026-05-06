import SwiftUI

struct DailyReviewView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    let review: DailyReview
    var embedded = false
    @State private var showHeader = false
    @State private var showSummary = false
    @State private var showReviewSection = false
    @State private var showSuggestedSection = false
    @State private var supportExpanded = false

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

    private var primaryHeadline: String {
        let candidates = [
            currentReview.suggestedGoalTitle,
            currentReview.insight.reframe,
            currentReview.insight.pattern,
            currentReview.summary
        ]

        for candidate in candidates {
            let cleaned = cleaned(candidate)
            if cleaned.isEmpty == false {
                return cleaned
            }
        }
        return "A clearer next step is starting to show up."
    }

    private var supportingRead: String {
        let candidates = [
            currentReview.insight.pattern,
            currentReview.insight.emotionalRead,
            currentReview.summary
        ]

        for candidate in candidates {
            let cleaned = cleaned(candidate)
            if cleaned.isEmpty == false, cleaned != primaryHeadline {
                return cleaned
            }
        }
        return ""
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                VStack(spacing: 14) {
                    HStack(alignment: .center, spacing: 12) {
                        Text(currentReview.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if embedded == false {
                            Button("Done") { dismiss() }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                        }
                    }

                    AICircleView(
                        state: appModel.companionCircleState,
                        size: 104,
                        strokeWidth: 3.1,
                        tint: appModel.journalCompanionTint,
                        personality: appModel.companionPersonality
                    )
                }
                .padding(.top, -10)
                .padding(.bottom, 4)
                .opacity(showHeader ? 1 : 0)
                .offset(y: showHeader ? 0 : 12)

                Text(primaryHeadline)
                    .font(.largeTitle.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 2)
                    .opacity(showSummary ? 1 : 0)
                    .offset(y: showSummary ? 0 : 10)

                VStack(alignment: .leading, spacing: 14) {
                    if supportingRead.isEmpty == false {
                        reviewCard(
                            title: "What this points to",
                            body: supportingRead,
                            symbol: InsightType.pattern.symbol
                        )
                    }

                    reviewCard(
                        title: "Try next",
                        body: currentReview.insight.action,
                        symbol: InsightType.action.symbol,
                        emphasized: true
                    )

                    if appModel.isPremium == false {
                        Button {
                            router.presentPaywall(.dailyReview)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "lock.fill")
                                    .font(.caption.weight(.bold))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Unlock deeper daily AI reviews")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Longer context, evidence strength, and a sharper next step.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(14)
                            .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppSurface.stroke, lineWidth: 0.5)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if appModel.isPremium, currentReview.evidenceStrength.isEmpty == false {
                        reviewCard(
                            title: "Why this seems likely",
                            body: currentReview.evidenceStrength,
                            symbol: "dial.medium"
                        )
                    }
                    if hasSupportInfo {
                        supportInfoDisclosure
                    }
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
                            feedbackControls(for: acceptedGoal)
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

                                Button {} label: {
                                    Text("Skip for now")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 12)
                                        .frame(height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
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

    private func feedbackControls(for goal: ReflectionGoal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Did this help?")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                feedbackButton("Helped", feedback: "helped", goal: goal, symbol: "checkmark.circle")
                feedbackButton("Didn't", feedback: "didnt_help", goal: goal, symbol: "xmark.circle")
                feedbackButton("Skipped", feedback: "skipped", goal: goal, symbol: "forward.circle")
            }
        }
        .padding(.top, 6)
    }

    private func feedbackButton(_ title: String, feedback: String, goal: ReflectionGoal, symbol: String) -> some View {
        let selected = goal.feedback == feedback
        return Button {
            appModel.setGoalFeedback(goal, feedback: feedback)
        } label: {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .frame(height: 34)
                .foregroundStyle(selected ? Color(.systemBackground) : .primary)
                .background(selected ? appModel.companionTint : AppSurface.fill, in: Capsule())
                .overlay {
                    Capsule().stroke(selected ? appModel.companionTint : AppSurface.stroke, lineWidth: 0.5)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func reviewCard(title: String, body: String, symbol: String, emphasized: Bool = false) -> some View {
        let cleanedBody = cleaned(body)
        guard cleanedBody.isEmpty == false else { return AnyView(EmptyView()) }

        return AnyView(
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                    .frame(width: 18)
                    .foregroundStyle(appModel.companionTint)
                Text(title)
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }
            Text(cleanedBody)
                .font(emphasized ? .title3.weight(.semibold) : .body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        )
    }

    private var hasSupportInfo: Bool {
        cleaned(currentReview.supportInfoTitle).isEmpty == false ||
            cleaned(currentReview.supportInfoBody).isEmpty == false ||
            supportSteps.isEmpty == false
    }

    private var supportSteps: [String] {
        (currentReview.supportSteps ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .prefix(3)
            .map { $0 }
    }

    private var supportInfoDisclosure: some View {
        DisclosureGroup(isExpanded: $supportExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                let body = cleaned(currentReview.supportInfoBody)
                if body.isEmpty == false {
                    Text(body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if supportSteps.isEmpty == false {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(supportSteps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color(.systemBackground))
                                    .frame(width: 22, height: 22)
                                    .background(appModel.companionTint, in: Circle())
                                Text(step)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "book.closed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appModel.companionTint)
                Text(cleaned(currentReview.supportInfoTitle).isEmpty ? "What could help" : cleaned(currentReview.supportInfoTitle))
                    .font(.subheadline.weight(.semibold))
            }
        }
        .tint(.secondary)
    }

    private func cleaned(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
