import SwiftUI
import UIKit

struct CalmView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var router: AppRouter
    @State private var selectedDestination: CalmLaunchDestination?

    private let pathwayColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var recommendedPathway: CalmPathway {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 21 || hour <= 4 {
            return .sleepOffRamp
        }

        switch appModel.companionState {
        case .overwhelmed:
            return .panicSettle
        case .activated:
            return .slowDown
        case .steadying:
            return .clearHead
        case .balanced:
            return .workClosure
        case .thriving:
            return .bodyGrounding
        }
    }

    private var calmTabTint: Color {
        appModel.journalCompanionTint
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: 1)
                            .id("calm-top")

                        CompanionTabHeader(
                            title: "Calm",
                            state: recommendedPathway.heroCompanionState,
                            tint: calmTabTint,
                            showsCircle: false
                        )

                        VStack(alignment: .leading, spacing: AppSpacing.section) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Choose a guided breathing reset for sleep, overwhelm, focus, or closure.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                SectionLabel(title: "Pick a reset")
                                Text("Tap any pathway to start it immediately.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                LazyVGrid(columns: pathwayColumns, spacing: 12) {
                                    ForEach(CalmPathway.allCases) { pathway in
                                        CalmPathwayButton(
                                            pathway: pathway,
                                            isSelected: false,
                                            accent: calmTabTint
                                        ) {
                                            openPathway(pathway)
                                        }
                                    }
                                }
                            }

                            if appModel.recentCalmSessions.isEmpty == false {
                                VStack(alignment: .leading, spacing: 10) {
                                    SectionLabel(title: "Recent sessions")
                                    VStack(spacing: 10) {
                                        ForEach(appModel.recentCalmSessions.prefix(3)) { session in
                                            CalmRecentSessionRow(session: session)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(AppSpacing.page)
                    }
                }
                .onChange(of: router.selectedTab) { _, tab in
                    guard tab == .calm else { return }
                    proxy.scrollTo("calm-top", anchor: .top)
                    consumePendingCalmLaunchIfNeeded()
                }
            }
            .scrollIndicators(.hidden)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedDestination) { destination in
                CalmSessionView(pathway: destination.pathway, mode: destination.mode, autoStart: destination.autoStart)
            }
            .onAppear {
                consumePendingCalmLaunchIfNeeded()
            }
        }
    }

    private func openPathway(_ pathway: CalmPathway) {
        selectedDestination = CalmLaunchDestination(
            pathway: pathway,
            mode: pathway.defaultMode,
            autoStart: false
        )
    }

    private func consumePendingCalmLaunchIfNeeded() {
        let launch = router.consumeCalmLaunch()
        guard let pathway = launch.pathway else { return }
        selectedDestination = CalmLaunchDestination(pathway: pathway, mode: pathway.defaultMode, autoStart: launch.autoStart)
    }
}

private struct CalmPathwayButton: View {
    let pathway: CalmPathway
    let isSelected: Bool
    let accent: Color
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    Image(systemName: pathway.icon)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(accent)
                    Spacer()
                    Text(pathway.durationLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(pathway.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Text(pathway.selectionLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.14) : AppSurface.fill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? accent.opacity(0.9) : AppSurface.stroke, lineWidth: isSelected ? 1.2 : 0.5)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CalmRecentSessionRow: View {
    let session: CalmSessionLog

    var body: some View {
        ReferenceCard {
            HStack(spacing: 12) {
                Image(systemName: session.pathway.icon)
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 24)
                    .foregroundStyle(session.targetMood.interfaceAccentColor)

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.pathway.title)
                        .font(.subheadline.weight(.semibold))
                    Text("\(session.durationString) • \(session.endedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let helpfulness = session.helpfulness {
                    Text(helpfulness.label)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppSurface.fill, in: Capsule())
                }
            }
        }
    }
}

private struct CalmLaunchDestination: Identifiable, Hashable {
    let pathway: CalmPathway
    let mode: BreathingMode
    let autoStart: Bool

    var id: String {
        "\(pathway.rawValue)-\(mode.rawValue)-\(autoStart)"
    }
}

