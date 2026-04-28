import SwiftUI

struct CalmView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var playingSoundID: UUID?
    private let soundColumns = [GridItem(.adaptive(minimum: 76), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    HStack {
                        AICircleView(state: .idle, size: 58, strokeWidth: 2.5)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(title: "Sounds", action: "See all")
                        LazyVGrid(columns: soundColumns, spacing: 10) {
                            ForEach(appModel.sounds.prefix(4)) { sound in
                                Button {
                                    playingSoundID = playingSoundID == sound.id ? nil : sound.id
                                } label: {
                                    VStack(spacing: 10) {
                                        Image(systemName: sound.icon)
                                            .font(.title3)
                                        Text(sound.title)
                                            .font(.caption.weight(.medium))
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 84)
                                    .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(playingSoundID == sound.id ? Color.primary : AppSurface.stroke, lineWidth: playingSoundID == sound.id ? 1.2 : 0.5)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(title: "Breathing")
                        VStack(spacing: 10) {
                            breathingLink("Box Breathing", subtitle: "4 min", symbol: "square", mode: .box)
                            breathingLink("4-7-8 Breathing", subtitle: "4 min", symbol: "timer", mode: .fourSevenEight)
                            breathingLink("Reset Breath", subtitle: "2 min", symbol: "arrow.counterclockwise", mode: .reset)
                        }
                    }
                }
                .padding(AppSpacing.page)
            }
            .navigationTitle("Calm")
        }
    }

    private func breathingLink(_ title: String, subtitle: String, symbol: String, mode: BreathingMode) -> some View {
        NavigationLink {
            BreathingView(mode: mode)
        } label: {
            ReferenceCard {
                HStack(spacing: 12) {
                    Image(systemName: symbol)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

enum BreathingMode: String {
    case box = "Box Breathing"
    case fourSevenEight = "4-7-8 Breathing"
    case reset = "Reset Breath"

    var phases: [(label: String, seconds: Int, scale: CGFloat)] {
        switch self {
        case .box:
            [("inhale", 4, 1.18), ("hold", 4, 1.18), ("exhale", 4, 0.88), ("hold", 4, 0.88)]
        case .fourSevenEight:
            [("inhale", 4, 1.16), ("hold", 7, 1.16), ("exhale", 8, 0.86)]
        case .reset:
            [("inhale", 3, 1.12), ("exhale", 5, 0.88)]
        }
    }
}

struct BreathingView: View {
    let mode: BreathingMode
    @State private var isRunning = false
    @State private var phaseIndex = 0
    @State private var circleScale: CGFloat = 0.9
    @State private var task: Task<Void, Never>?

    var currentPhase: (label: String, seconds: Int, scale: CGFloat) {
        mode.phases[phaseIndex]
    }

    var body: some View {
        VStack(spacing: 34) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(.primary.opacity(0.22), lineWidth: 2)
                    .frame(width: 190, height: 190)
                Circle()
                    .stroke(.primary, lineWidth: 2.5)
                    .frame(width: 142, height: 142)
                    .scaleEffect(circleScale)
                AICircleView(state: isRunning ? .thinking : .settled, size: 70, strokeWidth: 2)
            }
            .animation(.easeInOut(duration: Double(currentPhase.seconds)), value: circleScale)

            VStack(spacing: 6) {
                Text(currentPhase.label)
                    .font(.title.weight(.semibold))
                Text("\(currentPhase.seconds) seconds")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button(isRunning ? "Stop" : "Start") {
                isRunning ? stop() : start()
            }
            .buttonStyle(PrimaryCapsuleButtonStyle())
            .padding(.horizontal, AppSpacing.page)

            Spacer()
        }
        .navigationTitle(mode.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { stop() }
    }

    private func start() {
        isRunning = true
        task?.cancel()
        task = Task {
            while Task.isCancelled == false {
                let phase = await MainActor.run { currentPhase }
                await MainActor.run {
                    circleScale = phase.scale
                }
                try? await Task.sleep(for: .seconds(phase.seconds))
                await MainActor.run {
                    phaseIndex = (phaseIndex + 1) % mode.phases.count
                }
            }
        }
    }

    private func stop() {
        task?.cancel()
        task = nil
        isRunning = false
        phaseIndex = 0
        circleScale = 0.9
    }
}

#Preview {
    CalmView()
        .environmentObject(AppViewModel())
}
