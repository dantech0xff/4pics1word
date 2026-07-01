import Foundation

struct Puzzle: Codable, Identifiable, Hashable {
    let id: Int
    let solution: String
    let copyrights: [String]
    let time: Int
    let rating: Double
    let difficulty: String?
}

extension Puzzle {
    var solutionCharacters: [Character] {
        Array(solution.uppercased())
    }
}

struct PuzzleData: Codable {
    let time: String
    let puzzles: [Puzzle]
}

struct Strategy: Codable {
    let id: String
    let puzzleIds: [Int]
    let rateLevels: [Int]
}

extension Strategy {
    func tier(for levelIndex: Int) -> Int {
        rateLevels.filter { levelIndex >= $0 }.count
    }
}

struct Progress: Codable, Equatable {
    var currentLevelIndex: Int = 0
    var coins: Int = Progress.startingCoins
    var solvedIds: Set<Int> = []
    var lastCheckInDate: Date?
    var streakDays: Int = 0
    var lifetimeCheckIns: Int = 0
    var lastKnownNow: Date?
    var levelsCompletedSinceInterstitial: Int = 0
    var lastInterstitialAt: Date?
    var hasSeenAttPrompt: Bool = false

    static let startingCoins = 100

    private enum CodingKeys: String, CodingKey {
        case currentLevelIndex, coins, solvedIds
        case lastCheckInDate, streakDays, lifetimeCheckIns, lastKnownNow
        case levelsCompletedSinceInterstitial, lastInterstitialAt, hasSeenAttPrompt
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currentLevelIndex = try c.decodeIfPresent(Int.self, forKey: .currentLevelIndex) ?? 0
        coins = try c.decodeIfPresent(Int.self, forKey: .coins) ?? Progress.startingCoins
        solvedIds = try c.decodeIfPresent(Set<Int>.self, forKey: .solvedIds) ?? []
        lastCheckInDate = try c.decodeIfPresent(Date.self, forKey: .lastCheckInDate)
        streakDays = try c.decodeIfPresent(Int.self, forKey: .streakDays) ?? 0
        lifetimeCheckIns = try c.decodeIfPresent(Int.self, forKey: .lifetimeCheckIns) ?? 0
        lastKnownNow = try c.decodeIfPresent(Date.self, forKey: .lastKnownNow)
        levelsCompletedSinceInterstitial = try c.decodeIfPresent(Int.self, forKey: .levelsCompletedSinceInterstitial) ?? 0
        lastInterstitialAt = try c.decodeIfPresent(Date.self, forKey: .lastInterstitialAt)
        hasSeenAttPrompt = try c.decodeIfPresent(Bool.self, forKey: .hasSeenAttPrompt) ?? false
    }
}
