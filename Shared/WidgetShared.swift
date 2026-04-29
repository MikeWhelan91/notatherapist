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

struct WidgetAffirmationPayload: Codable {
    var preferredName: String
    var planTier: WidgetPlanTier
    var primaryText: String
    var secondaryText: String
    var affirmationText: String?
    var affirmationOptions: [String]
    var affirmationIndex: Int
    var stylePreset: WidgetStylePreset
    var enabledCategories: [WidgetAffirmationCategory]
    var issueContext: String
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
        enabledCategories: [WidgetAffirmationCategory],
        issueContext: String,
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
        self.enabledCategories = enabledCategories
        self.issueContext = issueContext
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
        case enabledCategories
        case issueContext
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
        enabledCategories = try container.decodeIfPresent([WidgetAffirmationCategory].self, forKey: .enabledCategories) ?? WidgetAffirmationCategory.allCases
        issueContext = try container.decode(String.self, forKey: .issueContext)
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
