import Foundation

struct MockAIInsightService {
    func dailyReview(
        for date: Date,
        entries: [JournalEntry],
        recentEntries: [JournalEntry] = [],
        profile: OnboardingProfile = .current,
        healthSummary: HealthSummary? = nil
    ) -> DailyReview? {
        guard entries.isEmpty == false else { return nil }

        let sortedEntries = entries.sorted { $0.date < $1.date }
        let combinedText = sortedEntries.map(\.text).joined(separator: " ")
        let lowerText = combinedText.lowercased()
        let averageMood = Double(sortedEntries.map(\.mood.score).reduce(0, +)) / Double(sortedEntries.count)
        let themes = sortedEntries.flatMap(\.themes)
        let topTheme = Dictionary(grouping: themes, by: { $0 })
            .mapValues(\.count)
            .max { $0.value < $1.value }?
            .key
        let hasPreviousData = recentEntries.contains { Calendar.current.isDate($0.date, inSameDayAs: date) == false }

        let summary: String
        if sortedEntries.count == 1, let entry = sortedEntries.first {
            summary = "You logged one \(entry.entryType.label.lowercased()) today."
        } else {
            summary = "You wrote \(sortedEntries.count) entries today."
        }

        let emotionalRead: String
        if (lowerText.contains("anxiety") || lowerText.contains("anxious")) && sortedEntries.contains(where: { $0.entryType == .win }) {
            emotionalRead = "You noted anxiety, and also recorded something that went well."
        } else if lowerText.contains("anxiety") || lowerText.contains("anxious") {
            emotionalRead = "Anxiety seems to be part of today's context."
        } else if sortedEntries.contains(where: { $0.entryType == .win }) || averageMood >= 4 {
            emotionalRead = hasPreviousData ? "Today includes a steadier note." : "There is a steady moment in today's entries."
        } else if lowerText.contains("overwhel") || lowerText.contains("too much") || averageMood <= 2.4 {
            emotionalRead = "Today sounds heavy and a little crowded."
        } else {
            emotionalRead = "Today has a few threads worth noticing."
        }

        let pattern: String
        if let sleepHours = sortedEntries.first(where: { $0.sleepHours != nil })?.sleepHours, sleepHours < 6.25, averageMood <= 3.2 {
            pattern = "Lower sleep may have shaped the tone of the day."
        } else if let steps = sortedEntries.first(where: { $0.steps != nil })?.steps, steps >= 7500, averageMood >= 3.5 {
            pattern = "More movement may be linked with a steadier day."
        } else if lowerText.contains("drove") || lowerText.contains("driving") {
            pattern = "Driving showed up as something you were watching closely."
        } else if let topTheme {
            pattern = "\(topTheme) was the clearest theme today."
        } else {
            pattern = "The useful signal is still early."
        }

        let reframe: String
        if sortedEntries.contains(where: { $0.entryType == .win }) {
            reframe = "This is worth recording as evidence of what can go right."
        } else if lowerText.contains("again") || lowerText.contains("same") {
            reframe = "A repeated thought may need one clear next step, not more time in your head."
        } else {
            reframe = "You do not need to solve the whole pattern from one day."
        }

        let action: String
        let goalTitle: String
        let goalReason: String
        if lowerText.contains("drove") || lowerText.contains("driving") {
            action = "If the drive feels tense again, name one thing that helped today before leaving."
            goalTitle = "Capture one driving anchor"
            goalReason = "You referenced driving directly, so this can be tested tomorrow."
        } else if sortedEntries.contains(where: { $0.entryType == .win }) {
            action = "If a good moment appears tomorrow, write one line on what made it possible."
            goalTitle = "Repeat one useful condition"
            goalReason = "Today's win gives a concrete condition you can repeat."
        } else if themes.contains("Work") {
            action = "If work loops start spinning tomorrow, close or park one decision in under 10 minutes."
            goalTitle = "Close one work loop"
            goalReason = "Work showed up repeatedly, so one clear closure is measurable."
        } else if themes.contains("Anxiety") {
            action = "If anxiety rises tomorrow, do a 60-second reset before deciding what to do next."
            goalTitle = "Use a 60-second reset once"
            goalReason = "Anxiety appeared in today's entries, so this is a direct test."
        } else {
            action = "If the same thought comes back tomorrow, write one next action and stop there."
            goalTitle = ""
            goalReason = ""
        }

        return DailyReview(
            id: UUID(),
            date: date,
            summary: summary,
            insight: StructuredInsight(
                emotionalRead: emotionalRead,
                pattern: pattern,
                reframe: reframe,
                action: action
            ),
            suggestedGoalTitle: goalTitle,
            suggestedGoalReason: goalReason,
            acceptedGoalID: nil,
            entryIDs: sortedEntries.map(\.id),
            createdAt: Date()
        )
    }

