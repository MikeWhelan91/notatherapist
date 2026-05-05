import SwiftUI

enum AICircleMotionStyle {
    case continuous
    case intro
}

enum CompanionPersonality {
    case grounded
    case energetic
    case calm
    case analytic
}

struct AICircleView: View {
    let state: AICircleState
    var size: CGFloat = 64
    var strokeWidth: CGFloat = 2.5
    var motionStyle: AICircleMotionStyle = .continuous
    var tint: Color = AppTheme.accentSoft
    var lensFocusActive: Bool = false
    var personality: CompanionPersonality = .grounded
    var trigger: Int = 0
    var centerLabel: String? = nil
    var ringRotationDegrees: Double = 0

    @State private var animationStart = Date()
    @State private var responseKick = false
    @State private var lensRotation: Double = 0
    @State private var lensScale: CGFloat = 1
    @State private var burstPulse = false
    @State private var burstTask: Task<Void, Never>?
    @State private var responseKickTask: Task<Void, Never>?
    @State private var lensTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let profile = AICircleProfile(state: state)
        let personality = CompanionPersonalityProfile(kind: personality)
        let brushWidth = max(strokeWidth * 2.2, size * 0.093)
        let hairlineWidth = max(strokeWidth * 0.5, size * 0.018)
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let elapsed = timeline.date.timeIntervalSince(animationStart)
            let basePulse = (sin((time / (profile.breatheDuration * personality.breatheSpeed)) * .pi * 2) + 1) / 2
            let pulse = min(1, basePulse * personality.pulseMultiplier * 0.58)
            let introProgress = min(max(elapsed / 18, 0), 1)
            let easedIntroProgress = introProgress * introProgress * (3 - 2 * introProgress)
            let drift = motionStyle == .intro ? easedIntroProgress * 88 : (elapsed / profile.motionDuration) * profile.motionOffset
            let lineMotion = motionStyle == .intro ? easedIntroProgress * 420 : (elapsed / profile.lineDuration) * profile.lineTravel
            let orbitActivity = reduceMotion ? 0 : profile.orbitActivity(at: time)
            let maxScale = motionStyle == .intro ? CGFloat(1.006) : profile.maxScale + personality.extraScale
            let ringRotation = ringRotationDegrees + (reduceMotion ? 0 : sin(time * personality.swaySpeed) * personality.swayAmount)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                tint.opacity(profile.mistCoreOpacity),
                                tint.opacity(profile.mistMidOpacity),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.52
                        )
                    )
                    .blur(radius: profile.mistBlur)
                    .scaleEffect(profile.mistScale + (CGFloat(pulse) * 0.016))

                Circle()
                    .stroke(tint.opacity(profile.glowOpacity), style: StrokeStyle(lineWidth: brushWidth * 1.15, lineCap: .round, lineJoin: .round))
                    .blur(radius: profile.glowRadius)
                    .scaleEffect(1.015)

                Circle()
                    .stroke(tint.opacity(profile.innerGlowOpacity), style: StrokeStyle(lineWidth: brushWidth * 1.55, lineCap: .round, lineJoin: .round))
                    .blur(radius: profile.innerGlowRadius)
                    .scaleEffect(0.84)

                Circle()
                    .fill(tint.opacity(profile.coreGlowOpacity))
                    .blur(radius: profile.innerGlowRadius * 1.4)
                    .scaleEffect(0.58)

                Circle()
                    .trim(from: 0.025, to: 0.965)
                    .stroke(tint.opacity(profile.baseOpacity), style: StrokeStyle(lineWidth: brushWidth, lineCap: .round, lineJoin: .round))
                    .rotationEffect(.degrees(12 + (drift * 0.09)))
                    .scaleEffect(0.99)

                Circle()
                    .trim(from: profile.primaryTrim.lowerBound, to: profile.primaryTrim.upperBound)
                    .stroke(tint.opacity(profile.primaryOpacity), style: StrokeStyle(lineWidth: brushWidth * 0.82, lineCap: .round, lineJoin: .round))
                    .rotationEffect(.degrees(-14 - (drift * 0.12)))
                    .scaleEffect(profile.primaryScale)

                Circle()
                    .trim(from: profile.secondaryTrim.lowerBound, to: profile.secondaryTrim.upperBound)
                    .stroke(tint.opacity(profile.secondaryOpacity), style: StrokeStyle(lineWidth: brushWidth * 0.62, lineCap: .round, lineJoin: .round))
                    .rotationEffect(.degrees(140 + (drift * 0.1)))
                    .scaleEffect(1.015)

                Circle()
                    .trim(from: profile.highlightTrim.lowerBound, to: profile.highlightTrim.upperBound)
                    .stroke(tint.opacity(profile.highlightOpacity), style: StrokeStyle(lineWidth: brushWidth * 0.44, lineCap: .round, lineJoin: .round))
                    .rotationEffect(.degrees(44 - (drift * 0.11)))
                    .scaleEffect(0.975)

                Circle()
                    .trim(from: 0.01, to: 0.97)
                    .stroke(tint.opacity(profile.scratchOpacity), style: StrokeStyle(lineWidth: hairlineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-12 + (lineMotion * 0.08)))
                    .scaleEffect(1.105)

                Circle()
                    .trim(from: 0.045, to: 0.94)
                    .stroke(tint.opacity(profile.scratchOpacity * 0.8), style: StrokeStyle(lineWidth: hairlineWidth * 0.82, lineCap: .round))
                    .rotationEffect(.degrees(8 + (lineMotion * 0.07)))
                    .scaleEffect(0.86)

                Circle()
                    .trim(from: 0.14, to: 0.31)
                    .stroke(tint.opacity(profile.dryBrushOpacity), style: StrokeStyle(lineWidth: hairlineWidth * 0.9, lineCap: .round))
                    .rotationEffect(.degrees(-42 + (lineMotion * 0.14)))
                    .scaleEffect(1.18)

                Circle()
                    .trim(from: 0.56, to: 0.72)
                    .stroke(tint.opacity(profile.dryBrushOpacity * 0.86), style: StrokeStyle(lineWidth: hairlineWidth * 0.78, lineCap: .round))
                    .rotationEffect(.degrees(104 + (lineMotion * 0.11)))
                    .scaleEffect(1.06)

                Circle()
                    .trim(from: 0.79, to: 0.93)
                    .stroke(tint.opacity(profile.dryBrushOpacity * 1.15), style: StrokeStyle(lineWidth: hairlineWidth * 1.05, lineCap: .round))
                    .rotationEffect(.degrees(23 + (lineMotion * 0.09)))
                    .scaleEffect(1.16)

                Circle()
                    .trim(from: 0.04, to: 0.18)
                    .stroke(tint.opacity(profile.innerLineOpacity), style: StrokeStyle(lineWidth: hairlineWidth * 1.1, lineCap: .round))
                    .rotationEffect(.degrees(-28 + (lineMotion * 0.15)))
                    .scaleEffect(0.66)

                Circle()
                    .trim(from: 0.34, to: 0.52)
                    .stroke(tint.opacity(profile.innerLineOpacity * 0.82), style: StrokeStyle(lineWidth: hairlineWidth * 0.9, lineCap: .round))
                    .rotationEffect(.degrees(78 + (lineMotion * 0.12)))
                    .scaleEffect(0.74)

                Circle()
                    .trim(from: 0.64, to: 0.82)
                    .stroke(tint.opacity(profile.innerLineOpacity * 0.72), style: StrokeStyle(lineWidth: hairlineWidth * 0.72, lineCap: .round))
                    .rotationEffect(.degrees(154 + (lineMotion * 0.1)))
                    .scaleEffect(0.56)

                if state == .typing || state == .checkIn || state == .listening {
                    Circle()
                        .trim(from: 0.82, to: 0.96)
                        .stroke(tint.opacity(0.24), style: StrokeStyle(lineWidth: brushWidth * 0.28, lineCap: .round))
                        .rotationEffect(.degrees(28 + (drift * 0.16)))
                        .scaleEffect(1.08)
                }

                if state == .responding || state == .checkIn || state == .typing || state == .thinking || state == .listening {
                    ForEach(0..<personality.orbitDots, id: \.self) { index in
                        let phase = (Double(index) / 6.0) * .pi * 2
                        let orbit = size * (state == .responding || state == .thinking ? 0.62 : 0.56) * personality.orbitRadius
                        let x = cos((time * personality.orbitSpeed) + phase) * orbit
                        let y = sin((time * personality.orbitSpeed) + phase) * orbit
                        Circle()
                            .fill(tint.opacity((state == .responding || state == .thinking ? personality.respondingOpacity : personality.idleOrbitOpacity) * orbitActivity))
                            .frame(width: max(2, size * personality.dotSize), height: max(2, size * personality.dotSize))
                            .offset(x: x, y: y)
                            .blur(radius: state == .responding || state == .thinking ? 0.75 : 0.25)
                    }
                }

                if burstPulse {
                    Circle()
                        .stroke(tint.opacity(0.5), style: StrokeStyle(lineWidth: hairlineWidth * 2))
                        .scaleEffect(1.14 + CGFloat(pulse) * 0.12)
                        .blur(radius: 0.6)
                    Circle()
                        .stroke(tint.opacity(0.24), style: StrokeStyle(lineWidth: hairlineWidth * 1.4))
                        .scaleEffect(1.26 + CGFloat(pulse) * 0.1)
                }

                if lensFocusActive {
                    Circle()
                        .stroke(tint.opacity(0.4), style: StrokeStyle(lineWidth: hairlineWidth * 1.3))
                        .scaleEffect(0.84 * lensScale)
                        .blur(radius: 1.1)

                    Circle()
                        .trim(from: 0.11, to: 0.39)
                        .stroke(tint.opacity(0.6), style: StrokeStyle(lineWidth: brushWidth * 0.18, lineCap: .round))
                        .rotationEffect(.degrees(-32 + lensRotation))
                        .scaleEffect(0.82 * lensScale)

                    Circle()
                        .trim(from: 0.58, to: 0.86)
                        .stroke(tint.opacity(0.52), style: StrokeStyle(lineWidth: brushWidth * 0.15, lineCap: .round))
                        .rotationEffect(.degrees(138 - lensRotation))
                        .scaleEffect(0.86 * lensScale)
                }

                CompanionGlyphView(
                    state: state,
                    tint: tint,
                    size: size,
                    pulse: CGFloat(pulse),
                    time: time,
                    drift: drift,
                    personality: personality.kind,
                    lensFocusActive: lensFocusActive,
                    responseKick: responseKick,
                    reduceMotion: reduceMotion
                )
                .rotationEffect(.degrees(-ringRotation))

                if let label = resolvedCenterLabel {
                    Text(label)
                        .font(.system(size: max(12, size * 0.16), weight: .semibold, design: .rounded))
                        .foregroundStyle(tint.opacity(0.92))
                        .tracking(0.3)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .padding(.horizontal, size * 0.12)
                        .padding(.vertical, size * 0.055)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.22))
                        )
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(tint.opacity(0.22), lineWidth: 0.6)
                        }
                        .scaleEffect(1 + (CGFloat(pulse) * 0.02))
                        .rotationEffect(.degrees(-ringRotation))
                }
            }
            .frame(width: size, height: size)
            .rotationEffect(.degrees(ringRotation))
            .scaleEffect((responseKick ? 1.024 : 1.0) * (1 + (maxScale - 1) * CGFloat(pulse)))
            .opacity(profile.totalOpacity)
        }
        .animation(.easeOut(duration: 0.26), value: responseKick)
        .task {
            animationStart = Date()
            configureAnimation()
        }
        .onChange(of: state) { _, _ in
            configureAnimation()
        }
        .onChange(of: trigger) { _, _ in
            burstTask?.cancel()
            withAnimation(reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.22)) {
                burstPulse = true
            }
            burstTask = Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard Task.isCancelled == false else { return }
                await MainActor.run {
                    withAnimation(reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.22)) {
                        burstPulse = false
                    }
                }
            }
        }
        .onChange(of: lensFocusActive) { _, active in
            if active {
                runLensFocusSequence()
            } else {
                lensTask?.cancel()
                withAnimation(reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.25)) {
                    lensRotation = 0
                    lensScale = 1
                }
            }
        }
        .onDisappear {
            burstTask?.cancel()
            responseKickTask?.cancel()
            lensTask?.cancel()
        }
        .animation(.easeInOut(duration: 0.52), value: state)
        .accessibilityHidden(true)
    }

    private var resolvedCenterLabel: String? {
        if let centerLabel {
            let trimmed = centerLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : String(trimmed.prefix(10))
        }
        return nil
    }

    private func configureAnimation() {
        responseKickTask?.cancel()

        withAnimation(reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.18)) {
            responseKick = false
        }

        if state == .responding {
            withAnimation(reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.24)) {
                responseKick = true
            }
            responseKickTask = Task {
                try? await Task.sleep(nanoseconds: 280_000_000)
                guard Task.isCancelled == false else { return }
                await MainActor.run {
                    responseKick = false
                }
            }
        }
    }

    private func runLensFocusSequence() {
        lensTask?.cancel()

        if reduceMotion {
            withAnimation(.linear(duration: 0.01)) {
                lensRotation = 0
                lensScale = 1
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.62)) {
            lensRotation = 26
        }

        lensTask = Task {
            try? await Task.sleep(nanoseconds: 620_000_000)
            guard Task.isCancelled == false else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.48)) {
                    lensRotation = -10
                }
            }

            try? await Task.sleep(nanoseconds: 480_000_000)
            guard Task.isCancelled == false else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.34)) {
                    lensScale = 1.06
                }
            }

            try? await Task.sleep(nanoseconds: 340_000_000)
            guard Task.isCancelled == false else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.34)) {
                    lensScale = 0.97
                }
            }

            try? await Task.sleep(nanoseconds: 340_000_000)
            guard Task.isCancelled == false else { return }
            await MainActor.run {
                withAnimation(.interactiveSpring(response: 0.46, dampingFraction: 0.86, blendDuration: 0.14)) {
                    lensRotation = 0
                    lensScale = 1
                }
            }
        }
    }
}