enum BreathingMode: String {
    case box = "Box breathing"
    case fourSevenEight = "4-7-8 breathing"
    case reset = "Reset breath"
    case extendedExhale = "Extended exhale"
    case coherent = "Coherent breathing"
    case physiologicalSigh = "Physiological sigh"

    var phases: [(label: String, seconds: Int, scale: CGFloat)] {
        switch self {
        case .box:
            [("Inhale", 4, 1.14), ("Hold", 4, 1.14), ("Exhale", 4, 0.9), ("Hold", 4, 0.9)]
        case .fourSevenEight:
            [("Inhale", 4, 1.12), ("Hold", 7, 1.12), ("Exhale", 8, 0.88)]
        case .reset:
            [("Inhale", 3, 1.1), ("Exhale", 5, 0.9)]
        case .extendedExhale:
            [("Inhale", 4, 1.1), ("Exhale", 7, 0.88)]
        case .coherent:
            [("Inhale", 5, 1.1), ("Exhale", 5, 0.9)]
        case .physiologicalSigh:
            [("Inhale", 2, 1.05), ("Top up", 1, 1.12), ("Exhale", 6, 0.86)]
        }
    }

    var helperText: String {
        switch self {
        case .box:
            "Equal counts in and out help when your body feels overstimulated."
        case .fourSevenEight:
            "A longer exhale helps slow the body down for sleep."
        case .reset:
            "A short reset helps interrupt stress quickly."
        case .extendedExhale:
            "Use this when your mind still feels stuck on work or worry."
        case .coherent:
            "This steady rhythm helps you settle and focus on your body."
        case .physiologicalSigh:
            "This helps when panic rises fast and your breathing feels tight."
        }
    }
}

private enum CalmBreathPhase {
    case inhale
    case hold
    case exhale

    init(label: String) {
        switch label {
        case "Inhale", "Top up":
            self = .inhale
        case "Exhale":
            self = .exhale
        default:
            self = .hold
        }
    }

    var circlePhase: AICircleBreathPhase {
        switch self {
        case .inhale: .inhale
        case .hold: .hold
        case .exhale: .exhale
        }
    }

    var stageScale: CGFloat {
        switch self {
        case .inhale: 1.06
        case .hold: 1.07
        case .exhale: 0.91
        }
    }

    var timerTintOpacity: Double {
        switch self {
        case .inhale: 0.92
        case .hold: 0.84
        case .exhale: 1
        }
    }
}

struct CalmSessionView: View {
    @EnvironmentObject private var appModel: AppViewModel
    let pathway: CalmPathway
    let mode: BreathingMode
    var autoStart: Bool = false

    @State private var isRunning = false
    @State private var phaseIndex = 0
    @State private var sessionStartedAt: Date?
    @State private var sessionLogID: UUID?
    @State private var elapsed: TimeInterval = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var loopTask: Task<Void, Never>?
    @State private var companionTrigger = 0
    @State private var phaseStartedAt: Date?
    @State private var settledTint: Color?

    private var currentPhase: (label: String, seconds: Int, scale: CGFloat) {
        mode.phases[phaseIndex]
    }

    private var startingMood: MoodLevel {
        appModel.selectedMood
    }

    private var targetMood: MoodLevel {
        startingMood.calmerCompanionMood
    }

    private var targetDuration: TimeInterval { pathway.targetDuration }

    private var sessionProgress: Double {
        min(1, max(0, elapsed / targetDuration))
    }

    private var phaseDisplayTitle: String {
        pathway.displayTitle(for: currentPhase.label)
    }

    private var breathPhase: CalmBreathPhase {
        CalmBreathPhase(label: currentPhase.label)
    }

    private var currentPhaseDuration: Double {
        Double(currentPhase.seconds)
    }

    private var companionTint: Color {
        if let settledTint {
            return settledTint
        }
        return blendColor(from: startingMood.companionColor, to: targetMood.companionColor, progress: sessionProgress)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 24)

