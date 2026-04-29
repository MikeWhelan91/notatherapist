import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("onboardingPreferredName") private var storedPreferredName = ""
    @AppStorage("onboardingAgeRange") private var storedAgeRange = ""
    @AppStorage("onboardingLifeContext") private var storedLifeContext = ""
    @AppStorage("onboardingReflectionGoal") private var storedReflectionGoal = ""
    @AppStorage("onboardingPersonalStory") private var storedPersonalStory = ""

    @State private var page = 0
    @State private var preferredName = ""
    @State private var ageRange = ""
    @State private var lifeContext: Set<String> = []
    @State private var reflectionGoal = ""
    @State private var personalStory = ""
    @State private var wantsWeeklyReviewReminder = true
    @State private var customIssue = ""
    @State private var healthChoice: OnboardingHealthChoice?
    @State private var storageChoice: OnboardingStorageChoice?
    @State private var firstCheckInBody = ""
    @State private var firstCheckInMood: MoodLevel = .okay
    @State private var firstCheckInType: EntryType = .reflection
    @State private var firstCheckInGenerated = false
    @State private var firstCheckInReview: DailyReview?
    @State private var firstCheckInErrorMessage = ""
    @State private var firstCheckInUsedFallback = false
    @State private var isGeneratingFirstCheckIn = false
    @State private var isRequestingNotificationPermission = false
    @State private var isRequestingHealthPermission = false
    @FocusState private var focusedField: OnboardingField?

    private let pageCount = 12
    private let reminderPageIndex = 6
    private let healthPageIndex = 7
    private let storagePageIndex = 8
    private let firstCheckInInputPageIndex = 9
    private let firstCheckInResultPageIndex = 10

    var body: some View {
        VStack(spacing: 0) {
            progress
                .padding(.horizontal, AppSpacing.page)
                .padding(.top, 10)

            onboardingCircle
                .padding(.top, page == 0 ? 92 : 42)
                .padding(.bottom, page == 0 ? 30 : 22)
                .animation(.smooth(duration: 0.35), value: page)

            TabView(selection: $page) {
                welcomePage.tag(0)
                namePage.tag(1)
                agePage.tag(2)
                contextPage.tag(3)
                goalPage.tag(4)
                storyPage.tag(5)
                reminderPage.tag(6)
                healthPage.tag(7)
                storagePage.tag(8)
                firstCheckInPage.tag(9)
                firstCheckInResultPage.tag(10)
                scopePage.tag(11)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.smooth(duration: 0.28), value: page)

            if shouldShowControls {
                controls
                    .padding(.horizontal, AppSpacing.page)
                    .padding(.bottom, 26)
            }
        }
        .background(Color(.systemBackground))
        .onTapGesture {
            focusedField = nil
        }
        .onChange(of: page) {
            focusedField = nil
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
    }

    private var onboardingCircle: some View {
        HStack {
            Spacer()
            AICircleView(
                state: .idle,
                size: page == 0 ? 188 : 92,
                strokeWidth: page == 0 ? 4.2 : 3,
                motionStyle: page == 0 ? .intro : .continuous
            )
            Spacer()
        }
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

    private var controls: some View {
        HStack(spacing: 12) {
            if page > 0 && shouldShowBackButton {
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

            if page != firstCheckInInputPageIndex {
                Button {
                    focusedField = nil
                    Task {
                        await continueTapped()
                    }
                } label: {
                    Text(continueButtonTitle)
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .foregroundStyle(Color(.systemBackground))
                .background(Color.primary.opacity(canContinue ? 1 : 0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .buttonStyle(.plain)
                .disabled(canContinue == false || isRequestingNotificationPermission || isRequestingHealthPermission)
            }
        }
    }

    private var continueButtonTitle: String {
        if isRequestingNotificationPermission || isRequestingHealthPermission {
            return "Connecting"
        }
        return page == pageCount - 1 ? "Get started" : "Continue"
    }

    private var canContinue: Bool {
        switch page {
        case 2:
            return ageRange.isEmpty == false
        case 3:
            return lifeContext.isEmpty == false || customIssue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case 4:
            return reflectionGoal.isEmpty == false
        case healthPageIndex:
            return healthChoice != nil
        case storagePageIndex:
            return storageChoice != nil
        case firstCheckInResultPageIndex:
            return firstCheckInGenerated
        default:
            return true
        }
    }

    private var shouldShowControls: Bool {
        focusedField == nil
    }

    private var shouldShowBackButton: Bool {
        page != firstCheckInInputPageIndex && page != firstCheckInResultPageIndex
    }

    private var welcomePage: some View {
        VStack(spacing: 8) {
            VStack(spacing: 8) {
                Text("Anchor")
                    .font(.largeTitle.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("A calmer way to reflect.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(AppSpacing.page)
    }

    private var namePage: some View {
        OnboardingQuestionPage(
            title: "What should I call you?",
            subtitle: "Optional. A first name or nickname is enough."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Name or nickname", text: $preferredName)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
                    .font(.title3.weight(.semibold))
                    .padding(16)
                    .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppSurface.stroke, lineWidth: 0.5)
                    }
                Text("This helps messages feel less generic. You can leave it blank.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var agePage: some View {
        OnboardingQuestionPage(
            title: "Which age range fits?",
            subtitle: "Optional. A broad range is enough."
        ) {
            VStack(spacing: 10) {
                singleChoice("Under 18", symbol: "person.crop.circle.badge.questionmark", selection: $ageRange)
                singleChoice("18-24", symbol: "person", selection: $ageRange)
                singleChoice("25-34", symbol: "person", selection: $ageRange)
                singleChoice("35-44", symbol: "person", selection: $ageRange)
                singleChoice("45+", symbol: "person", selection: $ageRange)
                singleChoice("Prefer not to say", symbol: "eye.slash", selection: $ageRange)
            }
        }
    }

    private var contextPage: some View {
        OnboardingQuestionPage(
            title: "What are you dealing with?",
            subtitle: "Choose anything you want the app to watch for in your reflections."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                multiChoice("Anxiety", symbol: "wind", set: $lifeContext)
                multiChoice("Depression or low mood", symbol: "cloud", set: $lifeContext)
                multiChoice("Attention or ADHD", symbol: "scope", set: $lifeContext)
                multiChoice("Stress", symbol: "bolt", set: $lifeContext)
                multiChoice("Burnout", symbol: "battery.25", set: $lifeContext)
                multiChoice("Overthinking", symbol: "bubble.left.and.text.bubble.right", set: $lifeContext)
                multiChoice("Relationships", symbol: "person.2", set: $lifeContext)
                multiChoice("Sleep", symbol: "moon", set: $lifeContext)

                TextField("Other", text: $customIssue)
                    .textInputAutocapitalization(.sentences)
                    .focused($focusedField, equals: .customIssue)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
                    .font(.subheadline.weight(.semibold))
                    .padding(14)
                    .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppSurface.stroke, lineWidth: 0.5)
                    }
            }
        }
    }

    private var goalPage: some View {
        OnboardingQuestionPage(
            title: "What do you want from journaling?",
            subtitle: "This is more useful than asking for a writing schedule."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                singleChoice("Get thoughts out", subtitle: "A place to put what is noisy", symbol: "square.and.pencil", selection: $reflectionGoal)
                singleChoice("Understand patterns", subtitle: "Notice what repeats over time", symbol: "point.3.connected.trianglepath.dotted", selection: $reflectionGoal)
                singleChoice("Make decisions", subtitle: "Turn loops into next steps", symbol: "arrow.triangle.branch", selection: $reflectionGoal)
                singleChoice("Feel more settled", subtitle: "Close the day cleanly", symbol: "circle", selection: $reflectionGoal)
                singleChoice("Track wins", subtitle: "Notice what is working", symbol: "checkmark.seal", selection: $reflectionGoal)
            }
        }
    }

    private var storyPage: some View {
        OnboardingQuestionPage(
            title: "Your story",
            subtitle: "Optional. Add context the AI should keep in mind when reflecting on entries."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TextEditor(text: $personalStory)
                    .scrollContentBackground(.hidden)
                    .focused($focusedField, equals: .personalStory)
                    .font(.body)
                    .frame(minHeight: 170)
                    .padding(10)
                    .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppSurface.stroke, lineWidth: 0.5)
                    }
                Text("Example: 'Panic while driving recently. I want practical steps, not fluff.'")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var scopePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Before you start")
                        .font(.largeTitle.weight(.semibold))
                    Text("This is not therapy and it is not a diagnosis. It is a reflection tool to help you understand your own patterns.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ReferenceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Context for insights")
                            .font(.subheadline.weight(.semibold))
                        setupSummary("Name", values: [preferredName.isEmpty ? "Not set" : preferredName])
                        setupSummary("Age", values: [ageRange])
                        setupSummary("Issues", values: selectedIssues)
                        setupSummary("Goal", values: [reflectionGoal])
                        setupSummary("Story", values: [personalStory])
                        setupSummary("Reminder", values: [wantsWeeklyReviewReminder ? "Sunday 18:00" : "Off"])
                        setupSummary("Storage", values: [storageChoice?.label ?? "On this device"])
                        setupSummary("Voice", values: ["Factual, calm, contemplative, kind"])
                    }
                }
                ReferenceCard {
                    Text("Daily entries build the review. Reviews can create one small next step. Next check-in asks how it went.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(AppSpacing.page)
            .padding(.top, 28)
        }
    }

    private var firstCheckInPage: some View {
        OnboardingQuestionPage(
            title: "First check-in",
            subtitle: "Capture one real moment. This creates your first AI reflection."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                MoodSelectorView(selectedMood: $firstCheckInMood, size: 40, labelFont: .caption2)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Entry style")
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 8) {
                        firstCheckInTypeChip(.quickThought)
                        firstCheckInTypeChip(.reflection)
                        firstCheckInTypeChip(.rant)
                        firstCheckInTypeChip(.win)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("How was your day?")
                        .font(.subheadline.weight(.semibold))
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $firstCheckInBody)
                            .textInputAutocapitalization(.sentences)
                            .focused($focusedField, equals: .firstCheckInBody)
                            .font(.subheadline)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(minHeight: 140)
                        if firstCheckInBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Write one short honest entry.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 16)
                        }
                    }
                        .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(AppSurface.stroke, lineWidth: 0.5)
                        }
                }
                Button {
                    focusedField = nil
                    Task {
                        await generateFirstCheckIn()
                        if firstCheckInGenerated {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                page = firstCheckInResultPageIndex
                            }
                        }
                    }
                } label: {
                    HStack {
                        if isGeneratingFirstCheckIn {
                            ProgressView()
                                .tint(Color(.systemBackground))
                        }
                        Text(isGeneratingFirstCheckIn ? "Generating AI reflection" : "Get first reflection")
                            .font(.headline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .foregroundStyle(Color(.systemBackground))
                .background(Color.primary.opacity(firstCheckInCanGenerate ? 1 : 0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(firstCheckInCanGenerate == false || isGeneratingFirstCheckIn)
                .buttonStyle(.plain)

                if firstCheckInUsedFallback {
                    Button {
                        Task { await retryAIFirstCheckIn() }
                    } label: {
                        Text("Retry AI")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .foregroundStyle(.primary)
                    .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppSurface.stroke, lineWidth: 0.5)
                    }
                    .buttonStyle(.plain)
                    .disabled(isGeneratingFirstCheckIn)
                }

                if firstCheckInErrorMessage.isEmpty == false {
                    Text(firstCheckInErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var firstCheckInResultPage: some View {
        OnboardingQuestionPage(
            title: "Your first reflection",
            subtitle: "This came from your first journal entry and onboarding context."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if let review = firstCheckInReview {
                    ReferenceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                AICircleView(
                                    state: .responding,
                                    size: 34,
                                    strokeWidth: 2.4,
                                    motionStyle: .continuous
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("AI Reflection")
                                        .font(.subheadline.weight(.semibold))
                                    Text(review.source == "openai" ? "Generated by OpenAI" : "Offline/local reflection")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Divider()
                            Text(review.insight.emotionalRead)
                                .font(.body.weight(.medium))
                            Text(review.insight.action)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    ReferenceCard {
                        Text("No reflection generated yet. Go back and submit your first check-in.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var reminderPage: some View {
        OnboardingQuestionPage(
            title: "Weekly review reminder?",
            subtitle: "A local notification can let you know when the weekly review is ready."
        ) {
            VStack(spacing: 10) {
                OnboardingChoiceRow(
                    title: "Remind me on Sunday",
                    subtitle: "Starts the short weekly check-in",
                    symbol: "bell",
                    isSelected: wantsWeeklyReviewReminder
                ) {
                    wantsWeeklyReviewReminder = true
                }

                OnboardingChoiceRow(
                    title: "I'll turn it on later",
                    subtitle: "You can change this in Settings",
                    symbol: "bell.slash",
                    isSelected: wantsWeeklyReviewReminder == false
                ) {
                    wantsWeeklyReviewReminder = false
                }
            }
        }
    }

    private var healthPage: some View {
        OnboardingQuestionPage(
            title: "Connect Apple Health?",
            subtitle: "Optional. Sleep and steps can add quiet context to reviews."
        ) {
            VStack(spacing: 10) {
                ReferenceCard {
                    VStack(spacing: 0) {
                        onboardingInfoRow(symbol: "moon", title: "Sleep", body: "Used to notice whether rest may line up with mood.")
                        Divider()
                        onboardingInfoRow(symbol: "figure.walk", title: "Steps", body: "Used to notice simple movement patterns.")
                    }
                }

                OnboardingChoiceRow(
                    title: "Connect Health",
                    subtitle: "Ask permission for sleep and steps only",
                    symbol: "heart",
                    isSelected: healthChoice == .connect
                ) {
                    healthChoice = .connect
                }

                OnboardingChoiceRow(
                    title: "Continue without Health",
                    subtitle: "The app works normally without access",
                    symbol: "heart.slash",
                    isSelected: healthChoice == .skip
                ) {
                    healthChoice = .skip
                }
            }
        }
    }

    private var storagePage: some View {
        OnboardingQuestionPage(
            title: "Where should your data live?",
            subtitle: "Choose local-only or private iCloud sync. You can change this later in Settings."
        ) {
            VStack(spacing: 10) {
                OnboardingChoiceRow(
                    title: "On this device",
                    subtitle: "Data is removed if the app is deleted",
                    symbol: "iphone",
                    isSelected: storageChoice == .deviceOnly
                ) {
                    storageChoice = .deviceOnly
                }

                OnboardingChoiceRow(
                    title: "Sync with iCloud",
                    subtitle: "Keeps entries available across reinstalls and devices",
                    symbol: "icloud",
                    isSelected: storageChoice == .iCloudSync
                ) {
                    storageChoice = .iCloudSync
                }
            }
        }
    }

    private func setupSummary(_ title: String, values: [String]) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
            Text(values.filter { $0.isEmpty == false }.joined(separator: ", "))
                .font(.caption)
                .lineLimit(3)
        }
    }

    private func singleChoice(_ title: String, subtitle: String? = nil, symbol: String, selection: Binding<String>) -> some View {
        OnboardingChoiceRow(
            title: title,
            subtitle: subtitle,
            symbol: symbol,
            isSelected: selection.wrappedValue == title
        ) {
            selection.wrappedValue = title
        }
    }

    private func multiChoice(_ title: String, symbol: String, set: Binding<Set<String>>) -> some View {
        OnboardingChoiceRow(
            title: title,
            subtitle: nil,
            symbol: symbol,
            isSelected: set.wrappedValue.contains(title)
        ) {
            if set.wrappedValue.contains(title) {
                set.wrappedValue.remove(title)
            } else {
                set.wrappedValue.insert(title)
            }
        }
    }

    private func finish() {
        let trimmedName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let issues = selectedIssues
        storedPreferredName = trimmedName
        storedAgeRange = ageRange
        storedLifeContext = issues.joined(separator: "|")
        storedReflectionGoal = reflectionGoal
        storedPersonalStory = personalStory
        appModel.isICloudSyncEnabled = storageChoice == .iCloudSync
        appModel.updateOnboardingProfile(
            preferredName: trimmedName,
            ageRange: ageRange,
            lifeContext: issues,
            reflectionGoal: reflectionGoal,
            personalStory: personalStory
        )
        hasCompletedOnboarding = true
        Task {
            if wantsWeeklyReviewReminder == false {
                await notificationService.setWeeklyReminderEnabled(false)
            }
        }
    }

    private func continueTapped() async {
        if page == reminderPageIndex {
            if wantsWeeklyReviewReminder {
                isRequestingNotificationPermission = true
                await notificationService.setWeeklyReminderEnabled(true)
                isRequestingNotificationPermission = false
            } else {
                await notificationService.setWeeklyReminderEnabled(false)
            }
        }

        if page == healthPageIndex {
            switch healthChoice {
            case .connect:
                isRequestingHealthPermission = true
                await healthKitManager.requestPermissionsAndRefresh()
                appModel.updateHealthSummary(healthKitManager.summary)
                isRequestingHealthPermission = false
            case .skip:
                healthKitManager.markSkipped()
            case .none:
                return
            }
        }

        if page == storagePageIndex {
            appModel.isICloudSyncEnabled = storageChoice == .iCloudSync
            await appModel.refreshICloudStatus()
        }

        if page == firstCheckInInputPageIndex {
            return
        }

        if page == pageCount - 1 {
            finish()
        } else {
            withAnimation { page += 1 }
        }
    }

    private func onboardingInfoRow(symbol: String, title: String, body: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }

    private func firstCheckInTypeChip(_ type: EntryType) -> some View {
        Button {
            firstCheckInType = type
        } label: {
            Text(shortEntryTypeLabel(type))
                .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(firstCheckInType == type ? Color(.systemBackground) : .primary)
            .background(firstCheckInType == type ? Color.primary : AppSurface.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(firstCheckInType == type ? Color.primary : AppSurface.stroke, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    private var selectedIssues: [String] {
        var values = Array(lifeContext).sorted()
        let trimmed = customIssue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty == false {
            values.append(trimmed)
        }
        return values
    }

    private var firstCheckInCanGenerate: Bool {
        firstCheckInBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func generateFirstCheckIn() async {
        guard firstCheckInCanGenerate else { return }
        guard isGeneratingFirstCheckIn == false else { return }
        isGeneratingFirstCheckIn = true
        firstCheckInErrorMessage = ""
        firstCheckInUsedFallback = false
        defer { isGeneratingFirstCheckIn = false }

        let text = firstCheckInBody.trimmingCharacters(in: .whitespacesAndNewlines)

        _ = appModel.addEntry(text: text, mood: firstCheckInMood, type: firstCheckInType)
        let review = await appModel.generateOnboardingFirstReflection(for: Date())
        firstCheckInReview = review
        firstCheckInGenerated = review != nil
        firstCheckInUsedFallback = review?.source != "openai"
        if firstCheckInUsedFallback {
            firstCheckInErrorMessage = "OpenAI is temporarily unavailable. Showing offline reflection for now."
        }
    }

    private func retryAIFirstCheckIn() async {
        guard isGeneratingFirstCheckIn == false else { return }
        guard let review = await appModel.reviewDay(Date()) else { return }
        if review.source == "openai" {
            firstCheckInReview = review
            firstCheckInUsedFallback = false
            firstCheckInErrorMessage = ""
        }
    }

    private func shortEntryTypeLabel(_ type: EntryType) -> String {
        switch type {
        case .quickThought: return "Quick"
        case .rant: return "Rant"
        case .reflection: return "Reflection"
        case .win: return "Win"
        }
    }
}

private enum OnboardingField {
    case name
    case customIssue
    case personalStory
    case firstCheckInBody
}

private enum OnboardingHealthChoice {
    case connect
    case skip
}

private enum OnboardingStorageChoice {
    case deviceOnly
    case iCloudSync

    var label: String {
        switch self {
        case .deviceOnly: "On this device"
        case .iCloudSync: "iCloud sync"
        }
    }
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
                        .font(.largeTitle.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                content
            }
            .padding(AppSpacing.page)
            .padding(.top, 6)
        }
    }
}

private struct OnboardingChoiceRow: View {
    let title: String
    let subtitle: String?
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(isSelected ? Color(.systemBackground).opacity(0.72) : .secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(14)
            .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
            .background(isSelected ? Color.primary : AppSurface.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.primary : AppSurface.stroke, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(NotificationService.shared)
}
