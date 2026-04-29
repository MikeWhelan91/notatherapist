import Foundation

enum MainTab: Hashable {
    case journal
    case insights
    case messages
    case calm
}

@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var selectedTab: MainTab = .journal
    @Published var pendingWeeklyCheckIn = false
    @Published var pendingNewEntry = false
    @Published var pendingRunDailyReview = false

    private init() {}

    func openWeeklyCheckIn() {
        selectedTab = .messages
        pendingWeeklyCheckIn = true
    }

    func consumeWeeklyCheckIn() {
        pendingWeeklyCheckIn = false
    }

    func openNewQuickThought() {
        selectedTab = .journal
        pendingNewEntry = true
    }

    func consumeNewEntry() {
        pendingNewEntry = false
    }

    func runDailyReview() {
        selectedTab = .journal
        pendingRunDailyReview = true
    }

    func consumeRunDailyReview() {
        pendingRunDailyReview = false
    }
}
