import Foundation

struct MockAIInsightService {
    private struct IssueRule {
        let key: String
        let label: String
        let includes: [String]
        let excludes: [String]
        let severityTerms: [String]
        let calmingTerms: [String]
        let action: String
        let goalTitle: String
        let goalReason: String
    }

    private let issueRules: [IssueRule] = [
        IssueRule(
            key: "anxiety",
            label: "Anxiety",
            includes: ["anxiety", "anxious", "worry", "worried", "panic", "panicky", "on edge", "nervous", "fear", "dread", "racing heart", "tight chest"],
            excludes: ["no anxiety", "not anxious", "without anxiety", "didn't have anxiety", "did not have anxiety", "didn't have any anxiety", "did not have any anxiety", "didn't feel anxious", "did not feel anxious", "no panic", "not panicking", "without panic", "didn't panic", "did not panic", "no worry", "no worries", "not worried", "without worry"],
            severityTerms: ["panic attack", "spiraling", "can't breathe", "couldn't breathe", "terror", "constant worry"],
            calmingTerms: ["calm", "settled", "grounded", "manageable", "handled it"],
            action: "If anxiety spikes tomorrow, pause for 60 seconds and name the next tiny action before deciding anything bigger.",
            goalTitle: "Use one 60-second reset",
            goalReason: "Anxiety signals came up today, so this gives you a direct test for tomorrow."
        ),
        IssueRule(
            key: "mood",
            label: "Low mood",
            includes: ["low mood", "down", "flat", "empty", "numb", "hopeless", "depressed", "sad", "heavy", "bleak"],
            excludes: ["not depressed", "not sad", "no sadness", "feeling okay", "felt okay", "felt good", "feeling good"],
            severityTerms: ["hopeless", "worthless", "pointless", "can't do this"],
            calmingTerms: ["okay", "lighter", "better", "relief", "stable"],
            action: "If mood drops again tomorrow, do one 10-minute anchor activity before judging the whole day.",
            goalTitle: "Log one mood anchor",
            goalReason: "Low mood language appeared, so a concrete anchor improves comparability."
        ),
        IssueRule(
            key: "stress",
            label: "Stress",
            includes: ["stress", "stressed", "overwhelm", "overwhelmed", "too much", "burnout", "pressure", "frazzled"],
            excludes: ["not stressed", "no stress", "stress free", "stress-free", "without stress"],
            severityTerms: ["meltdown", "breaking point", "burnt out", "burned out", "collapse"],
            calmingTerms: ["under control", "manageable", "fine now", "recovered"],
            action: "When pressure builds tomorrow, pick one task to finish or park within 10 minutes.",
            goalTitle: "Close one pressure loop",
            goalReason: "Stress language repeated, so loop-closure is measurable and immediate."
        ),
        IssueRule(
            key: "sleep",
            label: "Sleep disruption",
            includes: ["sleep", "insomnia", "woke", "waking", "up all night", "tired", "exhausted", "restless", "couldn't sleep", "broken sleep"],
            excludes: ["slept well", "good sleep", "rested", "well rested", "well-rested"],
            severityTerms: ["no sleep", "awake all night", "zero sleep"],
            calmingTerms: ["slept okay", "slept better", "rested", "solid sleep"],
            action: "Set a shutdown time tonight and write tomorrow's first task before bed.",
            goalTitle: "Set one shutdown time",
            goalReason: "Sleep disruption came up, so pre-planned shutdown helps protect energy."
        ),
        IssueRule(
            key: "focus",
            label: "Focus friction",
            includes: ["focus", "distracted", "attention", "procrastinat", "adhd", "couldn't start", "can't start", "avoid", "scattered", "brain fog"],
            excludes: ["focused", "good focus", "clear focus", "concentrated"],
            severityTerms: ["frozen", "paralyzed", "couldn't do anything"],
            calmingTerms: ["focused", "locked in", "made progress", "finished"],
            action: "Start with a 15-minute focus block on one task only, then reassess.",
            goalTitle: "Run one 15-minute focus block",
            goalReason: "Focus friction showed up, so timed single-tasking is the cleanest experiment."
        ),
        IssueRule(
            key: "work",
            label: "Work pressure",
            includes: ["work", "deadline", "meeting", "manager", "client", "email", "job", "office", "slack", "inbox", "deliverable"],
            excludes: ["work was fine", "good day at work", "work felt okay"],
            severityTerms: ["impossible deadline", "in trouble at work", "can't keep up"],
            calmingTerms: ["productive", "wrapped up", "done for today", "clear plan"],
            action: "At your next work block, close or park one unresolved decision before opening new tasks.",
            goalTitle: "Close one work decision",
            goalReason: "Work pressure is recurring, so one decision closure reduces carry-over load."
        ),
        IssueRule(
            key: "social",
            label: "Relationship strain",
            includes: ["friend", "family", "partner", "relationship", "argument", "conflict", "people", "social"],
            excludes: ["good time with", "nice time with", "connected with", "supportive"],
            severityTerms: ["fight", "blow up", "ignored me", "rejected"],
            calmingTerms: ["repaired", "apologized", "talked it through", "felt supported"],
            action: "If tension returns tomorrow, send one short clarifying message instead of replaying it mentally.",
            goalTitle: "Send one clarifying message",
            goalReason: "Relationship strain appeared, so one clean communication step is actionable."
        ),
        IssueRule(
            key: "motivation",
            label: "Motivation dip",
            includes: ["unmotivated", "no motivation", "can't be bothered", "apathetic", "stuck", "no energy", "drained"],
            excludes: ["motivated", "had energy", "energized", "productive"],
            severityTerms: ["pointless", "why bother", "gave up"],
            calmingTerms: ["started", "got going", "made a dent", "finished one thing"],
            action: "Choose one low-friction task and complete it before noon to restart momentum.",
            goalTitle: "Complete one low-friction task",
            goalReason: "Motivation dip appeared, and early wins tend to reset momentum."
        ),
        IssueRule(
            key: "health",
            label: "Body symptom stress",
            includes: ["headache", "migraine", "pain", "nausea", "dizzy", "heart racing", "chest tight"],
            excludes: ["no pain", "pain free", "felt physically fine"],
            severityTerms: ["severe pain", "couldn't move", "constant pain"],
            calmingTerms: ["pain eased", "felt better physically", "symptoms improved"],
            action: "Track one body symptom and one trigger/context note tomorrow so patterns become clearer.",
            goalTitle: "Log one symptom + trigger",
            goalReason: "Body stress signals appeared; structured tracking improves local pattern quality."
        ),
        IssueRule(
            key: "finance",
            label: "Financial stress",
            includes: ["money", "rent", "bills", "debt", "afford", "finance", "financial", "bank", "payment"],
            excludes: ["money is fine", "paid it", "sorted finances"],
            severityTerms: ["can't pay", "overdue", "maxed out", "debt spiral"],
            calmingTerms: ["paid", "caught up", "budgeted", "plan in place"],
            action: "Pick one money task and complete it in under 15 minutes (check, schedule, or note one payment).",
            goalTitle: "Complete one money admin task",
            goalReason: "Money stress came up, so one concrete admin step reduces uncertainty."
        ),
        IssueRule(
            key: "avoidance",
            label: "Avoidance loop",
            includes: ["avoiding", "avoid", "putting off", "procrastinating", "scrolling", "doomscroll", "numbing out"],
            excludes: ["stopped avoiding", "faced it", "did it anyway"],
            severityTerms: ["all day", "hours", "couldn't stop"],
            calmingTerms: ["started anyway", "faced it", "short burst", "made progress"],
            action: "Use a 5-minute starter rule on the avoided task, then decide whether to continue.",
            goalTitle: "Run one 5-minute starter",
            goalReason: "Avoidance language appeared; very short starts break inertia reliably."
        )
    ]