struct CompanionTabHeader: View {
    let title: String
    let state: AICircleState
    let tint: Color

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.title2.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, AppSpacing.page)
            .padding(.top, 8)

            HStack {
                Spacer()
                AICircleView(state: state, size: 122, strokeWidth: 3.1, tint: tint)
                    .opacity(0)
                Spacer()
            }
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
    }
}

private struct CompanionPersonalityProfile {
    let kind: CompanionPersonality

    var breatheSpeed: Double {
        switch kind {
        case .grounded: 1.0
        case .energetic: 0.8
        case .calm: 1.24
        case .analytic: 0.94
        }
    }

    var orbitSpeed: Double {
        switch kind {
        case .grounded: 1.35
        case .energetic: 1.9
        case .calm: 1.05
        case .analytic: 1.6
        }
    }

    var orbitDots: Int {
        switch kind {
        case .grounded: 6
        case .energetic: 8
        case .calm: 5
        case .analytic: 7
        }
    }

    var orbitRadius: CGFloat {
        switch kind {
        case .grounded: 1
        case .energetic: 1.07
        case .calm: 0.93
        case .analytic: 1.02
        }
    }

    var swaySpeed: Double {
        switch kind {
        case .grounded: 0.34
        case .energetic: 0.9
        case .calm: 0.24
        case .analytic: 0.52
        }
    }

