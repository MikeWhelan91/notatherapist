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
            ZStack {
                Group {
                    if hasCompletedOnboarding {
                        MainTabView()
                    } else {
                        OnboardingView()
                    }
                }

                if router.onboardingCompanionHandoffActive {
                    OnboardingCompanionHandoffOverlay()
                }
            }
            .environmentObject(appModel)
            .environmentObject(router)
            .environmentObject(notificationService)
            .environmentObject(healthKitManager)
            .preferredColorScheme(.dark)
            .tint(AppTheme.accent)
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

private struct OnboardingCompanionHandoffOverlay: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            AICircleView(
                state: .attentive,
                size: 132,
                strokeWidth: 3.2,
                motionStyle: .continuous,
                tint: appModel.journalCompanionTint,
                personality: appModel.companionPersonality
            )
            .position(
                x: geo.size.width / 2,
                y: router.onboardingCompanionHandoffSettled ? todayLandingY(in: geo) : onboardingStartY(in: geo)
            )
            .animation(handoffAnimation, value: router.onboardingCompanionHandoffSettled)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var handoffAnimation: Animation {
        reduceMotion
            ? .linear(duration: 0.01)
            : .spring(response: 0.72, dampingFraction: 0.86, blendDuration: 0.12)
    }

    private func onboardingStartY(in geo: GeometryProxy) -> CGFloat {
        max(geo.safeAreaInsets.top + 128, 188)
    }

    private func todayLandingY(in geo: GeometryProxy) -> CGFloat {
        max(geo.safeAreaInsets.top + 300, 338)
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var previousTab: MainTab = .journal
    @State private var transitionTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .top) {
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

            GlobalCompanionOverlay()
                .allowsHitTesting(false)
        }
        .tint(AppTheme.accent)
        .onAppear {
            updateCompanionPresentation(for: router.selectedTab)
            previousTab = router.selectedTab
        }
        .onChange(of: router.selectedTab) { _, tab in
            runCompanionTabTransition(from: previousTab, to: tab)
            previousTab = tab
        }
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

    private func updateCompanionPresentation(for tab: MainTab) {
        switch tab {
        case .journal:
            router.companionPresentation = .journal
        case .insights:
            router.companionPresentation = .hidden
        case .messages:
            router.companionPresentation = .hidden
        case .calm:
            router.companionPresentation = .calm
        }
    }

    private func runCompanionTabTransition(from oldTab: MainTab, to newTab: MainTab) {
        guard oldTab != newTab else { return }
        transitionTask?.cancel()

        router.companionTabTransitioning = true
        router.companionPresentation = presentation(for: oldTab)

        transitionTask = Task {
            try? await Task.sleep(for: .milliseconds(24))
            guard Task.isCancelled == false else { return }
            await MainActor.run {
                withAnimation(companionPageTransitionAnimation) {
                    router.companionPresentation = presentation(for: newTab)
                }
            }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 20 : 520))
            guard Task.isCancelled == false else { return }
            await MainActor.run {
                transitionTask = nil
                router.companionTabTransitioning = false
            }
        }
    }

    private func cancelCompanionTransitionIfNeeded() {
        transitionTask?.cancel()
        transitionTask = nil
        router.companionTabTransitioning = false
    }

    private var companionPageTransitionAnimation: Animation {
        reduceMotion
            ? .linear(duration: 0.01)
            : .smooth(duration: 0.52, extraBounce: 0)
    }

    private func presentation(for tab: MainTab) -> CompanionPresentation {
        switch tab {
        case .journal: .journal
        case .insights: .hidden
        case .messages: .hidden
        case .calm: .calm
        }
    }
}

private struct GlobalCompanionOverlay: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if shouldRenderOverlay {
            GeometryReader { geo in
                AICircleView(
                    state: overlayState,
                    size: overlaySize,
                    strokeWidth: overlayStrokeWidth,
                    tint: overlayTint,
                    personality: appModel.companionPersonality
                )
                .position(x: geo.size.width / 2, y: overlayCenterY(in: geo))
                .animation(companionMotion, value: router.companionPresentation)
            }
            .ignoresSafeArea(edges: .top)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.18), value: shouldRenderOverlay)
        }
    }

    private var overlaySize: CGFloat {
        switch router.companionPresentation {
        case .journal: 132
        case .insights, .messages, .calm: 122
        case .composer: 130
        case .transitioningToComposer: 132
        case .hidden: 0
        }
    }

    private var overlayStrokeWidth: CGFloat {
        switch router.companionPresentation {
        case .journal: 3.2
        case .insights, .messages, .calm: 3.1
        case .composer: 3.2
        case .transitioningToComposer: 3.2
        case .hidden: 0
        }
    }

    private var overlayState: AICircleState {
        switch router.companionPresentation {
        case .journal: journalOverlayState
        case .insights: .checkIn
        case .messages: .attentive
        case .calm: .settled
        case .composer: .listening
        case .transitioningToComposer: .listening
        case .hidden: .idle
        }
    }

    private var overlayTint: Color {
        switch router.companionPresentation {
        case .hidden:
            appModel.journalCompanionTint
        case .journal, .transitioningToComposer:
            appModel.journalCompanionTint
        case .insights, .messages, .calm, .composer:
            appModel.companionTint
        }
    }

    private var journalOverlayState: AICircleState {
        appModel.companionCircleState
    }

    private var overlayTopPadding: CGFloat {
        switch router.companionPresentation {
        case .journal: 274
        case .insights, .messages, .calm: 84
        case .composer: 104
        case .transitioningToComposer: 104
        case .hidden: 0
        }
    }

    private var shouldRenderOverlay: Bool {
        if router.onboardingCompanionHandoffActive {
            return false
        }
        switch router.companionPresentation {
        case .insights, .messages, .calm:
            return true
        case .journal, .transitioningToComposer, .hidden, .composer:
            return false
        }
    }

    private var companionMotion: Animation {
        reduceMotion
            ? .linear(duration: 0.01)
            : .smooth(duration: 0.86, extraBounce: 0)
    }

    private func overlayCenterY(in geo: GeometryProxy) -> CGFloat {
        geo.safeAreaInsets.top + overlayTopPadding + (overlaySize / 2)
    }
}
