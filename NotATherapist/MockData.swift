import Foundation

enum MockData {
    static let calendar = Calendar.current

    static var entries: [JournalEntry] {
        let service = MockAIInsightService()
        let drafts: [(Int, MoodLevel, EntryType, String, Double?, Int?)] = [
            (-31, .low, .reflection, "I started the month tired and scattered. Work felt louder than everything else.", 5.6, 3200),
            (-29, .okay, .quickThought, "A shorter to-do list stopped the spiral a bit.", 6.1, 4100),
            (-27, .good, .win, "Closed one messy work thread and slept easier.", 7.0, 6400),
            (-25, .low, .rant, "Too many tabs open again. I kept delaying one decision that would have helped.", 5.2, 2900),
            (-23, .okay, .reflection, "Writing before bed helped me stop replaying the meeting.", 6.4, 5200),
            (-21, .good, .win, "A walk before lunch gave me more focus for the afternoon.", 7.3, 8800),
            (-18, .terrible, .rant, "Slept badly and snapped at everything. I felt like I was bracing all day.", 4.9, 1800),
            (-17, .low, .reflection, "The day was still heavy, but taking one thing off the list reduced the pressure.", 5.5, 3600),
            (-15, .okay, .quickThought, "I noticed the usual Sunday work dread but it passed faster this time.", 6.8, 4700),
            (-13, .good, .reflection, "Sticking to one clear point in the meeting helped me feel less scrambled.", 7.1, 7000),
            (-11, .great, .win, "I finished the task I had been avoiding and felt lighter immediately.", 7.8, 9100),
            (-9, .low, .rant, "Family stuff plus work noise made it hard to settle tonight.", 5.7, 3900),
            (-8, .okay, .reflection, "A calmer evening routine seems to be helping a bit.", 6.9, 5400),
            (-6, .okay, .reflection, "Sunday evening felt heavier than it needed to. Work kept coming back into my head.", 6.2, 4600),
            (-5, .good, .win, "Went for a long walk before answering messages. I felt clearer afterwards.", 7.4, 9800),
            (-4, .low, .rant, "Too many open tabs, too many requests, and not enough clean stopping points.", 5.8, 3300),
            (-3, .okay, .quickThought, "Sleeping a little more made the day feel less sharp around the edges.", 7.2, 5100),
            (-2, .okay, .quickThought, "I slept badly but writing the list down helped a little.", 5.9, 4200),
            (-1, .good, .reflection, "The meeting was fine once I picked the one point I actually needed to make.", 7.0, 6900),
            (0, .okay, .quickThought, "I keep circling the same work decision. It might need one small close rather than more thinking.", 6.5, 4800)
        ]

        var built: [JournalEntry] = []
        for draft in drafts {
            let date = calendar.date(byAdding: .day, value: draft.0, to: Date()) ?? Date()
            let themes = service.themes(for: draft.3, entryType: draft.2)
            var entry = JournalEntry(
                id: UUID(),
                date: date,
                mood: draft.1,
                entryType: draft.2,
                text: draft.3,
                aiInsight: StructuredInsight(emotionalRead: "", pattern: "", reframe: "", action: ""),
                themes: themes,
                sleepHours: draft.4,
                steps: draft.5
            )
            entry.aiInsight = service.insight(for: entry, recentEntries: built)
            built.append(entry)
        }
        return built.sorted { $0.date > $1.date }
    }

    static var insights: [Insight] {
        [
            Insight(id: UUID(), title: "Unfinished decisions", body: "Work entries often mention unfinished decisions.", category: "Patterns", date: Date(), type: .pattern),
            Insight(id: UUID(), title: "Movement helps", body: "Mood trends higher on days with a walk or gym note.", category: "Suggestions", date: calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date(), type: .suggestion),
            Insight(id: UUID(), title: "Sunday pressure", body: "Stress tends to appear before the week starts.", category: "Recent", date: calendar.date(byAdding: .day, value: -2, to: Date()) ?? Date(), type: .emotionalRead),
            Insight(id: UUID(), title: "One close", body: "A single finished task may help more than a longer plan.", category: "Suggestions", date: calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date(), type: .action)
        ]
    }

    static var healthSummary: HealthSummary {
        HealthSummary(
            averageSleep: 6.6,
            lastNightSleep: 6.5,
            averageSteps: 5480,
            trend: .up
        )
    }

