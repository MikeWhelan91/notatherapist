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
        let brushWidth = max(strokeWidth * 2.4, size * 0.1)
        let hairlineWidth = max(strokeWidth * 0.5, size * 0.018)
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let elapsed = timeline.date.timeIntervalSince(animationStart)
            let pulse = (sin((time / profile.breatheDuration) * .pi * 2) + 1) / 2
            let introProgress = min(max(elapsed / 18, 0), 1)
            let easedIntroProgress = introProgress * introProgress * (3 - 2 * introProgress)
            let drift = motionStyle == .intro ? easedIntroProgress * 160 : (elapsed / profile.motionDuration) * profile.motionOffset
            let lineMotion = motionStyle == .intro ? easedIntroProgress * 720 : (elapsed / profile.lineDuration) * profile.lineTravel
            let maxScale = motionStyle == .intro ? CGFloat(1.008) : profile.maxScale

            ZStack {
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
                    .trim(from: 0.005, to: 0.995)
                    .stroke(.primary.opacity(profile.baseOpacity), style: StrokeStyle(lineWidth: brushWidth, lineCap: .round, lineJoin: .round))
                    .rotationEffect(.degrees(18 + (drift * 0.18)))
                    .scaleEffect(0.99)

                Circle()
                    .trim(from: profile.primaryTrim.lowerBound, to: profile.primaryTrim.upperBound)
                    .stroke(.primary.opacity(profile.primaryOpacity), style: StrokeStyle(lineWidth: brushWidth * 0.82, lineCap: .round, lineJoin: .round))
                    .rotationEffect(.degrees(-18 - (drift * 0.25)))
                    .scaleEffect(profile.primaryScale)

                Circle()
                    .trim(from: profile.secondaryTrim.lowerBound, to: profile.secondaryTrim.upperBound)
                    .stroke(.primary.opacity(profile.secondaryOpacity), style: StrokeStyle(lineWidth: brushWidth * 0.62, lineCap: .round, lineJoin: .round))
                    .rotationEffect(.degrees(138 + (drift * 0.35)))
                    .scaleEffect(1.015)

                Circle()
                    .trim(from: profile.highlightTrim.lowerBound, to: profile.highlightTrim.upperBound)
                    .stroke(.primary.opacity(profile.highlightOpacity), style: StrokeStyle(lineWidth: brushWidth * 0.44, lineCap: .round, lineJoin: .round))
                    .rotationEffect(.degrees(42 - (drift * 0.22)))
                    .scaleEffect(0.975)

                Circle()
                    .trim(from: 0.01, to: 0.97)
                    .stroke(.primary.opacity(profile.scratchOpacity), style: StrokeStyle(lineWidth: hairlineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-12 + (lineMotion * 0.18)))
                    .scaleEffect(1.105)

                Circle()
                    .trim(from: 0.045, to: 0.94)
                    .stroke(.primary.opacity(profile.scratchOpacity * 0.8), style: StrokeStyle(lineWidth: hairlineWidth * 0.82, lineCap: .round))
                    .rotationEffect(.degrees(8 + (lineMotion * 0.16)))
                    .scaleEffect(0.86)

                Circle()
                    .trim(from: 0.14, to: 0.31)
                    .stroke(.primary.opacity(profile.dryBrushOpacity), style: StrokeStyle(lineWidth: hairlineWidth * 0.9, lineCap: .round))
                    .rotationEffect(.degrees(-42 + lineMotion))
                    .scaleEffect(1.18)

                Circle()
                    .trim(from: 0.56, to: 0.72)
                    .stroke(.primary.opacity(profile.dryBrushOpacity * 0.86), style: StrokeStyle(lineWidth: hairlineWidth * 0.78, lineCap: .round))
                    .rotationEffect(.degrees(104 + (lineMotion * 0.72)))
                    .scaleEffect(1.06)

                Circle()
                    .trim(from: 0.79, to: 0.93)
                    .stroke(.primary.opacity(profile.dryBrushOpacity * 1.15), style: StrokeStyle(lineWidth: hairlineWidth * 1.05, lineCap: .round))
                    .rotationEffect(.degrees(23 + (lineMotion * 0.62)))
                    .scaleEffect(1.16)

                Circle()
                    .trim(from: 0.04, to: 0.18)
                    .stroke(.primary.opacity(profile.innerLineOpacity), style: StrokeStyle(lineWidth: hairlineWidth * 1.1, lineCap: .round))
                    .rotationEffect(.degrees(-28 + (lineMotion * 1.25)))
                    .scaleEffect(0.66)

                Circle()
                    .trim(from: 0.34, to: 0.52)
                    .stroke(.primary.opacity(profile.innerLineOpacity * 0.82), style: StrokeStyle(lineWidth: hairlineWidth * 0.9, lineCap: .round))
                    .rotationEffect(.degrees(78 + (lineMotion * 0.96)))
                    .scaleEffect(0.74)

                Circle()
                    .trim(from: 0.64, to: 0.82)
                    .stroke(.primary.opacity(profile.innerLineOpacity * 0.72), style: StrokeStyle(lineWidth: hairlineWidth * 0.72, lineCap: .round))
                    .rotationEffect(.degrees(154 + (lineMotion * 0.92)))
                    .scaleEffect(0.56)

                if state == .typing || state == .checkIn {
                    Circle()
                        .trim(from: 0.78, to: 0.98)
                        .stroke(.primary.opacity(0.32), style: StrokeStyle(lineWidth: brushWidth * 0.32, lineCap: .round))
                        .rotationEffect(.degrees(28 + drift))
                        .scaleEffect(1.08)
                }
            }
            .frame(width: size, height: size)
            .scaleEffect((responseKick ? 1.06 : 1.0) * (1 + (maxScale - 1) * CGFloat(pulse)))
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
        case .typing: 1.04
        case .thinking: 1.018
        case .responding: 1.01
        case .checkIn: 1.045
        case .settled: 1.01
        }
    }

    var breatheDuration: Double {
        switch state {
        case .idle: 2.8
        case .typing: 1.35
        case .thinking: 2.2
        case .responding: 0.3
        case .checkIn: 1.65
        case .settled: 4.2
        }
    }

    var motionDuration: Double {
        switch state {
        case .idle: 28
        case .typing: 12
        case .thinking: 16
        case .responding: 2.8
        case .checkIn: 14
        case .settled: 36
        }
    }

    var lineDuration: Double {
        switch state {
        case .idle: 24
        case .typing: 10
        case .thinking: 13
        case .responding: 3.2
        case .checkIn: 12
        case .settled: 42
        }
    }

    var baseOpacity: Double {
        switch state {
        case .settled: 0.34
        case .thinking, .checkIn: 0.94
        default: 0.9
        }
    }

    var primaryOpacity: Double {
        switch state {
        case .settled: 0.38
        case .thinking, .typing, .checkIn: 1.0
        default: 0.98
        }
    }

    var secondaryOpacity: Double {
        switch state {
        case .settled: 0.22
        case .thinking, .checkIn: 0.72
        default: 0.62
        }
    }

    var highlightOpacity: Double {
        switch state {
        case .settled: 0.2
        case .thinking, .typing, .checkIn: 0.66
        default: 0.56
        }
    }

    var dryBrushOpacity: Double {
        switch state {
        case .settled: 0.16
        case .thinking, .typing, .checkIn: 0.82
        default: 0.7
        }
    }

    var scratchOpacity: Double {
        switch state {
        case .settled: 0.12
        case .thinking, .typing, .checkIn: 0.68
        default: 0.58
        }
    }

    var innerLineOpacity: Double {
        switch state {
        case .settled: 0.08
        case .thinking, .typing, .checkIn: 0.54
        default: 0.42
        }
    }

    var totalOpacity: Double {
        state == .settled ? 0.72 : 1
    }

    var glowOpacity: Double {
        switch state {
        case .settled: 0.12
        case .thinking, .typing, .checkIn: 0.28
        default: 0.2
        }
    }

    var glowRadius: CGFloat {
        switch state {
        case .thinking, .typing, .checkIn: 5
        default: 3.5
        }
    }

    var innerGlowOpacity: Double {
        switch state {
        case .settled: 0.04
        case .thinking, .typing, .checkIn: 0.18
        default: 0.12
        }
    }

    var innerGlowRadius: CGFloat {
        switch state {
        case .thinking, .typing, .checkIn: 10
        default: 8
        }
    }

    var coreGlowOpacity: Double {
        switch state {
        case .settled: 0.015
        case .thinking, .typing, .checkIn: 0.055
        default: 0.035
        }
    }

    var primaryTrim: ClosedRange<CGFloat> {
        switch state {
        case .idle: 0.04...0.965
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
        case .typing: 0.14...0.58
        case .thinking: 0.18...0.52
        case .responding: 0.12...0.64
        case .checkIn: 0.13...0.62
        case .settled: 0.2...0.46
        }
    }

    var motionOffset: Double {
        switch state {
        case .idle: 18
        case .typing: 28
        case .thinking: 36
        case .responding: 18
        case .checkIn: 30
        case .settled: 8
        }
    }

    var lineTravel: Double {
        switch state {
        case .idle: 360
        case .typing: 420
        case .thinking: 460
        case .responding: 260
        case .checkIn: 420
        case .settled: 90
        }
    }

    var primaryScale: CGFloat {
        switch state {
        case .typing, .checkIn: 1.018
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
                        MoodFaceIcon(mood: mood, color: selectedMood == mood ? Color(.systemBackground) : .primary)
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

private struct MoodFaceIcon: View {
    let mood: MoodLevel
    let color: Color

    var body: some View {
        ZStack {
            eyeView
            mouthView
        }
        .foregroundStyle(color)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var eyeView: some View {
        switch mood {
        case .terrible:
            HStack(spacing: 10) {
                Capsule()
                    .frame(width: 7, height: 2)
                    .rotationEffect(.degrees(28))
                Capsule()
                    .frame(width: 7, height: 2)
                    .rotationEffect(.degrees(-28))
            }
            .offset(y: -7)
        case .low:
            HStack(spacing: 8) {
                Capsule().frame(width: 7, height: 2)
                Capsule().frame(width: 7, height: 2)
            }
            .offset(y: -7)
        default:
            HStack(spacing: 8) {
                Circle().frame(width: 3.5, height: 3.5)
                Circle().frame(width: 3.5, height: 3.5)
            }
            .offset(y: -7)
        }
    }

    @ViewBuilder
    private var mouthView: some View {
        switch mood {
        case .terrible:
            Arc(startAngle: .degrees(205), endAngle: .degrees(335))
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 18, height: 13)
                .rotationEffect(.degrees(180))
                .offset(y: 7)
        case .low:
            Capsule()
                .frame(width: 15, height: 2)
                .offset(y: 7)
        case .okay:
            Arc(startAngle: .degrees(205), endAngle: .degrees(335))
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 17, height: 12)
                .offset(y: 4)
        case .good:
            Arc(startAngle: .degrees(200), endAngle: .degrees(340))
                .stroke(color, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .frame(width: 22, height: 15)
                .offset(y: 3)
        case .great:
            Capsule()
                .frame(width: 14, height: 9)
                .offset(y: 6)
            Arc(startAngle: .degrees(198), endAngle: .degrees(342))
                .stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .frame(width: 24, height: 17)
                .offset(y: 2)
        }
    }
}

private struct Arc: Shape {
    var startAngle: Angle
    var endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

struct WeekCalendarStripView: View {
    @Binding var selectedDate: Date
    let dates: [Date]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(dates, id: \.self) { date in
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    Button {
                        selectedDate = date
                    } label: {
                        VStack(spacing: 6) {
                            Text(date.shortDay)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(date.dayNumber)
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 32, height: 32)
                                .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                                .background(isSelected ? Color.primary : Color.clear, in: Circle())
                        }
                        .frame(width: 46)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.page)
        }
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
        HStack(alignment: .top, spacing: 12) {
            Text(entry.date.compactTime)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)

            Image(systemName: entry.entryType.icon)
                .font(.subheadline)
                .frame(width: 24)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.text)
                    .font(.subheadline)
                    .lineLimit(2)
                Text(entry.entryType.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: entry.mood.symbol)
                .font(.caption2.weight(.semibold))
                .frame(width: 24, height: 24)
                .foregroundStyle(Color(.systemBackground))
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

    var body: some View {
        HStack(alignment: .bottom) {
            if message.sender == .user {
                Spacer(minLength: 42)
            }

            Text(message.text)
                .font(.body)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .foregroundStyle(message.sender == .user ? Color(.systemBackground) : .primary)
                .background(message.sender == .user ? Color.primary : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 17, style: .continuous))

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
