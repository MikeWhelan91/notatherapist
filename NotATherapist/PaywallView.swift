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

    var title: String {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .annual: "Yearly"
        }
    }
}

struct PremiumPlanOption: Identifiable, Hashable {
    let id: String
    let cycle: PremiumBillingCycle
    let price: String
    let monthlyEquivalent: String?
    let badge: String?

    var ctaTitle: String {
        switch cycle {
        case .weekly:
            "Start weekly"
        case .monthly:
            "Start monthly"
        case .annual:
            "Get Anchor+ yearly"
        }
    }

    var billingCopy: String {
        switch cycle {
        case .weekly:
            return "\(price) billed weekly."
        case .monthly:
            return "\(price) billed monthly."
        case .annual:
            if let monthlyEquivalent {
                return "\(monthlyEquivalent) per month billed yearly."
            }
            return "\(price) billed yearly."
        }
    }

    static let all: [PremiumPlanOption] = [
        .init(
            id: "anchor.premium.annual",
            cycle: .annual,
            price: "$39.99",
            monthlyEquivalent: "$3.33",
            badge: "Best value"
        ),
        .init(
            id: "anchor.premium.monthly",
            cycle: .monthly,
            price: "$7.99",
            monthlyEquivalent: nil,
            badge: nil
        ),
        .init(
            id: "anchor.premium.weekly",
            cycle: .weekly,
            price: "$3.99",
            monthlyEquivalent: nil,
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
    .init(symbol: "sparkles", title: "Deeper AI daily review", detail: "Free daily review stays local. Premium adds one deeper AI review for each day you log."),
    .init(symbol: "calendar.badge.clock", title: "Expanded weekly AI report", detail: "Weekly AI review is included for everyone. Premium adds baseline comparison, progress tracking, and richer goal follow-through."),
    .init(symbol: "bubble.left.and.bubble.right", title: "Longer review conversations", detail: "Go deeper with weekly and monthly follow-up check-ins."),
    .init(symbol: "calendar", title: "Monthly review", detail: "A 4-week pattern read with a deeper AI conversation."),
    .init(symbol: "heart.text.square", title: "Health-aware insights", detail: "Sleep and steps pulled into the review when the data helps."),
    .init(symbol: "chart.line.uptrend.xyaxis", title: "Baseline comparison and progress tracking", detail: "See what changed week to week instead of reading each day in isolation.")
]

struct PaywallView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    let source: PaywallSource
    @State private var selectedPlan = PremiumPlanOption.all[0]

    var body: some View {
        GeometryReader { geo in
            NavigationStack {
                VStack(spacing: 0) {
                    header

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            titleBlock
                            featuresCard
                            planPicker(availableWidth: geo.size.width - 44)
                            pricingCopy
                            ctaButton
                            footerLinks
                        }
                        .frame(maxWidth: 520)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 22)
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
                .frame(maxWidth: 320)
        }
        .padding(.top, 4)
    }

    private var featuresCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(premiumFeatures.enumerated()), id: \.offset) { index, feature in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: feature.symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 24, height: 24)
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
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)

                if index < premiumFeatures.count - 1 {
                    Divider()
                        .overlay(Color.white.opacity(0.06))
                        .padding(.leading, 52)
                }
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
        let usableWidth = min(availableWidth, 520)
        let cardWidth = max(84, floor((usableWidth - (spacing * 2)) / 3))

        return HStack(spacing: 8) {
            ForEach(PremiumPlanOption.all) { plan in
                Button {
                    selectedPlan = plan
                } label: {
                    VStack(spacing: 6) {
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

                        Text(plan.price)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(selectedTextColor(for: plan))
                            .multilineTextAlignment(.center)

                        Text(planSubtitle(for: plan))
                            .font(.caption)
                            .foregroundStyle(selectedSecondaryTextColor(for: plan))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.86)
                    }
                    .frame(width: cardWidth, height: 110, alignment: .center)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                    .background(planBackground(for: plan), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(planStroke(for: plan), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: (cardWidth * 3) + (spacing * 2))
        .frame(maxWidth: .infinity)
    }

    private var pricingCopy: some View {
        VStack(spacing: 4) {
            Text(selectedPlan.billingCopy)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)
            Text("Auto-renews unless canceled at least 24 hours before renewal. Cancel anytime in App Store settings.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.52))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 310)
        }
    }

    private var ctaButton: some View {
        Button {
            appModel.activatePremium(plan: selectedPlan)
            dismiss()
        } label: {
            Text(appModel.isPremium ? "Premium active" : selectedPlan.ctaTitle)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(Color.black)
        }
        .buttonStyle(.plain)
        .disabled(appModel.isPremium)
        .opacity(appModel.isPremium ? 0.6 : 1)
    }

    private var footerLinks: some View {
        HStack(spacing: 18) {
            Button("Terms of service") {}
            Button("Privacy policy") {}
            Button("Restore purchase") {}
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

    private func perMonthLine(for plan: PremiumPlanOption) -> String {
        switch plan.cycle {
        case .weekly:
            return "Flexible access"
        case .monthly:
            return "Month to month"
        case .annual:
            return plan.monthlyEquivalent.map { "\($0) per month" } ?? ""
        }
    }

    private func planSubtitle(for plan: PremiumPlanOption) -> String {
        switch plan.cycle {
        case .annual:
            return "$3.33\nper month"
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
}