                    VStack(spacing: 30) {
                        VStack(spacing: 10) {
                            Text(pathway.title)
                                .font(.largeTitle.weight(.bold))
                                .multilineTextAlignment(.center)
                            Text(mode.helperText)
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.primary.opacity(0.78))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(spacing: 22) {
                            TimelineView(.animation) { timeline in
                                CalmCompanionStage(
                                    pathway: pathway,
                                    centerLabel: phaseDisplayTitle,
                                    tint: companionTint,
                                    isRunning: isRunning,
                                    size: 228,
                                    trigger: companionTrigger,
                                    breathPhase: isRunning ? breathPhase.circlePhase : .neutral,
                                    breathProgress: phaseProgress(at: timeline.date)
                                )
                                .frame(maxWidth: .infinity)
                            }

                            VStack(spacing: 8) {
                                Text(elapsedLabel)
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(companionTint.opacity(breathPhase.timerTintOpacity))

                                Text(pathway.durationLabel)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.primary.opacity(0.72))
                            }

                            Text(pathway.cue(for: currentPhase.label))
                                .font(.title2.weight(.medium))
                                .foregroundStyle(.primary.opacity(0.82))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(maxWidth: 360, minHeight: 72, alignment: .top)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 32)

                    if let sessionLogID {
                        ReferenceCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Did that help?")
                                    .font(.headline)
                                HStack(spacing: 10) {
                                    feedbackButton(.notReally, for: sessionLogID)
                                    feedbackButton(.aBit, for: sessionLogID)
                                    feedbackButton(.yes, for: sessionLogID)
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }

                    Button(isRunning ? "End reset" : "Start reset") {
                        isRunning ? stop() : start()
                    }
                    .frame(height: 56)
                    .buttonStyle(PrimaryCapsuleButtonStyle())
                    .padding(.bottom, 28)
                }
                .padding(AppSpacing.page)
                .frame(minHeight: geometry.size.height, alignment: .center)
            }
        }
        .navigationTitle("Calm")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            if autoStart && isRunning == false && sessionLogID == nil {
                start()
            }
        }
        .onDisappear {
            stop(record: false)
        }
    }

    private var elapsedLabel: String {
        let wholeSeconds = Int(elapsed.rounded())
        let minutes = wholeSeconds / 60
        let seconds = wholeSeconds % 60
        return String(format: "%d:%02d of %.0f min", minutes, seconds, max(1, targetDuration / 60))
    }

    private func start() {
        sessionLogID = nil
        elapsed = 0
        phaseIndex = 0
        isRunning = true
        sessionStartedAt = Date()
        phaseStartedAt = Date()
        settledTint = nil
        companionTrigger += 1

        timerTask?.cancel()
        timerTask = Task {
            while Task.isCancelled == false {
                try? await Task.sleep(for: .seconds(1))
                guard Task.isCancelled == false else { break }
                await MainActor.run {
                    elapsed += 1
                }
            }
        }

        loopTask?.cancel()
        loopTask = Task {
            while Task.isCancelled == false {
                let phase = await MainActor.run { currentPhase }
                try? await Task.sleep(for: .seconds(phase.seconds))
                guard Task.isCancelled == false else { break }
                await MainActor.run {
                    phaseIndex = (phaseIndex + 1) % mode.phases.count
                    phaseStartedAt = Date()
                    companionTrigger += 1
                }
            }
        }
    }

    private func stop(record: Bool = true) {
        timerTask?.cancel()
        loopTask?.cancel()
        timerTask = nil
        loopTask = nil
        guard record, let started = sessionStartedAt else {
            isRunning = false
            sessionStartedAt = nil
            phaseStartedAt = nil
            phaseIndex = 0
            elapsed = 0
            return
        }

        let duration = max(0, Date().timeIntervalSince(started))
        settledTint = targetMood.companionColor
        if let session = appModel.completeCalmSession(
            pathway: pathway,
            mode: mode,
            duration: duration,
            startingMood: startingMood,
            targetMood: targetMood
        ) {
            sessionLogID = session.id
        }

        isRunning = false
        sessionStartedAt = nil
        phaseStartedAt = nil
        phaseIndex = 0
        elapsed = 0
    }

    private func feedbackButton(_ helpfulness: CalmHelpfulness, for sessionID: UUID) -> some View {
        Button(helpfulness.label) {
            appModel.setCalmSessionHelpfulness(sessionID, helpfulness: helpfulness)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppSurface.stroke, lineWidth: 0.5)
        }
        .buttonStyle(.plain)
    }

    private func blendColor(from: Color, to: Color, progress: Double) -> Color {
        let p = min(1, max(0, progress))
        let fromRGBA = UIColor(from).rgba
        let toRGBA = UIColor(to).rgba
        return Color(
            red: fromRGBA.r + ((toRGBA.r - fromRGBA.r) * p),
            green: fromRGBA.g + ((toRGBA.g - fromRGBA.g) * p),
            blue: fromRGBA.b + ((toRGBA.b - fromRGBA.b) * p)
        )
    }

    private func phaseProgress(at date: Date) -> CGFloat {
        guard isRunning, let phaseStartedAt, currentPhaseDuration > 0 else { return 0 }
        let elapsed = date.timeIntervalSince(phaseStartedAt)
        return CGFloat(min(max(elapsed / currentPhaseDuration, 0), 1))
    }
}

