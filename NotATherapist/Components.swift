import SwiftUI

enum AICircleMotionStyle {
    case continuous
    case intro
}

struct AICircleView: View {
    let state: AICircleState
    var size: CGFloat = 64
    var strokeWidth: CGFloat = 2.5
    var motionStyle: AICircleMotionStyle = .continuous

    @State private var animationStart = Date()
    @State private var responseKick = false

    var body: some View {
        let profile = AICircleProfile(state: state)
        let brushWidth = max(strokeWidth * 2.2, size * 0.093)
        let hairlineWidth = max(strokeWidth * 0.5, size * 0.018)
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let elapsed = timeline.date.timeIntervalSince(animationStart)
            let pulse = (sin((time / profile.breatheDuration) * .pi * 2) + 1) / 2
            let introProgress = min(max(elapsed / 18, 0), 1)
            let easedIntroProgress = introProgress * introProgress * (3 - 2 * introProgress)
            let drift = motionStyle == .intro ? easedIntroProgress * 88 : (elapsed / profile.motionDuration) * profile.motionOffset
            let lineMotion = motionStyle == .intro ? easedIntroProgress * 420 : (elapsed / profile.lineDuration) * profile.lineTravel
            let maxScale = motionStyle == .intro ? CGFloat(1.006) : profile.maxScale

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(profile.mistCoreOpacity),
                                .white.opacity(profile.mistMidOpacity),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.52
                        )
                    )
                    .blur(radius: profile.mistBlur)
                    .scaleEffect(profile.mistScale + (CGFloat(pulse) * 0.03))

                Circle()
                    .stroke(.white.opacity(profile.glowOpacity), style: StrokeStyle(lineWidth: brushWidth * 1.15, lineCap: .round, lineJoin: .round))
                    .blur(radius: profile.glowRadius)
                    .scaleEffect(1.015)

                Circle()
                    .stroke(.white.opacity(profile.innerGlowOpacity), style: StrokeStyle(lineWidth: brushWidth * 1.55, lineCap: .round, lineJoin: .round))
                    .blur(radius: profile.innerGlowRadius)
                    .scaleEffect(0.84)

                Circle()
                    .fill(.white.opacity(profile.coreGlowOpacity))
                    .blur(radius: profile.innerGlowRadius * 1.4)
                    .scaleEffect(0.58)

                Circle()
                    .trim(from: 0.025, to: 0.965)
                    .stroke(.primary.opacity(profile.baseOpacity), style: StrokeStyle(lineWidth: brushWidth, lineCap: .round, lineJoin: .round))
                    .rotationEffect(.degrees(12 + (drift * 0.09)))
                    .scaleEffect(0.99)

                Circle()
                    .trim(from: profile.primaryTrim.lowerBound, to: profile.primaryTrim.upperBound)
                    .stroke(.primary.opacity(profile.primaryOpacity), style: StrokeStyle(lineWidth: brushWidth * 0.82, lineCap: .round, lineJoin: .round))
                    .rotationEffect(.degrees(-14 - (drift * 0.12)))
                    .scaleEffect(profile.primaryScale)

                Circle()
                    .trim(from: profile.secondaryTrim.lowerBound, to: profile.secondaryTrim.upperBound)
                    .stroke(.primary.opacity(profile.secondaryOpacity), style: StrokeStyle(lineWidth: brushWidth * 0.62, lineCap: .round, lineJoin: .round))
                    .rotationEffect(.degrees(140 + (drift * 0.1)))
                    .scaleEffect(1.015)

                Circle()
                    .trim(from: profile.highlightTrim.lowerBound, to: profile.highlightTrim.upperBound)
                    .stroke(.primary.opacity(profile.highlightOpacity), style: StrokeStyle(lineWidth: brushWidth * 0.44, lineCap: .round, lineJoin: .round))
                    .rotationEffect(.degrees(44 - (drift * 0.11)))
                    .scaleEffect(0.975)

                Circle()
                    .trim(from: 0.01, to: 0.97)
                    .stroke(.primary.opacity(profile.scratchOpacity), style: StrokeStyle(lineWidth: hairlineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-12 + (lineMotion * 0.08)))
                    .scaleEffect(1.105)

                Circle()
                    .trim(from: 0.045, to: 0.94)
                    .stroke(.primary.opacity(profile.scratchOpacity * 0.8), style: StrokeStyle(lineWidth: hairlineWidth * 0.82, lineCap: .round))
                    .rotationEffect(.degrees(8 + (lineMotion * 0.07)))
                    .scaleEffect(0.86)

                Circle()
                    .trim(from: 0.14, to: 0.31)
                    .stroke(.primary.opacity(profile.dryBrushOpacity), style: StrokeStyle(lineWidth: hairlineWidth * 0.9, lineCap: .round))
                    .rotationEffect(.degrees(-42 + (lineMotion * 0.14)))
                    .scaleEffect(1.18)

                Circle()
                    .trim(from: 0.56, to: 0.72)
                    .stroke(.primary.opacity(profile.dryBrushOpacity * 0.86), style: StrokeStyle(lineWidth: hairlineWidth * 0.78, lineCap: .round))
                    .rotationEffect(.degrees(104 + (lineMotion * 0.11)))
                    .scaleEffect(1.06)

                Circle()
                    .trim(from: 0.79, to: 0.93)
                    .stroke(.primary.opacity(profile.dryBrushOpacity * 1.15), style: StrokeStyle(lineWidth: hairlineWidth * 1.05, lineCap: .round))
                    .rotationEffect(.degrees(23 + (lineMotion * 0.09)))
                    .scaleEffect(1.16)

                Circle()
                    .trim(from: 0.04, to: 0.18)
                    .stroke(.primary.opacity(profile.innerLineOpacity), style: StrokeStyle(lineWidth: hairlineWidth * 1.1, lineCap: .round))
                    .rotationEffect(.degrees(-28 + (lineMotion * 0.15)))
                    .scaleEffect(0.66)

                Circle()
                    .trim(from: 0.34, to: 0.52)
                    .stroke(.primary.opacity(profile.innerLineOpacity * 0.82), style: StrokeStyle(lineWidth: hairlineWidth * 0.9, lineCap: .round))
                    .rotationEffect(.degrees(78 + (lineMotion * 0.12)))
                    .scaleEffect(0.74)

                Circle()
                    .trim(from: 0.64, to: 0.82)
                    .stroke(.primary.opacity(profile.innerLineOpacity * 0.72), style: StrokeStyle(lineWidth: hairlineWidth * 0.72, lineCap: .round))
                    .rotationEffect(.degrees(154 + (lineMotion * 0.1)))
                    .scaleEffect(0.56)

                if state == .typing || state == .checkIn || state == .listening {
                    Circle()
                        .trim(from: 0.82, to: 0.96)
                        .stroke(.primary.opacity(0.24), style: StrokeStyle(lineWidth: brushWidth * 0.28, lineCap: .round))
                        .rotationEffect(.degrees(28 + (drift * 0.16)))
                        .scaleEffect(1.08)
                }
            }
            .frame(width: size, height: size)
            .scaleEffect((responseKick ? 1.045 : 1.0) * (1 + (maxScale - 1) * CGFloat(pulse)))
            .opacity(profile.totalOpacity)
        }
        .animation(.easeOut(duration: 0.26), value: responseKick)
        .task(id: state) {
            animationStart = Date()
            configureAnimation()
        }
        .accessibilityHidden(true)
    }

    private func configureAnimation() {
        responseKick = false

        if state == .responding {
            withAnimation(.easeOut(duration: 0.24)) {
                responseKick = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                responseKick = false
            }
        }
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
        case .idle: 180
        case .attentive: 120
        case .listening: 230
        case .typing: 320
        case .thinking: 460
        case .responding: 260
        case .checkIn: 300
        case .settled: 40
        }
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

    var body: some View {
        HStack(spacing: 10) {
            ForEach(MoodLevel.allCases) { mood in
                Button {
                    selectedMood = mood
                } label: {
                    VStack(spacing: 7) {
                        Text(mood.emoji)
                            .font(.system(size: size * 0.42))
                            .frame(width: size, height: size)
                            .background(selectedMood == mood ? Color.primary : AppSurface.fill, in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(AppSurface.stroke, lineWidth: 0.5)
                            }
                        Text(mood.label)
                            .font(labelFont)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mood.label)
            }
        }
    }
}