    static var calmSessions: [CalmSessionLog] {
        [
            CalmSessionLog(
                id: UUID(),
                pathway: .slowDown,
                breathingMode: BreathingMode.box.rawValue,
                startedAt: calendar.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
                endedAt: calendar.date(byAdding: .day, value: -5, to: Date())?.addingTimeInterval(120) ?? Date(),
                duration: 120,
                startingMood: .low,
                targetMood: .okay,
                helpfulness: .yes
            ),
            CalmSessionLog(
                id: UUID(),
                pathway: .workClosure,
                breathingMode: BreathingMode.extendedExhale.rawValue,
                startedAt: calendar.date(byAdding: .day, value: -4, to: Date()) ?? Date(),
                endedAt: calendar.date(byAdding: .day, value: -4, to: Date())?.addingTimeInterval(150) ?? Date(),
                duration: 150,
                startingMood: .okay,
                targetMood: .good,
                helpfulness: .yes
            ),
            CalmSessionLog(
                id: UUID(),
                pathway: .clearHead,
                breathingMode: BreathingMode.reset.rawValue,
                startedAt: calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                endedAt: calendar.date(byAdding: .day, value: -3, to: Date())?.addingTimeInterval(90) ?? Date(),
                duration: 90,
                startingMood: .okay,
                targetMood: .good,
                helpfulness: .aBit
            ),
            CalmSessionLog(
                id: UUID(),
                pathway: .panicSettle,
                breathingMode: BreathingMode.physiologicalSigh.rawValue,
                startedAt: calendar.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                endedAt: calendar.date(byAdding: .day, value: -2, to: Date())?.addingTimeInterval(75) ?? Date(),
                duration: 75,
                startingMood: .terrible,
                targetMood: .low,
                helpfulness: .aBit
            ),
            CalmSessionLog(
                id: UUID(),
                pathway: .sleepOffRamp,
                breathingMode: BreathingMode.fourSevenEight.rawValue,
                startedAt: calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                endedAt: calendar.date(byAdding: .day, value: -1, to: Date())?.addingTimeInterval(180) ?? Date(),
                duration: 180,
                startingMood: .low,
                targetMood: .okay,
                helpfulness: .yes
            ),
            CalmSessionLog(
                id: UUID(),
                pathway: .bodyGrounding,
                breathingMode: BreathingMode.coherent.rawValue,
                startedAt: calendar.date(byAdding: .day, value: -8, to: Date()) ?? Date(),
                endedAt: calendar.date(byAdding: .day, value: -8, to: Date())?.addingTimeInterval(240) ?? Date(),
                duration: 240,
                startingMood: .low,
                targetMood: .okay,
                helpfulness: .yes
            ),
            CalmSessionLog(
                id: UUID(),
                pathway: .workClosure,
                breathingMode: BreathingMode.extendedExhale.rawValue,
                startedAt: calendar.date(byAdding: .day, value: -11, to: Date()) ?? Date(),
                endedAt: calendar.date(byAdding: .day, value: -11, to: Date())?.addingTimeInterval(150) ?? Date(),
                duration: 150,
                startingMood: .okay,
                targetMood: .good,
                helpfulness: .notReally
            ),
            CalmSessionLog(
                id: UUID(),
                pathway: .sleepOffRamp,
                breathingMode: BreathingMode.fourSevenEight.rawValue,
                startedAt: calendar.date(byAdding: .day, value: -15, to: Date()) ?? Date(),
                endedAt: calendar.date(byAdding: .day, value: -15, to: Date())?.addingTimeInterval(180) ?? Date(),
                duration: 180,
                startingMood: .low,
                targetMood: .okay,
                helpfulness: .yes
            ),
            CalmSessionLog(
                id: UUID(),
                pathway: .clearHead,
                breathingMode: BreathingMode.reset.rawValue,
                startedAt: calendar.date(byAdding: .day, value: -19, to: Date()) ?? Date(),
                endedAt: calendar.date(byAdding: .day, value: -19, to: Date())?.addingTimeInterval(90) ?? Date(),
                duration: 90,
                startingMood: .okay,
                targetMood: .good,
                helpfulness: .aBit
            ),
            CalmSessionLog(
                id: UUID(),
                pathway: .bodyGrounding,
                breathingMode: BreathingMode.coherent.rawValue,
                startedAt: calendar.date(byAdding: .day, value: -23, to: Date()) ?? Date(),
                endedAt: calendar.date(byAdding: .day, value: -23, to: Date())?.addingTimeInterval(240) ?? Date(),
                duration: 240,
                startingMood: .low,
                targetMood: .okay,
                helpfulness: .yes
            )
        ]
        .sorted { $0.endedAt > $1.endedAt }
    }

