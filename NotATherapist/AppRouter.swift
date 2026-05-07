import Foundation

enum MainTab: Hashable {
    case journal
    case insights
    case messages
    case calm
}

enum CompanionPresentation: Hashable {
    case journal
    case insights
    case messages
    case calm
    case composer
    case transitioningToComposer
    case hidden
}

@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var selectedTab: MainTab = .journal
    @Published var companionPresentation: CompanionPresentation = .journal
    @Published var companionTabTransitioning = false
    @Published var onboardingCompanionHandoffActive = false
    @Published var onboardingCompanionHandoffSettled = false
    @Published var pendingWeeklyCheckIn = false
    @Published var pendingNewEntry = false
    @Published var pendingRunDailyReview = false
    @Published var pendingCalmPathway: CalmPathway?
    @Published var pendingCalmAutostart = false
    @Published var activePaywall: PaywallSource?

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

    func openCalm(pathway: CalmPathway? = nil, autoStart: Bool = false) {
        selectedTab = .calm
        pendingCalmPathway = pathway
        pendingCalmAutostart = autoStart
    }

    func consumeCalmLaunch() -> (pathway: CalmPathway?, autoStart: Bool) {
        let launch = (pendingCalmPathway, pendingCalmAutostart)
        pendingCalmPathway = nil
        pendingCalmAutostart = false
        return launch
    }

    func presentPaywall(_ source: PaywallSource) {
        activePaywall = source
    }

    func dismissPaywall() {
        activePaywall = nil
    }
}
