import Foundation

enum MainTab: Hashable {
    case today
    case journal
    case insights
    case messages
    case calm
}

@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var selectedTab: MainTab = .today
    @Published var pendingWeeklyCheckIn = false

    private init() {}

    func openWeeklyCheckIn() {
        selectedTab = .messages
        pendingWeeklyCheckIn = true
    }

    func consumeWeeklyCheckIn() {
        pendingWeeklyCheckIn = false
    }
}
