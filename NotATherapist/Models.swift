import Foundation
import SwiftUI

enum CompanionEmotionalState: String, CaseIterable, Codable {
    case overwhelmed
    case activated
    case steadying
    case balanced
    case thriving

    var title: String {
        switch self {
        case .overwhelmed: "Overwhelmed"
        case .activated: "Activated"
        case .steadying: "Steadying"
        case .balanced: "Balanced"
        case .thriving: "Thriving"
        }
    }

    var summary: String {
        switch self {
        case .overwhelmed: "High strain right now. Keep steps short and calming."
        case .activated: "Still tense, but starting to stabilize."
        case .steadying: "You are finding rhythm and recovering faster."
        case .balanced: "Mostly steady with healthy day-to-day regulation."
        case .thriving: "Strong momentum and consistent emotional recovery."
        }
    }
}

enum MoodLevel: String, CaseIterable, Identifiable, Codable {
    case terrible
    case low
    case okay
    case good
    case great

    var id: String { rawValue }

    var label: String {
        switch self {
        case .terrible: "Terrible"
        case .low: "Low"
        case .okay: "Okay"
        case .good: "Good"
        case .great: "Great"
        }
    }

    var shortLabel: String {
        switch self {
        case .terrible: "Terrible"
        case .low: "Low"
        case .okay: "Okay"
        case .good: "Good"
        case .great: "Great"
        }
    }

    var symbol: String {
        switch self {
        case .terrible: "face.dashed"
        case .low: "minus"
        case .okay: "face.smiling"
        case .good: "face.smiling.inverse"
        case .great: "sparkles"
        }
    }

    var emoji: String {
        switch self {
        case .terrible: "😞"
        case .low: "😕"
        case .okay: "🙂"
        case .good: "😊"
        case .great: "😄"
        }
    }

    var score: Int {
        switch self {
        case .terrible: 1
        case .low: 2
        case .okay: 3
        case .good: 4
        case .great: 5
        }
    }

    var companionColor: Color {
        switch self {
        case .terrible: Color(red: 0.82, green: 0.40, blue: 0.39)
        case .low: Color(red: 0.86, green: 0.60, blue: 0.34)
        case .okay: .white
        case .good: Color(red: 0.30, green: 0.61, blue: 0.95)
        case .great: Color(red: 0.36, green: 0.76, blue: 0.56)
        }
    }

    // UI accent keeps "okay" readable on dark surfaces while preserving companion white.
    var interfaceAccentColor: Color {
        switch self {
        case .okay: Color(red: 0.78, green: 0.80, blue: 0.84)
        default: companionColor
        }
    }

    var calmerCompanionMood: MoodLevel {
        switch self {
        case .terrible: .low
        case .low: .okay
        case .okay: .good
        case .good: .great
        case .great: .great
        }
    }
}

enum EntryType: String, CaseIterable, Identifiable, Codable {
    case quickThought
    case rant
    case reflection
    case win

    var id: String { rawValue }

    var label: String {
        switch self {
        case .quickThought: "Quick thought"
        case .rant: "Unload"
        case .reflection: "Reflection"
        case .win: "Win"
        }
    }

    var icon: String {
        switch self {
        case .quickThought: "text.alignleft"
        case .rant: "exclamationmark.bubble"
        case .reflection: "sparkle.magnifyingglass"
        case .win: "checkmark.seal"
        }
    }
}

struct JournalEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var date: Date
    var mood: MoodLevel
    var entryType: EntryType
    var text: String
    var aiInsight: StructuredInsight
    var themes: [String]
    var sleepHours: Double? = nil
    var steps: Int? = nil
}

struct StructuredInsight: Codable, Hashable {
    var emotionalRead: String
    var pattern: String
    var reframe: String
    var action: String
}

enum InsightType: String, CaseIterable, Identifiable, Codable {
    case emotionalRead
    case pattern
    case reframe
    case action
    case risk
    case suggestion

    var id: String { rawValue }

    var label: String {
        switch self {
        case .emotionalRead: "Emotional read"
        case .pattern: "Pattern"
        case .reframe: "Reframe"
        case .action: "Action"
        case .risk: "Focus for next week"
        case .suggestion: "Suggestion"
        }
    }