    func insight(
        for entry: JournalEntry,
        recentEntries: [JournalEntry],
        profile: OnboardingProfile = .current,
        healthSummary: HealthSummary? = nil
    ) -> StructuredInsight {
        let lowerText = entry.text.lowercased()
        let workCount = recentEntries.filter { $0.themes.contains("Work") }.count
        let sleepCount = recentEntries.filter { $0.themes.contains("Sleep") }.count

        let emotional: String
        if lowerText.contains("overwhel") || lowerText.contains("too much") {
            emotional = "You sound tense and overloaded."
        } else if lowerText.contains("stuck") || lowerText.contains("can't") {
            emotional = "You sound caught between wanting movement and not seeing the next step."
        } else if entry.mood.score >= 4 {
            emotional = "There is some steadiness in this entry."
        } else {
            emotional = "This reads like something has been taking up more room than usual."
        }

        let pattern: String
        if let sleepHours = entry.sleepHours, sleepHours < 6.25, entry.mood.score <= 3 {
            pattern = "You slept \(sleepHours.cleanHours) last night. Lower sleep often lines up with lower mood."
        } else if let steps = entry.steps, steps >= 7500, entry.mood.score >= 4 {
            pattern = "Better mood tends to appear on more active days."
        } else if profile.focusAreas.contains("Unfinished tasks or decisions"), lowerText.contains("again") || lowerText.contains("same") {
            pattern = "The same unfinished decision seems to be taking attention again."
        } else if workCount >= 3 {
            pattern = "This is the third work-related entry this week."
        } else if sleepCount >= 2 {
            pattern = "Sleep has come up more than once recently."
        } else if let healthSummary, healthSummary.trend == .down, entry.mood.score <= 3 {
            pattern = "Lower movement this week may be linked with your energy."
        } else if entry.entryType == .win {
            pattern = "Wins seem to appear when you name something specific."
        } else {
            pattern = "This seems connected to something unfinished rather than one single event."
        }

        let reframe: String
        if lowerText.contains("failed") || lowerText.contains("failure") {
            reframe = "This looks less like failure and more like too many unfinished things at once."
        } else if lowerText.contains("should") {
            reframe = "The pressure may be coming from an old rule rather than what matters today."
        } else {
            reframe = "This may be easier to handle as one small decision, not a full life verdict."
        }

        let action: String
        if lowerText.contains("work") || entry.themes.contains("Work") {
            action = "Pick one unfinished thing to finish or park."
        } else if lowerText.contains("sleep") || entry.themes.contains("Sleep") {
            action = "Choose a stop point tonight and leave the rest written down."
        } else {
            action = "Name the next smallest action and leave the rest for later."
        }

        return StructuredInsight(
            emotionalRead: emotional,
            pattern: pattern,
            reframe: reframe,
            action: action
        )
    }

    func themes(for text: String, entryType: EntryType) -> [String] {
        let lower = text.lowercased()
        var themes: [String] = []

        if lower.contains("work") || lower.contains("meeting") || lower.contains("deadline") || lower.contains("manager") || lower.contains("client") || lower.contains("email") {
            themes.append("Work")
        }
        if lower.contains("sleep") || lower.contains("tired") || lower.contains("night") || lower.contains("exhausted") || lower.contains("drained") {
            themes.append("Sleep")
        }
        if lower.contains("run") || lower.contains("walk") || lower.contains("gym") || lower.contains("movement") || lower.contains("exercise") || lower.contains("outside") {
            themes.append("Movement")
        }
        if lower.contains("friend") || lower.contains("family") || lower.contains("message") || lower.contains("partner") || lower.contains("relationship") {
            themes.append("Relationships")
        }
        if lower.contains("anxiety") || lower.contains("anxious") || lower.contains("panic") || lower.contains("worry") || lower.contains("worried") {
            themes.append("Anxiety")
        }
        if lower.contains("sad") || lower.contains("low mood") || lower.contains("depressed") || lower.contains("flat") || lower.contains("empty") {
            themes.append("Low mood")
        }
        if lower.contains("adhd") || lower.contains("focus") || lower.contains("distracted") || lower.contains("attention") || lower.contains("procrastinat") {
            themes.append("Focus")
        }
        if lower.contains("stuck") || lower.contains("loop") || lower.contains("decision") || lower.contains("unfinished") || lower.contains("again") {
            themes.append("Open loops")
        }
        if lower.contains("stress") || lower.contains("overwhelm") || lower.contains("too much") || lower.contains("burnout") {
            themes.append("Stress")
        }
        if entryType == .win {
            themes.append("Progress")
        }

        return themes.isEmpty ? ["Reflection"] : Array(Set(themes)).sorted()
    }

