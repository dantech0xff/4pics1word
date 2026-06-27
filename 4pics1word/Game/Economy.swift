import Foundation

enum HintCost {
    static let reveal: Int = 60
    static let remove: Int = 90
    static let shuffle: Int = 0
}

enum Economy {
    static let startingCoins: Int = 100

    static func reward(forTier tier: Int) -> Int {
        25 + 5 * tier
    }
}