    var swayAmount: Double {
        switch kind {
        case .grounded: 0.55
        case .energetic: 2.0
        case .calm: 0.36
        case .analytic: 0.72
        }
    }

    var pulseMultiplier: Double {
        switch kind {
        case .grounded: 0.86
        case .energetic: 1.05
        case .calm: 0.72
        case .analytic: 0.92
        }
    }

    var dotSize: CGFloat {
        switch kind {
        case .grounded: 0.045
        case .energetic: 0.05
        case .calm: 0.04
        case .analytic: 0.043
        }
    }

    var extraScale: CGFloat {
        switch kind {
        case .grounded: 0
        case .energetic: 0.004
        case .calm: -0.005
        case .analytic: 0.002
        }
    }

    var respondingOpacity: Double {
        switch kind {
        case .grounded: 0.55
        case .energetic: 0.72
        case .calm: 0.46
        case .analytic: 0.6
        }
    }

    var idleOrbitOpacity: Double {
        switch kind {
        case .grounded: 0.35
        case .energetic: 0.46
        case .calm: 0.28
        case .analytic: 0.4
        }
    }
}

private struct CompanionGlyphView: View {
    let state: AICircleState
    let tint: Color
    let size: CGFloat
    let pulse: CGFloat
    let time: TimeInterval
    let drift: Double
    let personality: CompanionPersonality
    let lensFocusActive: Bool
    let responseKick: Bool
    let reduceMotion: Bool