    private func hasAnxietySignal(in text: String) -> Bool {
        let lower = text.lowercased()
        let negativePhrases = [
            "no anxiety", "not anxious", "without anxiety", "no panic", "not panicking",
            "no worry", "no worries", "not worried",
            "didn't have anxiety", "did not have anxiety", "didn't have any anxiety", "did not have any anxiety",
            "didn't feel anxious", "did not feel anxious", "without panic", "without worry"
        ]
        if negativePhrases.contains(where: { lower.contains($0) }) {
            return false
        }
        return lower.contains("anxiety") || lower.contains("anxious") || lower.contains("panic") || lower.contains("worry") || lower.contains("worried")
    }

    private struct IssueSignal {
        let key: String
        let label: String
        let count: Int
        let weightedScore: Double
        let severityHits: Int
    }

    private func containsPhrase(_ phrase: String, in text: String) -> Bool {
        if text.contains(phrase) {
            return true
        }
        let collapsed = text.replacingOccurrences(of: "-", with: " ")
        return collapsed.contains(phrase)
    }

    private func normalized(_ text: String) -> String {
        let lowered = text.lowercased()
        let punctuation = CharacterSet.punctuationCharacters
            .union(.symbols)
            .subtracting(CharacterSet(charactersIn: "'"))
        let cleaned = lowered.unicodeScalars.map { punctuation.contains($0) ? " " : Character($0) }
        return String(cleaned).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func isNegated(_ phrase: String, in text: String) -> Bool {
        let negations = ["no", "not", "without", "never", "hardly", "didn't", "didnt", "did not"]
        let tokens = text.split(separator: " ").map(String.init)
        let phraseTokens = phrase.split(separator: " ").map(String.init)
        guard phraseTokens.isEmpty == false, tokens.count >= phraseTokens.count else { return false }

        for i in 0...(tokens.count - phraseTokens.count) where Array(tokens[i..<(i + phraseTokens.count)]) == phraseTokens {
            let start = max(0, i - 3)
            if tokens[start..<i].contains(where: { negations.contains($0) }) {
                return true
            }
        }
        return false
    }

    private func entryWeight(_ entry: JournalEntry) -> Double {
        var weight = 1.0
        if entry.entryType == .rant { weight += 0.5 }
        if entry.entryType == .reflection { weight += 0.2 }
        if entry.entryType == .win { weight -= 0.25 }
        if entry.mood.score <= 2 { weight += 0.4 }
        if entry.mood.score >= 4 { weight -= 0.2 }
        return max(0.4, weight)
    }

    private func detectIssueSignals(in entries: [JournalEntry]) -> [IssueSignal] {
        var counts: [String: (label: String, count: Int, weightedScore: Double, severityHits: Int)] = [:]
        for entry in entries {
            let lower = normalized(entry.text)
            let weight = entryWeight(entry)
            for rule in issueRules {
                let excluded = rule.excludes.contains { containsPhrase($0, in: lower) }
                let includedPhrase = rule.includes.first(where: { phrase in
                    containsPhrase(phrase, in: lower) && isNegated(phrase, in: lower) == false
                })
                if excluded == false, let includedPhrase {
                    var scoreBump = weight
                    if rule.calmingTerms.contains(where: { containsPhrase($0, in: lower) }) {
                        scoreBump -= 0.35
                    }
                    var severityHits = 0
                    if rule.severityTerms.contains(where: { containsPhrase($0, in: lower) }) {
                        scoreBump += 0.6
                        severityHits = 1
                    }
                    if includedPhrase.count > 15 {
                        scoreBump += 0.1
                    }

                    let existing = counts[rule.key] ?? (label: rule.label, count: 0, weightedScore: 0.0, severityHits: 0)
                    counts[rule.key] = (
                        label: rule.label,
                        count: existing.count + 1,
                        weightedScore: existing.weightedScore + max(0.2, scoreBump),
                        severityHits: existing.severityHits + severityHits
                    )
                }
            }
        }

        return counts
            .map {
                IssueSignal(
                    key: $0.key,
                    label: $0.value.label,
                    count: $0.value.count,
                    weightedScore: $0.value.weightedScore,
                    severityHits: $0.value.severityHits
                )
            }
            .sorted {
                if $0.severityHits != $1.severityHits { return $0.severityHits > $1.severityHits }
                if abs($0.weightedScore - $1.weightedScore) > 0.01 { return $0.weightedScore > $1.weightedScore }
                return $0.count > $1.count
            }
    }

    private func contextAnchors(from entries: [JournalEntry], profile: OnboardingProfile) -> [String] {
        let text = normalized(entries.map(\.text).joined(separator: " "))
        var anchors: [String] = []

        if text.contains("dog") || text.contains("walk") || text.contains("outside") {
            anchors.append("a short walk outside")
        }
        if text.contains("drive") || text.contains("driving") || text.contains("car") {
            anchors.append("a calmer driving start")
        }
        if text.contains("sleep") || text.contains("tired") || text.contains("awake") {
            anchors.append("protecting your sleep window")
        }
        if text.contains("work") || text.contains("meeting") || text.contains("deadline") {
            anchors.append("closing one work loop early")
        }
        if text.contains("family") || text.contains("partner") || text.contains("friend") {
            anchors.append("one clean check-in with someone close")
        }

        let story = normalized(profile.personalStory)
        if story.contains("panic") || story.contains("anxiety") {
            anchors.append("body-first calming before analysis")
        }
        if story.contains("sleep") {
            anchors.append("a consistent wind-down")
        }

        return Array(anchors.prefix(2))
    }

    private func anchorAdviceSuffix(_ anchors: [String]) -> String {
        guard anchors.isEmpty == false else { return "" }
        if anchors.count == 1, let first = anchors.first {
            return " From today, prioritize \(first)."
        }
        return " From today, prioritize \(anchors[0]), then \(anchors[1])."
    }

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
        let recentSignals = detectIssueSignals(in: recentEntries)
        let recentTopIssue = recentSignals.first
        let issueSignals = detectIssueSignals(in: sortedEntries)
        let topIssue = issueSignals.first
        let topRule = topIssue.flatMap { signal in
            issueRules.first(where: { $0.key == signal.key })
        }

        let summary: String
        if sortedEntries.count == 1, let entry = sortedEntries.first {
            summary = "You logged one \(entry.entryType.label.lowercased()) today."
        } else {
            summary = "You wrote \(sortedEntries.count) entries today."
        }

        let emotionalRead: String
        let anxietySignal = hasAnxietySignal(in: lowerText)
        if let topIssue {
            emotionalRead = "\(topIssue.label) came up most today."
        } else if anxietySignal && topTheme == "Anxiety" && sortedEntries.contains(where: { $0.entryType == .win }) {
            emotionalRead = "You noted anxiety, and also recorded something that went well."
        } else if anxietySignal && topTheme == "Anxiety" {
            emotionalRead = "Anxiety seems to be part of today's context."
        } else if sortedEntries.contains(where: { $0.entryType == .win }) || averageMood >= 4 {
            emotionalRead = hasPreviousData ? "Today includes a steadier note." : "There is a steady moment in today's entries."
        } else if topTheme == "Work" {
            emotionalRead = "Work seems to have taken a lot of attention today."
        } else if topTheme == "Sleep" {
            emotionalRead = "Energy and sleep look relevant to today's tone."
        } else if topTheme == "Focus" {
            emotionalRead = "Focus and attention seem to have taken effort today."
        } else if topTheme == "Relationships" {
            emotionalRead = "People and relationships seem central in today's entries."
        } else if topTheme == "Open loops" {
            emotionalRead = "Unfinished decisions seem to be taking up space."
        } else if lowerText.contains("overwhel") || lowerText.contains("too much") || averageMood <= 2.4 {
            emotionalRead = "Today sounds heavy and a little crowded."
        } else {
            emotionalRead = "Today has a few threads worth noticing."
        }

        let pattern: String
        if let topIssue {
            let countText = topIssue.count > 1 ? "\(topIssue.count) entries" : "1 entry"
            if topIssue.severityHits > 0 {
                pattern = "\(topIssue.label) came up in \(countText), and some wording sounded intense."
            } else {
                pattern = "\(topIssue.label) came up in \(countText)."
            }
        } else if let sleepHours = sortedEntries.first(where: { $0.sleepHours != nil })?.sleepHours, sleepHours < 6.25, averageMood <= 3.2 {
            pattern = "Lower sleep may have shaped the tone of the day."
        } else if let steps = sortedEntries.first(where: { $0.steps != nil })?.steps, steps >= 7500, averageMood >= 3.5 {
            pattern = "More movement may be linked with a steadier day."
        } else if lowerText.contains("drove") || lowerText.contains("driving") {
            pattern = "Driving showed up as something you were watching closely."
        } else if let topTheme {
            pattern = "\(topTheme) was the clearest theme today."
        } else {
            pattern = "A clearer pattern will emerge as you keep checking in."
        }

        let patternWithContext: String
        if let topIssue, let recentTopIssue, topIssue.key == recentTopIssue.key, hasPreviousData {
            patternWithContext = "\(pattern) This also showed up in recent entries, so it looks like a repeating pattern."
        } else if let topIssue, let recentTopIssue, topIssue.key != recentTopIssue.key, hasPreviousData {
            patternWithContext = "\(pattern) Compared with recent entries, today's main theme shifted."
        } else {
            patternWithContext = pattern
        }

        let reframe: String
        if sortedEntries.contains(where: { $0.entryType == .win }) {
            reframe = "This is worth recording as evidence of what can go right."
        } else if topIssue?.severityHits ?? 0 > 0 {
            reframe = "Even high-intensity moments can be handled one concrete step at a time."
        } else if lowerText.contains("again") || lowerText.contains("same") {
            reframe = "A repeated thought may need one clear next step, not more time in your head."
        } else {
            reframe = "You do not need to solve the whole pattern from one day."
        }

        let anchors = contextAnchors(from: sortedEntries, profile: profile)
        let action: String
        let goalTitle: String
        let goalReason: String
        if let topRule {
            action = topRule.action + anchorAdviceSuffix(anchors)
            goalTitle = topRule.goalTitle
            goalReason = topRule.goalReason
        } else if lowerText.contains("drove") || lowerText.contains("driving") {
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
            action = anchors.isEmpty
                ? "If the same thought comes back tomorrow, write one next action and stop there."
                : "If the same thought comes back tomorrow, do one small step tied to \(anchors[0]) and stop there."
            goalTitle = ""
            goalReason = ""
        }

        var normalizedAction = action
        var normalizedGoalTitle = goalTitle
        var normalizedGoalReason = goalReason
        if normalizedGoalTitle.isEmpty {
            normalizedAction = "If the same thought comes back tomorrow, write one next action and stop there."
            normalizedGoalTitle = "Write one concrete next step"
            normalizedGoalReason = "A single concrete next step keeps tomorrow measurable and reduces rumination."
        }

        return DailyReview(
            id: UUID(),
            date: date,
            summary: summary,
            insight: StructuredInsight(
                emotionalRead: emotionalRead,
                pattern: patternWithContext,
                reframe: reframe,
                action: normalizedAction
            ),
            suggestedGoalTitle: normalizedGoalTitle,
            suggestedGoalReason: normalizedGoalReason,
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
        let lower = normalized(text)
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
        if lower.contains("focus") || lower.contains("distracted") || lower.contains("attention") || lower.contains("procrastinat") || lower.contains("adhd") {
            themes.append("Focus")
        }
        if lower.contains("stress") || lower.contains("overwhelm") || lower.contains("burnout") {
            themes.append("Stress")
        }
        if hasAnxietySignal(in: lower) {
            themes.append("Anxiety")
        }
        if lower.contains("sad") || lower.contains("low mood") || lower.contains("depressed") || lower.contains("flat") || lower.contains("empty") || lower.contains("numb") || lower.contains("hopeless") {
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
        if lower.contains("money") || lower.contains("debt") || lower.contains("bills") || lower.contains("rent") {
            themes.append("Financial")
        }
        if lower.contains("pain") || lower.contains("migraine") || lower.contains("nausea") || lower.contains("dizzy") {
            themes.append("Physical")
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
                    category: "What I am noticing",
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
                    category: "What I am noticing",
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
                    category: "What I am noticing",
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
                        category: "What I am noticing",
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
                        category: "What I am noticing",
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
                    category: "What I am noticing",
                    date: activeGoals.first?.createdAt ?? now,
                    type: .action
                )
            )
        }

        return Array(signals.prefix(5))
    }
}

struct MockConversationService {
    let maxTurns = 6

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
