import Foundation

enum NotATherapistAPIError: Error {
    case invalidResponse
    case server(String)
}

struct NotATherapistAPIService {
    private let baseURL = URL(string: "https://notatherapist.vercel.app")!
    private let session: URLSession
    private let appAttestService: AppAttestService

    init(session: URLSession = .shared, appAttestService: AppAttestService = .shared) {
        self.session = session
        self.appAttestService = appAttestService
    }

    func dailyReview(date: Date, entries: [JournalEntry], profile: OnboardingProfile, healthSummary: HealthSummary?) async throws -> DailyReview {
        let request = DailyReviewRequest(date: date, entries: entries, profile: profile, healthSummary: healthSummary, goals: [])
        let response: DailyReviewResponse = try await post("/api/daily-review", body: request)
        return response.review
    }

    func dailyReview(date: Date, entries: [JournalEntry], profile: OnboardingProfile, healthSummary: HealthSummary?, goals: [ReflectionGoal]) async throws -> DailyReview {
        let request = DailyReviewRequest(date: date, entries: entries, profile: profile, healthSummary: healthSummary, goals: goals)
        let response: DailyReviewResponse = try await post("/api/daily-review", body: request)
        return response.review
    }

    func weeklyReview(entries: [JournalEntry], profile: OnboardingProfile, healthSummary: HealthSummary?, goals: [ReflectionGoal], planTier: AppPlanTier) async throws -> WeeklyReview? {
        let request = WeeklyReviewRequest(entries: entries, profile: profile, healthSummary: healthSummary, goals: goals, planTier: planTier.rawValue)
        let response: WeeklyReviewResponse = try await post("/api/weekly-review", body: request)
        return response.weeklyReview
    }

    func health() async throws -> APIHealthResponse {
        var request = URLRequest(url: baseURL.appending(path: "/api/health"))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 12

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw NotATherapistAPIError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(APIHealthResponse.self, from: data)
    }

    func startConversation(weeklyReview: WeeklyReview, profile: OnboardingProfile) async throws -> Conversation {
        let request = ConversationStartRequest(weeklyReview: weeklyReview, profile: profile)
        let response: ConversationStartResponse = try await post("/api/conversation/start", body: request)
        return response.conversation
    }

    func reply(text: String, action: String?, remainingTurns: Int, conversation: Conversation, profile: OnboardingProfile) async throws -> ConversationReplyResponse {
        let request = ConversationReplyRequest(
            text: text,
            action: action,
            remainingTurns: remainingTurns,
            conversation: conversation,
            profile: profile
        )
        return try await post("/api/conversation/reply", body: request)
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(_ path: String, body: RequestBody) async throws -> ResponseBody {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        let requestBody = try await attestableBody(body)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = try encoder.encode(requestBody)
        request.httpBody = payload

        let attestHeaders = await appAttestService.assertionHeaders(for: payload)
        attestHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotATherapistAPIError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if (200..<300).contains(httpResponse.statusCode) == false {
            if let error = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw NotATherapistAPIError.server(error.error.message)
            }
            throw NotATherapistAPIError.invalidResponse
        }

        return try decoder.decode(ResponseBody.self, from: data)
    }

    private func attestableBody<RequestBody: Encodable>(_ body: RequestBody) async throws -> AttestableRequest<RequestBody> {
        let challenge = try? await appAttestService.challenge()
        return AttestableRequest(attestChallenge: challenge, payload: body)
    }
}

private struct AttestableRequest<Payload: Encodable>: Encodable {
    let attestChallenge: String?
    let payload: Payload

    func encode(to encoder: Encoder) throws {
        try payload.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(attestChallenge, forKey: .attestChallenge)
    }

    private enum CodingKeys: String, CodingKey {
        case attestChallenge
    }
}

private struct DailyReviewRequest: Encodable {
    let date: Date
    let entries: [JournalEntry]
    let profile: OnboardingProfile
    let healthSummary: HealthSummary?
    let goals: [ReflectionGoal]
}

private struct DailyReviewResponse: Decodable {
    let ok: Bool
    let source: String?
    let review: DailyReview
}

private struct WeeklyReviewRequest: Encodable {
    let entries: [JournalEntry]
    let profile: OnboardingProfile
    let healthSummary: HealthSummary?
    let goals: [ReflectionGoal]
    let planTier: String
}

private struct WeeklyReviewResponse: Decodable {
    let ok: Bool
    let canReview: Bool
    let reason: String
    let source: String?
    let weeklyReview: WeeklyReview?
}

private struct ConversationStartRequest: Encodable {
    let weeklyReview: WeeklyReview
    let profile: OnboardingProfile
}

private struct ConversationStartResponse: Decodable {
    let ok: Bool
    let source: String?
    let conversation: Conversation
    let actions: [String]
}

private struct ConversationReplyRequest: Encodable {
    let text: String
    let action: String?
    let remainingTurns: Int
    let conversation: Conversation
    let profile: OnboardingProfile
}

struct ConversationReplyResponse: Decodable {
    let ok: Bool
    let source: String?
    let status: ConversationStatus
    let remainingTurns: Int
    let reply: String
    let userMessage: String?
    let suggestedGoal: ReflectionGoal?
    let actions: [String]
}

struct APIHealthResponse: Decodable {
    let ok: Bool
    let service: String
    let status: String
    let ai: String
    let model: String
    let timestamp: String
}

private struct APIErrorResponse: Decodable {
    let ok: Bool
    let error: APIErrorBody
}

private struct APIErrorBody: Decodable {
    let code: String
    let message: String
}