    private var faceSize: CGFloat { size * 0.48 }
    private var showsSignalMarks: Bool { size >= 56 }

    var body: some View {
        ZStack {
            innerPresence
            eyes
            stateMarks
        }
        .frame(width: faceSize, height: faceSize)
        .offset(y: stateProfile.verticalOffset * size)
        .scaleEffect(stateProfile.scale + (pulse * stateProfile.pulseAmount) + (responseKick ? 0.045 : 0))
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: state)
        .animation(.spring(response: 0.32, dampingFraction: 0.74), value: responseKick)
    }

    private var innerPresence: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(stateProfile.innerMistOpacity))
                .frame(width: faceSize * 1.12, height: faceSize * 1.12)
                .blur(radius: max(3, size * 0.035))

            Circle()
                .stroke(tint.opacity(stateProfile.innerRingOpacity), style: StrokeStyle(lineWidth: max(0.7, size * 0.01), lineCap: .round))
                .frame(width: faceSize * 1.06, height: faceSize * 1.06)
                .scaleEffect(0.98 + pulse * 0.035)
        }
    }

    private var eyes: some View {
        HStack(spacing: faceSize * stateProfile.eyeSpacing) {
            RingCompanionEye(
                size: faceSize * stateProfile.eyeSize,
                tint: tint,
                shape: stateProfile.eyeShape,
                offset: stateProfile.leftEyeOffset,
                tilt: stateProfile.leftEyeTilt,
                pulse: pulse,
                time: time,
                blinkScale: synchronizedBlinkScale,
                glancePhase: 0
            )
            RingCompanionEye(
                size: faceSize * stateProfile.eyeSize,
                tint: tint,
                shape: stateProfile.eyeShape,
                offset: stateProfile.rightEyeOffset,
                tilt: stateProfile.rightEyeTilt,
                pulse: pulse,
                time: time,
                blinkScale: synchronizedBlinkScale,
                glancePhase: 0.47
            )
        }
        .offset(y: faceSize * stateProfile.eyeY)
    }

    private var synchronizedBlinkScale: CGFloat {
        guard reduceMotion == false else { return 1 }
        let period = 5.8
        let position = time.truncatingRemainder(dividingBy: period)
        let blinkCenter = 0.22
        let distance = abs(position - blinkCenter)
        let squint = 0.92 + (sin(time * 0.9) * 0.08)
        guard distance < 0.12 else { return squint }
        let blink = 1 - CGFloat(distance / 0.12)
        return max(0.16, squint * (1 - blink * 0.84))
    }

    private var stateMarks: some View {
        ZStack {
            if showsSignalMarks && (state == .responding || state == .checkIn || state == .thinking) {
                ForEach(0..<stateProfile.signalCount, id: \.self) { index in
                    let angle = stateProfile.signalStartAngle + (Double(index) * 58)
                    let radius = faceSize * 0.48
                    Circle()
                        .fill(tint.opacity(0.34 - Double(index) * 0.045))
                        .frame(width: max(2, faceSize * 0.055), height: max(2, faceSize * 0.055))
                        .offset(
                            x: cos(angle * .pi / 180) * radius,
                            y: sin(angle * .pi / 180) * radius
                        )
                        .scaleEffect(0.85 + pulse * 0.2)
                }
            }

            if state == .typing || state == .listening {
                HStack(spacing: faceSize * 0.055) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(tint.opacity(0.36 + Double(index) * 0.12))
                            .frame(width: faceSize * 0.06, height: faceSize * 0.06)
                            .scaleEffect(0.82 + pulse * (0.25 + CGFloat(index) * 0.08))
                    }
                }
                .offset(y: faceSize * 0.36)
            }

            if lensFocusActive || state == .thinking {
                Circle()
                    .trim(from: 0.05, to: 0.32)
                    .stroke(tint.opacity(0.36), style: StrokeStyle(lineWidth: max(0.8, faceSize * 0.02), lineCap: .round))
                    .frame(width: faceSize * 0.86, height: faceSize * 0.86)
                    .rotationEffect(.degrees(18 + Double(pulse * 8)))
            }
        }
    }

    private var stateProfile: CompanionGlyphProfile {
        CompanionGlyphProfile(state: state, personality: personality)
    }
}

private struct CompanionGlyphProfile {
    let state: AICircleState
    let personality: CompanionPersonality

    var scale: CGFloat {
        switch state {
        case .settled: 0.88
        case .responding, .checkIn: 1.03
        case .listening: 1.01
        default: 0.96
        }
    }

    var pulseAmount: CGFloat {
        switch state {
        case .settled: 0.008
        case .typing, .responding, .checkIn: 0.024
        default: 0.014
        }
    }

