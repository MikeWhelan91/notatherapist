import Foundation

enum WidgetPlanTier: String, Codable {
    case free
    case premium
}

enum WidgetStylePreset: String, CaseIterable, Codable {
    case minimal
    case bold
    case calm

    var label: String {
        switch self {
        case .minimal: "Minimal"
        case .bold: "Bold"
        case .calm: "Calm"
        }
    }
}

enum WidgetAffirmationCategory: String, CaseIterable, Codable, Identifiable {
    case grounding
    case confidence
    case focus
    case rest
    case stress

    var id: String { rawValue }

    var label: String {
        switch self {
        case .grounding: "Grounding"
        case .confidence: "Confidence"
        case .focus: "Focus"
        case .rest: "Rest"
        case .stress: "Stress"
        }
    }
}

enum WidgetAccentColor: String, CaseIterable, Codable, Identifiable {
    case green
    case blue
    case copper
    case purple
    case rose

    var id: String { rawValue }

    var label: String {
        switch self {
        case .green: "Green"
        case .blue: "Blue"
        case .copper: "Copper"
        case .purple: "Purple"
        case .rose: "Rose"
        }
    }
}

enum WidgetFontStyle: String, CaseIterable, Codable, Identifiable {
    case rounded
    case serif
    case clean

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rounded: "Rounded"
        case .serif: "Serif"
        case .clean: "Clean"
        }
    }
}

struct WidgetAffirmationPayload: Codable {
    var preferredName: String
    var planTier: WidgetPlanTier
    var primaryText: String
    var secondaryText: String
    var affirmationText: String?
    var affirmationOptions: [String]
    var affirmationIndex: Int
    var stylePreset: WidgetStylePreset
    var accentColor: WidgetAccentColor
    var fontStyle: WidgetFontStyle
    var enabledCategories: [WidgetAffirmationCategory]
    var issueContext: String
    var entryCount: Int
    var currentStreak: Int
    var averageMood: Double
    var latestMood: String
    var recentMoodScores: [Int]
    var updatedAt: Date

    init(
        preferredName: String,
        planTier: WidgetPlanTier,
        primaryText: String,
        secondaryText: String,
        affirmationText: String?,
        affirmationOptions: [String],
        affirmationIndex: Int,
        stylePreset: WidgetStylePreset,
        accentColor: WidgetAccentColor,
        fontStyle: WidgetFontStyle,
        enabledCategories: [WidgetAffirmationCategory],
        issueContext: String,
        entryCount: Int = 0,
        currentStreak: Int = 0,
        averageMood: Double = 0,
        latestMood: String = "okay",
        recentMoodScores: [Int] = [],
        updatedAt: Date
    ) {
        self.preferredName = preferredName
        self.planTier = planTier
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.affirmationText = affirmationText
        self.affirmationOptions = affirmationOptions
        self.affirmationIndex = affirmationIndex
        self.stylePreset = stylePreset
        self.accentColor = accentColor
        self.fontStyle = fontStyle
        self.enabledCategories = enabledCategories
        self.issueContext = issueContext
        self.entryCount = entryCount
        self.currentStreak = currentStreak
        self.averageMood = averageMood
        self.latestMood = latestMood
        self.recentMoodScores = recentMoodScores
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case preferredName
        case planTier
        case primaryText
        case secondaryText
        case affirmationText
        case affirmationOptions
        case affirmationIndex
        case stylePreset
        case accentColor
        case fontStyle
        case enabledCategories
        case issueContext
        case entryCount
        case currentStreak
        case averageMood
        case latestMood
        case recentMoodScores
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preferredName = try container.decode(String.self, forKey: .preferredName)
        planTier = try container.decode(WidgetPlanTier.self, forKey: .planTier)
        primaryText = try container.decode(String.self, forKey: .primaryText)
        secondaryText = try container.decode(String.self, forKey: .secondaryText)
        affirmationText = try container.decodeIfPresent(String.self, forKey: .affirmationText)
        affirmationOptions = try container.decodeIfPresent([String].self, forKey: .affirmationOptions) ?? []
        affirmationIndex = try container.decodeIfPresent(Int.self, forKey: .affirmationIndex) ?? 0
        stylePreset = try container.decodeIfPresent(WidgetStylePreset.self, forKey: .stylePreset) ?? .minimal
        accentColor = try container.decodeIfPresent(WidgetAccentColor.self, forKey: .accentColor) ?? .green
        fontStyle = try container.decodeIfPresent(WidgetFontStyle.self, forKey: .fontStyle) ?? .rounded
        enabledCategories = try container.decodeIfPresent([WidgetAffirmationCategory].self, forKey: .enabledCategories) ?? WidgetAffirmationCategory.allCases
        issueContext = try container.decode(String.self, forKey: .issueContext)
        entryCount = try container.decodeIfPresent(Int.self, forKey: .entryCount) ?? 0
        currentStreak = try container.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        averageMood = try container.decodeIfPresent(Double.self, forKey: .averageMood) ?? 0
        latestMood = try container.decodeIfPresent(String.self, forKey: .latestMood) ?? "okay"
        recentMoodScores = try container.decodeIfPresent([Int].self, forKey: .recentMoodScores) ?? []
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

enum WidgetShared {
    static let appGroupID = "group.com.mikewhelan.anchor"
    static let payloadKey = "anchor.widget.affirmation.payload"
    static let appCommandKey = "anchor.app.command"
}

enum AnchorAppCommand: String, Codable {
    case newQuickThought
    case runDailyReview
    case startWeeklyCheckIn
    case startCalmSession
    case nextAffirmation
}

struct WidgetPayloadStore {
    private let defaults = UserDefaults(suiteName: WidgetShared.appGroupID)

    func load() -> WidgetAffirmationPayload? {
        guard let data = defaults?.data(forKey: WidgetShared.payloadKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetAffirmationPayload.self, from: data)
    }

    func save(_ payload: WidgetAffirmationPayload) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return }
        defaults?.set(data, forKey: WidgetShared.payloadKey)
    }

    func cycleAffirmation() -> WidgetAffirmationPayload? {
        guard var payload = load() else { return nil }
        guard payload.affirmationOptions.isEmpty == false else { return payload }
        payload.affirmationIndex = (payload.affirmationIndex + 1) % payload.affirmationOptions.count
        payload.affirmationText = payload.affirmationOptions[payload.affirmationIndex]
        payload.updatedAt = .now
        save(payload)
        return payload
    }
}

struct AppCommandStore {
    private let defaults = UserDefaults(suiteName: WidgetShared.appGroupID)

    func set(_ command: AnchorAppCommand) {
        defaults?.set(command.rawValue, forKey: WidgetShared.appCommandKey)
    }

    func consume() -> AnchorAppCommand? {
        guard let raw = defaults?.string(forKey: WidgetShared.appCommandKey),
              let command = AnchorAppCommand(rawValue: raw) else {
            return nil
        }
        defaults?.removeObject(forKey: WidgetShared.appCommandKey)
        return command
    }
}
