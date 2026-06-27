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

    static let startingCoins = 100
}
