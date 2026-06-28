import Foundation

enum CheckIn {
    static let rewards: [Int] = [20, 25, 30, 35, 40, 50, 100]
    static let rewindTolerance: TimeInterval = 120

    static func reward(forStreakDay day: Int) -> Int {
        let idx = ((day - 1) % 7 + 7) % 7
        return rewards[idx]
    }

    static func dayDelta(from last: Date?, to now: Date = Date()) -> Int? {
        guard let last else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: last), to: cal.startOfDay(for: now)).day ?? 0
    }

    static func canClaim(_ progress: Progress, now: Date = Date()) -> Bool {
        if isRewindSuspected(progress, now: now) { return false }
        return dayDelta(from: progress.lastCheckInDate, to: now) != 0
    }

    static func nextStreakDay(_ progress: Progress, now: Date = Date()) -> Int {
        guard let delta = dayDelta(from: progress.lastCheckInDate, to: now) else { return 1 }
        return delta == 1 ? progress.streakDays + 1 : 1
    }

    private static func isRewindSuspected(_ progress: Progress, now: Date) -> Bool {
        progress.lastKnownNow.map { now < $0.addingTimeInterval(-rewindTolerance) } ?? false
    }
}
