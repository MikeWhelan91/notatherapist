import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var page = 0
    @State private var preferredName = ""
    @State private var ageRange = ""
    @State private var focusAreas: Set<String> = []
    @State private var selectedGoal = ""
    @State private var triedTherapy: Bool?
    @State private var emotionAwarenessHard: Bool?
    @State private var personalStory = ""
    @State private var streakGoal = 3
    @State private var checkInTime = "Evening"

    @State private var assessmentIndex = 0
    @State private var assessmentAnswers = Array<Int?>(repeating: nil, count: OnboardingAssessment.items.count)
    @State private var selectedMood: MoodLevel = .okay
    @State private var firstCheckInType: EntryType = .reflection
    @State private var firstCheckInBody = ""

    @State private var isGeneratingFirstCheckIn = false
    @State private var firstCheckInReview: DailyReview?
    @State private var firstCheckInErrorMessage = ""
    @State private var firstCheckInUsedFallback = false
    @State private var firstCheckInGenerated = false
    @State private var firstCheckInEntryCreated = false

    @State private var scoreReveal = false
    @State private var isRequestingNotificationPermission = false
    @FocusState private var focusedField: OnboardingField?

    private let pageCount = 16

    private let introPageIndex = 0
    private let goalsPageIndex = 1
    private let reasonPageIndex = 2
    private let therapyPageIndex = 3
    private let emotionPageIndex = 4
    private let assessmentPageIndex = 5
    private let scoreLoadingPageIndex = 6
    private let scoreSummaryPageIndex = 7
    private let scoreTrendPageIndex = 8
    private let planPageIndex = 9
    private let streakPageIndex = 10
    private let reminderPageIndex = 11
    private let storyPageIndex = 12
    private let firstCheckInPageIndex = 13
    private let firstReflectionPageIndex = 14
    private let completionPageIndex = 15

    var body: some View {
        VStack(spacing: 0) {
            progress
                .padding(.horizontal, AppSpacing.page)
                .padding(.top, 12)

            circleHeader
                .padding(.top, 30)
                .padding(.bottom, 18)

            TabView(selection: $page) {
                introPage.tag(introPageIndex)
                goalsPage.tag(goalsPageIndex)
                reasonPage.tag(reasonPageIndex)
                therapyPage.tag(therapyPageIndex)
                emotionPage.tag(emotionPageIndex)
                assessmentPage.tag(assessmentPageIndex)
                scoreLoadingPage.tag(scoreLoadingPageIndex)
                scoreSummaryPage.tag(scoreSummaryPageIndex)
                scoreTrendPage.tag(scoreTrendPageIndex)
                planPage.tag(planPageIndex)
                streakPage.tag(streakPageIndex)
                reminderPage.tag(reminderPageIndex)
                storyPage.tag(storyPageIndex)
                firstCheckInPage.tag(firstCheckInPageIndex)
                firstReflectionPage.tag(firstReflectionPageIndex)
                completionPage.tag(completionPageIndex)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.interactiveSpring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.18), value: page)
            .sensoryFeedback(.selection, trigger: page)

            if shouldShowBottomControls {
                controls
                    .padding(.horizontal, AppSpacing.page)
                    .padding(.bottom, 24)
            }
        }
        .background(onboardingBackground)
        .fontDesign(.rounded)
        .onTapGesture { focusedField = nil }
        .onChange(of: page) { oldPage, newPage in
            focusedField = nil
            enforcePageRules(from: oldPage, to: newPage)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
    }

    private var onboardingBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemGray6).opacity(0.75),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.primary.opacity(0.05), Color.clear],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index <= page ? Color.primary : Color(.separator).opacity(0.35))
                    .frame(height: 3)
            }
        }
        .opacity(page == 0 ? 0 : 1)
    }

    private var circleHeader: some View {
        AICircleView(
            state: circleState,
            size: page == firstReflectionPageIndex ? 132 : 104,
            strokeWidth: 3.4,
            motionStyle: .continuous
        )
    }

    private var circleState: AICircleState {
        if page == assessmentPageIndex { return .attentive }
        if page == firstCheckInPageIndex { return .listening }
        if page == firstReflectionPageIndex { return .responding }
        return .idle
    }

    private var shouldShowBottomControls: Bool {
        if page == assessmentPageIndex || page == firstCheckInPageIndex || page == firstReflectionPageIndex { return false }
        return focusedField == nil
    }

    private var shouldShowBackButton: Bool {
        if page == introPageIndex { return false }
        if page == scoreLoadingPageIndex { return false }
        return true
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if shouldShowBackButton {
                Button {
                    focusedField = nil
                    withAnimation { page -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                        .frame(width: 56, height: 56)
                }
                .foregroundStyle(.primary)
                .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppSurface.stroke, lineWidth: 0.5)
                }
                .buttonStyle(.plain)
            }

            Button {
                focusedField = nil
                Task { await continueTapped() }
            } label: {
                Text(continueTitle)
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .foregroundStyle(Color(.systemBackground))
            .background(Color.primary.opacity(canContinue ? 1 : 0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .buttonStyle(.plain)
            .disabled(!canContinue || isRequestingNotificationPermission)
        }
    }

    private var continueTitle: String {
        if isRequestingNotificationPermission { return "Connecting" }
        return page == completionPageIndex ? "Start using Anchor" : "Continue"
    }

    private var canContinue: Bool {
        switch page {
        case goalsPageIndex:
            return !focusAreas.isEmpty
        case reasonPageIndex:
            return !selectedGoal.isEmpty
        case therapyPageIndex:
            return triedTherapy != nil
        case emotionPageIndex:
            return emotionAwarenessHard != nil
        case reminderPageIndex:
            return !checkInTime.isEmpty
        default:
            return true
        }
    }

    private var introPage: some View {
        OnboardingQuestionPage(
            title: "Begin your journey",
            subtitle: "A short setup to personalize your check-ins and weekly guidance."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                singleRow("Guided daily check-ins", symbol: "sparkles")
                singleRow("Weekly AI review in your tone", symbol: "brain")
                singleRow("Plans based on your answers", symbol: "list.bullet.rectangle")
                TextField("Name (optional)", text: $preferredName)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .name)
                    .font(.subheadline.weight(.semibold))
                    .padding(14)
                    .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppSurface.stroke, lineWidth: 0.5)
                    }
                Menu {
                    ForEach(OnboardingDemographics.ageRanges, id: \.self) { range in
                        Button(range) { ageRange = range }
                    }
                } label: {
                    HStack {
                        Text(ageRange.isEmpty ? "Age range (optional)" : ageRange)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ageRange.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppSurface.stroke, lineWidth: 0.5)
                    }
                }
                Text("Your age range helps tailor examples and pacing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var goalsPage: some View {
        OnboardingQuestionPage(
            title: "What brings you here?",
            subtitle: "Pick your top focus areas."
        ) {
            VStack(spacing: 10) {
                focusRow("Relieve anxiety", "wind")
                focusRow("Boost mood", "sun.max")
                focusRow("Sleep better", "moon")
                focusRow("Improve relationships", "person.2")
                focusRow("Support personal growth", "figure.walk")
                focusRow("Reduce overthinking", "bubble.left.and.text.bubble.right")
            }
        }
    }

    private var reasonPage: some View {
        OnboardingQuestionPage(
            title: "I want to...",
            subtitle: "Choose one main goal to start."
        ) {
            VStack(spacing: 10) {
                singleChoiceRow("Improve relationships", "person.2", selected: selectedGoal == "Improve relationships") { selectedGoal = "Improve relationships" }
                singleChoiceRow("Support personal growth", "figure.walk", selected: selectedGoal == "Support personal growth") { selectedGoal = "Support personal growth" }
                singleChoiceRow("Relieve anxiety", "wind", selected: selectedGoal == "Relieve anxiety") { selectedGoal = "Relieve anxiety" }
                singleChoiceRow("Boost mood", "sun.max", selected: selectedGoal == "Boost mood") { selectedGoal = "Boost mood" }
                singleChoiceRow("Something else", "ellipsis.circle", selected: selectedGoal == "Something else") { selectedGoal = "Something else" }
            }
        }
    }

    private var therapyPage: some View {
        OnboardingQuestionPage(
            title: "Have you tried therapy before?",
            subtitle: "This helps us match the right pace."
        ) {
            binaryChoice(leftTitle: "No", rightTitle: "Yes", selection: $triedTherapy)
        }
    }

    private var emotionPage: some View {
        OnboardingQuestionPage(
            title: "Do you find it hard to identify emotions?",
            subtitle: "We can adapt prompts to make check-ins easier."
        ) {
            binaryChoice(leftTitle: "No", rightTitle: "Yes", selection: $emotionAwarenessHard)
        }
    }

    private var assessmentPage: some View {
        let q = OnboardingAssessment.items[assessmentIndex]
        return OnboardingQuestionPage(
            title: "Question \(assessmentIndex + 1)/\(OnboardingAssessment.items.count)",
            subtitle: q.prompt
        ) {
            VStack(spacing: 12) {
                ForEach(Array(OnboardingAssessment.optionTitles.enumerated()), id: \.offset) { index, title in
                    Button {
                        assessmentAnswers[assessmentIndex] = index
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if assessmentIndex < OnboardingAssessment.items.count - 1 {
                                assessmentIndex += 1
                            } else {
                                page = scoreLoadingPageIndex
                                startScoreReveal()
                            }
                        }
                    } label: {
                        Text(title)
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 62)
                    }
                    .foregroundStyle(.primary)
                    .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppSurface.stroke, lineWidth: 0.5)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var scoreLoadingPage: some View {
        OnboardingQuestionPage(
            title: "Reviewing your responses",
            subtitle: "Preparing your score and your starting plan."
        ) {
            VStack(spacing: 16) {
                ProgressView().tint(.primary)
                Text(scoreReveal ? "Ready" : "Calculating")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 80)
        }
    }

    private var scoreSummaryPage: some View {
        let breakdown = scoreBreakdown
        return OnboardingQuestionPage(
            title: "Your results",
            subtitle: "This is your baseline snapshot."
        ) {
            VStack(spacing: 14) {
                Text("\(totalScore)")
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                Text("Total score")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(scoreHeadline)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                scoreBar("Anxiety load", value: breakdown.anxiety)
                scoreBar("Mood load", value: breakdown.mood)
                scoreBar("Stress load", value: breakdown.stress)
            }
        }
    }

    private var scoreTrendPage: some View {
        OnboardingQuestionPage(
            title: "Your trend",
            subtitle: "Small daily check-ins can move this in the right direction."
        ) {
            VStack(spacing: 16) {
                scoreTrajectoryChart
                Text("Goal range: 0-2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var planPage: some View {
        OnboardingQuestionPage(
            title: "Your plan is ready",
            subtitle: planFocusTitle
        ) {
            VStack(spacing: 10) {
                planRow("Why this plan", body: planWhyLine)
                planRow("Daily Check-In", body: dailyPlanLine)
                planRow("Guided Journal Track", body: guidedTrackLine)
                planRow("Weekly AI Review", body: "Looks at this week next to your recent entries and context.")
                planRow("Companion Memory", body: "Keeps your preferences so guidance feels consistent.")
            }
        }
    }

    private var streakPage: some View {
        OnboardingQuestionPage(
            title: "Choose a streak goal",
            subtitle: "Small consistency beats intensity."
        ) {
            VStack(spacing: 10) {
                streakChoice(3)
                streakChoice(5)
                streakChoice(7)
                streakChoice(14)
            }
        }
    }

    private var reminderPage: some View {
        OnboardingQuestionPage(
            title: "When is a good time to check in?",
            subtitle: "We’ll set your reminder around this."
        ) {
            VStack(spacing: 10) {
                timeChoice("Morning", "sunrise")
                timeChoice("Afternoon", "sun.max")
                timeChoice("Evening", "sunset")
                timeChoice("Night", "moon")
            }
        }
    }

    private var storyPage: some View {
        OnboardingQuestionPage(
            title: "AI personalization",
            subtitle: "Optional. Share context so AI responses sound like they understand your life."
        ) {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $personalStory)
                    .scrollContentBackground(.hidden)
                    .focused($focusedField, equals: .story)
                    .font(.body)
                    .frame(minHeight: 210)
                    .padding(10)
                    .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppSurface.stroke, lineWidth: 0.5)
                    }
                Text("Example: ‘10 years of panic disorder, especially when driving. I want practical support and less fear.’")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(personalStory.count)/600")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(personalStory.count > 600 ? Color.red : Color.secondary)
            }
        }
    }

    private var firstCheckInPage: some View {
        OnboardingQuestionPage(
            title: "First check-in",
            subtitle: "How was your day?"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                MoodSelectorView(selectedMood: $selectedMood, size: 42, labelFont: .caption)

                HStack(spacing: 8) {
                    entryTypeChip(.quickThought, "Quick")
                    entryTypeChip(.reflection, "Reflection")
                    entryTypeChip(.rant, "Rant")
                    entryTypeChip(.win, "Win")
                }

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $firstCheckInBody)
                        .focused($focusedField, equals: .firstEntry)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(minHeight: 230)
                    if firstCheckInBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Write what happened, what you felt, and why it mattered.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                    }
                }
                .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppSurface.stroke, lineWidth: 0.5)
                }

                Button {
                    focusedField = nil
                    Task {
                        await generateFirstCheckIn()
                        if firstCheckInGenerated {
                            withAnimation(.easeInOut(duration: 0.3)) { page = firstReflectionPageIndex }
                        }
                    }
                } label: {
                    HStack {
                        if isGeneratingFirstCheckIn { ProgressView().tint(Color(.systemBackground)) }
                        Text(isGeneratingFirstCheckIn ? "Generating reflection" : "Get first reflection")
                            .font(.headline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
                .foregroundStyle(Color(.systemBackground))
                .background(Color.primary.opacity(firstCheckInCanGenerate ? 1 : 0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .buttonStyle(.plain)
                .disabled(!firstCheckInCanGenerate || isGeneratingFirstCheckIn)

                if !firstCheckInErrorMessage.isEmpty {
                    Text(firstCheckInErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var firstReflectionPage: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Your first reflection")
                    .font(.largeTitle.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .center)

                if let review = firstCheckInReview {
                    Text(reflectionLead(review))
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(review.insight.action)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No reflection yet. Go back and generate one.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(AppSpacing.page)
            .padding(.top, 8)
        }
    }

    private var completionPage: some View {
        OnboardingQuestionPage(
            title: "You’re ready",
            subtitle: "Your plan, preferences, and first check-in are saved."
        ) {
            VStack(spacing: 10) {
                singleRow("Main goal: \(selectedGoal.isEmpty ? "Support mental wellness" : selectedGoal)", symbol: "target")
                singleRow("Streak goal: \(streakGoal) days", symbol: "flame")
                singleRow("Reminder: \(checkInTime)", symbol: "clock")
                singleRow("AI memory and tone personalization enabled", symbol: "sparkles")
            }
        }
    }

    private var firstCheckInCanGenerate: Bool {
        !firstCheckInBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var totalScore: Int {
        assessmentAnswers.compactMap { $0 }.reduce(0, +)
    }

    private var scoreHeadline: String {
        switch totalScore {
        case 40...63:
            return "You reported frequent symptoms recently. We’ll keep your plan short and stabilizing."
        case 24...39:
            return "Your baseline shows mixed days. We’ll focus on consistency and clearer patterns."
        default:
            return "Your baseline is lighter overall. We’ll build momentum with practical routines."
        }
    }

    private var planFocusTitle: String {
        "Here is a starting plan based on your highest-load domains."
    }

    private var planWhyLine: String {
        let ranked = rankedDomains
        guard let first = ranked.first else {
            return "We start with consistency first, then adjust once more entries are available."
        }
        if ranked.count > 1 {
            return "\(first.name) came through strongest, with \(ranked[1].name) as a secondary focus."
        }
        return "\(first.name) came through strongest, so this week is tuned for that."
    }

    private var dailyPlanLine: String {
        switch dominantDomain {
        case "Anxiety":
            return "One short check-in daily focused on worry loops, body cues, and de-escalation."
        case "Mood":
            return "One daily check-in focused on energy, self-talk, and one doable action."
        default:
            return "One short check-in daily with calming prompts and low pressure."
        }
    }

    private var guidedTrackLine: String {
        switch dominantDomain {
        case "Anxiety":
            return "Grounding track with shorter exercises and worry-unhook prompts."
        case "Mood":
            return "Mood reset track with activation prompts and self-criticism interrupts."
        default:
            return "Stress load track with boundary, pacing, and recovery prompts."
        }
    }

    private var rankedDomains: [(name: String, value: Double)] {
        [
            (name: "Anxiety", value: scoreBreakdown.anxiety),
            (name: "Mood", value: scoreBreakdown.mood),
            (name: "Stress", value: scoreBreakdown.stress)
        ]
        .sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.name < rhs.name
            }
            return lhs.value > rhs.value
        }
    }

    private var dominantDomain: String {
        rankedDomains.first?.name ?? "Stress"
    }

    private var scoreBreakdown: (anxiety: Double, mood: Double, stress: Double) {
        func average(_ indices: [Int]) -> Double {
            let values = indices.compactMap { idx -> Int? in
                guard idx < assessmentAnswers.count else { return nil }
                return assessmentAnswers[idx]
            }
            guard !values.isEmpty else { return 0 }
            let max = Double(values.count * 3)
            let sum = Double(values.reduce(0, +))
            return max == 0 ? 0 : sum / max
        }
        return (
            average([0, 1, 2, 3, 4, 6]),
            average([7, 8, 9, 10, 11, 12, 13]),
            average([5, 14, 15, 16, 17, 18, 19, 20])
        )
    }

    private var scoreTrajectoryChart: some View {
        let points = trajectoryPoints
        return GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                Path { path in
                    for (idx, p) in points.enumerated() {
                        let x = CGFloat(idx) / CGFloat(max(points.count - 1, 1)) * w
                        let y = (1 - p) * h
                        if idx == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color.primary.opacity(0.85), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                ForEach(Array(points.enumerated()), id: \.offset) { idx, p in
                    let x = CGFloat(idx) / CGFloat(max(points.count - 1, 1)) * w
                    let y = (1 - p) * h
                    Circle()
                        .fill(idx == 0 ? Color.primary : Color.primary.opacity(0.65))
                        .frame(width: idx == 0 ? 12 : 9, height: idx == 0 ? 12 : 9)
                        .position(x: x, y: y)
                }
            }
        }
        .frame(height: 160)
        .padding(12)
        .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppSurface.stroke, lineWidth: 0.5)
        }
    }

    private var trajectoryPoints: [CGFloat] {
        let start = CGFloat(min(max(Double(totalScore) / 63.0, 0.08), 1))
        return [
            start,
            max(start * 0.68, 0.18),
            max(start * 0.48, 0.12),
            max(start * 0.35, 0.09),
            max(start * 0.24, 0.06),
            0.03
        ]
    }

    private func startScoreReveal() {
        scoreReveal = false
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            scoreReveal = true
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(.easeInOut(duration: 0.25)) { page = scoreSummaryPageIndex }
        }
    }

    private func continueTapped() async {
        if page == reminderPageIndex {
            isRequestingNotificationPermission = true
            await notificationService.setWeeklyReminderEnabled(true)
            isRequestingNotificationPermission = false
        }

        if page == completionPageIndex {
            finishOnboarding()
            return
        }

        withAnimation(.easeInOut(duration: 0.25)) { page += 1 }
    }

    private func enforcePageRules(from oldPage: Int, to newPage: Int) {
        guard newPage != oldPage else { return }
        if firstCheckInGenerated == false && newPage > firstCheckInPageIndex {
            withAnimation(.easeInOut(duration: 0.2)) {
                page = firstCheckInPageIndex
            }
            return
        }
        if newPage == completionPageIndex && firstCheckInGenerated == false {
            withAnimation(.easeInOut(duration: 0.2)) {
                page = firstCheckInPageIndex
            }
        }
    }

    private func finishOnboarding() {
        let trimmedName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStory = personalStory.trimmingCharacters(in: .whitespacesAndNewlines)
        let clippedStory = String(trimmedStory.prefix(600))
        let focus = Array(focusAreas).sorted()
        let labels = OnboardingAssessment.items.map(\.prompt)
        let answers = assessmentAnswers.map { min(max($0 ?? 0, 0), 3) }

        func domainSummary(name: String, indices: [Int]) -> OnboardingProfile.AssessmentDomainSummary {
            let domainAnswers = indices.compactMap { idx -> Int? in
                guard idx < answers.count else { return nil }
                return answers[idx]
            }
            let score = domainAnswers.reduce(0, +)
            let maxScore = domainAnswers.count * 3
            let ratio = maxScore == 0 ? 0 : Double(score) / Double(maxScore)
            let level: String
            if ratio >= 0.67 {
                level = "high"
            } else if ratio >= 0.34 {
                level = "moderate"
            } else {
                level = "low"
            }
            return .init(domain: name, score: score, maxScore: maxScore, level: level)
        }

        let assessment = OnboardingProfile.AssessmentProfile(
            instrument: "Anchor Intake 21",
            version: "1",
            totalScore: answers.reduce(0, +),
            maxScore: answers.count * 3,
            answers: answers,
            questionLabels: labels,
            domains: [
                domainSummary(name: "Anxiety", indices: [0, 1, 2, 3, 4, 6]),
                domainSummary(name: "Mood", indices: [7, 8, 9, 10, 11, 12, 13]),
                domainSummary(name: "Stress", indices: [5, 14, 15, 16, 17, 18, 19, 20])
            ],
            completedAt: Date()
        )

        let lifeContext = focus + [
            "Main goal: \(selectedGoal)",
            "Tried therapy before: \(triedTherapy == true ? "yes" : "no")",
            "Emotion awareness difficult: \(emotionAwarenessHard == true ? "yes" : "no")",
            "Streak goal: \(streakGoal) days",
            "Preferred check-in: \(checkInTime)"
        ]

        appModel.updateOnboardingProfile(
            preferredName: trimmedName,
            ageRange: ageRange,
            lifeContext: lifeContext,
            focusAreas: focus,
            reflectionGoal: selectedGoal.isEmpty ? "Build a consistent daily check-in habit" : selectedGoal,
            personalStory: clippedStory,
            assessment: assessment
        )

        hasCompletedOnboarding = true
    }

    private func generateFirstCheckIn() async {
        guard firstCheckInCanGenerate else { return }
        guard !isGeneratingFirstCheckIn else { return }
        isGeneratingFirstCheckIn = true
        firstCheckInErrorMessage = ""
        firstCheckInUsedFallback = false
        defer { isGeneratingFirstCheckIn = false }

        let text = firstCheckInBody.trimmingCharacters(in: .whitespacesAndNewlines)
        if firstCheckInEntryCreated == false {
            _ = appModel.addEntry(text: text, mood: selectedMood, type: firstCheckInType)
            firstCheckInEntryCreated = true
        }

        let review = await appModel.generateOnboardingFirstReflection(for: Date())
        firstCheckInReview = review
        firstCheckInGenerated = review != nil
        firstCheckInUsedFallback = review?.source != "openai"

        if review == nil {
            firstCheckInErrorMessage = "Could not generate reflection right now. Please try again."
        } else if firstCheckInUsedFallback {
            firstCheckInErrorMessage = "Using fallback reflection for now."
        }
    }

    private func reflectionLead(_ review: DailyReview) -> String {
        let name = appModel.onboardingProfile.preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let greetingName = name.isEmpty ? "" : ", \(name)"
        return "I hear you\(greetingName). \(review.insight.emotionalRead)"
    }

    private func singleRow(_ text: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 30, height: 30)
            Text(text)
                .font(.subheadline.weight(.semibold))
            Spacer()
        }
        .padding(14)
        .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppSurface.stroke, lineWidth: 0.5)
        }
    }

    private func focusRow(_ title: String, _ symbol: String) -> some View {
        let selected = focusAreas.contains(title)
        return Button {
            if selected { focusAreas.remove(title) } else { focusAreas.insert(title) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .frame(width: 30, height: 30)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if selected { Image(systemName: "checkmark") }
            }
            .padding(14)
            .foregroundStyle(selected ? Color(.systemBackground) : .primary)
            .background(selected ? Color.primary : AppSurface.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? Color.primary : AppSurface.stroke, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    private func singleChoiceRow(_ title: String, _ symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .frame(width: 30, height: 30)
                Text(title)
                    .font(.title3.weight(.semibold))
                Spacer()
                if selected { Image(systemName: "checkmark") }
            }
            .padding(.horizontal, 14)
            .frame(height: 58)
            .foregroundStyle(selected ? Color(.systemBackground) : .primary)
            .background(selected ? Color.primary : AppSurface.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? Color.primary : AppSurface.stroke, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    private func binaryChoice(leftTitle: String, rightTitle: String, selection: Binding<Bool?>) -> some View {
        HStack(spacing: 12) {
            Button {
                selection.wrappedValue = false
            } label: {
                Text(leftTitle)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .foregroundStyle((selection.wrappedValue == false) ? Color(.systemBackground) : .primary)
                    .background((selection.wrappedValue == false) ? Color.primary : AppSurface.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                selection.wrappedValue = true
            } label: {
                Text(rightTitle)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .foregroundStyle((selection.wrappedValue == true) ? Color(.systemBackground) : .primary)
                    .background((selection.wrappedValue == true) ? Color.primary : AppSurface.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func streakChoice(_ days: Int) -> some View {
        let selected = streakGoal == days
        return Button {
            streakGoal = days
        } label: {
            Text("\(days) day streak")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundStyle(selected ? Color(.systemBackground) : .primary)
                .background(selected ? Color.primary : AppSurface.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(selected ? Color.primary : AppSurface.stroke, lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
    }

    private func timeChoice(_ title: String, _ symbol: String) -> some View {
        let selected = checkInTime == title
        return Button {
            checkInTime = title
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .frame(width: 24)
                Text(title)
                    .font(.title3.weight(.semibold))
                Spacer()
                if selected { Image(systemName: "checkmark") }
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .foregroundStyle(selected ? Color(.systemBackground) : .primary)
            .background(selected ? Color.primary : AppSurface.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? Color.primary : AppSurface.stroke, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    private func entryTypeChip(_ type: EntryType, _ label: String) -> some View {
        let selected = firstCheckInType == type
        return Button {
            firstCheckInType = type
        } label: {
            Text(label)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(selected ? Color(.systemBackground) : .primary)
                .background(selected ? Color.primary : AppSurface.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(selected ? Color.primary : AppSurface.stroke, lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
    }

    private func scoreBar(_ title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int((value * 100).rounded()))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppSurface.fill)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary)
                        .frame(width: max(6, proxy.size.width * value))
                }
            }
            .frame(height: 12)
        }
        .padding(14)
        .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppSurface.stroke, lineWidth: 0.5)
        }
    }

    private func planRow(_ title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppSurface.stroke, lineWidth: 0.5)
        }
    }
}

private enum OnboardingField {
    case name
    case story
    case firstEntry
}

private enum OnboardingAssessment {
    struct Item {
        let prompt: String
    }

    static let optionTitles = ["Not at all", "Several days", "More than half the days", "Nearly every day"]

    static let items: [Item] = [
        .init(prompt: "Over the last two weeks, how often have you felt nervous, anxious, or on edge?"),
        .init(prompt: "Over the last two weeks, how often have you been unable to stop or control worrying?"),
        .init(prompt: "Over the last two weeks, how often have you worried excessively about different things?"),
        .init(prompt: "Over the last two weeks, how often have you had trouble relaxing once stress starts?"),
        .init(prompt: "Over the last two weeks, how often have you been so restless that sitting still felt difficult?"),
        .init(prompt: "Over the last two weeks, how often have you become easily annoyed or irritable?"),
        .init(prompt: "Over the last two weeks, how often have you felt afraid as if something bad might happen?"),
        .init(prompt: "Over the last two weeks, how often have you had little interest or pleasure in doing things?"),
        .init(prompt: "Over the last two weeks, how often have you felt down, depressed, or hopeless?"),
        .init(prompt: "Over the last two weeks, how often have you had trouble falling asleep, staying asleep, or slept too much?"),
        .init(prompt: "Over the last two weeks, how often have you felt tired or low in energy?"),
        .init(prompt: "Over the last two weeks, how often have appetite changes (too little or too much) affected you?"),
        .init(prompt: "Over the last two weeks, how often have you felt bad about yourself, or like you have let yourself or others down?"),
        .init(prompt: "Over the last two weeks, how often have you had trouble concentrating (for example while reading, working, or watching something)?"),
        .init(prompt: "Over the last two weeks, how often have routine demands felt overwhelming?"),
        .init(prompt: "Over the last two weeks, how often have you reacted more intensely than you wanted to?"),
        .init(prompt: "Over the last two weeks, how often have interruptions or delays triggered a strong stress response?"),
        .init(prompt: "Over the last two weeks, how often have you noticed stress tension in your body (jaw, neck, chest, stomach)?"),
        .init(prompt: "Over the last two weeks, how often have racing thoughts made it hard to switch off?"),
        .init(prompt: "Over the last two weeks, how often has stress spilled over into your relationships?"),
        .init(prompt: "Over the last two weeks, how often have anxiety or low mood made daily tasks harder to complete?")
    ]
}

private enum OnboardingDemographics {
    static let ageRanges = [
        "Under 18",
        "18-24",
        "25-34",
        "35-44",
        "45-54",
        "55-64",
        "65+",
        "Prefer not to say"
    ]
}

private struct OnboardingQuestionPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.largeTitle.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
            }
            .padding(AppSpacing.page)
            .padding(.top, 8)
            .opacity(isVisible ? 1 : 0.0)
            .offset(y: isVisible ? 0 : 14)
            .animation(.easeOut(duration: 0.24), value: isVisible)
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }

    @State private var isVisible = false
}
