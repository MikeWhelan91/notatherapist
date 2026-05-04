import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var router: AppRouter
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
    @State private var therapyExperience = ""
    @State private var emotionAwarenessLevel = ""

    @State private var assessmentIndex = 0
    @State private var assessmentAnswers = Array<Int?>(repeating: nil, count: OnboardingAssessment.items.count)
    @State private var selectedMood: MoodLevel = .okay
    @State private var firstCheckInType: EntryType = .reflection
    @State private var firstCheckInBody = ""

    @State private var isGeneratingFirstCheckIn = false
    @State private var firstCheckInReview: DailyReview?
    @State private var firstCheckInErrorMessage = ""
    @State private var firstCheckInGenerated = false
    @State private var firstCheckInEntryCreated = false

    @State private var scoreReveal = false
    @State private var isRequestingNotificationPermission = false
    @State private var isConnectingHealth = false
    @State private var isAnimatingAssessment = false
    @State private var animatedAnxietyScore: Double = 0
    @State private var animatedMoodScore: Double = 0
    @State private var animatedStressScore: Double = 0
    @State private var animatedFunctioningScore: Double = 0
    @State private var animatedTotalScore: Double = 0
    @State private var scoreLineProgress: CGFloat = 0
    @State private var rangeLineProgress: CGFloat = 0
    @State private var planRevealCount = 0
    @State private var transientCircleState: AICircleState?
    @State private var circleSpinDegrees: Double = 0
    @State private var circleTransitionToken = 0
    @State private var lensFocusActive = false
    @State private var pageNudgeX: CGFloat = 0
    @State private var pageNudgeY: CGFloat = 0
    @State private var pageScale: CGFloat = 1
    @State private var onboardingConfettiTrigger = 0
    @State private var companionTrigger = 0
    @State private var onboardingStreakCelebrationMessage: String?
    @State private var onboardingStreakCelebrationPending = false
    @State private var isCompletingOnboarding = false
    @FocusState private var focusedField: OnboardingField?

    private let pageCount = 17

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
    private let healthPageIndex = 12
    private let storyPageIndex = 13
    private let firstCheckInPageIndex = 14
    private let firstReflectionPageIndex = 15
    private let completionPageIndex = 16

    var body: some View {
        VStack(spacing: 0) {
            stepCounter
                .padding(.horizontal, AppSpacing.page)
                .padding(.top, 10)

            circleHeader
                .padding(.top, 30)
                .padding(.bottom, 18)
                .opacity(isCompletingOnboarding ? 0 : 1)

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
                healthPage.tag(healthPageIndex)
                storyPage.tag(storyPageIndex)
                firstCheckInPage.tag(firstCheckInPageIndex)
                firstReflectionPage.tag(firstReflectionPageIndex)
                completionPage.tag(completionPageIndex)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.interactiveSpring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.18), value: page)
            .sensoryFeedback(.selection, trigger: page)
            .offset(x: pageNudgeX, y: pageNudgeY)
            .scaleEffect(pageScale)

            if shouldShowBottomControls {
                controls
                    .padding(.horizontal, AppSpacing.page)
                    .padding(.bottom, 24)
            }
        }
        .background(onboardingBackground)
        .fontDesign(.rounded)
        .onTapGesture { focusedField = nil }
        .onChange(of: preferredName) { _, value in
            guard page == introPageIndex else { return }
            if value.count % 3 == 0, value.isEmpty == false { reactCompanion(.typing) }
        }
        .onChange(of: personalStory) { _, value in
            guard page == storyPageIndex else { return }
            if value.count % 24 == 0, value.isEmpty == false { reactCompanion(.typing) }
        }
        .onChange(of: firstCheckInBody) { _, value in
            guard page == firstCheckInPageIndex else { return }
            if value.count % 18 == 0, value.isEmpty == false { reactCompanion(.typing) }
        }
        .onChange(of: page) { oldPage, newPage in
            focusedField = nil
            enforcePageRules(from: oldPage, to: newPage)
            triggerCircleTransition(from: oldPage, to: newPage)
            triggerPageAccentTransition(for: newPage)
        }
        .onChange(of: assessmentIndex) { oldIndex, newIndex in
            guard page == assessmentPageIndex, oldIndex != newIndex else { return }
            triggerCircleMicroTransitionForAssessment()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .overlay {
            ConfettiOverlayView(trigger: onboardingConfettiTrigger)
        }
        .task(id: page) {
            lensFocusActive = false
            while !Task.isCancelled {
                let wait = UInt64(Int.random(in: 3_600_000_000...5_800_000_000))
                try? await Task.sleep(nanoseconds: wait)
                guard page != firstCheckInPageIndex else { continue }
                guard page != scoreLoadingPageIndex else { continue }
                guard transientCircleState == nil else { continue }
                let nextState = randomAmbientCircleState(for: page)
                transientCircleState = nextState
                if Bool.random() {
                    lensFocusActive = true
                }
                let activeDuration = UInt64(Int.random(in: 1_600_000_000...2_700_000_000))
                try? await Task.sleep(nanoseconds: activeDuration)
                if Task.isCancelled { return }
                lensFocusActive = false
                transientCircleState = nil
            }
        }
    }

    private var onboardingBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.04, green: 0.08, blue: 0.14),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [AppTheme.accent.opacity(0.24), Color.clear],
                center: .topTrailing,
                startRadius: 18,
                endRadius: 420
            )
            RadialGradient(
                colors: [Color.white.opacity(0.08), Color.clear],
                center: .bottomLeading,
                startRadius: 24,
                endRadius: 380
            )
        }
        .ignoresSafeArea()
    }

    private var stepCounter: some View {
        HStack {
            Spacer()
            Text("\(displayStepIndex)/\(displayStepTotal)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var displayStepTotal: Int {
        pageCount - 1 + OnboardingAssessment.items.count
    }

    private var displayStepIndex: Int {
        if page < assessmentPageIndex {
            return page + 1
        }
        if page == assessmentPageIndex {
            return assessmentPageIndex + assessmentIndex + 1
        }
        return page + OnboardingAssessment.items.count
    }

    private var circleHeader: some View {
        AICircleView(
            state: displayedCircleState,
            size: circleSize,
            strokeWidth: 3.4,
            motionStyle: .continuous,
            tint: onboardingCompanionTint,
            lensFocusActive: lensFocusActive,
            personality: onboardingCompanionPersonality,
            trigger: companionTrigger,
            ringRotationDegrees: circleSpinDegrees
        )
    }

    private var onboardingCompanionPersonality: CompanionPersonality {
        switch page {
        case introPageIndex, completionPageIndex: .grounded
        case goalsPageIndex, reasonPageIndex, firstCheckInPageIndex: .calm
        case assessmentPageIndex: .analytic
        case scoreSummaryPageIndex, scoreTrendPageIndex: .calm
        case planPageIndex, firstReflectionPageIndex: .energetic
        default: .grounded
        }
    }

    private var onboardingCompanionTint: Color {
        if page < firstCheckInPageIndex {
            return .white
        }
        return selectedMood.companionColor
    }

    private var onboardingActionTint: Color {
        if page == firstCheckInPageIndex || page == firstReflectionPageIndex {
            return selectedMood.companionColor
        }
        return .white
    }

    private var circleSize: CGFloat {
        if page == introPageIndex { return 188 }
        if page == completionPageIndex { return 156 }
        if page == firstReflectionPageIndex { return 162 }
        if page == storyPageIndex { return 148 }
        return 138
    }

    private var displayedCircleState: AICircleState {
        transientCircleState ?? circleState
    }

    private func randomAmbientCircleState(for page: Int) -> AICircleState {
        let pool: [AICircleState]
        if page == scoreSummaryPageIndex || page == scoreTrendPageIndex || page == planPageIndex {
            pool = [.checkIn, .attentive, .responding, .listening]
        } else if page == assessmentPageIndex {
            pool = [.attentive, .checkIn, .listening]
        } else {
            pool = [.attentive, .listening, .checkIn]
        }
        return pool.randomElement() ?? .attentive
    }

    private var circleState: AICircleState {
        if page == introPageIndex { return .idle }
        if page == goalsPageIndex || page == reasonPageIndex { return .listening }
        if page == therapyPageIndex || page == emotionPageIndex { return .attentive }
        if page == assessmentPageIndex { return .attentive }
        if page == scoreSummaryPageIndex || page == scoreTrendPageIndex { return .attentive }
        if page == planPageIndex { return .responding }
        if page == firstCheckInPageIndex { return .listening }
        if page == firstReflectionPageIndex { return .responding }
        if page == completionPageIndex { return .checkIn }
        return .idle
    }

    private func triggerCircleTransition(from oldPage: Int, to newPage: Int) {
        guard oldPage != newPage else { return }
        companionTrigger += 1
        circleTransitionToken += 1
        let token = circleTransitionToken
        let start = circleSpinDegrees

        withAnimation(.easeInOut(duration: 0.24)) {
            circleSpinDegrees = start + 320
        }

        Task {
            try? await Task.sleep(nanoseconds: 240_000_000)
            guard token == circleTransitionToken else { return }
            withAnimation(.easeOut(duration: 0.32)) {
                circleSpinDegrees = start + 250
            }

            try? await Task.sleep(nanoseconds: 300_000_000)
            guard token == circleTransitionToken else { return }
            withAnimation(.interactiveSpring(response: 0.62, dampingFraction: 0.88, blendDuration: 0.2)) {
                circleSpinDegrees = start + 360
            }
        }

        transientCircleState = .responding
        Task {
            try? await Task.sleep(nanoseconds: 460_000_000)
            transientCircleState = nil
        }
    }

    private func triggerCircleMicroTransitionForAssessment() {
        companionTrigger += 1
        circleTransitionToken += 1
        let token = circleTransitionToken
        let start = circleSpinDegrees

        withAnimation(.easeInOut(duration: 0.2)) {
            circleSpinDegrees = start + 120
        }
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard token == circleTransitionToken else { return }
            withAnimation(.easeOut(duration: 0.26)) {
                circleSpinDegrees = start + 95
            }
            try? await Task.sleep(nanoseconds: 260_000_000)
            guard token == circleTransitionToken else { return }
            withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.88, blendDuration: 0.18)) {
                circleSpinDegrees = start + 140
            }
        }
    }

    private func triggerPageAccentTransition(for newPage: Int) {
        let phase = newPage % 4
        let x: CGFloat
        let y: CGFloat
        let scale: CGFloat
        let outDuration: Double
        let inDuration: Double

        switch phase {
        case 0:
            x = 10; y = 0; scale = 0.992; outDuration = 0.08; inDuration = 0.22
        case 1:
            x = -12; y = 2; scale = 0.994; outDuration = 0.09; inDuration = 0.24
        case 2:
            x = 0; y = 8; scale = 0.991; outDuration = 0.1; inDuration = 0.26
        default:
            x = 6; y = -4; scale = 0.993; outDuration = 0.09; inDuration = 0.23
        }

        withAnimation(.easeOut(duration: outDuration)) {
            pageNudgeX = x
            pageNudgeY = y
            pageScale = scale
        }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(outDuration * 1_000_000_000))
            withAnimation(.interactiveSpring(response: inDuration, dampingFraction: 0.86, blendDuration: 0.14)) {
                pageNudgeX = 0
                pageNudgeY = 0
                pageScale = 1
            }
        }
    }

    private func assessmentOptionSymbol(for index: Int) -> String {
        switch index {
        case 0: return "circle"
        case 1: return "circle.lefthalf.filled"
        case 2: return "circle.inset.filled"
        default: return "circle.fill"
        }
    }

    private var shouldShowBottomControls: Bool {
        if page == assessmentPageIndex || page == firstCheckInPageIndex { return false }
        if page == reasonPageIndex || page == therapyPageIndex || page == emotionPageIndex { return false }
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
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .foregroundStyle(.primary)
                .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppSurface.stroke, lineWidth: 0.5)
                }
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .buttonStyle(.plain)
            }

            Button {
                focusedField = nil
                reactCompanion(.responding, withLens: true)
                Task { await continueTapped() }
            } label: {
                Text(continueTitle)
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .foregroundStyle(Color(.systemBackground))
            .background(onboardingActionTint.opacity(canContinue ? 1 : 0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: onboardingActionTint.opacity(0.32), radius: 14, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .buttonStyle(.plain)
            .disabled(!canContinue || isRequestingNotificationPermission)
        }
    }

    private var continueTitle: String {
        if isRequestingNotificationPermission { return "Connecting" }
        return page == completionPageIndex ? "Start using Anchor" : "Continue"
    }

    private func pageAdvanceAnimation(from sourcePage: Int) -> Animation {
        switch sourcePage {
        case introPageIndex:
            return .interactiveSpring(response: 0.46, dampingFraction: 0.86, blendDuration: 0.16)
        case goalsPageIndex, reasonPageIndex, therapyPageIndex, emotionPageIndex:
            return .easeInOut(duration: 0.2)
        case assessmentPageIndex:
            return .interactiveSpring(response: 0.34, dampingFraction: 0.9, blendDuration: 0.12)
        case scoreSummaryPageIndex, scoreTrendPageIndex, planPageIndex:
            return .interactiveSpring(response: 0.5, dampingFraction: 0.82, blendDuration: 0.2)
        case storyPageIndex, firstReflectionPageIndex:
            return .easeInOut(duration: 0.28)
        default:
            return .easeInOut(duration: 0.24)
        }
    }

    private var canContinue: Bool {
        switch page {
        case goalsPageIndex:
            return !focusAreas.isEmpty
        case reasonPageIndex:
            return !selectedGoal.isEmpty
        case therapyPageIndex:
            return !therapyExperience.isEmpty
        case emotionPageIndex:
            return !emotionAwarenessLevel.isEmpty
        case reminderPageIndex:
            return !checkInTime.isEmpty
        default:
            return true
        }
    }

    private var introPage: some View {
        OnboardingQuestionPage(
            title: "Begin your journey",
            subtitle: "Tell your companion who you are, then we will tailor your plan.",
            motionStyle: .hero
        ) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Name (optional)", text: $preferredName)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .name)
                    .font(.subheadline.weight(.semibold))
                    .padding(14)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
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
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
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
            subtitle: "Pick all areas you want support with.",
            motionStyle: .form
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
            title: "What would feel like progress in 2 weeks?",
            subtitle: "Choose one clear outcome to aim for first.",
            motionStyle: .form
        ) {
            VStack(spacing: 10) {
                singleChoiceRow("Feel calmer in stressful moments", "circle", selected: selectedGoal == "Feel calmer in stressful moments") {
                    selectedGoal = "Feel calmer in stressful moments"
                    advanceAfterSingleChoice()
                }
                singleChoiceRow("Have more steady energy", "circle", selected: selectedGoal == "Have more steady energy") {
                    selectedGoal = "Have more steady energy"
                    advanceAfterSingleChoice()
                }
                singleChoiceRow("Stop overthinking spirals sooner", "circle", selected: selectedGoal == "Stop overthinking spirals sooner") {
                    selectedGoal = "Stop overthinking spirals sooner"
                    advanceAfterSingleChoice()
                }
                singleChoiceRow("Handle relationships with less reactivity", "circle", selected: selectedGoal == "Handle relationships with less reactivity") {
                    selectedGoal = "Handle relationships with less reactivity"
                    advanceAfterSingleChoice()
                }
                singleChoiceRow("Build a consistent reflection routine", "circle", selected: selectedGoal == "Build a consistent reflection routine") {
                    selectedGoal = "Build a consistent reflection routine"
                    advanceAfterSingleChoice()
                }
            }
        }
    }

    private var therapyPage: some View {
        OnboardingQuestionPage(
            title: "How familiar are you with therapy or counseling?",
            subtitle: "This helps us choose the right level of guidance.",
            motionStyle: .form
        ) {
            VStack(spacing: 10) {
                singleChoiceRow("Never tried", "circle", selected: therapyExperience == "Never tried") {
                    therapyExperience = "Never tried"
                    triedTherapy = false
                    advanceAfterSingleChoice()
                }
                singleChoiceRow("Tried briefly", "circle", selected: therapyExperience == "Tried briefly") {
                    therapyExperience = "Tried briefly"
                    triedTherapy = true
                    advanceAfterSingleChoice()
                }
                singleChoiceRow("Had regular sessions before", "circle", selected: therapyExperience == "Had regular sessions before") {
                    therapyExperience = "Had regular sessions before"
                    triedTherapy = true
                    advanceAfterSingleChoice()
                }
                singleChoiceRow("Currently in therapy", "circle", selected: therapyExperience == "Currently in therapy") {
                    therapyExperience = "Currently in therapy"
                    triedTherapy = true
                    advanceAfterSingleChoice()
                }
            }
        }
    }

    private var emotionPage: some View {
        OnboardingQuestionPage(
            title: "How often is it hard to identify what you are feeling?",
            subtitle: "We can tune prompt clarity and pacing to match this.",
            motionStyle: .form
        ) {
            VStack(spacing: 10) {
                singleChoiceRow("Rarely", "circle", selected: emotionAwarenessLevel == "Rarely") {
                    emotionAwarenessLevel = "Rarely"
                    emotionAwarenessHard = false
                    advanceAfterSingleChoice()
                }
                singleChoiceRow("Sometimes", "circle", selected: emotionAwarenessLevel == "Sometimes") {
                    emotionAwarenessLevel = "Sometimes"
                    emotionAwarenessHard = false
                    advanceAfterSingleChoice()
                }
                singleChoiceRow("Often", "circle", selected: emotionAwarenessLevel == "Often") {
                    emotionAwarenessLevel = "Often"
                    emotionAwarenessHard = true
                    advanceAfterSingleChoice()
                }
                singleChoiceRow("Almost always", "circle", selected: emotionAwarenessLevel == "Almost always") {
                    emotionAwarenessLevel = "Almost always"
                    emotionAwarenessHard = true
                    advanceAfterSingleChoice()
                }
            }
        }
    }

    private var assessmentPage: some View {
        TabView(selection: $assessmentIndex) {
            ForEach(Array(OnboardingAssessment.items.enumerated()), id: \.offset) { qIndex, item in
                OnboardingQuestionPage(
                    eyebrow: "Over the last 2 weeks",
                    title: item.prompt,
                    subtitle: "Choose the option that best matches your experience.",
                    motionStyle: .assessment
                ) {
                    VStack(spacing: 12) {
                        ForEach(Array(OnboardingAssessment.optionTitles.enumerated()), id: \.offset) { answerIndex, title in
                            Button {
                                Task { await selectAssessmentAnswer(answerIndex, for: qIndex) }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: assessmentOptionSymbol(for: answerIndex))
                                        .font(.body.weight(.semibold))
                                        .frame(width: 24)
                                    Text(title)
                                        .font(.headline.weight(.semibold))
                                    Spacer()
                                    if assessmentAnswers[qIndex] == answerIndex {
                                        Image(systemName: "checkmark")
                                            .font(.body.weight(.semibold))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 56)
                                .frame(maxWidth: .infinity)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .foregroundStyle(.primary)
                            .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(AppSurface.stroke, lineWidth: 0.5)
                                }
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .buttonStyle(.plain)
                            .disabled(isAnimatingAssessment)
                        }
                    }
                }
                .tag(qIndex)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.25), value: assessmentIndex)
        .sensoryFeedback(.selection, trigger: assessmentIndex)
    }

    private var scoreLoadingPage: some View {
        OnboardingQuestionPage(
            title: "Reviewing your responses",
            subtitle: "Preparing your score and your starting plan.",
            motionStyle: .results
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
            subtitle: "",
            motionStyle: .results
        ) {
            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Text("\(Int(animatedTotalScore.rounded()))")
                        .font(.system(size: 76, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("out of 63")
                        .font(.caption.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                .scaleEffect(scoreLineProgress > 0.35 ? 1 : 0.94)
                .opacity(scoreLineProgress > 0.08 ? 1 : 0)
                .animation(.smooth(duration: 0.45, extraBounce: 0.12), value: scoreLineProgress)

                animatedUnderline(progress: scoreLineProgress, tint: onboardingCompanionTint)
                    .frame(height: 22)
                    .padding(.horizontal, 34)

                Text(scoreHeadline)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .opacity(scoreLineProgress > 0.45 ? 1 : 0)
                    .offset(y: scoreLineProgress > 0.45 ? 0 : 10)

                Text("The companion mirrors recent signal intensity. It looks more active when the baseline is noisier, then settles as your check-ins, reviews, and follow-through become steadier.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 10)
                    .opacity(scoreLineProgress > 0.62 ? 1 : 0)
                    .offset(y: scoreLineProgress > 0.62 ? 0 : 8)

                VStack(spacing: 14) {
                    scoreSignalRow("Anxiety", value: animatedAnxietyScore, symbol: "waveform.path.ecg")
                    scoreSignalRow("Mood", value: animatedMoodScore, symbol: "circle.lefthalf.filled")
                    scoreSignalRow("Stress", value: animatedStressScore, symbol: "bolt")
                    scoreSignalRow("Functioning", value: animatedFunctioningScore, symbol: "figure.walk.motion")
                }
                .padding(.top, 4)

                Text("Lower scores mean fewer recent difficulties. This is a reflection baseline, not a diagnosis.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .opacity(scoreLineProgress > 0.8 ? 1 : 0)
            }
        }
        .task(id: page) {
            guard page == scoreSummaryPageIndex else { return }
            animatedTotalScore = 0
            animatedAnxietyScore = 0
            animatedMoodScore = 0
            animatedStressScore = 0
            animatedFunctioningScore = 0
            scoreLineProgress = 0

            withAnimation(.smooth(duration: 0.7, extraBounce: 0.08)) {
                animatedTotalScore = Double(totalScore)
                scoreLineProgress = 1
            }
            try? await Task.sleep(nanoseconds: 260_000_000)
            withAnimation(.easeOut(duration: 0.46)) {
                animatedAnxietyScore = breakdown.anxiety
            }
            try? await Task.sleep(nanoseconds: 170_000_000)
            withAnimation(.easeOut(duration: 0.46)) {
                animatedMoodScore = breakdown.mood
            }
            try? await Task.sleep(nanoseconds: 170_000_000)
            withAnimation(.easeOut(duration: 0.46)) {
                animatedStressScore = breakdown.stress
            }
            try? await Task.sleep(nanoseconds: 170_000_000)
            withAnimation(.easeOut(duration: 0.46)) {
                animatedFunctioningScore = breakdown.functioning
            }
        }
    }

    private var scoreTrendPage: some View {
        OnboardingQuestionPage(
            title: "How to read your score",
            subtitle: "",
            motionStyle: .results
        ) {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Lower means fewer recent difficulties.")
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text("The number is a comparison point for future reviews, not a label.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(rangeLineProgress > 0.12 ? 1 : 0)
                .offset(y: rangeLineProgress > 0.12 ? 0 : 8)

                scoreRangeChart

                HStack(spacing: 18) {
                    rangeLegend("Lighter", "0-21", tint: .green)
                    rangeLegend("Middle", "22-42", tint: .orange)
                    rangeLegend("Heavier", "43-63", tint: .red)
                }
                .opacity(rangeLineProgress > 0.55 ? 1 : 0)
                .offset(y: rangeLineProgress > 0.55 ? 0 : 10)

                Text("Your baseline starts at \(totalScore). Future daily and weekly reviews compare against this, so progress can be specific instead of generic.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .opacity(rangeLineProgress > 0.82 ? 1 : 0)
            }
        }
        .onAppear {
            rangeLineProgress = 0
            withAnimation(.smooth(duration: 0.85, extraBounce: 0)) {
                rangeLineProgress = 1
            }
        }
    }

    private var planPage: some View {
        let items = planItems
        return OnboardingQuestionPage(
            title: "Your core loop is ready",
            subtitle: "",
            motionStyle: .results
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text(planName)
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(planFocusTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                animatedUnderline(progress: CGFloat(min(planRevealCount, 1)), tint: onboardingCompanionTint)
                    .frame(height: 18)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)

            VStack(spacing: 14) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    planTimelineRow(title: item.title, body: item.body, icon: planItemIcon(for: item.title), index: index, isLast: index == items.count - 1)
                        .opacity(planRevealCount > index ? 1 : 0)
                        .offset(x: planRevealCount > index ? 0 : -10)
                        .animation(.smooth(duration: 0.34, extraBounce: 0), value: planRevealCount)
                }
            }
            .task(id: page) {
                guard page == planPageIndex else { return }
                planRevealCount = 0
                for i in 0..<items.count {
                    try? await Task.sleep(nanoseconds: 90_000_000)
                    planRevealCount = i + 1
                }
            }
        }
    }

    private var streakPage: some View {
        OnboardingQuestionPage(
            title: "Choose a streak goal",
            subtitle: "Small consistency beats intensity.",
            motionStyle: .form
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
            subtitle: "We’ll set your reminder around this.",
            motionStyle: .form
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
            subtitle: "Optional. Share context so AI responses sound like they understand your life.",
            motionStyle: .form
        ) {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $personalStory)
                    .scrollContentBackground(.hidden)
                    .focused($focusedField, equals: .story)
                    .font(.body)
                    .frame(minHeight: 210)
                    .padding(10)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
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

    private var healthPage: some View {
        OnboardingQuestionPage(
            title: "Connect Apple Health",
            subtitle: "Optional. Sleep and step trends can add useful context to reflections.",
            motionStyle: .form
        ) {
            VStack(spacing: 10) {
                singleRow("Sleep context for calmer planning", symbol: "moon")
                singleRow("Step trends for energy pattern signals", symbol: "figure.walk")
                singleRow("You can skip this and connect later in Settings", symbol: "lock.shield")

                Button {
                    Task {
                        isConnectingHealth = true
                        await healthKitManager.requestPermissionsAndRefresh()
                        appModel.updateHealthSummary(healthKitManager.summary)
                        isConnectingHealth = false
                        reactCompanion(.responding, withLens: true)
                        let current = page
                        withAnimation(pageAdvanceAnimation(from: current)) {
                            page = min(page + 1, completionPageIndex)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isConnectingHealth { ProgressView().tint(Color(.systemBackground)) }
                        Text(isConnectingHealth ? "Connecting..." : "Connect Apple Health")
                            .font(.headline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .foregroundStyle(Color(.systemBackground))
                .background(onboardingCompanionTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .buttonStyle(.plain)
                .disabled(isConnectingHealth || !healthKitManager.isHealthAvailable)
            }
        }
    }

    private var firstCheckInPage: some View {
        OnboardingQuestionPage(
            title: "First check-in",
            subtitle: "How was your day?",
            motionStyle: .assessment
        ) {
            VStack(alignment: .leading, spacing: 12) {
                MoodSelectorView(selectedMood: $selectedMood, size: 42, labelFont: .caption, useMoodAccent: true)

                HStack(spacing: 8) {
                    entryTypeChip(.quickThought, "Quick")
                    entryTypeChip(.reflection, "Reflection")
                    entryTypeChip(.rant, "Unload")
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
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
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
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .foregroundStyle(Color(.systemBackground))
                .background(Color.primary.opacity(firstCheckInCanGenerate ? 1 : 0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        OnboardingQuestionPage(
            title: "Your first reflection",
            subtitle: "",
            motionStyle: .results
        ) {
            VStack(spacing: 20) {
                if let review = firstCheckInReview {
                    Text(reflectionLead(review))
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 4)

                    reflectionSection(
                        title: "Noticed",
                        body: review.insight.pattern,
                        emphasized: false
                    )

                    reflectionSection(
                        title: "Reframe",
                        body: review.insight.reframe,
                        emphasized: true
                    )

                    reflectionSection(
                        title: "Try next",
                        body: review.insight.action,
                        emphasized: false
                    )

                    Text("Your companion mirrors recent signal intensity. It becomes more active when your entries suggest heavier strain, then settles as check-ins and follow-through get steadier.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No reflection yet. Go back and generate one.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .onAppear {
            guard onboardingStreakCelebrationPending else { return }
            onboardingStreakCelebrationPending = false
            onboardingConfettiTrigger += 1
            Task {
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                withAnimation(.easeOut(duration: 0.22)) {
                    onboardingStreakCelebrationMessage = nil
                }
            }
        }
        .overlay(alignment: .top) {
            if let message = onboardingStreakCelebrationMessage {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                    Text(message)
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white, in: Capsule())
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func reflectionSection(title: String, body: String, emphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.3)
                .foregroundStyle(.secondary)
            Text(body)
                .font(emphasized ? .body.weight(.semibold) : .body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }

    private var completionPage: some View {
        OnboardingQuestionPage(
            title: "You’re ready",
            subtitle: "Your plan, preferences, and first check-in are saved.",
            motionStyle: .hero
        ) {
            VStack(spacing: 10) {
                singleRow("Main goal: \(selectedGoal.isEmpty ? "Support mental wellness" : selectedGoal)", symbol: "target")
                singleRow("Streak goal: \(streakGoal) days", symbol: "flame")
                singleRow(onboardingStreakMessage, symbol: "calendar.badge.clock")
                singleRow("Reminder: \(checkInTime)", symbol: "clock")
                singleRow("Pattern memory and tone personalization enabled", symbol: "sparkles")
            }
        }
    }

    private var firstCheckInCanGenerate: Bool {
        !firstCheckInBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var totalScore: Int {
        assessmentAnswers.compactMap { $0 }.reduce(0, +)
    }

    private var onboardingStreakMessage: String {
        let current = appModel.currentStreakDays
        if current >= streakGoal {
            return "You hit your streak goal. Keep going to extend it."
        }
        if current == 0 {
            return "No active streak yet. Your next check-in starts day 1."
        }
        return "Current streak: \(current) day\(current == 1 ? "" : "s"). Miss 2 days and it resets."
    }

    private var scoreHeadline: String {
        switch totalScore {
        case 40...63:
            return "You reported frequent strain recently. We’ll keep your first loop stabilizing, practical, and easy to repeat."
        case 24...39:
            return "Your baseline shows mixed days. We’ll focus on spotting patterns and turning them into small actions."
        default:
            return "Your baseline is lighter overall. We’ll build momentum with reflection, feedback, and steady routines."
        }
    }

    private var planFocusTitle: String {
        "Your first loop: check in, get a useful read, try one action, review the pattern."
    }

    private var planName: String {
        switch dominantDomain {
        case "Anxiety":
            return "Calm Response Plan"
        case "Mood":
            return "Mood Stability Plan"
        case "Functioning":
            return "Daily Function Plan"
        default:
            return "Stress Reset Plan"
        }
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
            return "A daily check-in that names worry loops, body cues, avoidance, and what helped you come down."
        case "Mood":
            return "A daily check-in that tracks interest, energy, self-talk, and one doable activation step."
        case "Functioning":
            return "A daily check-in that connects symptoms to sleep, focus, relationships, and getting through the day."
        default:
            return "A daily check-in that tracks load, irritability, body tension, and one recovery or boundary move."
        }
    }

    private var guidedTrackLine: String {
        switch dominantDomain {
        case "Anxiety":
            return "Grounding track with shorter exercises and worry-unhook prompts."
        case "Mood":
            return "Mood reset track with activation prompts and self-criticism interrupts."
        case "Functioning":
            return "Function track with sleep, focus, avoidance, and support prompts."
        default:
            return "Stress support track with boundary, pacing, and recovery prompts."
        }
    }

    private var rankedDomains: [(name: String, value: Double)] {
        [
            (name: "Anxiety", value: scoreBreakdown.anxiety),
            (name: "Mood", value: scoreBreakdown.mood),
            (name: "Stress", value: scoreBreakdown.stress),
            (name: "Functioning", value: scoreBreakdown.functioning)
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

    private var scoreBreakdown: (anxiety: Double, mood: Double, stress: Double, functioning: Double) {
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
            average([5, 14, 15, 16, 17]),
            average([9, 13, 18, 19, 20])
        )
    }

    private var scoreRangeChart: some View {
        return GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let y = h * 0.5
            let baselineRatio = min(max(Double(totalScore) / 63.0, 0), 1)
            let x = max(10, min(w - 10, w * baselineRatio))
            ZStack {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 16)
                    .position(x: w / 2, y: y)

                HStack(spacing: 3) {
                    Capsule().fill(Color.green.opacity(0.48))
                    Capsule().fill(Color.orange.opacity(0.42))
                    Capsule().fill(Color.red.opacity(0.4))
                }
                .frame(width: w * rangeLineProgress, height: 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .position(x: (w * rangeLineProgress) / 2, y: y)

                Path { path in
                    path.move(to: CGPoint(x: w * (21.0 / 63.0), y: y - 13))
                    path.addLine(to: CGPoint(x: w * (21.0 / 63.0), y: y + 13))
                }
                .stroke(Color.white.opacity(0.25), lineWidth: 1)

                Path { path in
                    path.move(to: CGPoint(x: w * (42.0 / 63.0), y: y - 13))
                    path.addLine(to: CGPoint(x: w * (42.0 / 63.0), y: y + 13))
                }
                .stroke(Color.white.opacity(0.25), lineWidth: 1)

                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .shadow(color: .white.opacity(0.3), radius: 8)
                    .position(x: x, y: y)
                    .scaleEffect(rangeLineProgress > 0.72 ? 1 : 0.4)
                    .opacity(rangeLineProgress > 0.72 ? 1 : 0)

                Text("You: \(totalScore)")
                    .font(.caption2.weight(.semibold))
                    .position(x: max(48, min(w - 48, x)), y: y - 24)
                    .opacity(rangeLineProgress > 0.78 ? 1 : 0)
            }
        }
        .frame(height: 112)
        .padding(.vertical, 8)
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
            await notificationService.applyOnboardingCheckInPreference(checkInTime, enableReminder: true)
            await notificationService.setWeeklyReminderEnabled(true)
            isRequestingNotificationPermission = false
        }

        if page == completionPageIndex {
            finishOnboarding()
            return
        }

        let current = page
        withAnimation(pageAdvanceAnimation(from: current)) { page += 1 }
    }

    private func selectAssessmentAnswer(_ answerIndex: Int, for questionIndex: Int) async {
        guard !isAnimatingAssessment else { return }
        guard questionIndex == assessmentIndex else { return }
        assessmentAnswers[questionIndex] = answerIndex
        switch answerIndex {
        case 0: reactCompanion(.settled)
        case 1: reactCompanion(.attentive)
        case 2: reactCompanion(.attentive, withLens: true)
        default: reactCompanion(.checkIn, withLens: true)
        }

        if questionIndex >= OnboardingAssessment.items.count - 1 {
            withAnimation(pageAdvanceAnimation(from: assessmentPageIndex)) {
                page = scoreLoadingPageIndex
            }
            startScoreReveal()
            return
        }

        isAnimatingAssessment = true
        withAnimation(pageAdvanceAnimation(from: assessmentPageIndex)) {
            assessmentIndex = questionIndex + 1
        }
        try? await Task.sleep(nanoseconds: 260_000_000)
        isAnimatingAssessment = false
    }

    private func advanceAfterSingleChoice() {
        focusedField = nil
        reactCompanion(.checkIn)
        guard page < completionPageIndex else { return }
        let current = page
        withAnimation(pageAdvanceAnimation(from: current)) {
            page += 1
        }
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
            version: "2",
            totalScore: answers.reduce(0, +),
            maxScore: answers.count * 3,
            answers: answers,
            questionLabels: labels,
            domains: [
                domainSummary(name: "Anxiety", indices: [0, 1, 2, 3, 4, 6]),
                domainSummary(name: "Mood", indices: [7, 8, 9, 10, 11, 12, 13]),
                domainSummary(name: "Stress", indices: [5, 14, 15, 16, 17]),
                domainSummary(name: "Functioning", indices: [9, 13, 18, 19, 20])
            ],
            completedAt: Date()
        )

        let therapyBinary = triedTherapy.map { $0 ? "yes" : "no" } ?? "unknown"
        let emotionBinary = emotionAwarenessHard.map { $0 ? "yes" : "no" } ?? "unknown"

        let lifeContext = focus + [
            "Main goal: \(selectedGoal)",
            "Therapy familiarity: \(therapyExperience)",
            "Emotion awareness frequency: \(emotionAwarenessLevel)",
            "Tried therapy before: \(therapyBinary)",
            "Emotion awareness difficult: \(emotionBinary)",
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
            streakGoal: streakGoal,
            assessment: assessment
        )

        completeOnboardingWithCompanionHandoff()
    }

    private func completeOnboardingWithCompanionHandoff() {
        guard !isCompletingOnboarding else { return }
        isCompletingOnboarding = true
        router.selectedTab = .journal
        router.companionPresentation = .journal
        router.companionTabTransitioning = true
        router.onboardingCompanionHandoffSettled = false
        router.onboardingCompanionHandoffActive = true

        Task {
            try? await Task.sleep(for: .milliseconds(90))
            await MainActor.run {
                withAnimation(.spring(response: 0.72, dampingFraction: 0.86, blendDuration: 0.12)) {
                    router.onboardingCompanionHandoffSettled = true
                }
            }

            try? await Task.sleep(for: .milliseconds(190))
            await MainActor.run {
                hasCompletedOnboarding = true
            }

            try? await Task.sleep(for: .milliseconds(440))
            await MainActor.run {
                router.onboardingCompanionHandoffActive = false
                router.onboardingCompanionHandoffSettled = false
                router.companionTabTransitioning = false
            }
        }
    }

    private func generateFirstCheckIn() async {
        guard firstCheckInCanGenerate else { return }
        guard !isGeneratingFirstCheckIn else { return }
        isGeneratingFirstCheckIn = true
        firstCheckInErrorMessage = ""
        defer { isGeneratingFirstCheckIn = false }

        let text = firstCheckInBody.trimmingCharacters(in: .whitespacesAndNewlines)
        if firstCheckInEntryCreated == false {
            let streakBefore = appModel.currentStreakDays
            _ = appModel.addEntry(text: text, mood: selectedMood, type: firstCheckInType)
            let streakAfter = appModel.currentStreakDays
            if streakAfter > streakBefore {
                triggerOnboardingStreakCelebration(day: streakAfter)
            }
            firstCheckInEntryCreated = true
        }

        let review = await appModel.generateOnboardingFirstReflection(for: Date())
        firstCheckInReview = review
        firstCheckInGenerated = review != nil

        if review == nil {
            firstCheckInErrorMessage = "Could not generate AI reflection right now. Please try again."
        }
    }

    private func triggerOnboardingStreakCelebration(day: Int) {
        let message: String
        if day <= 1 {
            message = "Streak started: Day 1."
        } else if day >= streakGoal {
            message = "Streak goal reached: Day \(day)."
        } else {
            message = "Streak updated: Day \(day)."
        }
        onboardingStreakCelebrationMessage = message
        onboardingStreakCelebrationPending = true
        reactCompanion(.responding, withLens: true)
    }

    private func reactCompanion(_ state: AICircleState, withLens: Bool = false) {
        companionTrigger += 1
        transientCircleState = state
        if withLens { lensFocusActive = true }
        Task {
            try? await Task.sleep(nanoseconds: 520_000_000)
            if transientCircleState == state { transientCircleState = nil }
            if withLens { lensFocusActive = false }
        }
    }

    private func reflectionLead(_ review: DailyReview) -> String {
        let name = appModel.onboardingProfile.preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = name.isEmpty ? "" : "\(name), "
        return "\(prefix)\(review.insight.emotionalRead)"
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
        .overlay(alignment: .bottom) { Divider().overlay(Color.white.opacity(0.12)).padding(.horizontal, 4) }
    }

    private func focusRow(_ title: String, _ symbol: String) -> some View {
        let selected = focusAreas.contains(title)
        return Button {
            if selected { focusAreas.remove(title) } else { focusAreas.insert(title) }
            reactCompanion(selected ? .attentive : .checkIn)
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
            .background(selected ? onboardingCompanionTint : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? onboardingCompanionTint : Color.white.opacity(0.2), lineWidth: 0.8)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                    .font(.headline.weight(.semibold))
                Spacer()
                if selected { Image(systemName: "checkmark") }
            }
            .padding(.horizontal, 14)
            .frame(height: 58)
            .foregroundStyle(selected ? Color(.systemBackground) : .primary)
            .background(selected ? onboardingCompanionTint : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? onboardingCompanionTint : Color.white.opacity(0.2), lineWidth: 0.8)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func streakChoice(_ days: Int) -> some View {
        let selected = streakGoal == days
        return Button {
            streakGoal = days
            reactCompanion(.checkIn)
        } label: {
            Text("\(days) day streak")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundStyle(selected ? Color(.systemBackground) : .primary)
                .background(selected ? onboardingCompanionTint : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(selected ? onboardingCompanionTint : Color.white.opacity(0.2), lineWidth: 0.8)
                }
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func timeChoice(_ title: String, _ symbol: String) -> some View {
        let selected = checkInTime == title
        return Button {
            checkInTime = title
            reactCompanion(.checkIn, withLens: true)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .frame(width: 24)
                Text(title)
                    .font(.headline.weight(.semibold))
                Spacer()
                if selected { Image(systemName: "checkmark") }
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .foregroundStyle(selected ? Color(.systemBackground) : .primary)
            .background(selected ? onboardingCompanionTint : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? onboardingCompanionTint : Color.white.opacity(0.2), lineWidth: 0.8)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func entryTypeChip(_ type: EntryType, _ label: String) -> some View {
        let selected = firstCheckInType == type
        return Button {
            firstCheckInType = type
            reactCompanion(.attentive)
        } label: {
            Text(label)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(selected ? Color(.systemBackground) : .primary)
                .background(selected ? selectedMood.companionColor : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(selected ? selectedMood.companionColor : Color.white.opacity(0.2), lineWidth: 0.8)
                }
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func animatedUnderline(progress: CGFloat, tint: Color) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let y = proxy.size.height * 0.5
            ZStack(alignment: .leading) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addCurve(
                        to: CGPoint(x: width, y: y - 2),
                        control1: CGPoint(x: width * 0.28, y: y + 10),
                        control2: CGPoint(x: width * 0.68, y: y - 12)
                    )
                }
                .trim(from: 0, to: progress)
                .stroke(tint.opacity(0.75), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

                Path { path in
                    path.move(to: CGPoint(x: width * 0.08, y: y + 7))
                    path.addCurve(
                        to: CGPoint(x: width * 0.86, y: y + 4),
                        control1: CGPoint(x: width * 0.32, y: y - 3),
                        control2: CGPoint(x: width * 0.62, y: y + 12)
                    )
                }
                .trim(from: 0, to: max(0, progress - 0.22) / 0.78)
                .stroke(tint.opacity(0.26), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
            }
        }
    }

    private func scoreSignalRow(_ title: String, value: Double, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int((value * 100).rounded()))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(onboardingCompanionTint.opacity(0.92))
                        .frame(width: value > 0 ? max(4, proxy.size.width * value) : 0)
                    Rectangle()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 1, height: 12)
                        .offset(x: proxy.size.width * 0.5)
                }
            }
            .frame(height: 5)

            Text(scoreBarSubtitle(for: value))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .opacity(value > 0 ? 1 : 0)
        .offset(y: value > 0 ? 0 : 8)
    }

    private func rangeLegend(_ title: String, _ range: String, tint: Color) -> some View {
        VStack(spacing: 5) {
            Capsule()
                .fill(tint.opacity(0.5))
                .frame(width: 38, height: 5)
            Text(title)
                .font(.caption.weight(.semibold))
            Text(range)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func scoreBar(_ title: String, value: Double, subtitle: String) -> some View {
        let avg: Double = 0.5
        return VStack(alignment: .leading, spacing: 8) {
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
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 2, height: 14)
                        .offset(x: max(0, (proxy.size.width * avg) - 1))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary)
                        .frame(width: max(6, proxy.size.width * value))
                }
            }
            .frame(height: 12)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func scoreBarSubtitle(for value: Double) -> String {
        let percent = Int((value * 100).rounded())
        if value < 0.5 {
            return "\(percent)% • Below midpoint (lighter)"
        }
        if value > 0.5 {
            return "\(percent)% • Above midpoint (heavier)"
        }
        return "\(percent)% • At midpoint"
    }

    private func planRow(_ title: String, body: String) -> some View {
        planListRow(title: title, body: body, icon: planItemIcon(for: title))
    }

    private func planListRow(title: String, body: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }

    private func planTimelineRow(title: String, body: String, icon: String, index: Int, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(onboardingCompanionTint.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                }

                if isLast == false {
                    Rectangle()
                        .fill(onboardingCompanionTint.opacity(0.26))
                        .frame(width: 1.2, height: 44)
                        .scaleEffect(y: planRevealCount > index + 1 ? 1 : 0.2, anchor: .top)
                        .animation(.easeOut(duration: 0.28), value: planRevealCount)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .contentTransition(.opacity)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }

    private func planItemIcon(for title: String) -> String {
        switch title {
        case "Why this plan":
            return "scope"
        case "Daily check-in":
            return "sun.max"
        case "Daily review":
            return "sparkles"
        case "One tiny experiment":
            return "checkmark.seal"
        case "Guided journal track":
            return "book"
        case "Weekly pattern report":
            return "chart.line.uptrend.xyaxis"
        case "Companion memory":
            return "brain.head.profile"
        default:
            return "circle"
        }
    }

    private var planItems: [(title: String, body: String)] {
        [
            ("Why this plan", planWhyLine),
            ("Daily check-in", dailyPlanLine),
            ("Daily review", "Turns the entry into one pattern, one reframe, one action, and evidence strength."),
            ("One tiny experiment", guidedTrackLine),
            ("Weekly pattern report", "Compares your week against this baseline, then updates the next focus."),
            ("Companion memory", "Keeps your goals, context, and strongest domains so guidance compounds over time.")
        ]
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
        .init(prompt: "How often have you felt nervous, anxious, or on edge?"),
        .init(prompt: "How often have you been unable to stop or control worrying?"),
        .init(prompt: "How often have worries jumped between different parts of your life?"),
        .init(prompt: "How often have you avoided something because anxiety or dread showed up?"),
        .init(prompt: "How often has your body felt keyed up, tense, restless, or hard to settle?"),
        .init(prompt: "How often have you felt irritable or quicker to snap than usual?"),
        .init(prompt: "How often have you felt afraid that something bad might happen?"),
        .init(prompt: "How often have you had little interest or pleasure in things you normally do?"),
        .init(prompt: "How often have you felt down, flat, hopeless, or emotionally heavy?"),
        .init(prompt: "How often has sleep been a problem, including too little, too much, or poor-quality sleep?"),
        .init(prompt: "How often have you felt tired, slowed down, or low in energy?"),
        .init(prompt: "How often have appetite changes or comfort eating affected your day?"),
        .init(prompt: "How often have you been harsh with yourself or felt like you were failing?"),
        .init(prompt: "How often has it been hard to concentrate, make decisions, or finish ordinary tasks?"),
        .init(prompt: "How often have daily demands felt like more than you could comfortably handle?"),
        .init(prompt: "How often have emotions felt bigger than the situation called for?"),
        .init(prompt: "How often have racing thoughts made it hard to switch off?"),
        .init(prompt: "How often has stress shown up physically, like jaw, neck, chest, stomach, or headaches?"),
        .init(prompt: "How often have anxiety, low mood, or stress made work, school, home, or self-care harder?"),
        .init(prompt: "How often have you pulled away from people or felt unsupported when you needed support?"),
        .init(prompt: "How often have you used scrolling, substances, food, or other numbing habits to get through feelings?")
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
    enum MotionStyle {
        case hero
        case form
        case assessment
        case results
    }

    var eyebrow: String? = nil
    let title: String
    let subtitle: String
    var motionStyle: MotionStyle = .form
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 22) {
                VStack(alignment: .center, spacing: 8) {
                    if let eyebrow, !eyebrow.isEmpty {
                        Text(eyebrow.uppercased())
                            .font(.caption.weight(.semibold))
                            .tracking(0.4)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .opacity(headerVisible ? 1 : 0)
                            .offset(y: headerVisible ? 0 : 6)
                    }
                    Text(title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .opacity(headerVisible ? 1 : 0)
                        .offset(y: headerVisible ? 0 : 10)
                        .scaleEffect(headerVisible ? 1 : 0.985)
                    if subtitle.isEmpty == false {
                        Text(subtitle)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .opacity(subheaderVisible ? 1 : 0)
                            .offset(y: subheaderVisible ? 0 : 10)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                content
            }
            .padding(AppSpacing.page)
            .padding(.top, 8)
            .opacity(isVisible ? 1 : 0.0)
            .offset(y: isVisible ? 0 : bodyStartOffset)
            .scaleEffect(isVisible ? 1 : bodyStartScale)
            .animation(bodyAnimation, value: isVisible)
        }
        .onAppear {
            isVisible = true
            headerVisible = false
            subheaderVisible = false
            withAnimation(headerAnimation) {
                headerVisible = true
            }
            withAnimation(subheaderAnimation) {
                subheaderVisible = true
            }
        }
        .onDisappear {
            isVisible = false
            headerVisible = false
            subheaderVisible = false
        }
    }

    @State private var isVisible = false
    @State private var headerVisible = false
    @State private var subheaderVisible = false

    private var bodyStartOffset: CGFloat {
        switch motionStyle {
        case .hero: 22
        case .form: 14
        case .assessment: 10
        case .results: 30
        }
    }

    private var bodyStartScale: CGFloat {
        switch motionStyle {
        case .hero: 0.97
        case .form: 0.99
        case .assessment: 0.995
        case .results: 0.965
        }
    }

    private var bodyAnimation: Animation {
        switch motionStyle {
        case .hero: .interactiveSpring(response: 0.52, dampingFraction: 0.82, blendDuration: 0.2)
        case .form: .easeOut(duration: 0.24)
        case .assessment: .easeOut(duration: 0.2)
        case .results: .interactiveSpring(response: 0.58, dampingFraction: 0.8, blendDuration: 0.24)
        }
    }

    private var headerAnimation: Animation {
        switch motionStyle {
        case .hero: .interactiveSpring(response: 0.46, dampingFraction: 0.78, blendDuration: 0.18)
        case .form: .easeOut(duration: 0.28)
        case .assessment: .easeOut(duration: 0.22)
        case .results: .interactiveSpring(response: 0.5, dampingFraction: 0.78, blendDuration: 0.2)
        }
    }

    private var subheaderAnimation: Animation {
        switch motionStyle {
        case .hero: .interactiveSpring(response: 0.52, dampingFraction: 0.8, blendDuration: 0.2).delay(0.1)
        case .form: .easeOut(duration: 0.32).delay(0.08)
        case .assessment: .easeOut(duration: 0.22).delay(0.05)
        case .results: .interactiveSpring(response: 0.54, dampingFraction: 0.82, blendDuration: 0.22).delay(0.12)
        }
    }
}
