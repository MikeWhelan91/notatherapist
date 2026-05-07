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
        ),
        IssueRule(
            key: "rumination",
            label: "Rumination",
            includes: ["overthinking", "replaying", "can't stop thinking", "cant stop thinking", "looping", "spiral", "spiraling", "stuck in my head", "kept thinking"],
            excludes: ["stopped overthinking", "not overthinking", "less overthinking", "no spiral"],
            severityTerms: ["all day", "couldn't stop", "cant stop", "hours"],
            calmingTerms: ["let it go", "moved on", "clearer", "wrote it down"],
            action: "Set a 10-minute worry window, write the next decision, then move your body for 2 minutes.",
            goalTitle: "Use one worry window",
            goalReason: "Rumination language appeared, so containing the loop makes tomorrow easier to compare."
        ),
        IssueRule(
            key: "rejection",
            label: "Rejection sensitivity",
            includes: ["rejected", "ignored", "left out", "they hate me", "annoyed with me", "mad at me", "embarrassed", "ashamed", "humiliated"],
            excludes: ["not rejected", "wasn't ignored", "was not ignored", "talked it through"],
            severityTerms: ["everyone hates me", "ruined everything", "can't face them", "cant face them"],
            calmingTerms: ["clarified", "repaired", "talked", "reassured"],
            action: "Before reacting, write the story your mind made and one softer explanation that could also fit.",
            goalTitle: "Check one relationship story",
            goalReason: "Rejection sensitivity signals appeared, so testing the story is the useful next step."
        ),
        IssueRule(
            key: "numbing",
            label: "Emotional numbing",
            includes: ["numb", "numbing", "scrolling", "doomscroll", "drank", "weed", "food", "binged", "zoned out", "shut down", "shutdown"],
            excludes: ["didn't numb", "did not numb", "stopped scrolling", "less scrolling"],
            severityTerms: ["all night", "all day", "couldn't stop", "cant stop", "blackout"],
            calmingTerms: ["stopped", "paused", "noticed", "chose"],
            action: "When the urge to switch off appears, name the feeling underneath before choosing what to do.",
            goalTitle: "Name the feeling first",
            goalReason: "Numbing signals appeared, so naming the need underneath gives you more choice."
        ),
        IssueRule(
            key: "perfectionism",
            label: "Perfection pressure",
            includes: ["perfect", "not good enough", "failed", "failure", "should have", "should've", "mess up", "messed up", "disappointed"],
            excludes: ["good enough", "not perfect but", "didn't fail", "did not fail"],
            severityTerms: ["ruined", "useless", "worthless", "everything wrong"],
            calmingTerms: ["good enough", "finished", "accepted", "okay"],
            action: "Choose one good-enough version of the task and stop when that version is complete.",
            goalTitle: "Finish one good-enough version",
            goalReason: "Perfection pressure appeared, so a defined stopping point reduces the loop."
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

    private struct LocalReviewContext {
        let sortedEntries: [JournalEntry]
        let combinedText: String
        let normalizedText: String
        let averageMood: Double
        let moodRange: ClosedRange<Int>
        let themes: [String]
        let topTheme: String?
        let hasPreviousData: Bool
        let topIssue: IssueSignal?
        let secondaryIssue: IssueSignal?
        let recentTopIssue: IssueSignal?
        let topRule: IssueRule?
        let topDomain: String?
        let domainDefault: (emotionalRead: String, pattern: String, action: String, goalTitle: String, goalReason: String)
        let anchors: [String]
        let improvementSignals: [String]
        let protectiveSignals: [String]
        let strainScore: Double
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

    private func hasUrgentSafetySignal(in text: String) -> Bool {
        let lower = normalized(text)
        let phrases = [
            "kill myself", "end my life", "want to die", "suicide", "suicidal",
            "hurt myself", "self harm", "self-harm", "overdose", "cant stay safe",
            "can't stay safe", "not safe", "abuse", "being abused"
        ]
        let excluded = [
            "not suicidal", "not suicide", "no suicidal", "no suicide",
            "dont want to die", "don't want to die", "do not want to die",
            "would never hurt myself", "not going to hurt myself"
        ]
        if excluded.contains(where: { lower.contains($0) }) {
            return false
        }
        return phrases.contains(where: { lower.contains($0) })
    }

    private func topAssessmentDomain(from profile: OnboardingProfile) -> String? {
        profile.assessment?.domains
            .filter { $0.maxScore > 0 }
            .sorted {
                if $0.score == $1.score { return $0.domain < $1.domain }
                return $0.score > $1.score
            }
            .first?
            .domain
    }

    private func domainDefault(for domain: String?) -> (emotionalRead: String, pattern: String, action: String, goalTitle: String, goalReason: String) {
        switch domain?.lowercased() {
        case "anxiety":
            return (
                "Your baseline points toward anxiety as a useful lens today.",
                "One possible pattern to watch is worry, avoidance, or body alarm showing up before action.",
                "If tension rises tomorrow, name the feared outcome and take the smallest safe next step.",
                "Name one feared outcome",
                "Your baseline suggests anxiety tracking may make tomorrow's pattern clearer."
            )
        case "mood":
            return (
                "Your baseline points toward mood and energy as useful signals today.",
                "One possible pattern to watch is lower energy making ordinary tasks feel bigger.",
                "If energy dips tomorrow, do one 5-minute action before judging the whole day.",
                "Do one 5-minute action",
                "Your baseline suggests small activation steps may be useful to test."
            )
        case "functioning":
            return (
                "Your baseline points toward daily functioning as the useful lens today.",
                "One possible pattern to watch is sleep, focus, support, or load changing what feels doable.",
                "Tomorrow, choose one practical support: simplify, ask, schedule, or remove one blocker.",
                "Set one practical support",
                "Your baseline suggests functioning improves when support is made concrete."
            )
        default:
            return (
                "Your baseline points toward stress load as a useful lens today.",
                "One possible pattern to watch is overload building before your body or patience catches up.",
                "If pressure builds tomorrow, remove, delay, or finish one thing before adding more.",
                "Reduce one pressure point",
                "Your baseline suggests stress tracking may make the next step clearer."
            )
        }
    }

    private func educationalPatternLine(for issueKey: String) -> String? {
        switch issueKey {
        case "avoidance", "focus":
            return "This resembles an avoidance loop, which can be worth learning about if it keeps costing you."
        case "anxiety":
            return "This resembles a worry or body-alarm pattern, not a diagnosis."
        case "mood", "motivation":
            return "This resembles a low-energy or withdrawal pattern, not a label."
        case "social":
            return "This resembles a rejection-sensitivity or repair loop, if it repeats across relationships."
        case "stress", "work":
            return "This resembles overload or burnout load, especially if recovery keeps getting delayed."
        case "sleep":
            return "This resembles sleep debt shaping mood and focus."
        case "rumination":
            return "This resembles rumination: the mind trying to solve discomfort by replaying it."
        case "rejection":
            return "This resembles rejection sensitivity, especially if one interaction changes the whole day."
        case "numbing":
            return "This resembles emotional numbing: switching off because the feeling is too much."
        case "perfectionism":
            return "This resembles perfection pressure, where the standard keeps moving out of reach."
        default:
            return nil
        }
    }

    private func improvementSignals(in text: String) -> [String] {
        let checks: [(String, String)] = [
            ("calmer", "calmer"),
            ("better", "better"),
            ("easier", "easier"),
            ("managed", "managed it"),
            ("handled", "handled it"),
            ("started", "started"),
            ("finished", "finished"),
            ("done", "got something done"),
            ("less anxious", "less anxious"),
            ("slept better", "slept better"),
            ("talked it through", "talked it through")
        ]
        return checks.compactMap { phrase, label in text.contains(phrase) ? label : nil }
    }

    private func protectiveSignals(in entries: [JournalEntry], text: String) -> [String] {
        var signals: [String] = []
        if entries.contains(where: { $0.entryType == .win }) { signals.append("you recorded a win") }
        if text.contains("walk") || text.contains("outside") || text.contains("gym") { signals.append("movement or outside time showed up") }
        if text.contains("friend") || text.contains("partner") || text.contains("family") || text.contains("support") { signals.append("support or connection showed up") }
        if text.contains("breathe") || text.contains("breathing") || text.contains("grounded") || text.contains("meditat") { signals.append("a calming skill showed up") }
        if text.contains("plan") || text.contains("list") || text.contains("schedule") { signals.append("planning showed up") }
        return Array(signals.prefix(2))
    }

    private func strainScore(entries: [JournalEntry], issues: [IssueSignal]) -> Double {
        let moodLoad = entries.map { max(0, 3 - $0.mood.score) }.reduce(0, +)
        let rantLoad = entries.filter { $0.entryType == .rant }.count
        let issueLoad = issues.prefix(3).map { $0.weightedScore + Double($0.severityHits) }.reduce(0, +)
        return Double(moodLoad) + Double(rantLoad) + issueLoad
    }

    private func buildContext(
        date: Date,
        entries: [JournalEntry],
        recentEntries: [JournalEntry],
        profile: OnboardingProfile
    ) -> LocalReviewContext {
        let sortedEntries = entries.sorted { $0.date < $1.date }
        let combinedText = sortedEntries.map(\.text).joined(separator: " ")
        let normalizedText = normalized(combinedText)
        let moodScores = sortedEntries.map(\.mood.score)
        let averageMood = Double(moodScores.reduce(0, +)) / Double(max(1, moodScores.count))
        let moodRange = (moodScores.min() ?? 3)...(moodScores.max() ?? 3)
        let themes = sortedEntries.flatMap(\.themes)
        let topTheme = Dictionary(grouping: themes, by: { $0 })
            .mapValues(\.count)
            .max { $0.value < $1.value }?
            .key
        let hasPreviousData = recentEntries.contains { Calendar.current.isDate($0.date, inSameDayAs: date) == false }
        let issueSignals = detectIssueSignals(in: sortedEntries)
        let recentSignals = detectIssueSignals(in: recentEntries)
        let topIssue = issueSignals.first
        let secondaryIssue = issueSignals.dropFirst().first
        let topRule = topIssue.flatMap { signal in issueRules.first(where: { $0.key == signal.key }) }
        let topDomain = topAssessmentDomain(from: profile)
        return LocalReviewContext(
            sortedEntries: sortedEntries,
            combinedText: combinedText,
            normalizedText: normalizedText,
            averageMood: averageMood,
            moodRange: moodRange,
            themes: themes,
            topTheme: topTheme,
            hasPreviousData: hasPreviousData,
            topIssue: topIssue,
            secondaryIssue: secondaryIssue,
            recentTopIssue: recentSignals.first,
            topRule: topRule,
            topDomain: topDomain,
            domainDefault: domainDefault(for: topDomain),
            anchors: contextAnchors(from: sortedEntries, profile: profile),
            improvementSignals: improvementSignals(in: normalizedText),
            protectiveSignals: protectiveSignals(in: sortedEntries, text: normalizedText),
            strainScore: strainScore(entries: sortedEntries, issues: issueSignals)
        )
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
        healthSummary: HealthSummary? = nil,
        goals: [ReflectionGoal] = [],
        calmSessions: [CalmSessionLog] = []
    ) -> DailyReview? {
        guard entries.isEmpty == false else { return nil }

        let context = buildContext(date: date, entries: entries, recentEntries: recentEntries, profile: profile)
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
        let topDomain = topAssessmentDomain(from: profile)
        let domainDefault = domainDefault(for: topDomain)
        let recentlyCompletedGoals = goals
            .filter { $0.status == .completed }
            .sorted { ($0.feedbackAt ?? $0.createdAt) > ($1.feedbackAt ?? $1.createdAt) }
            .prefix(3)
        let activeGoalTitles = goals
            .filter { $0.status == .active }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(2)
            .map(\.title)
        let reflectionGoal = profile.reflectionGoal.trimmingCharacters(in: .whitespacesAndNewlines)

        if hasUrgentSafetySignal(in: combinedText) {
            return DailyReview(
                id: UUID(),
                date: date,
                summary: "This entry includes a safety signal.",
                insight: StructuredInsight(
                    emotionalRead: "This needs real-world support, not a reflection exercise.",
                    pattern: "When safety is in question, the next step is immediate support from a person or service.",
                    reframe: "You do not have to handle this alone or wait for it to pass.",
                    action: "Contact local emergency services, a crisis line, or a trusted nearby person now."
                ),
                evidenceStrength: "Strong safety signal from today's words.",
                suggestedGoalTitle: "Get support now",
                suggestedGoalReason: "Safety signals should be handled with immediate real-world support.",
                acceptedGoalID: nil,
                entryIDs: sortedEntries.map(\.id),
                createdAt: Date(),
                source: "local"
            )
        }

        let summary: String
        if sortedEntries.count == 1, let entry = sortedEntries.first {
            if let topIssue {
                summary = "You logged one \(entry.entryType.label.lowercased()); \(topIssue.label.lowercased()) was the clearest signal."
            } else if context.improvementSignals.isEmpty == false {
                summary = "You logged one \(entry.entryType.label.lowercased()) with a progress signal."
            } else {
                summary = "You logged one \(entry.entryType.label.lowercased()) today."
            }
        } else {
            let moodMoved = context.moodRange.lowerBound != context.moodRange.upperBound
            if let topIssue, let secondary = context.secondaryIssue {
                summary = "You wrote \(sortedEntries.count) entries; \(topIssue.label.lowercased()) led, with \(secondary.label.lowercased()) behind it."
            } else if moodMoved {
                summary = "You wrote \(sortedEntries.count) entries, and your mood shifted during the day."
            } else {
                summary = "You wrote \(sortedEntries.count) entries today."
            }
        }

        var emotionalRead: String
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
        } else if topDomain != nil {
            emotionalRead = domainDefault.emotionalRead
        } else if averageMood >= 3.0 {
            emotionalRead = "Today does not show a clear struggle, which is useful baseline information."
        } else {
            emotionalRead = "Today has a few threads worth noticing."
        }

        if reflectionGoal.isEmpty == false {
            if recentlyCompletedGoals.isEmpty == false {
                emotionalRead += " That matters for your goal of \(reflectionGoal.lowercased()), because you already have proof that some steps can help."
            } else if activeGoalTitles.isEmpty == false {
                emotionalRead += " Keep reading this through your goal of \(reflectionGoal.lowercased()), especially around \(naturalList(activeGoalTitles.map { $0.lowercased() }))."
            } else {
                emotionalRead += " Read today against your goal of \(reflectionGoal.lowercased()), not as an isolated mood snapshot."
            }
        }

        if recentlyCompletedGoals.isEmpty == false {
            let titles = naturalList(recentlyCompletedGoals.map { $0.title.lowercased() })
            emotionalRead += " Recently completed next steps include \(titles), which is useful evidence for what helps."
        }
        let recentHelpfulCalm = calmSessions
            .filter {
                Calendar.current.dateComponents([.day], from: $0.endedAt, to: date).day ?? 99 <= 7 &&
                ($0.helpfulness == .yes || $0.helpfulness == .aBit)
            }
        if recentHelpfulCalm.isEmpty == false {
            emotionalRead += " Calm sessions have also been helping you settle recently."
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
        } else if topDomain != nil {
            pattern = domainDefault.pattern
        } else {
            pattern = "A clearer pattern will emerge as you keep checking in."
        }

        let patternWithContext: String
        if let topIssue, let recentTopIssue, topIssue.key == recentTopIssue.key, hasPreviousData {
            patternWithContext = "\(pattern) This also showed up in recent entries, so it looks like a repeating pattern."
        } else if let topIssue, let recentTopIssue, topIssue.key != recentTopIssue.key, hasPreviousData {
            patternWithContext = "\(pattern) Compared with recent entries, today's main theme shifted."
        } else if let topIssue, let secondary = context.secondaryIssue {
            let education = educationalPatternLine(for: topIssue.key).map { " \($0)" } ?? ""
            patternWithContext = "\(pattern) \(secondary.label) was the next signal, so this may be a layered day.\(education)"
        } else if let topIssue, let education = educationalPatternLine(for: topIssue.key) {
            patternWithContext = "\(pattern) \(education)"
        } else if context.improvementSignals.isEmpty == false {
            patternWithContext = "\(pattern) Progress signal: \(context.improvementSignals[0])."
        } else if context.protectiveSignals.isEmpty == false {
            patternWithContext = "\(pattern) Protective signal: \(context.protectiveSignals[0])."
        } else {
            patternWithContext = pattern
        }

        var reframe: String
        if context.improvementSignals.isEmpty == false {
            reframe = "The useful detail is not that everything was fine; it is that something shifted: \(context.improvementSignals[0])."
        } else if sortedEntries.contains(where: { $0.entryType == .win }) {
            reframe = "This is worth recording as evidence of what can go right."
        } else if context.protectiveSignals.isEmpty == false, topIssue != nil {
            reframe = "The strain was real, and there was also a support signal: \(context.protectiveSignals[0])."
        } else if topIssue?.severityHits ?? 0 > 0 {
            reframe = "Even high-intensity moments can be handled one concrete step at a time."
        } else if lowerText.contains("again") || lowerText.contains("same") {
            reframe = "A repeated thought may need one clear next step, not more time in your head."
        } else if topDomain != nil {
            reframe = "This is information for your next decision, not a verdict about you."
        } else {
            reframe = "You do not need to solve the whole pattern from one day."
        }

        if reflectionGoal.isEmpty == false {
            reframe += " The more useful question is what would move \(reflectionGoal.lowercased()) forward from here."
        }

        let anchors = contextAnchors(from: sortedEntries, profile: profile)
        let action: String
        let goalTitle: String
        let goalReason: String
        if let topIssue, topIssue.severityHits > 0, context.anchors.isEmpty == false {
            action = "Keep tomorrow narrow: use \(context.anchors[0]) first, then do only the next concrete step."
            goalTitle = "Use one stabilizing anchor"
            goalReason = "Today's language was intense, so tomorrow should start with a known stabilizer."
        } else if let topRule {
            action = topRule.action + anchorAdviceSuffix(anchors)
            goalTitle = topRule.goalTitle
            goalReason = topRule.goalReason
        } else if context.improvementSignals.isEmpty == false {
            action = "Repeat the condition linked to \(context.improvementSignals[0]) once tomorrow, then write whether it still helped."
            goalTitle = "Repeat one helpful condition"
            goalReason = "A progress signal appeared today, so repeating the condition makes it testable."
        } else if context.protectiveSignals.isEmpty == false {
            action = "Use \(context.protectiveSignals[0]) deliberately tomorrow before the day gets crowded."
            goalTitle = "Use one support signal"
            goalReason = "A protective signal appeared today, so using it earlier is a practical experiment."
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
        } else if topDomain != nil {
            action = domainDefault.action
            goalTitle = domainDefault.goalTitle
            goalReason = domainDefault.goalReason
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
            let hasActionableSignal = topIssue != nil ||
                context.improvementSignals.isEmpty == false ||
                context.protectiveSignals.isEmpty == false ||
                lowerText.contains("drove") ||
                lowerText.contains("driving") ||
                sortedEntries.contains(where: { $0.entryType == .win }) ||
                themes.contains("Work") ||
                themes.contains("Anxiety") ||
                topDomain != nil

            if hasActionableSignal {
                normalizedAction = "If the same thought comes back tomorrow, write one next action and stop there."
                normalizedGoalTitle = "Write one concrete next step"
                normalizedGoalReason = "A single concrete next step keeps tomorrow measurable and reduces rumination."
            } else {
                normalizedAction = "Notice what helped today stay relatively clear, then protect one small piece of it tomorrow."
                normalizedGoalTitle = ""
                normalizedGoalReason = ""
            }
        }

        if reflectionGoal.isEmpty == false {
            normalizedAction = normalizedAction.replacingOccurrences(of: "tomorrow.", with: "tomorrow so it supports \(reflectionGoal.lowercased()).")
            if normalizedAction == action || normalizedAction.contains(reflectionGoal.lowercased()) == false {
                normalizedAction += " Keep it tied to \(reflectionGoal.lowercased())."
            }
            if normalizedGoalReason.isEmpty == false && normalizedGoalReason.contains(reflectionGoal.lowercased()) == false {
                normalizedGoalReason += " It supports \(reflectionGoal.lowercased())."
            }
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
            evidenceStrength: evidenceStrength(
                issue: topIssue,
                entryCount: sortedEntries.count,
                hasRecentContext: hasPreviousData,
                usedBaseline: topDomain != nil,
                improvementCount: context.improvementSignals.count,
                protectiveCount: context.protectiveSignals.count,
                strainScore: context.strainScore
            ),
            suggestedGoalTitle: normalizedGoalTitle,
            suggestedGoalReason: normalizedGoalReason,
            acceptedGoalID: nil,
            entryIDs: sortedEntries.map(\.id),
            createdAt: Date(),
            source: "local"
        )
    }

    private func naturalList(_ items: [String]) -> String {
        switch items.count {
        case 0:
            return ""
        case 1:
            return items[0]
        case 2:
            return "\(items[0]) and \(items[1])"
        default:
            return "\(items.dropLast().joined(separator: ", ")), and \(items.last ?? "")"
        }
    }

    private func evidenceStrength(
        issue: IssueSignal?,
        entryCount: Int,
        hasRecentContext: Bool,
        usedBaseline: Bool,
        improvementCount: Int = 0,
        protectiveCount: Int = 0,
        strainScore: Double = 0
    ) -> String {
        if let issue, issue.severityHits > 0 {
            return "Strong: today's wording included an intense \(issue.label.lowercased()) signal."
        }
        if strainScore >= 4.0 {
            return "Strong: several local signals pointed in the same direction."
        }
        if let issue, issue.count > 1 || hasRecentContext {
            return "Moderate: \(issue.label.lowercased()) appeared with supporting context."
        }
        if improvementCount > 0 || protectiveCount > 0 {
            return "Moderate: today's entry included a concrete shift or support signal."
        }
        if issue != nil {
            return "Early: based on today's entry language."
        }
        if usedBaseline {
            return "Early: based on today's entry plus your baseline."
        }
        return entryCount > 1 ? "Early: based on today's entries." : "Light: based on one entry."
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
    func latestReview(from entries: [JournalEntry], profile: OnboardingProfile = .current, healthSummary: HealthSummary? = nil, goals: [ReflectionGoal] = []) -> WeeklyReview {
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
        let reflectionGoal = profile.reflectionGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        let dateRange = reviewDateRange(for: sortedEntries)
        let generatedPatterns = patterns(from: entries, reflectionGoal: reflectionGoal, goals: goals)

        return WeeklyReview(
            id: UUID(),
            dateRange: dateRange,
            patterns: generatedPatterns,
            risk: risk(from: entries, reflectionGoal: reflectionGoal),
            suggestion: suggestion(from: entries, reflectionGoal: reflectionGoal),
            healthPatterns: healthPatterns(from: entries, summary: healthSummary),
            goalFollowThrough: goalFollowThrough(from: entries, goals: goals, reflectionGoal: reflectionGoal),
            progressSignal: progressSignal(from: entries, goals: goals, reflectionGoal: reflectionGoal),
            primaryLoop: primaryLoop(from: entries),
            nextExperiment: nextExperiment(from: entries, reflectionGoal: reflectionGoal),
            baselineComparison: baselineComparison(from: entries, reflectionGoal: reflectionGoal),
            suggestedTemplate: suggestedTemplate(from: entries),
            researchPrompt: researchPrompt(from: entries)
        )
    }

    private func reviewDateRange(for entries: [JournalEntry]) -> String {
        guard let first = entries.first?.date, let last = entries.last?.date else { return "" }
        if Calendar.current.isDate(first, inSameDayAs: last) {
            return first.compactDate
        }
        return "\(first.compactDate) - \(last.compactDate)"
    }

    private func naturalList(_ items: [String]) -> String {
        switch items.count {
        case 0:
            return ""
        case 1:
            return items[0]
        case 2:
            return "\(items[0]) and \(items[1])"
        default:
            return "\(items.dropLast().joined(separator: ", ")), and \(items.last ?? "")"
        }
    }

    private func patterns(from entries: [JournalEntry], reflectionGoal: String, goals: [ReflectionGoal]) -> [String] {
        var patterns: [String] = []
        let themes = entries.flatMap(\.themes)
        let themeCounts = Dictionary(grouping: themes, by: { $0 }).mapValues(\.count)
        let lowMoodCount = entries.filter { $0.mood.score <= 2 }.count
        let goodMoodWithMovement = entries.filter { $0.mood.score >= 4 && $0.themes.contains("Movement") }.count
        let completedTitles = goals
            .filter { $0.status == .completed }
            .sorted { ($0.feedbackAt ?? $0.createdAt) > ($1.feedbackAt ?? $1.createdAt) }
            .prefix(2)
            .map(\.title)

        if reflectionGoal.isEmpty == false {
            if completedTitles.isEmpty == false {
                patterns.append("Completed steps such as \(naturalList(completedTitles.map { $0.lowercased() })) gave real evidence of movement toward \(reflectionGoal.lowercased()).")
            } else {
                patterns.append("The clearest weekly question is what helped or blocked progress toward \(reflectionGoal.lowercased()).")
            }
        }

        if let topTheme = themeCounts.max(by: { $0.value < $1.value }), topTheme.value >= 2 {
            patterns.append("\(topTheme.key) came up \(topTheme.value) times.")
        }
        if lowMoodCount >= 2 {
            patterns.append("Lower mood appeared more than once.")
        }
        if goodMoodWithMovement >= 1 {
            patterns.append("Better mood appeared on a movement day.")
        }

        return Array(patterns.prefix(3))
    }

    private func risk(from entries: [JournalEntry], reflectionGoal: String) -> String {
        let lowMoodCount = entries.filter { $0.mood.score <= 2 }.count
        if lowMoodCount >= 2 {
            return reflectionGoal.isEmpty
                ? "Low mood repeated this week. Keep the next step small."
                : "Low mood repeated this week, so progress toward \(reflectionGoal.lowercased()) needs a smaller and steadier plan."
        }
        if entries.flatMap(\.themes).filter({ $0 == "Work" }).count >= 2 {
            return reflectionGoal.isEmpty
                ? "Work may be taking up more attention than usual."
                : "Work may be taking up more attention than usual and pulling energy away from \(reflectionGoal.lowercased())."
        }
        return entries.count >= 5 ? "Keep next steps small until a repeated signal is clearer." : ""
    }

    private func suggestion(from entries: [JournalEntry], reflectionGoal: String) -> String {
        let themes = entries.flatMap(\.themes)
        if themes.filter({ $0 == "Work" }).count >= 2 {
            return reflectionGoal.isEmpty
                ? "Choose one work decision to finish or park."
                : "Choose one work decision to finish or park so it stops competing with \(reflectionGoal.lowercased())."
        }
        if themes.filter({ $0 == "Sleep" }).count >= 2 {
            return reflectionGoal.isEmpty
                ? "Write down a stop point before tonight."
                : "Write down a stop point before tonight so tomorrow has more room for \(reflectionGoal.lowercased())."
        }
        return entries.count >= 5
            ? (reflectionGoal.isEmpty ? "Pick one small next step and leave the rest written down." : "Pick one small next step that clearly supports \(reflectionGoal.lowercased()), then leave the rest written down.")
            : "Log a few more days before treating this as a weekly review."
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

    private func progressSignal(from entries: [JournalEntry], goals: [ReflectionGoal], reflectionGoal: String) -> String {
        let completedTitles = goals
            .filter { $0.status == .completed }
            .sorted { ($0.feedbackAt ?? $0.createdAt) > ($1.feedbackAt ?? $1.createdAt) }
            .prefix(2)
            .map(\.title)
        if completedTitles.isEmpty == false {
            return reflectionGoal.isEmpty
                ? "Progress signal: completed steps included \(naturalList(completedTitles.map { $0.lowercased() }))."
                : "Progress signal: completed steps such as \(naturalList(completedTitles.map { $0.lowercased() })) gave concrete evidence of movement toward \(reflectionGoal.lowercased())."
        }
        let progressWords = ["calmer", "better", "easier", "handled", "managed", "finished", "started", "done"]
        let wins = entries.filter { $0.entryType == .win || progressWords.contains(where: $0.text.lowercased().contains) }
        if let latest = wins.sorted(by: { $0.date > $1.date }).first {
            return reflectionGoal.isEmpty
                ? "Progress signal: \(latest.entryType == .win ? "you recorded a win" : "your wording included a shift toward progress")."
                : "Progress signal: \(latest.entryType == .win ? "you recorded a win" : "your wording included a shift toward progress"), which may support \(reflectionGoal.lowercased())."
        }
        return entries.count >= 5 ? "Progress signal is still light. Track what helps, not only what hurts." : ""
    }

    private func primaryLoop(from entries: [JournalEntry]) -> String {
        let themes = entries.flatMap(\.themes)
        let counts = Dictionary(grouping: themes, by: { $0 }).mapValues(\.count)
        if (counts["Anxiety"] ?? 0) >= 2 || (counts["Open loops"] ?? 0) >= 2 {
            return "Likely loop: worry or unfinished decisions build pressure, then action gets harder."
        }
        if (counts["Stress"] ?? 0) >= 2 || (counts["Work"] ?? 0) >= 2 {
            return "Likely loop: load builds, recovery gets delayed, then everything feels more urgent."
        }
        if (counts["Sleep"] ?? 0) >= 2 {
            return "Likely loop: sleep disruption lowers energy, then smaller tasks feel heavier."
        }
        if (counts["Relationships"] ?? 0) >= 2 {
            return "Likely loop: an interaction sticks, the story grows, and repair gets delayed."
        }
        return entries.count >= 5 ? "Likely loop is still forming. Keep entries concrete so next week can compare better." : ""
    }

    private func nextExperiment(from entries: [JournalEntry], reflectionGoal: String) -> String {
        let themes = entries.flatMap(\.themes)
        if themes.contains("Anxiety") || themes.contains("Open loops") {
            return reflectionGoal.isEmpty
                ? "Next 7 days: use one 60-second reset before the hardest decision, then log whether it changed the next step."
                : "Next 7 days: use one 60-second reset before the hardest decision, then log whether it made \(reflectionGoal.lowercased()) easier to follow through on."
        }
        if themes.contains("Sleep") {
            return reflectionGoal.isEmpty
                ? "Next 7 days: set one wind-down cue and log sleep quality the next morning."
                : "Next 7 days: set one wind-down cue and log whether better sleep gives more room for \(reflectionGoal.lowercased())."
        }
        if themes.contains("Work") {
            return reflectionGoal.isEmpty
                ? "Next 7 days: close or park one work loop before opening a new one."
                : "Next 7 days: close or park one work loop before opening a new one, then note whether it helps \(reflectionGoal.lowercased())."
        }
        return reflectionGoal.isEmpty
            ? "Next 7 days: pick one small action daily and mark whether it helped."
            : "Next 7 days: pick one small daily action that clearly supports \(reflectionGoal.lowercased()), then mark whether it helped."
    }

    private func baselineComparison(from entries: [JournalEntry], reflectionGoal: String) -> String {
        let low = entries.filter { $0.mood.score <= 2 }.count
        let high = entries.filter { $0.mood.score >= 4 }.count
        if high > low {
            return reflectionGoal.isEmpty
                ? "Compared with your starting baseline, this week contains more steadiness signals than strain signals."
                : "Compared with your starting baseline, this week contains more steadiness signals than strain signals, which gives \(reflectionGoal.lowercased()) more room."
        }
        if low > high {
            return reflectionGoal.isEmpty
                ? "Compared with your starting baseline, this week still needs a smaller, stabilizing plan."
                : "Compared with your starting baseline, this week still needs a smaller, steadier plan before \(reflectionGoal.lowercased()) will feel reachable."
        }
        return reflectionGoal.isEmpty
            ? "Compared with your starting baseline, this week looks mixed rather than clearly better or worse."
            : "Compared with your starting baseline, this week looks mixed, so progress toward \(reflectionGoal.lowercased()) is still uneven."
    }

    private func suggestedTemplate(from entries: [JournalEntry]) -> String {
        let themes = entries.flatMap(\.themes)
        if themes.contains("Anxiety") { return "Worry loop" }
        if themes.contains("Sleep") { return "Sleep" }
        if themes.contains("Relationships") { return "Interaction" }
        if themes.contains("Stress") || themes.contains("Work") { return "Overload" }
        return "Harder today"
    }

    private func researchPrompt(from entries: [JournalEntry]) -> String {
        let text = entries.map(\.text).joined(separator: " ").lowercased()
        if text.contains("avoid") || text.contains("procrastinat") {
            return "Worth learning about: avoidance loops and behavioral activation."
        }
        if text.contains("overthinking") || text.contains("replay") || text.contains("spiral") {
            return "Worth learning about: rumination and worry windows."
        }
        if text.contains("ignored") || text.contains("rejected") || text.contains("ashamed") {
            return "Worth learning about: rejection sensitivity and repair conversations."
        }
        if text.contains("burnout") || text.contains("too much") || text.contains("overwhel") {
            return "Worth learning about: burnout load and recovery debt."
        }
        return "Worth learning about: the pattern that repeats most, not every possible label."
    }

    private func goalFollowThrough(from entries: [JournalEntry], goals: [ReflectionGoal], reflectionGoal: String) -> String {
        guard goals.isEmpty == false else {
            return reflectionGoal.isEmpty
                ? "No experiments were tracked this week."
                : "No tracked goals showed whether this week moved \(reflectionGoal.lowercased()) forward."
        }
        let completedTitles = goals
            .filter { $0.status == .completed }
            .sorted { ($0.feedbackAt ?? $0.createdAt) > ($1.feedbackAt ?? $1.createdAt) }
            .prefix(2)
            .map(\.title)
        if goals.contains(where: { $0.feedback == "helped" }) {
            return reflectionGoal.isEmpty
                ? "At least one experiment was marked helpful, so repeat the condition before changing the plan."
                : "At least one experiment was marked helpful, so repeat that condition as part of moving \(reflectionGoal.lowercased()) forward."
        }
        if goals.contains(where: { $0.feedback == "didnt_help" }) {
            return "One experiment did not help; that is useful data for choosing a smaller or different next step."
        }
        if goals.contains(where: { $0.feedback == "skipped" }) {
            return "Some next steps were skipped, so next week should reduce friction rather than add pressure."
        }
        let progressWords = ["done", "finished", "completed", "sent", "followed through"]
        let progressSignals = entries.filter { entry in
            progressWords.contains { entry.text.lowercased().contains($0) }
        }.count
        if goals.contains(where: { $0.status == .completed }) || progressSignals >= 2 {
            return reflectionGoal.isEmpty
                ? "Your notes show follow-through on at least one planned step."
                : completedTitles.isEmpty == false
                    ? "Your notes show follow-through on \(naturalList(completedTitles.map { $0.lowercased() })) as part of moving toward \(reflectionGoal.lowercased())."
                    : "Your notes show follow-through on at least one planned step tied to \(reflectionGoal.lowercased())."
        }
        return reflectionGoal.isEmpty
            ? "Goals stayed active, but progress signals were limited this week."
            : "Goals stayed active, but progress toward \(reflectionGoal.lowercased()) still looked limited this week."
    }
}
