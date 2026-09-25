import Foundation

/// Daily quests, modelled on the original game's check-in quests: three per calendar
/// day, ordered easy → medium → hard with rewards scaling up. The roll is
/// deterministic per (user seed, day) — each user carries a private `questSeed` in
/// Settings, so quest sets differ across users but stay stable all day for one user.
enum QuestDifficulty: String, Codable, CaseIterable {
    case easy
    case medium
    case hard
}

enum QuestKind: String, Codable, CaseIterable {
    case solvePuzzles
    case solveNoHints
    case useRevealHints
    case useRemoveHints
    case earnCoins
    case claimCheckin
}

struct DailyQuest: Codable, Hashable, Identifiable {
    var id: Int
    var kind: QuestKind
    var difficulty: QuestDifficulty
    var target: Int
    var reward: Int
    var progress: Int = 0
    var claimed: Bool = false

    var isComplete: Bool { progress >= target }
}

/// Per-day quest board persisted inside `Progress`. Regenerated when the day rolls over;
/// progress/claims of yesterday are discarded with the board.
struct DailyQuestsState: Codable, Equatable {
    var day: String
    var quests: [DailyQuest]
}

enum DailyQuests {
    struct Template: Equatable {
        let kind: QuestKind
        let target: Int
        let reward: Int
    }

    /// Rewards vs. the economy: hints cost 60/90, solve pays 25+5·tier, check-in pays 20–100.
    /// Easy ≈ half a hint, hard ≈ one remove hint; full clear pays ~one day's check-in.
    static let easyTemplates: [Template] = [
        Template(kind: .claimCheckin, target: 1, reward: 15),
        Template(kind: .solvePuzzles, target: 3, reward: 20),
        Template(kind: .useRevealHints, target: 1, reward: 15),
        Template(kind: .useRemoveHints, target: 1, reward: 20),
        Template(kind: .earnCoins, target: 60, reward: 15),
    ]

    static let mediumTemplates: [Template] = [
        Template(kind: .solvePuzzles, target: 6, reward: 35),
        Template(kind: .solveNoHints, target: 1, reward: 40),
        Template(kind: .useRevealHints, target: 3, reward: 30),
        Template(kind: .useRemoveHints, target: 2, reward: 35),
        Template(kind: .earnCoins, target: 150, reward: 35),
    ]

    static let hardTemplates: [Template] = [
        Template(kind: .solvePuzzles, target: 12, reward: 70),
        Template(kind: .solveNoHints, target: 3, reward: 80),
        Template(kind: .useRevealHints, target: 5, reward: 60),
        Template(kind: .earnCoins, target: 300, reward: 60),
    ]

    /// Roll today's board for a user. Deterministic on (seed, day): one template per
    /// difficulty bucket, no repeated kind within a board. Buckets are large enough
    /// that a valid triple always exists.
    static func roll(seed: UInt64, day: String) -> DailyQuestsState {
        var rng = SplitMix64(seed: seed &+ Self.fnv1a(day))
        var used = Set<QuestKind>()
        var quests: [DailyQuest] = []
        let buckets: [(QuestDifficulty, [Template])] = [
            (.easy, easyTemplates), (.medium, mediumTemplates), (.hard, hardTemplates),
        ]
        for (difficulty, pool) in buckets {
            let options = pool.filter { !used.contains($0.kind) }
            let pick = options[Int(rng.next() % UInt64(options.count))]
            used.insert(pick.kind)
            quests.append(DailyQuest(
                id: quests.count, kind: pick.kind, difficulty: difficulty,
                target: pick.target, reward: pick.reward))
        }
        return DailyQuestsState(day: day, quests: quests)
    }

    /// Increment every incomplete quest matching `kind` (a board never holds two of
    /// the same kind, but recording doesn't rely on that). Returns true if any quest
    /// moved — the caller persists only then.
    @discardableResult
    static func record(_ kind: QuestKind, amount: Int = 1, in state: inout DailyQuestsState) -> Bool {
        var changed = false
        for i in state.quests.indices where state.quests[i].kind == kind && !state.quests[i].isComplete {
            state.quests[i].progress = min(state.quests[i].progress + amount, state.quests[i].target)
            changed = true
        }
        return changed
    }

    /// Calendar-day key (yyyy-MM-dd, local tz) matching the check-in convention.
    static func dayKey(for date: Date = Date()) -> String {
        Self.dayFormatter.string(from: date)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    private static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return hash
    }

    /// SplitMix64: tiny, fast, well-distributed — plenty for a 3-slot daily pick.
    private struct SplitMix64: RandomNumberGenerator {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }
}

extension DailyQuest {
    var title: String {
        switch kind {
        case .solvePuzzles: return "Solve \(target) puzzles"
        case .solveNoHints: return target == 1 ? "Solve a puzzle without hints" : "Solve \(target) puzzles without hints"
        case .useRevealHints: return target == 1 ? "Use the Reveal hint" : "Use the Reveal hint \(target) times"
        case .useRemoveHints: return target == 1 ? "Use the Remove hint" : "Use the Remove hint \(target) times"
        case .earnCoins: return "Earn \(target) coins"
        case .claimCheckin: return "Claim your daily reward"
        }
    }

    var icon: String {
        switch kind {
        case .solvePuzzles: return "puzzlepiece.fill"
        case .solveNoHints: return "medal.fill"
        case .useRevealHints: return "lightbulb"
        case .useRemoveHints: return "minus.circle"
        case .earnCoins: return "dollarsign.circle.fill"
        case .claimCheckin: return "calendar.badge.checkmark"
        }
    }
}