private struct CalmCompanionStage: View {
    let pathway: CalmPathway
    let centerLabel: String?
    let tint: Color
    let isRunning: Bool
    let size: CGFloat
    var trigger: Int = 0
    var breathPhase: AICircleBreathPhase = .neutral
    var breathProgress: CGFloat = 0

    init(
        pathway: CalmPathway,
        centerLabel: String? = nil,
        tint: Color,
        isRunning: Bool,
        size: CGFloat,
        trigger: Int = 0,
        breathPhase: AICircleBreathPhase = .neutral,
        breathProgress: CGFloat = 0
    ) {
        self.pathway = pathway
        self.centerLabel = centerLabel
        self.tint = tint
        self.isRunning = isRunning
        self.size = size
        self.trigger = trigger
        self.breathPhase = breathPhase
        self.breathProgress = breathProgress
    }

    var body: some View {
        let descriptor = pathway.animationDescriptor(isRunning: isRunning)

        ZStack {
            pathwayBackdrop

            AICircleView(
                state: descriptor.state,
                size: size,
                strokeWidth: 3,
                motionStyle: .continuous,
                tint: tint,
                lensFocusActive: descriptor.lensFocusActive,
                personality: .calm,
                trigger: trigger,
                centerLabel: centerLabel,
                ringRotationDegrees: descriptor.rotationDegrees,
                breathPhase: breathPhase,
                breathProgress: breathProgress
            )

            pathwayForeground
        }
        .frame(width: size + 28, height: size + 28)
        .scaleEffect(stageScale)
    }

    private var stageScale: CGFloat {
        guard isRunning else { return 1 }
        switch breathPhase {
        case .neutral:
            return 1
        case .inhale:
            return 1 + (0.04 * breathProgress)
        case .hold:
            return 1.04
        case .exhale:
            return 1.04 - (0.11 * breathProgress)
        }
    }

    @ViewBuilder
    private var pathwayBackdrop: some View {
        switch pathway {
        case .slowDown:
            VStack(spacing: size * 0.08) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(tint.opacity(0.18 - (Double(index) * 0.03)))
                        .frame(width: size * (0.48 + (CGFloat(index) * 0.08)), height: max(3, size * 0.022))
                }
            }
            .blur(radius: 0.5)