    var symbol: String {
        switch self {
        case .emotionalRead: "waveform.path.ecg"
        case .pattern: "point.3.connected.trianglepath.dotted"
        case .reframe: "arrow.triangle.2.circlepath"
        case .action: "checkmark.circle"
        case .risk: "exclamationmark.triangle"
        case .suggestion: "lightbulb"
        }
    }
}

struct Insight: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var body: String
    var category: String
    var date: Date
    var type: InsightType
}

struct DailyReview: Identifiable, Codable, Hashable {
    let id: UUID
    var date: Date
    var summary: String
    var insight: StructuredInsight
    var evidenceStrength: String = ""
    var suggestedGoalTitle: String
    var suggestedGoalReason: String
    var supportInfoTitle: String? = nil
    var supportInfoBody: String? = nil
    var supportSteps: [String]? = nil
    var acceptedGoalID: UUID?
    var entryIDs: [UUID]
    var createdAt: Date
    var source: String? = nil
}

enum AppPlanTier: String, CaseIterable, Identifiable, Codable {
    case free
    case premium

    var id: String { rawValue }

    var label: String {
        switch self {
        case .free: "Free"
        case .premium: "Premium"
        }
    }

    var dailyReviewLabel: String {
        switch self {
        case .free: "Clear daily reflection and one small next step"
        case .premium: "Deeper daily review with evidence strength"
        }
    }

    var dailyContextLabel: String {
        switch self {
        case .free: "Last 5 days, up to 20 context entries"
        case .premium: "Last 21 days, up to 90 context entries"
        }
    }

    var weeklyReviewLabel: String {
        switch self {
        case .free: "Weekly summary and consistency stats"
        case .premium: "Weekly pattern report with change tracking"
        }
    }

    var weeklyContextLabel: String {
        switch self {
        case .free: "Last 30 days, up to 45 entries"
        case .premium: "Last 120 days, up to 220 entries"
        }
    }
}

enum MessageSender: String, Codable {
    case user
    case ai
}

enum ConversationStatus: String, Codable {
    case active
    case ended
}

enum ConversationPhase: String, Codable {
    case core
    case deeper
}

enum ReviewCadence: String, Codable {
    case weekly
    case monthly
}

struct ConversationMessage: Identifiable, Codable, Hashable {
    let id: UUID
    var sender: MessageSender
    var text: String
    var date: Date
    var replyContext: String? = nil
}

struct Conversation: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var date: Date
    var preview: String
    var messages: [ConversationMessage]
    var status: ConversationStatus
    var remainingTurns: Int
    var maxTurns: Int = 3
    var deepeningUsed: Bool = false
    var phase: ConversationPhase = .core
    var contextHints: [String] = []
    var reviewCadence: ReviewCadence? = .weekly
}

struct CalmSound: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var subtitle: String
    var icon: String
    var duration: String
}

