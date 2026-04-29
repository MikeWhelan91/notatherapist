import SwiftUI

@main
struct NotATherapistApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppNotificationDelegate.self) private var appDelegate
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var appModel = AppViewModel()
    @StateObject private var router = AppRouter.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var healthKitManager = HealthKitManager.shared
    private let commandStore = AppCommandStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(appModel)
            .environmentObject(router)
            .environmentObject(notificationService)
            .environmentObject(healthKitManager)
            .preferredColorScheme(.dark)
            .onAppear {
                consumePendingCommandIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                consumePendingCommandIfNeeded()
            }
        }
    }

    private func consumePendingCommandIfNeeded() {
        guard let command = commandStore.consume() else { return }
        appModel.handle(command, router: router)
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var healthKitManager: HealthKitManager

    var body: some View {
        TabView(selection: $router.selectedTab) {
            JournalView()
                .tabItem { Label("Today", systemImage: "book.closed") }
                .tag(MainTab.journal)

            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(MainTab.insights)

            MessagesView()
                .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right") }
                .tag(MainTab.messages)

            CalmView()
                .tabItem { Label("Calm", systemImage: "circle.dotted") }
                .tag(MainTab.calm)
        }
        .tint(.primary)
        .task {
            await healthKitManager.refreshIfPossible()
            appModel.updateHealthSummary(healthKitManager.summary)
            await appModel.refreshAIConnection()
            await appModel.refreshICloudStatus()
        }
        .onChange(of: healthKitManager.summary) { _, summary in
            appModel.updateHealthSummary(summary)
        }
    }
}