    func localSignals(
        from entries: [JournalEntry],
        dailyReviews: [DailyReview],
        goals: [ReflectionGoal],
        healthSummary: HealthSummary?
    ) -> [Insight] {
        guard entries.count >= 2 else { return [] }

        let recent = entries
            .sorted { $0.date > $1.date }
            .prefix(30)
        var signals: [Insight] = []
        let now = Date()

        let themeCounts = Dictionary(grouping: recent.flatMap(\.themes), by: { $0 }).mapValues(\.count)
        if let topTheme = themeCounts
            .filter({ $0.key != "Reflection" && $0.value >= 2 })
            .max(by: { $0.value < $1.value }) {
            signals.append(
                Insight(
                    id: UUID(),
                    title: "\(topTheme.key) is repeating",
                    body: "\(topTheme.key) has appeared in \(topTheme.value) recent entries.",
                    category: "Local signals",
                    date: now,
                    type: .pattern
                )
            )
        }

        let lowMoodEntries = recent.filter { $0.mood.score <= 2 }
        if lowMoodEntries.count >= 2 {
            signals.append(
                Insight(
                    id: UUID(),
                    title: "Lower mood repeated",
                    body: "Lower mood appears more than once in recent entries.",
                    category: "Local signals",
                    date: lowMoodEntries.first?.date ?? now,
                    type: .emotionalRead
                )
            )
        }

        let movementGoodDays = recent.filter { $0.mood.score >= 4 && $0.themes.contains("Movement") }
        if movementGoodDays.count >= 2 {
            signals.append(
                Insight(
                    id: UUID(),
                    title: "Movement may help",
                    body: "Better mood tends to show up on movement days.",
                    category: "Local signals",
                    date: movementGoodDays.first?.date ?? now,
                    type: .suggestion
                )
            )
        }

        if let healthSummary {
            let lowSleepLowMood = recent.filter { entry in
                (entry.sleepHours ?? healthSummary.lastNightSleep) < 6.25 && entry.mood.score <= 3
            }
            if lowSleepLowMood.count >= 2 {
                signals.append(
                    Insight(
                        id: UUID(),
                        title: "Sleep and energy",
                        body: "Lower sleep may be linked with heavier entries.",
                        category: "Local signals",
                        date: lowSleepLowMood.first?.date ?? now,
                        type: .pattern
                    )
                )
            }

            let activeGoodEntries = recent.filter { entry in
                (entry.steps ?? healthSummary.averageSteps) >= healthSummary.averageSteps && entry.mood.score >= 4
            }
            if activeGoodEntries.count >= 2 {
                signals.append(
                    Insight(
                        id: UUID(),
                        title: "Activity context",
                        body: "Steadier moods often appear on more active days.",
                        category: "Local signals",
                        date: activeGoodEntries.first?.date ?? now,
                        type: .suggestion
                    )
                )
            }
        }

        let activeGoals = goals.filter { $0.status == .active }
        if activeGoals.isEmpty == false, dailyReviews.isEmpty == false {
            signals.append(
                Insight(
                    id: UUID(),
                    title: "Open next step",
                    body: "\(activeGoals.count) agreed next \(activeGoals.count == 1 ? "step is" : "steps are") still active.",
                    category: "Local signals",
                    date: activeGoals.first?.createdAt ?? now,
                    type: .action
                )
            )
        }

        return Array(signals.prefix(5))
    }
}

struct MockConversationService {
    let maxTurns = 3

    func newWeeklyConversation(review: WeeklyReview, profile: OnboardingProfile = .current) -> Conversation {
        let namePrefix = profile.preferredName.isEmpty ? "" : "\(profile.preferredName), "
        let focus = profile.focusAreas.first.map { " Your setup says \($0.lowercased()) is worth watching." } ?? ""
        let opener = "\(namePrefix)I noticed a few patterns this week: \(review.patterns.prefix(2).joined(separator: ", ").lowercased()).\(focus) What feels most useful to look at?"
        return Conversation(
            id: UUID(),
            title: "Weekly check-in",
            date: Date(),
            preview: opener,
            messages: [
                ConversationMessage(id: UUID(), sender: .ai, text: opener, date: Date())
            ],
            status: .active,
            remainingTurns: maxTurns
        )
    }