    var verticalOffset: CGFloat {
        switch state {
        case .settled: 0.008
        case .listening, .checkIn: -0.006
        default: 0
        }
    }

    var sway: Double {
        switch personality {
        case .energetic: 1.8
        case .analytic: 0.9
        case .calm: 0.4
        case .grounded: 0.7
        }
    }

    var innerMistOpacity: Double {
        switch state {
        case .settled: 0.04
        case .thinking, .typing, .listening: 0.13
        case .responding, .checkIn: 0.16
        default: 0.1
        }
    }

    var innerRingOpacity: Double {
        switch state {
        case .settled: 0.12
        case .responding, .checkIn: 0.32
        default: 0.2
        }
    }

    var eyeSize: CGFloat {
        switch state {
        case .checkIn, .responding: 0.26
        case .thinking: 0.2
        case .typing, .settled: 0.22
        default: 0.25
        }
    }

    var eyeSpacing: CGFloat {
        switch state {
        case .listening, .checkIn: 0.22
        case .settled: 0.28
        default: 0.25
        }
    }

    var eyeShape: RingCompanionEye.ShapeKind {
        switch state {
        case .settled: .resting
        case .thinking: .pixelChevron
        case .typing: .softCapsule
        case .responding: .smileArc
        case .checkIn: .brightOval
        case .attentive, .idle: .displayOval
        case .listening: .sideOval
        }
    }

    var leftEyeOffset: CGPoint {
        switch state {
        case .thinking: CGPoint(x: 0.02, y: -0.01)
        case .listening: CGPoint(x: -0.02, y: 0)
        case .typing: CGPoint(x: 0.012, y: 0.015)
        default: CGPoint(x: 0, y: 0)
        }
    }

    var rightEyeOffset: CGPoint {
        switch state {
        case .thinking: CGPoint(x: -0.005, y: -0.015)
        case .listening: CGPoint(x: -0.02, y: 0)
        case .typing: CGPoint(x: 0.012, y: 0.015)
        default: CGPoint(x: 0, y: 0)
        }
    }

    var eyeY: CGFloat {
        switch state {
        case .settled: -0.02
        case .responding, .checkIn: -0.04
        default: -0.03
        }
    }

    var leftEyeTilt: Double {
        switch state {
        case .thinking: -8
        case .typing: -2
        case .responding, .checkIn: 2
        default: 0
        }
    }

    var rightEyeTilt: Double {
        switch state {
        case .thinking: 6
        case .typing: -2
        case .responding, .checkIn: -2
        default: 0
        }
    }

    var signalCount: Int {
        switch state {
        case .thinking: 2
        case .responding, .checkIn: 3
        default: 0
        }
    }

    var signalStartAngle: Double {
        switch state {
        case .thinking: 235
        default: 210
        }
    }
}

private struct RingCompanionEye: View {
    enum ShapeKind {
        case displayOval
        case sideOval
        case brightOval
        case softCapsule
        case pixelChevron
        case smileArc
        case resting
    }

    let size: CGFloat
    let tint: Color
    let shape: ShapeKind
    let offset: CGPoint
    let tilt: Double
    let pulse: CGFloat
    let time: TimeInterval
    let blinkScale: CGFloat
    let glancePhase: Double

