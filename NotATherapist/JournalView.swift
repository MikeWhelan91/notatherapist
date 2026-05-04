import SwiftUI

struct JournalView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var router: AppRouter
    @State private var showingNewEntry = false
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var activeDailyReview: DailyReview?
    @State private var isReviewingDay = false
    @State private var pendingReReviewDate: Date?
    @State private var showingReReviewConfirm = false
    @State private var companionState: AICircleState = .attentive
    @State private var companionLensFocusActive = false
    @State private var companionBusy = false
    @State private var companionTrigger = 0

    private var todayDate: Date { Date() }

    var todayEntries: [JournalEntry] {
        appModel.entries(on: appModel.selectedJournalDate)
    }

    private var preferredName: String {
        appModel.onboardingProfile.preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var greetingTitle: String {
        preferredName.isEmpty ? "Welcome" : "Welcome, \(preferredName)"
    }

    private var todayTitle: String {
        let dateText = todayDate.formatted(.dateTime.day().month(.wide))
        return "Today, \(dateText)"
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.section) {
                        Color.clear
                            .frame(height: 1)
                            .id("journal-top")
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(todayTitle)
                                .font(.title2.weight(.semibold))
                            Spacer()
                            Button {
                                showingSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.white.opacity(0.08), in: Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                    )
                                    .contentShape(Circle())
                            }
                            .accessibilityLabel("Settings")
                        }
                    }

                    VStack(spacing: 8) {
                        Text(greetingTitle)
                            .font(.largeTitle.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text("Log today, then review when you're done.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)

                    HStack {
                        Spacer()
                        AICircleView(
                            state: companionState,
                            size: 132,
                            strokeWidth: 3.2,
                            tint: appModel.journalCompanionTint,
                            lensFocusActive: companionLensFocusActive,
                            personality: appModel.companionPersonality,
                            trigger: companionTrigger
                        )
                        Spacer()
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    ReferenceCard {
                        VStack(spacing: 12) {
                            HStack {
                                Text("This week")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("History") {
                                    showingHistory = true
                                }
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                            }

                            WeekCalendarStripView(
                                selectedDate: $appModel.selectedJournalDate,
                                dates: appModel.centeredTodayDates,
                                hasEntry: { date in
                                    appModel.entries(on: date).isEmpty == false
                                }
                            )
                            .padding(.horizontal, -AppSpacing.page)
                        }
                    }
                    .padding(.top, 18)

                    if appModel.reflectionGoals.isEmpty == false {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(title: "Next steps")
                            ReferenceCard {
                                VStack(spacing: 0) {
                                    ForEach(appModel.reflectionGoals.prefix(3)) { goal in
                                        JournalGoalRow(goal: goal) {
                                            withAnimation(.snappy(duration: 0.22)) {
                                                appModel.toggleGoal(goal)
                                            }
                                        }

                                        if goal.id != appModel.reflectionGoals.prefix(3).last?.id {
                                            Divider()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(title: "Entries")
                        if todayEntries.isEmpty {
                            ReferenceCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Start with one note today.")
                                        .font(.headline)
                                    Text("A short check-in is enough. The review appears after you write.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            VStack(spacing: 10) {
                                ForEach(todayEntries) { entry in
                                    NavigationLink {
                                        EntryDetailView(entry: entry)
                                    } label: {
                                        ReferenceCard {
                                            EntryRowView(entry: entry)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    dayReviewSection
                }
                    .padding(AppSpacing.page)
                    .padding(.bottom, 110)
                }
                .onChange(of: router.selectedTab) { _, tab in
                    guard tab == .journal else { return }
                    proxy.scrollTo("journal-top", anchor: .top)
                }
            }
            .background {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.06),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, alignment: .trailing) {
                Button {
                    openComposer()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color(.systemBackground))
                        .frame(width: 58, height: 58)
                        .background(Color.primary, in: Circle())
                }
                .padding(.trailing, 20)
                .padding(.bottom, 10)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                .accessibilityLabel("New entry")
            }
            .alert("Update this day’s review?", isPresented: $showingReReviewConfirm) {
                Button("Cancel", role: .cancel) {
                    pendingReReviewDate = nil
                }
                Button("Update review") {
                    guard let date = pendingReReviewDate else { return }
                    pendingReReviewDate = nil
                    runReview(for: date)
                }
            } message: {
                Text("You added or changed entries after saving this review. Updating will replace today’s previous review.")
            }
            .sheet(isPresented: $showingNewEntry) {
                NewEntryView(initialMood: appModel.selectedMood, date: appModel.selectedJournalDate)
                    .presentationCornerRadius(28)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .presentationCornerRadius(28)
            }
            .sheet(isPresented: $showingHistory) {
                NavigationStack {
                    JournalHistoryView()
                }
                .presentationCornerRadius(28)
            }
            .sheet(item: $activeDailyReview) { review in
                NavigationStack {
                    DailyReviewView(review: review)
                }
                .presentationCornerRadius(28)
            }
            .animation(.snappy(duration: 0.22), value: todayEntries.count)
            .animation(.snappy(duration: 0.22), value: appModel.selectedJournalDate)
            .onAppear {
                handlePendingRouterActions()
            }
            .task {
                companionState = .attentive
                companionLensFocusActive = false
                while !Task.isCancelled {
                    let wait = UInt64(Int.random(in: 3_700_000_000...6_100_000_000))
                    try? await Task.sleep(nanoseconds: wait)
                    guard !Task.isCancelled else { return }
                    guard companionBusy == false else { continue }

                    if Bool.random() {
                        companionLensFocusActive = true
                        try? await Task.sleep(nanoseconds: 1_450_000_000)
                        companionLensFocusActive = false
                    }

                    let transient: [AICircleState] = [.attentive, .listening, .checkIn]
                    companionState = transient.randomElement() ?? .attentive
                    try? await Task.sleep(nanoseconds: 1_550_000_000)
                    if companionBusy == false {
                        companionState = .attentive
                    }
                }
            }
            .onChange(of: appModel.selectedJournalDate) {
                companionBusy = true
                companionState = .responding
                Task {
                    try? await Task.sleep(for: .milliseconds(420))
                    companionState = .attentive
                    companionBusy = false
                }
            }
            .onChange(of: todayEntries.count) { _, _ in
                guard companionBusy == false else { return }
                companionBusy = true
                companionTrigger += 1
                companionState = .responding
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    companionState = .attentive
                    companionBusy = false
                }
            }
            .onChange(of: router.pendingNewEntry) { _, _ in
                handlePendingRouterActions()
            }
            .onChange(of: router.pendingRunDailyReview) { _, _ in
                handlePendingRouterActions()
            }
            .onChange(of: showingNewEntry) { _, presented in
                if presented == false {
                    router.companionPresentation = .journal
                }
            }
            .onChange(of: router.selectedTab) { _, tab in
                guard tab == .journal else { return }
            }
        }
    }

    private var dayReviewSection: some View {
        let isSelectedDayToday = Calendar.current.isDate(appModel.selectedJournalDate, inSameDayAs: Date())
        let selectedDayReview = appModel.dailyReview(on: appModel.selectedJournalDate)
        return Group {
            if let review = selectedDayReview {
                    let hasChangesSinceReview = hasEntryChangesSinceReview(review, for: appModel.selectedJournalDate)
                    ReferenceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Text("Review saved for this day")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                            }
                            Text(review.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 10) {
                                Button {
                                    activeDailyReview = review
                                } label: {
                                    Label("Open review", systemImage: "doc.text.magnifyingglass")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.primary)
                                .foregroundStyle(Color(.systemBackground))

                                if isSelectedDayToday && hasChangesSinceReview {
                                    Button {
                                        pendingReReviewDate = appModel.selectedJournalDate
                                        showingReReviewConfirm = true
                                    } label: {
                                        Text("Update")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                        .overlay(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                .fill(appModel.journalCompanionTint.opacity(0.95))
                                .frame(width: 72, height: 3)
                                .offset(y: -8)
                        }
                    }
            } else if isSelectedDayToday == false {
                ReferenceCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No review saved for this day.")
                            .font(.subheadline.weight(.semibold))
                        Text("Daily review can only be created on the current day. Past entries still improve weekly insights.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if todayEntries.isEmpty == false {
                ReferenceCard {
                    HStack(spacing: 12) {
                        AICircleView(state: isReviewingDay ? .thinking : .attentive, size: 44, strokeWidth: 2, tint: appModel.journalCompanionTint)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Save the day")
                                .font(.subheadline.weight(.semibold))
                            Text("When you are done writing, review this date once.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            runReview(for: appModel.selectedJournalDate)
                        } label: {
                            Text(isReviewingDay ? "Saving" : "Review")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.primary)
                        .foregroundStyle(Color(.systemBackground))
                        .disabled(isReviewingDay)
                    }
                }
            }
        }
    }

    private func runReview(for date: Date) {
        guard Calendar.current.isDate(date, inSameDayAs: Date()) else { return }
        isReviewingDay = true
        companionBusy = true
        companionState = .thinking
        Task {
            companionTrigger += 1
            if let review = await appModel.reviewDay(date) {
                activeDailyReview = review
            }
            isReviewingDay = false
            companionState = .responding
            try? await Task.sleep(for: .milliseconds(450))
            companionState = .attentive
            companionBusy = false
        }
    }

    private func openComposer() {
        companionTrigger += 1
        router.companionPresentation = .transitioningToComposer
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            showingNewEntry = true
        }
    }

    private func handlePendingRouterActions() {
        if router.pendingNewEntry {
            showingNewEntry = true
            router.consumeNewEntry()
        }

        if router.pendingRunDailyReview {
            runReview(for: appModel.selectedJournalDate)
            router.consumeRunDailyReview()
        }
    }

    private func hasEntryChangesSinceReview(_ review: DailyReview, for date: Date) -> Bool {
        let currentIDs = Set(appModel.entries(on: date).map(\.id))
        let reviewedIDs = Set(review.entryIDs)
        return currentIDs != reviewedIDs
    }

}

private struct JournalGoalRow: View {
    let goal: ReflectionGoal
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: goal.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.title)
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(goal.status == .completed)
                    Text(goal.status == .completed ? "Marked done" : goal.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct NewEntryView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var mood: MoodLevel
    @State private var entryType: EntryType = .quickThought
    @State private var circleState: AICircleState = .idle
    @State private var isSaving = false
    @State private var streakFeedbackMessage = ""
    @State private var composeContentVisible = false
    @State private var companionDocked = false
    @State private var selectedTemplateID: JournalTemplate.ID?
    @StateObject private var voiceRecorder = VoiceJournalRecorder()
    @StateObject private var voiceModelManager = VoiceModelManager.shared
    @FocusState private var editorFocused: Bool

    private let date: Date

    init(initialMood: MoodLevel, date: Date = Date()) {
        _mood = State(initialValue: initialMood)
        self.date = date
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        AICircleView(state: circleState, size: 92, strokeWidth: 3, tint: mood.companionColor)
                            .scaleEffect(companionDocked ? 1 : 1.2)
                            .opacity(companionDocked ? 1 : 0.35)
                            .offset(x: 0, y: companionDocked ? 0 : -210)
                        Spacer()
                    }
                    .padding(.top, 6)
                    .animation(.spring(response: 0.52, dampingFraction: 0.86, blendDuration: 0.18), value: companionDocked)

                    VStack(spacing: 16) {
                        MoodSelectorView(selectedMood: $mood, size: 44, labelFont: .caption2, useMoodAccent: true)

                        EntryTypeSelectorView(
                            selection: $entryType,
                            accentColor: mood.interfaceAccentColor,
                            selectedForegroundColor: mood == .okay ? Color.black.opacity(0.78) : .white
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Label(entryType.label, systemImage: entryType.icon)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(mood.interfaceAccentColor)
                            Text(entryTypePrompt)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        JournalTemplateStrip(
                            templates: suggestedTemplates,
                            selectedTemplateID: selectedTemplateID,
                            accentColor: mood.interfaceAccentColor
                        ) { template in
                            applyTemplate(template)
                        }

                        if voiceModelManager.isVoiceEnabled {
                            voiceControls
                        }

                        TextEditor(text: $text)
                            .focused($editorFocused)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(AppSurface.stroke, lineWidth: 0.5)
                            }
                            .frame(minHeight: 260)
                            .onChange(of: text) { _, newValue in
                                guard isSaving == false else { return }
                                circleState = newValue.isEmpty ? (editorFocused ? .listening : .attentive) : .typing
                            }
                            .onChange(of: editorFocused) { _, focused in
                                guard isSaving == false else { return }
                                if focused, text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    circleState = .listening
                                } else if focused {
                                    circleState = .typing
                                } else if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    circleState = .attentive
                                }
                            }

                        if streakFeedbackMessage.isEmpty == false {
                            Text(streakFeedbackMessage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .transition(.opacity)
                        }
                    }
                    .opacity(composeContentVisible ? 1 : 0)
                    .offset(y: composeContentVisible ? 0 : 14)
                    .animation(.easeOut(duration: 0.28), value: composeContentVisible)
                }
                .padding(AppSpacing.page)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(
                LinearGradient(
                    colors: [Color(.secondarySystemBackground), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("What's on your mind?")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                router.companionPresentation = .composer
                companionDocked = false
                composeContentVisible = false
                withAnimation(.spring(response: 0.52, dampingFraction: 0.86, blendDuration: 0.18)) {
                    companionDocked = true
                }
                withAnimation(.easeOut(duration: 0.28).delay(0.2)) {
                    composeContentVisible = true
                }
            }
            .onDisappear {
                router.companionPresentation = .journal
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        editorFocused = false
                    }
                }
            }
            .onAppear {
                circleState = .attentive
            }
            .onChange(of: voiceRecorder.transcript) { _, transcript in
                guard transcript.isEmpty == false else { return }
                text = transcript
                circleState = .typing
            }
        }
    }

    private var voiceControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    voiceRecorder.toggleRecording()
                    editorFocused = false
                    circleState = voiceRecorder.isRecording ? .attentive : .listening
                } label: {
                    Label(voiceRecorder.isRecording ? "Stop voice" : "Voice entry", systemImage: voiceRecorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                }
                .buttonStyle(CompactIconButtonStyle())

                if voiceRecorder.transcript.isEmpty == false {
                    Button {
                        voiceRecorder.resetTranscript()
                        text = ""
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                }
            }

            switch voiceRecorder.state {
            case .requestingPermission:
                Text("Requesting microphone permission...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .recording:
                Text("Listening. Speak naturally, then stop when you are done.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .preparingModel:
                Text("Preparing the on-device voice model.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .transcribing:
                Text("Transcribing on device with WhisperKit...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .unavailable(let message):
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .idle:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var suggestedTemplates: [JournalTemplate] {
        let rankedDomains = appModel.onboardingProfile.assessment?.domains
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.domain < rhs.domain
                }
                return lhs.score > rhs.score
            }
            .map(\.domain) ?? []

        var ordered: [JournalTemplate] = []
        for domain in rankedDomains {
            let matches = JournalTemplate.all.filter { $0.domain.caseInsensitiveCompare(domain) == .orderedSame }
            for template in matches where ordered.contains(where: { $0.id == template.id }) == false {
                ordered.append(template)
            }
        }

        for template in JournalTemplate.defaultOrder where ordered.contains(where: { $0.id == template.id }) == false {
            ordered.append(template)
        }

        return Array(ordered.prefix(8))
    }

    private var entryTypePrompt: String {
        switch entryType {
        case .quickThought: "A short note. No need to explain everything."
        case .rant: "Write it raw. This is for getting it out, not making it tidy."
        case .reflection: "Look at what happened and what it might mean."
        case .win: "Record something that worked, however small."
        }
    }

    private func save() {
        editorFocused = false
        isSaving = true
        circleState = .thinking
        Task {
            try? await Task.sleep(for: .milliseconds(550))
            let streakBefore = appModel.currentStreakDays
            _ = appModel.addEntry(text: text, mood: mood, type: entryType, date: normalizedEntryDate(from: date))
            let streakAfter = appModel.currentStreakDays
            streakFeedbackMessage = streakFeedback(before: streakBefore, after: streakAfter, goal: appModel.streakGoalDays)
            circleState = .responding
            try? await Task.sleep(for: .milliseconds(900))
            dismiss()
        }
    }

    private func applyTemplate(_ template: JournalTemplate) {
        selectedTemplateID = template.id
        entryType = template.entryType
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            text = template.body
        } else {
            text = "\(trimmed)\n\n\(template.body)"
        }
        circleState = .typing
        editorFocused = true
    }

    private func normalizedEntryDate(from selectedDate: Date) -> Date {
        let calendar = Calendar.current
        let now = Date()

        guard calendar.isDate(selectedDate, inSameDayAs: now) == false else {
            return now
        }

        var day = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let time = calendar.dateComponents([.hour, .minute, .second], from: now)
        day.hour = time.hour
        day.minute = time.minute
        day.second = time.second
        return calendar.date(from: day) ?? selectedDate
    }

    private func streakFeedback(before: Int, after: Int, goal: Int) -> String {
        if after >= goal && before < goal {
            return "Streak goal reached: \(after)/\(goal) days."
        }
        if after > before {
            return "Streak updated: day \(after)."
        }
        if after == before && after > 0 {
            return "Check-in saved. Streak stays at \(after) days."
        }
        return "Check-in saved. Next day continues your streak."
    }
}

private struct JournalTemplate: Identifiable, Hashable {
    let id: String
    let title: String
    let domain: String
    let symbol: String
    let entryType: EntryType
    let body: String

    static let all: [JournalTemplate] = [
        .init(
            id: "anxiety-worry-loop",
            title: "Worry loop",
            domain: "Anxiety",
            symbol: "wind",
            entryType: .reflection,
            body: """
            Trigger:
            What my mind predicted:
            What my body did:
            What I avoided or wanted to avoid:
            What actually happened:
            One small calming or facing step:
            """
        ),
        .init(
            id: "anxiety-body-alarm",
            title: "Body alarm",
            domain: "Anxiety",
            symbol: "waveform.path.ecg",
            entryType: .quickThought,
            body: """
            Body cue:
            What I thought it meant:
            What else could explain it:
            What helped it drop even slightly:
            One thing I can do in the next 10 minutes:
            """
        ),
        .init(
            id: "mood-low-energy",
            title: "Low energy",
            domain: "Mood",
            symbol: "battery.25",
            entryType: .reflection,
            body: """
            Energy today:
            What I put off:
            What I said to myself:
            What gave even a small lift:
            One 5-minute action that would count:
            """
        ),
        .init(
            id: "mood-self-talk",
            title: "Self-talk",
            domain: "Mood",
            symbol: "quote.bubble",
            entryType: .reflection,
            body: """
            The harsh thought:
            What triggered it:
            What evidence supports it:
            What evidence softens it:
            A fairer sentence I can try:
            """
        ),
        .init(
            id: "stress-overload",
            title: "Overload",
            domain: "Stress",
            symbol: "exclamationmark.triangle",
            entryType: .reflection,
            body: """
            What felt like too much:
            What was actually urgent:
            What was just loud:
            Where stress showed up in my body:
            One thing to remove, delay, or ask help with:
            """
        ),
        .init(
            id: "stress-boundary",
            title: "Boundary",
            domain: "Stress",
            symbol: "hand.raised",
            entryType: .quickThought,
            body: """
            The pressure:
            What I need to protect:
            What I can say no to or make smaller:
            The shortest clear sentence:
            What I will do after:
            """
        ),
        .init(
            id: "functioning-day-harder",
            title: "Harder today",
            domain: "Functioning",
            symbol: "list.bullet.clipboard",
            entryType: .reflection,
            body: """
            What was harder than usual:
            Biggest blocker: sleep, focus, energy, people, or load:
            What still got done:
            What made the day 5% easier:
            One practical support to set up tomorrow:
            """
        ),
        .init(
            id: "functioning-support",
            title: "Support",
            domain: "Functioning",
            symbol: "person.2",
            entryType: .quickThought,
            body: """
            Where I got stuck:
            What I need:
            Who or what could help:
            The smallest ask:
            When I will ask:
            """
        ),
        .init(
            id: "relationship-rejection",
            title: "Interaction",
            domain: "Relationships",
            symbol: "bubble.left.and.text.bubble.right",
            entryType: .reflection,
            body: """
            The interaction:
            The story I told myself:
            Evidence for that story:
            Evidence that softens it:
            A calm repair or clarification:
            """
        ),
        .init(
            id: "avoidance-facing",
            title: "Avoidance",
            domain: "Anxiety",
            symbol: "arrow.uturn.backward",
            entryType: .reflection,
            body: """
            What I avoided:
            The feeling I was trying not to feel:
            What avoidance protected short-term:
            What it cost:
            The smallest safe version of facing it:
            """
        ),
        .init(
            id: "numbing-coping",
            title: "Numbing",
            domain: "Functioning",
            symbol: "moon.zzz",
            entryType: .reflection,
            body: """
            What I used to switch off:
            What feeling came before it:
            Did it help after 10 minutes:
            Did it help after 2 hours:
            What need was underneath:
            A lower-cost replacement:
            """
        ),
        .init(
            id: "sleep-wind-down",
            title: "Sleep",
            domain: "Functioning",
            symbol: "bed.double",
            entryType: .quickThought,
            body: """
            Sleep last night:
            The hour before bed:
            Thoughts that kept looping:
            What helped even slightly:
            One wind-down cue to repeat:
            """
        )
    ]

    static var defaultOrder: [JournalTemplate] {
        [
            template("anxiety-worry-loop"),
            template("mood-low-energy"),
            template("stress-overload"),
            template("functioning-day-harder"),
            template("relationship-rejection"),
            template("avoidance-facing"),
            template("numbing-coping"),
            template("sleep-wind-down")
        ]
        .compactMap { $0 }
    }

    private static func template(_ id: String) -> JournalTemplate? {
        all.first { $0.id == id }
    }
}

private struct JournalTemplateStrip: View {
    let templates: [JournalTemplate]
    let selectedTemplateID: JournalTemplate.ID?
    let accentColor: Color
    let onSelect: (JournalTemplate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Templates")
                    .font(.subheadline.weight(.semibold))
                ExplainerButton(
                    title: "Guided templates",
                    body: "Templates help you give the review engine better evidence without making you write a perfect journal entry.",
                    bullets: [
                        "They are ranked from your strongest onboarding domains.",
                        "Tapping one inserts editable prompts into the composer.",
                        "You can ignore the structure and write naturally anytime."
                    ],
                    symbol: "questionmark.circle"
                )
                Spacer()
                Text("Guided")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(templates) { template in
                        JournalTemplateChip(
                            template: template,
                            selected: selectedTemplateID == template.id,
                            accentColor: accentColor
                        ) {
                            onSelect(template)
                        }
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct JournalTemplateChip: View {
    let template: JournalTemplate
    let selected: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: template.symbol)
                    .font(.caption.weight(.semibold))
                Text(template.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .foregroundStyle(selected ? Color(.systemBackground) : .primary)
            .background(selected ? accentColor : AppSurface.fill, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(selected ? accentColor : AppSurface.stroke, lineWidth: 0.5)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(template.title) template")
    }
}

struct EntryTypeSelectorView: View {
    @Binding var selection: EntryType
    var accentColor: Color = .primary
    var selectedForegroundColor: Color = .white

    var body: some View {
        HStack(spacing: 8) {
            ForEach(EntryType.allCases) { type in
                Button {
                    selection = type
                } label: {
                    VStack(spacing: 7) {
                        Image(systemName: type.icon)
                            .font(.subheadline.weight(.semibold))
                        Text(type.label)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .foregroundStyle(selection == type ? selectedForegroundColor : .primary)
                    .background(selection == type ? accentColor : AppSurface.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(selection == type ? accentColor : AppSurface.stroke, lineWidth: 0.5)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(type.label)
            }
        }
    }
}

struct EntryTypePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: EntryType

    var body: some View {
        NavigationStack {
            List {
                ForEach(EntryType.allCases) { type in
                    Button {
                        selection = type
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: type.icon)
                                .font(.headline)
                                .frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.label)
                                    .font(.subheadline.weight(.semibold))
                                Text(typeSubtitle(type))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selection == type {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.primary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Entry type")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func typeSubtitle(_ type: EntryType) -> String {
        switch type {
        case .quickThought: "Capture a short thought"
        case .rant: "Get something off your chest"
        case .reflection: "Look at the day clearly"
        case .win: "Record something that worked"
        }
    }
}

struct EntryDetailView: View {
    @EnvironmentObject private var appModel: AppViewModel
    let entry: JournalEntry
    @State private var activeDailyReview: DailyReview?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                ReferenceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.text)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)

                        if let healthContext {
                            Divider()
                                .padding(.vertical, 2)
                            Label(healthContext, systemImage: "moon")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let review = appModel.dailyReview(on: entry.date) {
                    ReferenceCard {
                        Button {
                            activeDailyReview = review
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle")
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Included in day review")
                                        .font(.subheadline.weight(.semibold))
                                    Text(review.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(AppSpacing.page)
        }
        .navigationTitle(entry.entryType.label)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $activeDailyReview) { review in
            NavigationStack {
                DailyReviewView(review: review)
            }
            .presentationCornerRadius(28)
        }
    }

    private var healthContext: String? {
        let sleep = entry.sleepHours.map { "Slept \($0.cleanHours)" }
        let steps = entry.steps.map { "\($0.formatted()) steps" }
        let parts = [sleep, steps].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

#Preview {
    JournalView()
        .environmentObject(AppViewModel())
}
