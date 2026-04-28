import Foundation

enum NotATherapistAPIError: Error {
    case invalidResponse
    case server(String)
}

struct NotATherapistAPIService {
    private let baseURL = URL(string: "https://notatherapist.vercel.app")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func dailyReview(date: Date, entries: [JournalEntry], profile: OnboardingProfile, healthSummary: HealthSummary?) async throws -> DailyReview {
        let request = DailyReviewRequest(date: date, entries: entries, profile: profile, healthSummary: healthSummary)
        let response: DailyReviewResponse = try await post("/api/daily-review", body: request)
        return response.review
    }

    func weeklyReview(entries: [JournalEntry], profile: OnboardingProfile, healthSummary: HealthSummary?) async throws -> WeeklyReview? {
        let request = WeeklyReviewRequest(entries: entries, profile: profile, healthSummary: healthSummary)
        let response: WeeklyReviewResponse = try await post("/api/weekly-review", body: request)
        return response.weeklyReview
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

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(body)

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
}

private struct DailyReviewRequest: Encodable {
    let date: Date
    let entries: [JournalEntry]
    let profile: OnboardingProfile
    let healthSummary: HealthSummary?
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

private struct APIErrorResponse: Decodable {
    let ok: Bool
    let error: APIErrorBody
}

private struct APIErrorBody: Decodable {
    let code: String
    let message: String
}