    @ViewBuilder
    var body: some View {
        switch shape {
        case .pixelChevron:
            pixelEye
                .offset(x: size * offset.x, y: size * offset.y)
                .rotationEffect(.degrees(tilt))
                .scaleEffect(1 + pulse * pulseScale)
                .scaleEffect(x: glanceXScale, y: blinkScale, anchor: .center)
                .opacity(opacity)
        case .smileArc:
            arcEye
                .offset(x: size * offset.x, y: size * offset.y)
                .rotationEffect(.degrees(tilt))
                .scaleEffect(1 + pulse * pulseScale)
                .scaleEffect(x: glanceXScale, y: blinkScale, anchor: .center)
                .opacity(opacity)
        default:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fill)
                .frame(width: animatedWidth, height: animatedHeight)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(edgeOpacity), lineWidth: max(0.4, size * 0.035))
                }
                .shadow(color: tint.opacity(shadowOpacity), radius: shadowRadius)
                .offset(x: size * (offset.x + glanceOffset), y: size * offset.y)
                .rotationEffect(.degrees(tilt))
                .scaleEffect(1 + pulse * pulseScale)
                .opacity(opacity)
        }
    }

    private var pixelEye: some View {
        HStack(spacing: max(0.8, size * 0.09)) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: max(0.6, size * 0.08), style: .continuous)
                    .fill(fill)
                    .frame(width: max(1.9, size * 0.24), height: max(1.9, size * 0.24))
                    .offset(y: pixelOffset(for: index))
                    .shadow(color: tint.opacity(0.34), radius: max(0.7, size * 0.12))
            }
        }
    }

    private func pixelOffset(for index: Int) -> CGFloat {
        let pattern: [CGFloat] = [0.22, 0.08, -0.04, 0.08, 0.22]
        return size * pattern[index]
    }

    private var arcEye: some View {
        RingCompanionArcEye()
            .stroke(
                fill,
                style: StrokeStyle(lineWidth: max(1.2, size * 0.2), lineCap: .round, lineJoin: .round)
            )
            .frame(width: size * 1.18, height: size * 0.72)
            .shadow(color: tint.opacity(0.28), radius: max(0.8, size * 0.14))
    }

    private var fill: Color {
        switch shape {
        case .brightOval, .sideOval, .displayOval, .smileArc, .pixelChevron:
            tint.opacity(0.96)
        case .resting:
            tint.opacity(0.78)
        case .softCapsule:
            tint.opacity(0.88)
        }
    }

    private var width: CGFloat {
        switch shape {
        case .displayOval, .sideOval, .brightOval: size * 0.68
        case .softCapsule: size * 1.34
        case .resting: size * 1.28
        case .smileArc, .pixelChevron: size
        }
    }

    private var height: CGFloat {
        switch shape {
        case .displayOval, .brightOval: size * 1.08
        case .sideOval: size * 0.96
        case .softCapsule: size * 0.58
        case .resting: max(1.6, size * 0.22)
        case .smileArc, .pixelChevron: size
        }
    }

    private var cornerRadius: CGFloat {
        switch shape {
        case .displayOval, .sideOval, .brightOval: size * 0.36
        default: size * 0.28
        }
    }

    private var pulseScale: CGFloat {
        switch shape {
        case .brightOval, .displayOval, .sideOval, .smileArc: 0.04
        case .softCapsule: 0.025
        default: 0.012
        }
    }

    private var shadowOpacity: Double {
        switch shape {
        case .brightOval, .displayOval, .sideOval, .smileArc, .pixelChevron: 0.38
        default: 0.14
        }
    }

    private var shadowRadius: CGFloat {
        switch shape {
        case .brightOval, .displayOval, .sideOval: max(1.2, size * 0.28)
        case .smileArc, .pixelChevron: max(0.8, size * 0.18)
        default: max(0.6, size * 0.08)
        }
    }

    private var edgeOpacity: Double {
        switch shape {
        case .brightOval, .displayOval, .sideOval: 0.24
        default: 0.08
        }
    }

    private var opacity: Double {
        switch shape {
        case .resting: glancePhase > 0.4 ? 0 : 0.76
        default: 1
        }
    }

    private var animatedWidth: CGFloat {
        switch shape {
        case .displayOval, .brightOval, .sideOval:
            width * glanceXScale
        default:
            width
        }
    }

    private var animatedHeight: CGFloat {
        max(1.4, height * blinkScale)
    }

    private var glanceOffset: CGFloat {
        guard shape == .displayOval || shape == .brightOval || shape == .sideOval else { return 0 }
        return CGFloat(sin((time + glancePhase) * 0.42)) * 0.08
    }

    private var glanceXScale: CGFloat {
        guard shape == .displayOval || shape == .brightOval || shape == .sideOval else { return 1 }
        return 1 + CGFloat(cos((time + glancePhase) * 0.36)) * 0.06
    }
}

private struct RingCompanionArcEye: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.14, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.12)
        )
        return path
    }
}

private struct AICircleProfile {
    let state: AICircleState

    var maxScale: CGFloat {
        switch state {
        case .idle: 1.032
        case .attentive: 1.018
        case .listening: 1.028
        case .typing: 1.036
        case .thinking: 1.018
        case .responding: 1.01
        case .checkIn: 1.045
        case .settled: 1.01
        }
    }

    var breatheDuration: Double {
        switch state {
        case .idle: 2.8
        case .attentive: 3.2
        case .listening: 1.8
        case .typing: 1.2
        case .thinking: 2.2
        case .responding: 0.3
        case .checkIn: 1.65
        case .settled: 4.2
        }
    }

    var motionDuration: Double {
        switch state {
        case .idle: 52
        case .attentive: 62
        case .listening: 20
        case .typing: 14
        case .thinking: 18
        case .responding: 2.8
        case .checkIn: 22
        case .settled: 80
        }
    }

    var lineDuration: Double {
        switch state {
        case .idle: 42
        case .attentive: 54
        case .listening: 18
        case .typing: 9
        case .thinking: 14
        case .responding: 3.2
        case .checkIn: 18
        case .settled: 72
        }
    }

    var baseOpacity: Double {
        switch state {
        case .settled: 0.34
        case .thinking, .checkIn, .typing: 0.94
        case .attentive: 0.82
        default: 0.88
        }
    }

    var primaryOpacity: Double {
        switch state {
        case .settled: 0.38
        case .thinking, .typing, .checkIn, .listening: 1.0
        case .attentive: 0.86
        default: 0.95
        }
    }

    var secondaryOpacity: Double {
        switch state {
        case .settled: 0.22
        case .thinking, .checkIn, .listening: 0.72
        case .attentive: 0.46
        default: 0.58
        }
    }

    var highlightOpacity: Double {
        switch state {
        case .settled: 0.2
        case .thinking, .typing, .checkIn, .listening: 0.66
        case .attentive: 0.48
        default: 0.54
        }
    }

    var dryBrushOpacity: Double {
        switch state {
        case .settled: 0.16
        case .thinking, .typing, .checkIn, .listening: 0.82
        case .attentive: 0.46
        default: 0.66
        }
    }

    var scratchOpacity: Double {
        switch state {
        case .settled: 0.12
        case .thinking, .typing, .checkIn, .listening: 0.68
        case .attentive: 0.36
        default: 0.54
        }
    }

    var innerLineOpacity: Double {
        switch state {
        case .settled: 0.08
        case .thinking, .typing, .checkIn, .listening: 0.54
        case .attentive: 0.26
        default: 0.4
        }
    }