enum CalmPathway: String, CaseIterable, Identifiable, Codable, Hashable {
    case slowDown
    case clearHead
    case sleepOffRamp
    case workClosure
    case bodyGrounding
    case panicSettle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .slowDown: "Slow down"
        case .clearHead: "Clear your head"
        case .sleepOffRamp: "Sleep off-ramp"
        case .workClosure: "Work closure"
        case .bodyGrounding: "Ground in your body"
        case .panicSettle: "Panic settle"
        }
    }

    var subtitle: String {
        switch self {
        case .slowDown: "Steady your breathing and lower body tension."
        case .clearHead: "Reduce loops and settle one crowded thought."
        case .sleepOffRamp: "Make the evening quieter and easier to leave."
        case .workClosure: "Close the work loop before it follows you home."
        case .bodyGrounding: "Anchor attention in sensation when your head is too loud."
        case .panicSettle: "Lower urgency fast when your body spikes."
        }
    }

    var icon: String {
        switch self {
        case .slowDown: "wind"
        case .clearHead: "sparkle.magnifyingglass"
        case .sleepOffRamp: "moon.stars"
        case .workClosure: "briefcase"
        case .bodyGrounding: "figure.mind.and.body"
        case .panicSettle: "bolt.heart"
        }
    }

    var helperLine: String {
        switch self {
        case .slowDown: "Best when your body feels switched on."
        case .clearHead: "Best when your head keeps circling the same thing."
        case .sleepOffRamp: "Best when work or worry keeps following you into the evening."
        case .workClosure: "Best when unfinished work keeps staying mentally open."
        case .bodyGrounding: "Best when you need to get out of analysis and into sensation."
        case .panicSettle: "Best when urgency spikes and you need a fast landing."
        }
    }

    var shortLabel: String {
        switch self {
        case .slowDown: "Slow"
        case .clearHead: "Head"
        case .sleepOffRamp: "Sleep"
        case .workClosure: "Close"
        case .bodyGrounding: "Body"
        case .panicSettle: "Panic"
        }
    }

    var defaultMode: BreathingMode {
        switch self {
        case .slowDown: .box
        case .clearHead: .reset
        case .sleepOffRamp: .fourSevenEight
        case .workClosure: .extendedExhale
        case .bodyGrounding: .coherent
        case .panicSettle: .physiologicalSigh
        }
    }

    var targetDuration: TimeInterval {
        switch self {
        case .slowDown: 120
        case .clearHead: 90
        case .sleepOffRamp: 180
        case .workClosure: 150
        case .bodyGrounding: 240
        case .panicSettle: 75
        }
    }

    var durationLabel: String {
        switch self {
        case .slowDown: "2 min"
        case .clearHead: "90 sec"
        case .sleepOffRamp: "3 min"
        case .workClosure: "2.5 min"
        case .bodyGrounding: "4 min"
        case .panicSettle: "75 sec"
        }
    }

    var accentMood: MoodLevel {
        switch self {
        case .slowDown: .low
        case .clearHead: .good
        case .sleepOffRamp: .great
        case .workClosure: .okay
        case .bodyGrounding: .good
        case .panicSettle: .low
        }
    }
}

enum CalmHelpfulness: String, CaseIterable, Codable, Hashable {
    case notReally
    case aBit
    case yes

    var label: String {
        switch self {
        case .notReally: "Not really"
        case .aBit: "A bit"
        case .yes: "Yes"
        }
    }
}

struct CalmSessionLog: Identifiable, Codable, Hashable {
    let id: UUID
    var pathway: CalmPathway
    var breathingMode: String
    var startedAt: Date
    var endedAt: Date
    var duration: TimeInterval
    var startingMood: MoodLevel
    var targetMood: MoodLevel
    var helpfulness: CalmHelpfulness?
}

struct WeeklyReview: Identifiable, Codable, Hashable {
    let id: UUID
    var dateRange: String
    var patterns: [String]
    var risk: String
    var suggestion: String
    var healthPatterns: [String] = []
    var patternShift: String = ""
    var goalFollowThrough: String = ""
    var progressSignal: String?
    var primaryLoop: String?
    var nextExperiment: String?
    var baselineComparison: String?
    var suggestedTemplate: String?
    var researchPrompt: String?
}

struct MonthlyReview: Identifiable, Codable, Hashable {
    let id: UUID
    var monthTitle: String
    var dateRange: String = ""
    var entryCount: Int
    var activeDays: Int
    var averageMood: Double
    var topThemes: [String]
    var strongestPattern: String
    var progress: String
    var nextExperiment: String
    var dataQuality: String = "early"
    var summary: String = ""
    var moodRange: String = ""
    var patterns: [String] = []
    var risk: String = ""
    var suggestion: String = ""
    var healthPatterns: [String] = []
    var patternShift: String = ""
    var goalFollowThrough: String = ""
    var progressSignal: String?
    var primaryLoop: String?
    var baselineComparison: String?
    var suggestedTemplate: String?
    var researchPrompt: String?
}

struct MemorySignal: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var detail: String
    var count: Int
    var lastSeen: Date
    var category: String
}

enum HealthTrend: String, Codable, Hashable {
    case up
    case down
    case stable
}

struct HealthSummary: Codable, Hashable {
    var averageSleep: Double
    var lastNightSleep: Double
    var averageSteps: Int
    var trend: HealthTrend
}

enum GoalCadence: String, Codable, Hashable, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        }
    }
}

enum ReflectionGoalStatus: String, Codable, Hashable {
    case active
    case completed
    case archived
}