    func reply(to text: String, action: String? = nil, remainingTurns: Int, profile: OnboardingProfile = .current) -> String {
        let prompt = (action ?? text).lowercased()

        if prompt.contains("break") {
            return "Break it into three parts: what happened, what is still open, and what needs one decision."
        }
        if prompt.contains("reframe") {
            return "This may not be a sign that you are behind. It may be a sign that too many things are asking for attention."
        }
        if prompt.contains("action") {
            return "One useful next step: finish one small unfinished thing before Wednesday. Keep it small enough to do in twenty minutes."
        }
        if text.lowercased().contains("work") {
            return "Here's what I noticed: work is showing up as unfinished decisions. Which one can you finish or park today?"
        }
        if remainingTurns <= 1 {
            return "Keep this small. Pick one thread, write the next step, then stop."
        }
        return "This seems to come up often. What part of it feels most unresolved right now?"
    }
}

struct MockWeeklyReviewService {
    func latestReview(from entries: [JournalEntry], healthSummary: HealthSummary? = nil) -> WeeklyReview {
        guard entries.isEmpty == false else {
            return WeeklyReview(
                id: UUID(),
                dateRange: "",
                patterns: [],
                risk: "",
                suggestion: "",
                healthPatterns: []
            )
        }

        let sortedEntries = entries.sorted { $0.date < $1.date }
        let dateRange = reviewDateRange(for: sortedEntries)
        let generatedPatterns = patterns(from: entries)

        return WeeklyReview(
            id: UUID(),
            dateRange: dateRange,
            patterns: generatedPatterns,
            risk: risk(from: entries),
            suggestion: suggestion(from: entries),
            healthPatterns: healthPatterns(from: entries, summary: healthSummary)
        )
    }

    private func reviewDateRange(for entries: [JournalEntry]) -> String {
        guard let first = entries.first?.date, let last = entries.last?.date else { return "" }
        if Calendar.current.isDate(first, inSameDayAs: last) {
            return first.compactDate
        }
        return "\(first.compactDate) - \(last.compactDate)"
    }

    private func patterns(from entries: [JournalEntry]) -> [String] {
        var patterns: [String] = []
        let themes = entries.flatMap(\.themes)
        let themeCounts = Dictionary(grouping: themes, by: { $0 }).mapValues(\.count)
        let lowMoodCount = entries.filter { $0.mood.score <= 2 }.count
        let goodMoodWithMovement = entries.filter { $0.mood.score >= 4 && $0.themes.contains("Movement") }.count

        if let topTheme = themeCounts.max(by: { $0.value < $1.value }), topTheme.value >= 2 {
            patterns.append("\(topTheme.key) came up \(topTheme.value) times.")
        }
        if lowMoodCount >= 2 {
            patterns.append("Lower mood appeared more than once.")
        }
        if goodMoodWithMovement >= 1 {
            patterns.append("Better mood appeared on a movement day.")
        }
        if patterns.isEmpty {
            patterns.append("Your entries are starting to show early themes.")
        }

        return Array(patterns.prefix(3))
    }

    private func risk(from entries: [JournalEntry]) -> String {
        let lowMoodCount = entries.filter { $0.mood.score <= 2 }.count
        if lowMoodCount >= 2 {
            return "Low mood repeated this week. Keep the next step small."
        }
        if entries.flatMap(\.themes).filter({ $0 == "Work" }).count >= 2 {
            return "Work may be taking up more attention than usual."
        }
        return "There is not enough history for a strong pattern yet."
    }

    private func suggestion(from entries: [JournalEntry]) -> String {
        let themes = entries.flatMap(\.themes)
        if themes.filter({ $0 == "Work" }).count >= 2 {
            return "Choose one work decision to finish or park."
        }
        if themes.filter({ $0 == "Sleep" }).count >= 2 {
            return "Write down a stop point before tonight."
        }
        return "Pick one small next step and leave the rest written down."
    }

    private func healthPatterns(from entries: [JournalEntry], summary: HealthSummary?) -> [String] {
        guard let summary else { return [] }

        var patterns: [String] = []
        let activeGoodDays = entries.filter { ($0.steps ?? 0) >= summary.averageSteps && $0.mood.score >= 4 }.count
        if activeGoodDays >= 1 || summary.trend == .up {
            patterns.append("Better mood tends to follow more active days.")
        }

        if summary.lastNightSleep < 6.25 || summary.averageSleep < 6.5 {
            patterns.append("Lower sleep midweek may affect energy.")
        }

        if patterns.isEmpty, summary.averageSleep >= 7 {
            patterns.append("Your steadier days often follow longer sleep.")
        }

        return Array(patterns.prefix(2))
    }
}