    var totalOpacity: Double {
        state == .settled ? 0.74 : 1
    }

    var glowOpacity: Double {
        switch state {
        case .settled: 0.12
        case .thinking, .typing, .checkIn, .listening: 0.28
        case .attentive: 0.16
        default: 0.2
        }
    }

    var glowRadius: CGFloat {
        switch state {
        case .thinking, .typing, .checkIn, .listening: 5
        case .attentive: 2.8
        default: 3.2
        }
    }

    var innerGlowOpacity: Double {
        switch state {
        case .settled: 0.04
        case .thinking, .typing, .checkIn, .listening: 0.18
        case .attentive: 0.08
        default: 0.12
        }
    }

    var innerGlowRadius: CGFloat {
        switch state {
        case .thinking, .typing, .checkIn, .listening: 10
        case .attentive: 7
        default: 8
        }
    }

    var coreGlowOpacity: Double {
        switch state {
        case .settled: 0.015
        case .thinking, .typing, .checkIn, .listening: 0.055
        case .attentive: 0.03
        default: 0.035
        }
    }

    var mistCoreOpacity: Double {
        switch state {
        case .thinking, .typing, .listening: 0.09
        case .responding: 0.12
        case .attentive: 0.06
        case .settled: 0.03
        default: 0.07
        }
    }

    var mistMidOpacity: Double {
        switch state {
        case .thinking, .typing, .listening: 0.05
        case .responding: 0.07
        case .attentive: 0.028
        case .settled: 0.014
        default: 0.038
        }
    }

    var mistBlur: CGFloat {
        switch state {
        case .thinking, .typing, .listening: 10
        case .responding: 12
        case .attentive: 7
        case .settled: 5
        default: 8
        }
    }

    var mistScale: CGFloat {
        switch state {
        case .responding: 0.78
        case .settled: 0.64
        default: 0.72
        }
    }

    var primaryTrim: ClosedRange<CGFloat> {
        switch state {
        case .idle: 0.04...0.965
        case .attentive: 0.11...0.9
        case .listening: 0.05...0.96
        case .typing: 0.03...0.98
        case .thinking: 0.06...0.955
        case .responding: 0.01...0.99
        case .checkIn: 0.025...0.985
        case .settled: 0.12...0.84
        }
    }

    var secondaryTrim: ClosedRange<CGFloat> {
        switch state {
        case .idle: 0.78...0.995
        case .attentive: 0.8...0.94
        case .listening: 0.76...0.99
        case .typing: 0.72...0.998
        case .thinking: 0.7...0.985
        case .responding: 0.7...0.998
        case .checkIn: 0.7...0.998
        case .settled: 0.72...0.92
        }
    }

    var highlightTrim: ClosedRange<CGFloat> {
        switch state {
        case .idle: 0.16...0.54
        case .attentive: 0.2...0.42
        case .listening: 0.17...0.56
        case .typing: 0.14...0.58
        case .thinking: 0.18...0.52
        case .responding: 0.12...0.64
        case .checkIn: 0.13...0.62
        case .settled: 0.2...0.46
        }
    }

    var motionOffset: Double {
        switch state {
        case .idle: 7
        case .attentive: 4
        case .listening: 12
        case .typing: 18
        case .thinking: 36
        case .responding: 18
        case .checkIn: 20
        case .settled: 2
        }
    }

    var lineTravel: Double {
        switch state {
        case .idle: 80
        case .attentive: 64
        case .listening: 230
        case .typing: 320
        case .thinking: 460
        case .responding: 260
        case .checkIn: 130
        case .settled: 24
        }
    }

    func orbitActivity(at time: TimeInterval) -> Double {
        switch state {
        case .responding, .thinking, .typing, .listening:
            1
        case .checkIn:
            intermittentActivity(at: time, period: 7.2, activeFraction: 0.34)
        case .idle, .attentive:
            intermittentActivity(at: time, period: 9.5, activeFraction: 0.2) * 0.5
        case .settled:
            intermittentActivity(at: time, period: 12, activeFraction: 0.14) * 0.36
        }
    }

    private func intermittentActivity(at time: TimeInterval, period: Double, activeFraction: Double) -> Double {
        let position = time.truncatingRemainder(dividingBy: period) / period
        guard position < activeFraction else { return 0 }
        let phase = position / activeFraction
        return pow(sin(phase * .pi), 0.7)
    }

    var primaryScale: CGFloat {
        switch state {
        case .typing, .checkIn, .listening: 1.018
        case .attentive: 1.006
        case .responding: 1.03
        default: 1.01
        }
    }

    var outerScale: CGFloat {
        switch state {
        case .typing, .checkIn: 1.01
        default: 1.004
        }
    }

    var blur: CGFloat {
        state == .settled ? 0.2 : 0.12
    }

}

struct MoodSelectorView: View {
    @Binding var selectedMood: MoodLevel
    var size: CGFloat = 54
    var labelFont: Font = .caption
    var useMoodAccent: Bool = false

