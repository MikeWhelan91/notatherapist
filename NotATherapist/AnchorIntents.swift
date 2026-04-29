import AppIntents

private struct AnchorIntentCommandWriter {
    static let store = AppCommandStore()

    static func write(_ command: AnchorAppCommand) {
        store.set(command)
    }
}

struct NewQuickThoughtIntent: AppIntent {
    static var title: LocalizedStringResource = "New Quick Thought"
    static var description = IntentDescription("Open Anchor and start a quick thought entry.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        AnchorIntentCommandWriter.write(.newQuickThought)
        return .result()
    }
}

struct RunDailyReviewIntent: AppIntent {
    static var title: LocalizedStringResource = "Run Daily Review"
    static var description = IntentDescription("Open Anchor and run today's daily review.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        AnchorIntentCommandWriter.write(.runDailyReview)
        return .result()
    }
}

struct StartWeeklyCheckInIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Weekly Check-In"
    static var description = IntentDescription("Open Anchor and start a weekly check-in conversation.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        AnchorIntentCommandWriter.write(.startWeeklyCheckIn)
        return .result()
    }
}

struct NextAffirmationAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Affirmation"
    static var description = IntentDescription("Cycle to the next affirmation in Anchor.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        AnchorIntentCommandWriter.write(.nextAffirmation)
        return .result()
    }
}

struct AnchorShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NewQuickThoughtIntent(),
            phrases: [
                "New quick thought in \(.applicationName)",
                "Log a thought in \(.applicationName)"
            ],
            shortTitle: "New Thought",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: RunDailyReviewIntent(),
            phrases: [
                "Run daily review in \(.applicationName)",
                "Review today in \(.applicationName)"
            ],
            shortTitle: "Daily Review",
            systemImageName: "doc.text.magnifyingglass"
        )
        AppShortcut(
            intent: StartWeeklyCheckInIntent(),
            phrases: [
                "Start weekly check-in in \(.applicationName)",
                "Open weekly check-in in \(.applicationName)"
            ],
            shortTitle: "Weekly Check-In",
            systemImageName: "bubble.left.and.bubble.right"
        )
        AppShortcut(
            intent: NextAffirmationAppIntent(),
            phrases: [
                "Next affirmation in \(.applicationName)",
                "Cycle affirmation in \(.applicationName)"
            ],
            shortTitle: "Next Affirmation",
            systemImageName: "arrow.triangle.2.circlepath"
        )
    }
}
