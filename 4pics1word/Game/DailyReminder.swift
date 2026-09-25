import Foundation
import UserNotifications

/// Daily local notification nudging the user back for their check-in reward.
/// Fires at a fixed evening hour so there's still time to claim before midnight;
/// tapping it opens the app, where the check-in sheet auto-presents on the new day.
enum DailyReminder {
    static let identifier = "checkin.dailyReminder"
    static let fireHour = 20

    /// Applies the toggle end-to-end: requests authorization when enabling,
    /// (re)schedules the daily trigger, or cancels it when disabling.
    /// Returns the effective enabled state — false when the system denies permission,
    /// so the caller can revert the setting.
    static func apply(enabled: Bool) async -> Bool {
        let center = UNUserNotificationCenter.current()
        guard enabled else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return false
        }
        let granted: Bool
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined:
            granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .authorized, .provisional, .ephemeral:
            granted = true
        default:
            granted = false
        }
        guard granted else { return false }
        await schedule(on: center)
        return true
    }

    /// Re-arms the daily trigger when the feature is on — called at launch because
    /// `add` replaces the pending request with the same identifier (idempotent).
    static func refreshIfNeeded(enabled: Bool) async {
        guard enabled else { return }
        _ = await apply(enabled: true)
    }

    private static func schedule(on center: UNUserNotificationCenter) async {
        let content = UNMutableNotificationContent()
        content.title = "Daily Reward"
        content.body = "Your daily reward is waiting — claim it before midnight and keep your streak alive."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: fireHour),
            repeats: true
        )
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
