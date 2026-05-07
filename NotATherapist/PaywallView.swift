import SwiftUI

enum PaywallSource: String, Identifiable {
    case settings
    case dailyReview
    case weeklyReview
    case monthlyReview
    case messages

    var id: String { rawValue }
}

enum PremiumBillingCycle: String, CaseIterable, Codable, Identifiable {
    case weekly
    case monthly
    case annual

    var id: String { rawValue }

    init?(productID: String) {
        switch productID {
        case "anchor_weekly":
            self = .weekly
        case "anchor_monthly":
            self = .monthly
        case "anchor_yearly":
            self = .annual
        default:
            return nil
        }
    }

    var title: String {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .annual: "Yearly"
        }
    }

    var productID: String {
        switch self {
        case .weekly: "anchor_weekly"
        case .monthly: "anchor_monthly"
        case .annual: "anchor_yearly"
        }
    }
}

struct PremiumPlanOption: Identifiable, Hashable {
    let id: String
    let cycle: PremiumBillingCycle
    let badge: String?

    static let all: [PremiumPlanOption] = [
        .init(
            id: PremiumBillingCycle.annual.productID,
            cycle: .annual,
            badge: "Best value"
        ),
        .init(
            id: PremiumBillingCycle.monthly.productID,
            cycle: .monthly,
            badge: nil
        ),
        .init(
            id: PremiumBillingCycle.weekly.productID,
            cycle: .weekly,
            badge: nil
        )
    ]
}

struct PremiumFeature: Identifiable, Hashable {
    let id = UUID()
    let symbol: String
    let title: String
    let detail: String
}

private let premiumFeatures: [PremiumFeature] = [
    .init(symbol: "sparkles", title: "Deeper AI daily review", detail: "Free daily review stays local. Premium adds one stronger AI read for each day you log."),
    .init(symbol: "calendar.badge.clock", title: "Expanded weekly AI report", detail: "Weekly AI review is included for everyone. Premium adds progress tracking, completed-goal references, and baseline comparison."),
    .init(symbol: "calendar", title: "Monthly review", detail: "A 4-week pattern read with a deeper AI conversation."),
    .init(symbol: "bubble.left.and.bubble.right", title: "Longer review conversations", detail: "Go deeper with weekly and monthly follow-up check-ins."),
    .init(symbol: "heart.text.square", title: "Health-aware insights", detail: "Sleep and steps pulled into the review when the data helps."),
    .init(symbol: "square.and.arrow.up", title: "Structured wellbeing report export", detail: "Share a cleaner summary of entries, reviews, goals, and recurring signals.")
]

