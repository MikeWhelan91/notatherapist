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
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(todayTitle)
                            .font(.largeTitle.weight(.semibold))
                        Spacer()
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .frame(width: 46, height: 46)
                                .background(Color.white.opacity(0.08), in: Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                )
                        }
                        .accessibilityLabel("Settings")
                    }

                    VStack(spacing: 8) {
                        Text(greetingTitle)
                            .font(.title.weight(.semibold))
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
                            size: 116,
                            strokeWidth: 3,
                            tint: appModel.companionTint,
                            lensFocusActive: companionLensFocusActive
                        )
                        Spacer()
                    }
                    .padding(.vertical, 4)

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
                        },
                        dayMoodColor: { date in
                            dayMoodColor(for: date)
                        }
                    )
                        .padding(.horizontal, -AppSpacing.page)

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
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Start with one note today.")
                                    .font(.headline)
                                Text("A short check-in is enough. The review appears after you write.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
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
                .padding(.bottom, 86)
            }
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showingNewEntry = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color(.systemBackground))
                        .frame(width: 58, height: 58)
                        .background(Color.primary, in: Circle())
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
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
            .onChange(of: router.pendingNewEntry) { _, _ in
                handlePendingRouterActions()
            }
            .onChange(of: router.pendingRunDailyReview) { _, _ in
                handlePendingRouterActions()
            }
        }
    }

    private var dayReviewSection: some View {
        let isSelectedDayToday = Calendar.current.isDate(appModel.selectedJournalDate, inSameDayAs: Date())
        return Group {
            if isSelectedDayToday == false {
                ReferenceCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Daily review is available for today only.")
                            .font(.subheadline.weight(.semibold))
                        Text("Past entries still improve weekly AI insights and trend quality.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if todayEntries.isEmpty == false {
                if let review = appModel.dailyReview(on: appModel.selectedJournalDate) {
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
                                .buttonStyle(PrimaryCapsuleButtonStyle())

                                if hasChangesSinceReview {
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
                                .fill(appModel.companionTint.opacity(0.95))
                                .frame(width: 72, height: 3)
                                .offset(y: -8)
                        }
                    }
                } else {
                    ReferenceCard {
                        HStack(spacing: 12) {
                            AICircleView(state: isReviewingDay ? .thinking : .attentive, size: 44, strokeWidth: 2, tint: appModel.companionTint)
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
    }

    private func runReview(for date: Date) {
        guard Calendar.current.isDate(date, inSameDayAs: Date()) else { return }
        isReviewingDay = true
        companionBusy = true
        companionState = .thinking
        Task {
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

    private func dayMoodColor(for date: Date) -> Color? {
        appModel.latestEntry(on: date)?.mood.companionColor
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
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var mood: MoodLevel
    @State private var entryType: EntryType = .quickThought
    @State private var circleState: AICircleState = .idle
    @State private var isSaving = false
    @State private var streakFeedbackMessage = ""
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
                        Spacer()
                    }
                    .padding(.top, 6)

                    MoodSelectorView(selectedMood: $mood, size: 44, labelFont: .caption2, useMoodAccent: true)

                    EntryTypeSelectorView(selection: $entryType, accentColor: mood.companionColor)

                    VStack(alignment: .leading, spacing: 6) {
                        Label(entryType.label, systemImage: entryType.icon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(mood.companionColor)
                        Text(entryTypePrompt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

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
        }
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

struct EntryTypeSelectorView: View {
    @Binding var selection: EntryType
    var accentColor: Color = .primary

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
                    .foregroundStyle(selection == type ? Color.white : .primary)
                    .background(selection == type ? accentColor : AppSurface.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(selection == type ? accentColor : AppSurface.stroke, lineWidth: 0.5)
                    }
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