struct WeekCalendarStripView: View {
    @Binding var selectedDate: Date
    let dates: [Date]
    var hasEntry: (Date) -> Bool = { _ in false }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(dates, id: \.self) { date in
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    let hasSavedEntry = hasEntry(date)
                    Button {
                        selectedDate = date
                    } label: {
                        VStack(spacing: 6) {
                            Text(date.shortDay)
                                .font(.caption2)
                                .foregroundStyle(isSelected ? .primary : .secondary)
                            ZStack {
                                Circle()
                                    .fill(hasSavedEntry ? Color.primary : Color.clear)
                                    .frame(width: 40, height: 40)
                                Circle()
                                    .stroke(Color.primary.opacity(0.95), lineWidth: 1.2)
                                    .frame(width: 40, height: 40)

                                if isSelected {
                                    Circle()
                                        .stroke(Color.white.opacity(0.92), lineWidth: 2.4)
                                        .frame(width: 46, height: 46)
                                }

                                Text(date.dayNumber)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(hasSavedEntry ? Color.black : .primary)

                                if hasSavedEntry {
                                    Circle()
                                        .fill(Color.black)
                                        .frame(width: 4, height: 4)
                                        .offset(y: 13)
                                }
                            }
                        }
                        .frame(height: 68)
                        .frame(width: 50)
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
        HStack(alignment: .center, spacing: 12) {
            Text(entry.date.compactTime)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)

            Image(systemName: entry.entryType.icon)
                .font(.subheadline)
                .frame(width: 24)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.entryType.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(entry.mood.emoji)
                .font(.system(size: 21))
                .frame(width: 38, height: 38)
                .foregroundStyle(Color.black)
                .background(Color.primary, in: Circle())

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 5)
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