        case .clearHead:
            ZStack {
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .stroke(tint.opacity(0.12 - (Double(index) * 0.03)), lineWidth: max(1, size * 0.014))
                        .frame(width: size * (1.08 + (CGFloat(index) * 0.14)), height: size * (1.08 + (CGFloat(index) * 0.14)))
                }
            }

        case .sleepOffRamp:
            ZStack {
                Circle()
                    .fill(tint.opacity(0.08))
                    .frame(width: size * 1.04, height: size * 1.04)
                    .blur(radius: size * 0.08)

                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(tint.opacity(0.16 - (Double(index) * 0.02)))
                        .frame(width: max(4, size * 0.045), height: max(4, size * 0.045))
                        .offset(
                            x: CGFloat(index - 1) * size * 0.09,
                            y: -size * 0.18 - (CGFloat(index) * size * 0.06)
                        )
                }
            }

        case .workClosure:
            ZStack {
                Circle()
                    .trim(from: 0.12, to: 0.42)
                    .stroke(tint.opacity(0.18), style: StrokeStyle(lineWidth: max(1.4, size * 0.018), lineCap: .round))
                    .rotationEffect(.degrees(-20))
                    .scaleEffect(1.12)
                Circle()
                    .trim(from: 0.58, to: 0.88)
                    .stroke(tint.opacity(0.18), style: StrokeStyle(lineWidth: max(1.4, size * 0.018), lineCap: .round))
                    .rotationEffect(.degrees(16))
                    .scaleEffect(1.12)
            }

        case .bodyGrounding:
            VStack(spacing: size * 0.04) {
                Circle()
                    .fill(tint.opacity(0.2))
                    .frame(width: max(6, size * 0.06), height: max(6, size * 0.06))
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.16))
                    .frame(width: max(3, size * 0.018), height: size * 0.34)
            }
            .offset(y: size * 0.18)

        case .panicSettle:
            VStack(spacing: size * 0.035) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(tint.opacity(0.2 - (Double(index) * 0.04)))
                        .frame(width: size * (0.2 - (CGFloat(index) * 0.02)), height: max(5, size * 0.048))
                }
            }
            .offset(y: size * 0.22)
        }
    }

    @ViewBuilder
    private var pathwayForeground: some View {
        switch pathway {
        case .slowDown:
            EmptyView()

        case .clearHead:
            Capsule(style: .continuous)
                .fill(tint.opacity(0.22))
                .frame(width: max(2, size * 0.015), height: size * 0.74)
                .blur(radius: 0.5)

        case .sleepOffRamp:
            RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                .fill(.black.opacity(0.12))
                .frame(width: size * 0.52, height: size * 0.18)
                .blur(radius: size * 0.03)
                .offset(y: size * 0.36)

        case .workClosure:
            HStack(spacing: size * 0.3) {
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.24))
                    .frame(width: max(3, size * 0.02), height: size * 0.28)
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.24))
                    .frame(width: max(3, size * 0.02), height: size * 0.28)
            }
            .offset(y: size * 0.01)

        case .bodyGrounding:
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(tint.opacity(0.24 - (Double(index) * 0.05)))
                    .frame(width: max(5, size * 0.048), height: max(5, size * 0.048))
                    .offset(
                        x: 0,
                        y: size * (0.1 + (CGFloat(index) * 0.12))
                    )
            }

        case .panicSettle:
            VStack(spacing: size * 0.04) {
                ForEach(0..<2, id: \.self) { index in
                    Image(systemName: "chevron.down")
                        .font(.system(size: size * 0.09, weight: .bold))
                        .foregroundStyle(tint.opacity(0.28 - (Double(index) * 0.06)))
                }
            }
            .offset(y: size * 0.34)
        }
    }
}

private struct CalmAnimationDescriptor {
    let state: AICircleState
    let rotationDegrees: Double
    let lensFocusActive: Bool
}

private extension CalmPathway {
    func displayTitle(for phaseLabel: String) -> String {
        switch (self, phaseLabel) {
        case (.panicSettle, "Top up"):
            return "Second inhale"
        default:
            return phaseLabel
        }
    }

    var selectionLine: String {
        switch self {
        case .slowDown: "Slow your breathing."
        case .clearHead: "Quiet racing thoughts."
        case .sleepOffRamp: "Settle for sleep."
        case .workClosure: "Let work end here."
        case .bodyGrounding: "Come back to your body."
        case .panicSettle: "Calm a panic spike."
        }
    }

