import SwiftUI
import Lottie

struct ConfettiOverlayView: View {
    let trigger: Int

    var body: some View {
        Group {
            if trigger > 0 {
                LottieConfettiPlayer(trigger: trigger, name: "Confetti")
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
    }
}

private struct LottieConfettiPlayer: UIViewRepresentable {
    let trigger: Int
    let name: String

    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: .zero)
        container.backgroundColor = .clear

        let animationView = LottieAnimationView()
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.contentMode = .scaleAspectFill
        animationView.loopMode = .playOnce
        animationView.animationSpeed = 1.0
        animationView.isUserInteractionEnabled = false

        container.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        context.coordinator.animationView = animationView
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard context.coordinator.lastTrigger != trigger else { return }
        context.coordinator.lastTrigger = trigger

        let view = context.coordinator.animationView
        view?.animation = LottieAnimation.named(name)
        view?.currentProgress = 0
        view?.play()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var animationView: LottieAnimationView?
        var lastTrigger: Int = 0
    }
}