    var body: some View {
        HStack(spacing: 10) {
                ForEach(MoodLevel.allCases) { mood in
                    let isSelected = selectedMood == mood
                let activeFill = useMoodAccent ? mood.interfaceAccentColor : Color.primary
                    Button {
                        selectedMood = mood
                    } label: {
                    VStack(spacing: 7) {
                        Image(systemName: mood.symbol)
                            .font(.system(size: size * 0.34, weight: .semibold))
                            .frame(width: size, height: size)
                            .background(isSelected ? activeFill : AppSurface.fill, in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(AppSurface.stroke, lineWidth: 0.5)
                            }
                            .foregroundStyle(isSelected ? selectedForeground(for: mood) : .primary)
                        Text(mood.label)
                            .font(labelFont)
                            .foregroundStyle(isSelected ? activeFill : .secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mood.label)
            }
        }
    }

    private func selectedForeground(for mood: MoodLevel) -> Color {
        if useMoodAccent && mood == .okay {
            return Color.black.opacity(0.78)
        }
        return Color(.systemBackground)
    }
}

struct WeekCalendarStripView: View {
    @Binding var selectedDate: Date
    let dates: [Date]
    var hasEntry: (Date) -> Bool = { _ in false }

    var body: some View {
        let today = Calendar.current.startOfDay(for: Date())
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(dates, id: \.self) { date in
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    let hasSavedEntry = hasEntry(date)
                    let day = Calendar.current.startOfDay(for: date)
                    let isToday = Calendar.current.isDate(day, inSameDayAs: today)
                    let isPast = day < today
                    let isFuture = day > today

                    let fillColor: Color = {
                        if isToday, hasSavedEntry { return Color.white.opacity(0.2) }
                        if isToday { return Color.white.opacity(0.08) }
                        if isPast, hasSavedEntry { return Color.white.opacity(0.13) }
                        return Color.clear
                    }()

                    let ringColor: Color = {
                        if isToday { return Color.white.opacity(0.98) }
                        if isPast, hasSavedEntry { return Color.white.opacity(0.85) }
                        if isFuture { return Color.white.opacity(0.35) }
                        return Color.white.opacity(0.75)
                    }()

                    let dayTextColor: Color = {
                        if isFuture { return Color.secondary.opacity(0.68) }
                        return .primary
                    }()

                    Button {
                        selectedDate = date
                    } label: {
                        VStack(spacing: 6) {
                            Text(date.shortDay)
                                .font(.caption2)
                                .foregroundStyle(dayTextColor.opacity(isSelected ? 1 : 0.85))
                            ZStack {
                                Circle()
                                    .fill(fillColor)
                                    .frame(width: 36, height: 36)
                                Circle()
                                    .stroke(ringColor, lineWidth: isToday ? 1.35 : 1.15)
                                    .frame(width: 36, height: 36)

                                if isSelected {
                                    Circle()
                                        .stroke(Color.white.opacity(0.92), lineWidth: 2.4)
                                        .frame(width: 42, height: 42)
                                }

                                Text(date.dayNumber)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(dayTextColor)

                                if hasSavedEntry {
                                    Circle()
                                        .fill(isFuture ? Color.clear : Color.white.opacity(0.95))
                                        .frame(width: 4, height: 4)
                                        .offset(y: 13)
                                }
                            }
                        }
                        .frame(height: 64)
                        .frame(width: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.page)
            .padding(.vertical, 6)
        }
        .padding(.vertical, 2)
    }
}

struct InsightSectionView: View {
    let title: String
    let bodyText: String
    var symbol: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.caption.weight(.semibold))
                        .frame(width: 22)
                        .foregroundStyle(.primary)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            Text(bodyText)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }
}

struct EntryRowView: View {
    let entry: JournalEntry

    var body: some View {
        let accent = entry.mood.interfaceAccentColor
        let moodForeground: Color = entry.mood == .okay ? .black.opacity(0.78) : .white
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text(entry.date.compactTime)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.12), in: Capsule())

                Image(systemName: entry.entryType.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 24, height: 24)
                    .background(accent.opacity(0.14), in: Circle())

                Text(entry.entryType.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.12), in: Capsule())
                    .overlay {
                        Capsule().stroke(accent.opacity(0.35), lineWidth: 0.6)
                    }

                Spacer()

                Image(systemName: entry.mood.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .foregroundStyle(moodForeground)
                    .background(accent, in: Circle())
                    .overlay {
                        Circle().stroke(Color.white.opacity(entry.mood == .okay ? 0.26 : 0), lineWidth: 0.7)
                    }
            }

            Text(entry.text)
                .font(.body.weight(.medium))
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ConversationBubbleView: View {
    let message: ConversationMessage
    @State private var showWhy = false

    var body: some View {
        HStack(alignment: .bottom) {
            if message.sender == .user {
                Spacer(minLength: 42)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(message.text)
                    .font(.body)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .foregroundStyle(message.sender == .user ? Color(.systemBackground) : .primary)
                    .background(message.sender == .user ? Color.primary : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 17, style: .continuous))

                if message.sender == .ai, let replyContext = message.replyContext, replyContext.isEmpty == false {
                    DisclosureGroup("Why this reply", isExpanded: $showWhy) {
                        Text(replyContext)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                    .font(.caption.weight(.semibold))
                    .tint(.secondary)
                    .foregroundStyle(.secondary)
                }
            }

            if message.sender == .ai {
                Spacer(minLength: 42)
            }
        }
    }
}

struct CalmSoundRowView: View {
    let sound: CalmSound
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: sound.icon)
                    .font(.body)
                    .frame(width: 32, height: 32)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(sound.title)
                        .font(.body)
                    Text(sound.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(sound.duration)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle")
                    .font(.title3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("AI Circle") {
    VStack(spacing: 28) {
        AICircleView(state: .idle)
        AICircleView(state: .thinking)
        AICircleView(state: .checkIn)
    }
    .padding()
}
