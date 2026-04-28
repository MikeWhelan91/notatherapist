import Foundation
import SwiftUI

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
        case .low: "face.smiling.inverse"
        case .okay: "face.smiling"
        case .good: "face.smiling.fill"
        case .great: "sparkles"
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
        case .rant: "Rant"
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
        case .risk: "Potential risk"
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
    var suggestedGoalTitle: String
    var suggestedGoalReason: String
    var acceptedGoalID: UUID?
    var entryIDs: [UUID]
    var createdAt: Date
}

enum MessageSender: String, Codable {
    case user
    case ai
}

enum ConversationStatus: String, Codable {
    case active
    case ended
}

struct ConversationMessage: Identifiable, Codable, Hashable {
    let id: UUID
    var sender: MessageSender
    var text: String
    var date: Date
}

struct Conversation: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var date: Date
    var preview: String
    var messages: [ConversationMessage]
    var status: ConversationStatus
    var remainingTurns: Int
}

struct CalmSound: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var subtitle: String
    var icon: String
    var duration: String
}

struct WeeklyReview: Identifiable, Codable, Hashable {
    let id: UUID
    var dateRange: String
    var patterns: [String]
    var risk: String
    var suggestion: String
    var healthPatterns: [String] = []
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

enum ReflectionGoalStatus: String, Codable, Hashable {
    case active
    case completed
}

struct ReflectionGoal: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var reason: String
    var createdAt: Date
    var dueDate: Date?
    var status: ReflectionGoalStatus
    var sourceConversationID: UUID?
    var checkInPrompt: String
}

struct OnboardingProfile: Codable, Hashable {
    var preferredName: String
    var ageRange: String
    var lifeContext: [String]
    var focusAreas: [String]
    var reflectionGoal: String

    static var current: OnboardingProfile {
        let defaults = UserDefaults.standard
        return OnboardingProfile(
            preferredName: defaults.string(forKey: "onboardingPreferredName") ?? "",
            ageRange: defaults.string(forKey: "onboardingAgeRange") ?? "",
            lifeContext: split(defaults.string(forKey: "onboardingLifeContext")),
            focusAreas: split(defaults.string(forKey: "onboardingFocusAreas")),
            reflectionGoal: defaults.string(forKey: "onboardingReflectionGoal") ?? ""
        )
    }

    var compactContext: String {
        [
            preferredName.isEmpty ? nil : "Name: \(preferredName)",
            ageRange.isEmpty ? nil : "Age range: \(ageRange)",
            lifeContext.isEmpty ? nil : "Life context: \(lifeContext.joined(separator: ", "))",
            focusAreas.isEmpty ? nil : "Focus: \(focusAreas.joined(separator: ", "))",
            reflectionGoal.isEmpty ? nil : "Goal: \(reflectionGoal)",
            "Voice: factual, calm, contemplative, empathetic, kind"
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
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
    case typing
    case thinking
    case responding
    case checkIn
    case settled
}

extension Double {
    var cleanHours: String {
        "\(String(format: "%.1f", self))h"
    }
}