    var companionHeroLine: String {
        switch self {
        case .slowDown: "Use a steady rhythm to bring your stress level down."
        case .clearHead: "Keep your attention narrow so your thoughts can slow down."
        case .sleepOffRamp: "Use a slower exhale to help your body shift toward rest."
        case .workClosure: "This helps you stop carrying work into the rest of the night."
        case .bodyGrounding: "Bring attention out of your head and back into physical sensation."
        case .panicSettle: "Focus on getting your body down first, then let the mind catch up."
        }
    }

    var sessionIntroLine: String {
        switch self {
        case .slowDown: "Follow the count and let your breathing become more even."
        case .clearHead: "Use each breath to make your mind a little less busy."
        case .sleepOffRamp: "Let your exhale get longer so your body can prepare for sleep."
        case .workClosure: "Use the breath to mark that work is done for now."
        case .bodyGrounding: "Keep coming back to what you can physically feel."
        case .panicSettle: "Take two short inhales, then one long exhale to bring the panic down."
        }
    }

    var heroCompanionState: AICircleState {
        switch self {
        case .slowDown: .checkIn
        case .clearHead: .thinking
        case .sleepOffRamp: .settled
        case .workClosure: .attentive
        case .bodyGrounding: .listening
        case .panicSettle: .responding
        }
    }

    func animationDescriptor(isRunning: Bool) -> CalmAnimationDescriptor {
        let state: AICircleState
        switch self {
        case .slowDown:
            state = isRunning ? .checkIn : .attentive
        case .clearHead:
            state = isRunning ? .thinking : .attentive
        case .sleepOffRamp:
            state = .settled
        case .workClosure:
            state = isRunning ? .attentive : .checkIn
        case .bodyGrounding:
            state = isRunning ? .listening : .attentive
        case .panicSettle:
            state = isRunning ? .responding : .checkIn
        }

        let rotation: Double
        switch self {
        case .slowDown: rotation = 0
        case .clearHead: rotation = 8
        case .sleepOffRamp: rotation = -6
        case .workClosure: rotation = 18
        case .bodyGrounding: rotation = 0
        case .panicSettle: rotation = -12
        }

        return CalmAnimationDescriptor(
            state: state,
            rotationDegrees: rotation,
            lensFocusActive: self == .clearHead && isRunning
        )
    }

    func cue(for phaseLabel: String) -> String {
        switch self {
        case .slowDown:
            switch phaseLabel {
            case "Inhale": "Breathe in slowly."
            case "Exhale": "Breathe out and release tension."
            default: "Stay still and keep the count."
            }
        case .clearHead:
            switch phaseLabel {
            case "Inhale": "Breathe in and notice one thing."
            case "Exhale": "Breathe out and let the rest go quiet."
            default: "Hold softly and stay focused."
            }
        case .sleepOffRamp:
            switch phaseLabel {
            case "Inhale": "Take a light, easy inhale."
            case "Exhale": "Exhale longer than the inhale."
            default: "Pause and stay soft."
            }
        case .workClosure:
            switch phaseLabel {
            case "Inhale": "Notice what still feels unfinished."
            case "Exhale": "Let it wait until tomorrow."
            default: "Pause and leave it alone for now."
            }
        case .bodyGrounding:
            switch phaseLabel {
            case "Inhale": "Notice your feet, hands, or seat."
            case "Exhale": "Stay with the body, not the thought."
            default: "Pause and keep noticing sensation."
            }
        case .panicSettle:
            switch phaseLabel {
            case "Inhale": "Take a short inhale."
            case "Top up": "Take one small second inhale."
            case "Exhale": "Let out one long exhale."
            default: "Pause and let your body settle."
            }
        }
    }
}

private extension CalmSessionLog {
    var durationString: String {
        let seconds = Int(duration.rounded())
        if seconds >= 60 {
            let minutes = seconds / 60
            let remainder = seconds % 60
            if remainder == 0 {
                return "\(minutes) min"
            }
            return "\(minutes)m \(remainder)s"
        }
        return "\(seconds)s"
    }
}

#Preview {
    CalmView()
        .environmentObject(AppViewModel(seedWithMockData: true))
        .environmentObject(AppRouter.shared)
}

private extension UIColor {
    var rgba: (r: Double, g: Double, b: Double, a: Double) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue), Double(alpha))
    }
}
