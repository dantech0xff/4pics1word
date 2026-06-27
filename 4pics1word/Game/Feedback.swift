import UIKit

/// Lightweight haptic feedback. No audio assets bundled, so we ship haptics only
/// (system sounds use undocumented IDs that change across iOS releases — not worth the risk).
/// `enabled` mirrors `Settings.hapticsEnabled` and is checked on every call.
enum Feedback {
    static var enabled: Bool = true

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
}