struct ReflectionGoal: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var reason: String
    var createdAt: Date
    var dueDate: Date?
    var status: ReflectionGoalStatus
    var cadence: GoalCadence?
    var sourceConversationID: UUID?
    var checkInPrompt: String
    var feedback: String?
    var feedbackAt: Date?
}

struct OnboardingProfile: Codable, Hashable {
    struct AssessmentDomainSummary: Codable, Hashable {
        var domain: String
        var score: Int
        var maxScore: Int
        var level: String
    }

    struct AssessmentProfile: Codable, Hashable {
        var instrument: String
        var version: String
        var totalScore: Int
        var maxScore: Int
        var answers: [Int]
        var questionLabels: [String]
        var domains: [AssessmentDomainSummary]
        var completedAt: Date
    }

    var preferredName: String
    var ageRange: String
    var lifeContext: [String]
    var focusAreas: [String]
    var reflectionGoal: String
    var personalStory: String
    var streakGoal: Int = 3
    var assessment: AssessmentProfile?

    static var current: OnboardingProfile {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "onboardingProfileV2"),
           let decoded = try? JSONDecoder().decode(OnboardingProfile.self, from: data) {
            return decoded
        }
        let storedStreakGoal = defaults.integer(forKey: "onboardingStreakGoal")
        return OnboardingProfile(
            preferredName: defaults.string(forKey: "onboardingPreferredName") ?? "",
            ageRange: defaults.string(forKey: "onboardingAgeRange") ?? "",
            lifeContext: split(defaults.string(forKey: "onboardingLifeContext")),
            focusAreas: split(defaults.string(forKey: "onboardingFocusAreas")),
            reflectionGoal: defaults.string(forKey: "onboardingReflectionGoal") ?? "",
            personalStory: defaults.string(forKey: "onboardingPersonalStory") ?? "",
            streakGoal: storedStreakGoal > 0 ? storedStreakGoal : 3,
            assessment: nil
        )
    }

    var compactContext: String {
        [
            preferredName.isEmpty ? nil : "Name: \(preferredName)",
            ageRange.isEmpty ? nil : "Age range: \(ageRange)",
            lifeContext.isEmpty ? nil : "Life context: \(lifeContext.joined(separator: ", "))",
            focusAreas.isEmpty ? nil : "Focus: \(focusAreas.joined(separator: ", "))",
            reflectionGoal.isEmpty ? nil : "Goal: \(reflectionGoal)",
            "Streak goal: \(streakGoal) days",
            personalStory.isEmpty ? nil : "Story: \(personalStory)",
            assessmentSummaryLine
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    var assessmentSummaryLine: String? {
        guard let assessment else { return nil }
        let domainText = assessment.domains
            .map { "\($0.domain): \($0.score)/\($0.maxScore) (\($0.level))" }
            .joined(separator: ", ")
        return "Assessment (\(assessment.instrument)): total \(assessment.totalScore)/\(assessment.maxScore). \(domainText)"
    }

    private static func split(_ string: String?) -> [String] {
        (string ?? "")
            .split(separator: "|")
            .map(String.init)
            .filter { $0.isEmpty == false }
    }
}

enum AICircleState: Equatable {
    case idle
    case attentive
    case listening
    case typing
    case thinking
    case responding
    case checkIn
    case settled
}

enum AIConnectionState: Equatable {
    case unknown
    case checking
    case connected(model: String)
    case unconfigured(model: String)
    case unavailable

    var label: String {
        switch self {
        case .unknown: "Not checked"
        case .checking: "Checking"
        case .connected(let model): "Connected · \(model)"
        case .unconfigured(let model): "Unconfigured · \(model)"
        case .unavailable: "Unavailable"
        }
    }
}

enum ICloudSyncState: Equatable {
    case off
    case checking
    case available
    case synced(Date)
    case unavailable(String)

    var label: String {
        switch self {
        case .off: "Off"
        case .checking: "Checking"
        case .available: "Available"
        case .synced(let date): "Synced \(date.formatted(date: .omitted, time: .shortened))"
        case .unavailable(let reason): reason
        }
    }
}

extension Double {
    var cleanHours: String {
        "\(String(format: "%.1f", self))h"
    }
}
