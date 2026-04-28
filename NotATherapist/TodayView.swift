import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var circleState: AICircleState = .idle
    @State private var showingNewEntry = false
    @State private var showingWeekly = false
    @State private var showingSettings = false
    @State private var activeDailyReview: DailyReview?
    @State private var isReviewingToday = false

    private var todayEntries: [JournalEntry] {
        appModel.entries(on: Date())
    }

    private var todayReview: DailyReview? {
        appModel.dailyReview(on: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    HStack {
                        Spacer()
                        AICircleView(state: circleState, size: 104, strokeWidth: 3.2)
                        Spacer()
                    }
                    .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("How are you feeling?")
                            .font(.subheadline.weight(.semibold))
                        MoodSelectorView(selectedMood: $appModel.selectedMood)
                    }

                    Button {
                        showingNewEntry = true
                    } label: {
                        Label("New entry", systemImage: "pencil")
                    }
                    .buttonStyle(PrimaryCapsuleButtonStyle())

                    ReferenceCard {
                        HStack(spacing: 12) {
                            Image(systemName: todayEntries.isEmpty ? "book.closed" : "book")
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(todayEntries.count == 0 ? "No entries today" : "\(todayEntries.count) \(todayEntries.count == 1 ? "entry" : "entries") today")
                                    .font(.subheadline.weight(.semibold))
                                Text(todayReview == nil ? "Save what matters. Review when the day feels done." : "Today has been reviewed.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }

                    if appModel.reflectionGoals.isEmpty == false {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(title: "Agreed next steps")
                            ReferenceCard {
                                VStack(spacing: 0) {
                                    ForEach(appModel.reflectionGoals.prefix(3)) { goal in
                                        ReflectionGoalRow(goal: goal) {
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

                    if let todayReview {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(title: "Today's review")
                            Button {
                                activeDailyReview = todayReview
                            } label: {
                                ReferenceCard {
                                    HStack(alignment: .center, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(todayReview.summary)
                                                .font(.subheadline.weight(.semibold))
                                            Text(todayReview.insight.action)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if appModel.journalEntries.isEmpty {
                        ReferenceCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Start with one entry.")
                                    .font(.subheadline.weight(.semibold))
                                Text("Reviews and patterns appear after you write.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else if todayReview == nil, todayEntries.isEmpty == false {
                        ReferenceCard {
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Ready to review today.")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Run a short review when you are finished writing for the day.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Button {
                                    isReviewingToday = true
                                    circleState = .thinking
                                    Task {
                                        if let review = await appModel.reviewDay(Date()) {
                                            activeDailyReview = review
                                        }
                                        isReviewingToday = false
                                        circleState = .responding
                                        try? await Task.sleep(for: .milliseconds(450))
                                        circleState = .idle
                                    }
                                } label: {
                                    Label(isReviewingToday ? "Reviewing" : "Review today", systemImage: "sparkle.magnifyingglass")
                                }
                                .buttonStyle(PrimaryCapsuleButtonStyle())
                                .disabled(isReviewingToday)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(title: "This week")
                        ReferenceCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    ForEach(appModel.currentWeekDates, id: \.self) { date in
                                        let checked = appModel.entries(on: date).isEmpty == false
                                        VStack(spacing: 5) {
                                            Circle()
                                                .fill(checked ? Color.primary : Color.clear)
                                                .frame(width: 8, height: 8)
                                                .overlay {
                                                    Circle().stroke(AppSurface.stroke, lineWidth: 0.5)
                                                }
                                            Text(date.shortDay.prefix(1))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                                Text("\(appModel.checkInCountThisWeek()) of 7 days checked in")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if appModel.hasWeeklyReview {
                        ReferenceCard {
                            HStack(spacing: 12) {
                                AICircleView(state: .checkIn, size: 42, strokeWidth: 2.1)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("I noticed a few patterns this week.")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Weekly review is ready")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Review") {
                                    showingWeekly = true
                                }
                                .buttonStyle(CompactIconButtonStyle())
                            }
                        }
                    }
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
            }
            .sheet(isPresented: $showingNewEntry) {
                NewEntryView(initialMood: appModel.selectedMood)
                    .presentationCornerRadius(28)
            }
            .sheet(isPresented: $showingWeekly) {
                NavigationStack {
                    WeeklyReviewView(review: appModel.weeklyReview)
                }
                .presentationCornerRadius(28)
            }
            .sheet(item: $activeDailyReview) { review in
                NavigationStack {
                    DailyReviewView(review: review)
                }
                .presentationCornerRadius(28)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .presentationDetents([.medium])
                    .presentationCornerRadius(28)
            }
            .onAppear { circleState = .idle }
            .onChange(of: appModel.selectedMood) {
                circleState = .responding
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    circleState = .idle
                }
            }
        }
    }
}

private struct ReflectionGoalRow: View {
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
                    Text(goal.status == .completed ? "Logged as done" : goal.reason)
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

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @EnvironmentObject private var notificationService: NotificationService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var exportURL: URL?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section("About") {
                    LabeledContent("App", value: "Not a Therapist")
                    LabeledContent("Mode", value: "Local-first")
                    LabeledContent("AI", value: appModel.aiConnection.label)
                    Button("Check AI connection") {
                        Task {
                            await appModel.refreshAIConnection()
                        }
                    }
                }

                Section("Scope") {
                    Text("This is a reflection tool. It is not therapy, and it does not diagnose, treat, cure, or replace professional help.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Apple Health") {
                    LabeledContent("Status", value: healthKitManager.summary == nil ? "Off" : "Connected")

                    if let summary = healthKitManager.summary {
                        LabeledContent("Context", value: "\(summary.lastNightSleep.cleanHours) sleep · \(summary.averageSteps.formatted()) avg steps")
                            .font(.subheadline)
                        Text("Used only to add quiet context to insights and weekly reviews.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button(healthKitManager.summary == nil ? "Connect Apple Health" : "Refresh Health context") {
                        Task {
                            await healthKitManager.requestPermissionsAndRefresh()
                            appModel.updateHealthSummary(healthKitManager.summary)
                        }
                    }
                }

                Section("Weekly review reminder") {
                    Toggle(
                        "Notify when review is ready",
                        isOn: Binding(
                            get: { notificationService.isWeeklyReminderEnabled },
                            set: { enabled in
                                Task {
                                    await notificationService.setWeeklyReminderEnabled(enabled)
                                }
                            }
                        )
                    )

                    Picker(
                        "Day",
                        selection: Binding(
                            get: { notificationService.weeklyReminderWeekday },
                            set: { weekday in
                                Task {
                                    await notificationService.updateWeeklyReminderWeekday(weekday)
                                }
                            }
                        )
                    ) {
                        ForEach(ReminderWeekday.allCases) { weekday in
                            Text(weekday.label).tag(weekday.rawValue)
                        }
                    }
                    .disabled(notificationService.isWeeklyReminderEnabled == false)

                    LabeledContent("Time", value: "18:00")
                    LabeledContent("Permission", value: notificationService.authorizationLabel)

                    if notificationService.authorizationStatus == .denied {
                        Button("Open iOS Settings") {
                            notificationService.openAppSettings()
                        }
                    }
                }

                Section {
                    Button("Show onboarding again") {
                        hasCompletedOnboarding = false
                        dismiss()
                    }
                }

                Section("Privacy") {
                    Text("Journal data is stored locally on this device. Reviews are sent to the API only when you request them.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Export local data") {
                        exportURL = appModel.exportLocalData()
                    }

                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Share export", systemImage: "square.and.arrow.up")
                        }
                    }

                    Button("Delete journal data", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await notificationService.refreshAuthorizationStatus()
                await appModel.refreshAIConnection()
            }
            .confirmationDialog(
                "Delete journal data?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete journal data", role: .destructive) {
                    appModel.deleteLocalData()
                    exportURL = nil
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes entries, reviews, goals, conversations, insights, and saved Health context from this device.")
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct InsightDetailView: View {
    let insight: Insight

    var body: some View {
        List {
            Section {
                InsightSectionView(title: insight.title, bodyText: insight.body, symbol: insight.type.symbol)
                Text(insight.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(insight.type.label)
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview {
    TodayView()
        .environmentObject(AppViewModel())
        .environmentObject(NotificationService.shared)
}
