import Testing
import Foundation
@testable import _pics1word

struct CheckInTests {

    // MARK: - Reward curve

    @Test
    func rewardCurveMatchesSpec() {
        #expect(CheckIn.reward(forStreakDay: 1) == 20)
        #expect(CheckIn.reward(forStreakDay: 2) == 25)
        #expect(CheckIn.reward(forStreakDay: 3) == 30)
        #expect(CheckIn.reward(forStreakDay: 4) == 35)
        #expect(CheckIn.reward(forStreakDay: 5) == 40)
        #expect(CheckIn.reward(forStreakDay: 6) == 50)
        #expect(CheckIn.reward(forStreakDay: 7) == 100)
    }

    @Test
    func rewardCurveWrapsAt7() {
        #expect(CheckIn.reward(forStreakDay: 8) == 20)
        #expect(CheckIn.reward(forStreakDay: 9) == 25)
        #expect(CheckIn.reward(forStreakDay: 14) == 100)
        #expect(CheckIn.reward(forStreakDay: 15) == 20)
        #expect(CheckIn.reward(forStreakDay: 21) == 100)
        #expect(CheckIn.reward(forStreakDay: 22) == 20)
    }

    @Test
    func rewardCurveHandlesNonPositive() {
        #expect(CheckIn.reward(forStreakDay: 0) == CheckIn.rewards.last!)
        #expect(CheckIn.reward(forStreakDay: -1) == CheckIn.rewards[CheckIn.rewards.count - 2])
    }

    // MARK: - dayDelta

    @Test
    func dayDeltaNilWhenNeverClaimed() {
        #expect(CheckIn.dayDelta(from: nil, to: Date()) == nil)
    }

    @Test
    func dayDeltaSameDayIsZero() throws {
        let cal = Calendar.current
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        let later = cal.date(bySettingHour: 23, minute: 59, second: 59, of: Date())!
        #expect(CheckIn.dayDelta(from: noon, to: later) == 0)
    }

    @Test
    func dayDeltaNextDayIsOne() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        #expect(CheckIn.dayDelta(from: today, to: tomorrow) == 1)
    }

    @Test
    func dayDeltaGapIsCounted() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let threeDaysLater = cal.date(byAdding: .day, value: 3, to: today)!
        #expect(CheckIn.dayDelta(from: today, to: threeDaysLater) == 3)
    }

    @Test
    func dayDeltaNegativeWhenNowBeforeLast() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        #expect(CheckIn.dayDelta(from: today, to: yesterday) == -1)
    }

    // MARK: - canClaim

    @Test
    func canClaimTrueWhenNeverClaimed() {
        let p = Progress()
        #expect(CheckIn.canClaim(p) == true)
    }

    @Test
    func canClaimFalseSameDay() {
        var p = Progress()
        p.lastCheckInDate = Date()
        #expect(CheckIn.canClaim(p) == false)
    }

    @Test
    func canClaimTrueNextDay() {
        var p = Progress()
        p.lastCheckInDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        #expect(CheckIn.canClaim(p) == true)
    }

    @Test
    func canClaimTrueAfterGap() {
        var p = Progress()
        p.lastCheckInDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())
        #expect(CheckIn.canClaim(p) == true)
    }

    // MARK: - Rewind guard

    @Test
    func canClaimFalseWhenRewindSuspected() {
        var p = Progress()
        p.lastKnownNow = Date().addingTimeInterval(3600)
        #expect(CheckIn.canClaim(p, now: Date()) == false)
    }

    @Test
    func canClaimTrueWhenNowSlightlyBehindLastKnownWithinTolerance() {
        var p = Progress()
        p.lastKnownNow = Date()
        let now = Date().addingTimeInterval(-30)
        #expect(CheckIn.canClaim(p, now: now) == true)
    }

    @Test
    func canClaimFalseWhenNowFarBehindLastKnown() {
        var p = Progress()
        p.lastKnownNow = Date()
        let now = Date().addingTimeInterval(-(CheckIn.rewindTolerance + 60))
        #expect(CheckIn.canClaim(p, now: now) == false)
    }

    // MARK: - nextStreakDay

    @Test
    func nextStreakDayOneWhenNeverClaimed() {
        #expect(CheckIn.nextStreakDay(Progress()) == 1)
    }

    @Test
    func nextStreakDayContinuesOnDeltaOne() {
        var p = Progress()
        p.streakDays = 3
        p.lastCheckInDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        #expect(CheckIn.nextStreakDay(p) == 4)
    }

    @Test
    func nextStreakDayResetsOnGap() {
        var p = Progress()
        p.streakDays = 5
        p.lastCheckInDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())
        #expect(CheckIn.nextStreakDay(p) == 1)
    }

    @Test
    func nextStreakDayResetsOnSameDay() {
        var p = Progress()
        p.streakDays = 5
        p.lastCheckInDate = Date()
        #expect(CheckIn.nextStreakDay(p) == 1)
    }
}