struct PaywallView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    let source: PaywallSource
    @State private var selectedPlan = PremiumPlanOption.all[0]
    @State private var showAllFeatures = false

    private let contentWidth: CGFloat = 360

    var body: some View {
        GeometryReader { geo in
            let columnWidth = max(0, min(contentWidth, geo.size.width - 40))
            NavigationStack {
                VStack(spacing: 0) {
                    header

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            titleBlock
                            featuresCard
                            planPicker(availableWidth: columnWidth)
                            pricingCopy
                            ctaButton
                            footerLinks
                        }
                        .frame(width: columnWidth)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 22)
                        .padding(.bottom, max(26, geo.safeAreaInsets.bottom + 6))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color.black)
                .clipped()
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await appModel.prepareSubscriptions()
            if let matched = PremiumPlanOption.all.first(where: { $0.cycle == appModel.premiumBillingCycle }) {
                selectedPlan = matched
            }
        }
    }

    private var header: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
            .padding(.trailing, 22)
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                HStack(spacing: 0) {
                    Text("Unlock your ")
                    Text("Anchor")
                    Text("+")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .baselineOffset(6)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Text("reflection edge")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .font(.system(size: 31, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .lineSpacing(2)

            Text(sourceSubtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.66))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .padding(.top, 4)
    }

    private var featuresCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(visibleFeatures.enumerated()), id: \.offset) { index, feature in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: feature.symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(feature.detail)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 14)

                if index < visibleFeatures.count - 1 {
                    Divider()
                        .overlay(Color.white.opacity(0.06))
                        .padding(.leading, 49)
                }
            }

            if premiumFeatures.count > visibleFeatures.count {
                Divider()
                    .overlay(Color.white.opacity(0.06))
                    .padding(.leading, 49)

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showAllFeatures = true
                    }
                } label: {
                    HStack {
                        Text("More features")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, 15)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func planPicker(availableWidth: CGFloat) -> some View {
        let spacing: CGFloat = 8
        let usableWidth = max(300, availableWidth)
        let cardWidth = max(88, floor((usableWidth - (spacing * 2)) / 3))
        let rowWidth = max(0, (cardWidth * 3) + (spacing * 2))

        return HStack(spacing: 8) {
            ForEach(PremiumPlanOption.all) { plan in
                Button {
                    selectedPlan = plan
                } label: {
                    VStack(spacing: 4) {
                        ZStack(alignment: .top) {
                            if let badge = plan.badge {
                                Text(badge)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(selectedPlan.id == plan.id ? Color.black : .white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(selectedPlan.id == plan.id ? Color.black.opacity(0.08) : Color.white.opacity(0.08), in: Capsule())
                                    .padding(.top, -4)
                            }
                        }
                        .frame(height: 18)

                        Text(plan.cycle.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selectedTextColor(for: plan))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)

                        Text(displayPrice(for: plan))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(selectedTextColor(for: plan))
                            .multilineTextAlignment(.center)

                        Text(planSubtitle(for: plan))
                            .font(.caption)
                            .foregroundStyle(selectedSecondaryTextColor(for: plan))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }
                    .frame(width: cardWidth, height: 96, alignment: .center)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 8)
                    .background(planBackground(for: plan), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(planStroke(for: plan), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: rowWidth)
        .frame(maxWidth: .infinity)
    }

    private var pricingCopy: some View {
        VStack(spacing: 4) {
            Text(billingCopy(for: selectedPlan))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)
            Text("Auto-renews unless canceled at least 24 hours before renewal. Cancel anytime in App Store settings.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.52))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 290)

            if let message = appModel.subscriptionErrorMessage, message.isEmpty == false {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.red.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
        }
    }

    private var ctaButton: some View {
        Button {
            if appModel.isPremium {
                openManageSubscriptions()
            } else {
                Task {
                    let purchased = await appModel.purchasePremium(selectedPlan.cycle)
                    if purchased {
                        dismiss()
                    }
                }
            }
        } label: {
            Group {
                if appModel.purchaseInFlightCycle == selectedPlan.cycle {
                    ProgressView()
                        .tint(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                } else {
                    Text(appModel.isPremium ? "Manage subscription" : ctaTitle(for: selectedPlan))
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(Color.black)
        }
        .buttonStyle(.plain)
        .disabled(appModel.purchaseInFlightCycle != nil || (appModel.isPremium == false && appModel.subscriptionProduct(for: selectedPlan.cycle) == nil))
        .opacity((appModel.purchaseInFlightCycle != nil || (appModel.isPremium == false && appModel.subscriptionProduct(for: selectedPlan.cycle) == nil)) ? 0.6 : 1)
    }

    private var footerLinks: some View {
        HStack(spacing: 18) {
            Link("Terms of service", destination: URL(string: "https://getsolutions.app/terms")!)
            Link("Privacy policy", destination: URL(string: "https://getsolutions.app/privacy")!)
            Button(appModel.restoreInFlight ? "Restoring..." : "Restore purchase") {
                Task {
                    await appModel.restorePurchases()
                }
            }
            .disabled(appModel.restoreInFlight)
        }
        .buttonStyle(.plain)
        .font(.caption)
        .foregroundStyle(.white.opacity(0.58))
        .padding(.top, 4)
    }

    private var sourceSubtitle: String {
        switch source {
        case .settings:
            return "Unlock the full review system and longer AI context."
        case .dailyReview:
            return "Go beyond the local daily reflection with a deeper AI read."
        case .weeklyReview:
            return "Go beyond the core weekly AI review with deeper goal and baseline analysis."
        case .monthlyReview:
            return "Monthly reviews and monthly AI conversations are Premium."
        case .messages:
            return "Unlock longer review conversations and monthly AI follow-through."
        }
    }

    private var visibleFeatures: [PremiumFeature] {
        showAllFeatures ? premiumFeatures : Array(premiumFeatures.prefix(4))
    }

    private func perMonthLine(for plan: PremiumPlanOption) -> String {
        switch plan.cycle {
        case .weekly:
            return "Flexible access"
        case .monthly:
            return "Month to month"
        case .annual:
            return "Billed yearly"
        }
    }

    private func planSubtitle(for plan: PremiumPlanOption) -> String {
        switch plan.cycle {
        case .annual:
            return "Billed\nyearly"
        case .monthly:
            return "Month\nto month"
        case .weekly:
            return "Flexible\naccess"
        }
    }

    private func planBackground(for plan: PremiumPlanOption) -> some ShapeStyle {
        if selectedPlan.id == plan.id {
            return AnyShapeStyle(Color.white)
        }
        return AnyShapeStyle(Color.white.opacity(0.08))
    }

    private func planStroke(for plan: PremiumPlanOption) -> Color {
        selectedPlan.id == plan.id ? Color.white : Color.white.opacity(0.06)
    }

    private func selectedTextColor(for plan: PremiumPlanOption) -> Color {
        selectedPlan.id == plan.id ? .black : .white
    }

    private func selectedSecondaryTextColor(for plan: PremiumPlanOption) -> Color {
        selectedPlan.id == plan.id ? .black.opacity(0.74) : .white.opacity(0.58)
    }

    private func displayPrice(for plan: PremiumPlanOption) -> String {
        appModel.subscriptionProduct(for: plan.cycle)?.displayPrice ?? fallbackPrice(for: plan.cycle)
    }

    private func billingCopy(for plan: PremiumPlanOption) -> String {
        let price = displayPrice(for: plan)
        switch plan.cycle {
        case .weekly:
            return "\(price) billed weekly."
        case .monthly:
            return "\(price) billed monthly."
        case .annual:
            return "\(price) billed yearly."
        }
    }

    private func ctaTitle(for plan: PremiumPlanOption) -> String {
        switch plan.cycle {
        case .weekly:
            return "Start weekly"
        case .monthly:
            return "Start monthly"
        case .annual:
            return "Get Anchor+ yearly"
        }
    }

    private func fallbackPrice(for cycle: PremiumBillingCycle) -> String {
        switch cycle {
        case .weekly:
            return "$3.99"
        case .monthly:
            return "$7.99"
        case .annual:
            return "$39.99"
        }
    }

    private func openManageSubscriptions() {
        guard let url = appModel.manageSubscriptionsURL else { return }
        openURL(url)
    }
}
