import UIKit

/// Lightweight haptic feedback. No audio assets bundled, so we ship haptics only
/// (system sounds use undocumented IDs that change across iOS releases — not worth the risk).
/// `enabled` mirrors `Settings.hapticsEnabled` and is checked on every call.
enum Feedback {
    static var enabled: Bool = true

    // Cached generators so `prepare()` actually warms the SAME hardware instance that
    // later fires. `tap()/wrong()/win()` keep their fresh-generator bodies for minimal diff.
    private static let lightGen = UIImpactFeedbackGenerator(style: .light)
    private static let notifyGen = UINotificationFeedbackGenerator()

    static func tap() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func wrong() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func win() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: Celebration (correct-word wave)

    /// Warm the cached generators ~100ms before the burst to avoid cold-first-tap latency.
    /// Always fires (cheap, idempotent) — independent of `enabled`.
    static func prepareCelebration() {
        lightGen.prepare()
        notifyGen.prepare()
    }

    /// Per-tile tap during the celebration wave. `intensity` 0.0–1.0.
    static func celebrationTap(intensity: CGFloat = 0.7) {
        guard enabled else { return }
        lightGen.impactOccurred(intensity: intensity)
    }

    /// Final success chime at wave-end (replaces the old WinView.onAppear `win()`).
    static func celebrationChime() {
        guard enabled else { return }
        notifyGen.notificationOccurred(.success)
    }
}