    static var reflectionGoals: [ReflectionGoal] {
        [
            ReflectionGoal(
                id: UUID(),
                title: "Close one open work loop before ending the day",
                reason: "You keep revisiting unfinished work decisions at night.",
                createdAt: calendar.date(byAdding: .day, value: -6, to: Date()) ?? Date(),
                dueDate: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
                status: .active,
                cadence: .daily,
                sourceConversationID: nil,
                checkInPrompt: "Did closing one work loop help tonight?",
                feedback: nil,
                feedbackAt: nil
            ),
            ReflectionGoal(
                id: UUID(),
                title: "Name tomorrow's single priority before bed",
                reason: "You settle faster when the next day has one clear landing point.",
                createdAt: calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                dueDate: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
                status: .active,
                cadence: .daily,
                sourceConversationID: nil,
                checkInPrompt: "Did naming the one priority lower the bedtime spiral?",
                feedback: nil,
                feedbackAt: nil
            ),
            ReflectionGoal(
                id: UUID(),
                title: "Protect a steadier evening routine",
                reason: "Sleep and evening decompression seem to affect your next day more than usual.",
                createdAt: calendar.date(byAdding: .day, value: -9, to: Date()) ?? Date(),
                dueDate: calendar.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
                status: .active,
                cadence: .weekly,
                sourceConversationID: nil,
                checkInPrompt: "Did the evening routine help you switch off sooner?",
                feedback: nil,
                feedbackAt: nil
            ),
            ReflectionGoal(
                id: UUID(),
                title: "Build calmer work boundaries this month",
                reason: "The long-term pattern is less about single bad days and more about work staying open too long.",
                createdAt: calendar.date(byAdding: .day, value: -20, to: Date()) ?? Date(),
                dueDate: calendar.date(byAdding: .day, value: 10, to: Date()) ?? Date(),
                status: .active,
                cadence: .monthly,
                sourceConversationID: nil,
                checkInPrompt: "Is this month feeling more contained than the last one?",
                feedback: nil,
                feedbackAt: nil
            ),
            ReflectionGoal(
                id: UUID(),
                title: "Finish the one avoided decision before dinner",
                reason: "Small closure reduces the work replay at night.",
                createdAt: calendar.date(byAdding: .day, value: -6, to: Date()) ?? Date(),
                dueDate: calendar.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
                status: .completed,
                cadence: .daily,
                sourceConversationID: nil,
                checkInPrompt: "Did one clean decision help the evening feel lighter?",
                feedback: "helped",
                feedbackAt: calendar.date(byAdding: .day, value: -5, to: Date()) ?? Date()
            ),
            ReflectionGoal(
                id: UUID(),
                title: "Take a short walk before reopening messages",
                reason: "Movement keeps the stress pile-on from feeling so immediate.",
                createdAt: calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                dueDate: calendar.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                status: .completed,
                cadence: .daily,
                sourceConversationID: nil,
                checkInPrompt: "Did the walk interrupt the stress loop?",
                feedback: "helped",
                feedbackAt: calendar.date(byAdding: .day, value: -2, to: Date()) ?? Date()
            ),
            ReflectionGoal(
                id: UUID(),
                title: "Take a walk before responding to the pile-on",
                reason: "Movement seems to interrupt the stress build-up.",
                createdAt: calendar.date(byAdding: .day, value: -12, to: Date()) ?? Date(),
                dueDate: calendar.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
                status: .completed,
                cadence: .daily,
                sourceConversationID: nil,
                checkInPrompt: "Did the walk change your headspace?",
                feedback: "helped",
                feedbackAt: calendar.date(byAdding: .day, value: -10, to: Date()) ?? Date()
            ),
            ReflectionGoal(
                id: UUID(),
                title: "Choose the one closing point before the Friday finish",
                reason: "You are steadier when the week ends with one deliberate closure rather than drift.",
                createdAt: calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
                dueDate: calendar.date(byAdding: .day, value: -4, to: Date()) ?? Date(),
                status: .completed,
                cadence: .weekly,
                sourceConversationID: nil,
                checkInPrompt: "Did the clearer stopping point lower the weekend carry-over?",
                feedback: "helped",
                feedbackAt: calendar.date(byAdding: .day, value: -4, to: Date()) ?? Date()
            ),
            ReflectionGoal(
                id: UUID(),
                title: "Write the one point before the meeting",
                reason: "You feel steadier when you arrive with one clear point already chosen.",
                createdAt: calendar.date(byAdding: .day, value: -16, to: Date()) ?? Date(),
                dueDate: calendar.date(byAdding: .day, value: -13, to: Date()) ?? Date(),
                status: .completed,
                cadence: .weekly,
                sourceConversationID: nil,
                checkInPrompt: "Did the single-point prep reduce meeting stress?",
                feedback: "helped",
                feedbackAt: calendar.date(byAdding: .day, value: -13, to: Date()) ?? Date()
            ),
            ReflectionGoal(
                id: UUID(),
                title: "Keep evenings from turning back into work",
                reason: "You want calmer boundaries around the end of the day.",
                createdAt: calendar.date(byAdding: .day, value: -12, to: Date()) ?? Date(),
                dueDate: calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                status: .completed,
                cadence: .monthly,
                sourceConversationID: nil,
                checkInPrompt: "Did the month feel more contained overall?",
                feedback: "helped",
                feedbackAt: calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            ),
            ReflectionGoal(
                id: UUID(),
                title: "End one day with inbox zero pressure removed",
                reason: "Some daily steps were too broad and kept getting dropped.",
                createdAt: calendar.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
                dueDate: calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                status: .archived,
                cadence: .daily,
                sourceConversationID: nil,
                checkInPrompt: "Was the scope realistic?",
                feedback: "auto_cleared",
                feedbackAt: calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date()
            ),
            ReflectionGoal(
                id: UUID(),
                title: "Reduce late-night work rumination",
                reason: "You wanted a cleaner cut-off in the evenings.",
                createdAt: calendar.date(byAdding: .day, value: -22, to: Date()) ?? Date(),
                dueDate: calendar.date(byAdding: .day, value: -18, to: Date()) ?? Date(),
                status: .archived,
                cadence: .daily,
                sourceConversationID: nil,
                checkInPrompt: "Did this goal stay realistic?",
                feedback: "auto_cleared",
                feedbackAt: calendar.date(byAdding: .day, value: -18, to: Date()) ?? Date()
            )
        ]
    }

