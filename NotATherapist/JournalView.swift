import SwiftUI

struct JournalView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var showingNewEntry = false
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var activeDailyReview: DailyReview?
    @State private var isReviewingDay = false

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(greetingTitle)
                            .font(.largeTitle.weight(.semibold))
                        Text("Log today, then review when you're done.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Spacer()
                        AICircleView(state: .idle, size: 112, strokeWidth: 3)
                        Spacer()
                    }
                    .padding(.vertical, 4)

                    WeekCalendarStripView(selectedDate: $appModel.selectedJournalDate, dates: appModel.currentWeekDates)
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
                        HStack {
                            Text("\(todayEntries.count) \(todayEntries.count == 1 ? "entry" : "entries") on this date")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                showingHistory = true
                            } label: {
                                Label("Browse dates", systemImage: "calendar")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.plain)
                        }
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
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingHistory = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel("Browse dates")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showingNewEntry = true
                } label: {
                    Label("New entry", systemImage: "square.and.pencil")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color(.systemBackground))
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color.primary, in: Capsule())
                }
                .padding(.trailing, 22)
                .padding(.bottom, 22)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                .accessibilityLabel("New entry")
            }
            .sheet(isPresented: $showingNewEntry) {
                NewEntryView(initialMood: appModel.selectedMood, date: todayDate)
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
        }
    }

    @ViewBuilder
    private var dayReviewSection: some View {
        if todayEntries.isEmpty == false {
            if let review = appModel.dailyReview(on: appModel.selectedJournalDate) {
                ReferenceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            AICircleView(state: .settled, size: 44, strokeWidth: 2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Day reviewed")
                                    .font(.subheadline.weight(.semibold))
                                Text(review.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }

                        Button {
                            activeDailyReview = review
                        } label: {
                            Label("Open review", systemImage: "doc.text.magnifyingglass")
                        }
                        .buttonStyle(PrimaryCapsuleButtonStyle())
                    }
                }
            } else {
                ReferenceCard {
                    HStack(spacing: 12) {
                        AICircleView(state: isReviewingDay ? .thinking : .idle, size: 44, strokeWidth: 2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Save the day")
                                .font(.subheadline.weight(.semibold))
                            Text("When you are done writing, review this date once.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            isReviewingDay = true
                            Task {
                                if let review = await appModel.reviewDay(appModel.selectedJournalDate) {
                                    activeDailyReview = review
                                }
                                isReviewingDay = false
                            }
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
    @FocusState private var editorFocused: Bool

    private let date: Date

    init(initialMood: MoodLevel, date: Date = Date()) {
        _mood = State(initialValue: initialMood)
        self.date = date
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    AICircleView(state: circleState, size: 92, strokeWidth: 3)
                    Spacer()
                }
                .padding(.top, -10)
                .padding(.bottom, -4)

                MoodSelectorView(selectedMood: $mood, size: 44, labelFont: .caption2)
                    .padding(.top, -2)

                EntryTypeSelectorView(selection: $entryType)

                VStack(alignment: .leading, spacing: 6) {
                    Label(entryType.label, systemImage: entryType.icon)
                        .font(.subheadline.weight(.semibold))
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
                        circleState = newValue.isEmpty ? .idle : .typing
                    }

            }
            .padding(AppSpacing.page)
            .background(Color(.secondarySystemBackground))
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
            _ = appModel.addEntry(text: text, mood: mood, type: entryType, date: date)
            circleState = .responding
            try? await Task.sleep(for: .milliseconds(300))
            dismiss()
        }
    }
}

struct EntryTypeSelectorView: View {
    @Binding var selection: EntryType

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
                    .foregroundStyle(selection == type ? Color(.systemBackground) : .primary)
                    .background(selection == type ? Color.primary : AppSurface.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(selection == type ? Color.primary : AppSurface.stroke, lineWidth: 0.5)
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