    static var dailyReviews: [DailyReview] {
        let service = MockAIInsightService()
        let sortedEntries = entries.sorted { $0.date < $1.date }
        let reviewDays = [-11, -5, -2, 0]
        return reviewDays.compactMap { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: Date()) ?? Date()
            let dayEntries = sortedEntries.filter { calendar.isDate($0.date, inSameDayAs: date) }
            let recentEntries = sortedEntries.filter { $0.date < date }
            guard var review = service.dailyReview(
                for: date,
                entries: dayEntries,
                recentEntries: recentEntries,
                profile: .current,
                healthSummary: healthSummary,
                goals: reflectionGoals
            ) else { return nil }
            review.source = offset == 0 ? "openai" : "local"
            return review
        }
        .sorted { $0.date > $1.date }
    }

    static var monthlyReview: MonthlyReview {
        MonthlyReview(
            id: UUID(),
            monthTitle: calendar.date(byAdding: .month, value: 0, to: Date())?.formatted(.dateTime.month(.wide).year()) ?? "This month",
            dateRange: "Last 4 weeks",
            entryCount: entries.count,
            activeDays: Set(entries.map { calendar.startOfDay(for: $0.date) }).count,
            averageMood: 3.1,
            topThemes: ["Work", "Sleep", "Reflection", "Stress"],
            strongestPattern: "Work decisions and poor evening cut-offs keep reappearing, while movement and smaller finishing points improve your mood.",
            progress: "You completed several smaller follow-through goals, which suggests structure helps when stress starts to build.",
            nextExperiment: "Keep one cleaner work stopping point and one short evening reset for the next two weeks.",
            dataQuality: "solid",
            summary: "This month showed some strain around work loops, but also clearer evidence that small closure actions and movement help you recover.",
            moodRange: "Mood stayed mixed but improved faster after days with cleaner boundaries.",
            patterns: [
                "Work rumination is the most repeated drag on mood.",
                "Sleep quality changes how manageable the next day feels.",
                "Movement and short written plans reduce overload."
            ],
            risk: "If work stays mentally open at night, strain tends to carry into the next day.",
            suggestion: "Favor short closure rituals over larger productivity plans.",
            healthPatterns: [
                "Higher-step days tend to line up with steadier mood.",
                "Lower sleep nights make the next day feel sharper and more reactive."
            ],
            patternShift: "Compared with the start of the month, you are recovering a little faster after heavier days.",
            goalFollowThrough: "Your completed goals suggest you respond best to specific, concrete actions rather than broad intentions.",
            progressSignal: "You are not fully steady yet, but there is enough follow-through to show movement in the right direction.",
            primaryLoop: "Open work loops -> evening rumination -> lower sleep -> harder next day",
            baselineComparison: "Compared with earlier entries, the last two weeks show slightly better recovery when you close one task before stopping.",
            suggestedTemplate: nil,
            researchPrompt: nil
        )
    }

    static var sounds: [CalmSound] {
        [
            CalmSound(id: UUID(), title: "Rain", subtitle: "Soft steady rain", icon: "cloud.rain", duration: "20 min"),
            CalmSound(id: UUID(), title: "Ocean", subtitle: "Low shore wash", icon: "water.waves", duration: "18 min"),
            CalmSound(id: UUID(), title: "Forest", subtitle: "Light wind in trees", icon: "leaf", duration: "16 min"),
            CalmSound(id: UUID(), title: "Night", subtitle: "Quiet room tone", icon: "moon", duration: "25 min"),
            CalmSound(id: UUID(), title: "Fan", subtitle: "Even white noise", icon: "fan", duration: "30 min")
        ]
    }
}
