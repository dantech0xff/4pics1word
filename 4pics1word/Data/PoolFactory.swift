import Foundation

enum PoolFactory {
    static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    static func poolSize(for solutionLength: Int) -> Int {
        max(12, solutionLength + 3)
    }

    static func makePool(for puzzle: Puzzle) -> [Character] {
        var rng = SplitMix64(seed: puzzle.id.stableSeed)
        let solution = puzzle.solutionCharacters
        let size = poolSize(for: solution.count)
        var chars: [Character] = solution
        while chars.count < size {
            chars.append(alphabet.randomElement(using: &rng)!)
        }
        chars.shuffle(using: &rng)
        return chars
    }

    static func containsSolution(_ pool: [Character], solution: [Character]) -> Bool {
        var available: [Character: Int] = [:]
        for c in pool { available[c, default: 0] += 1 }
        for c in solution {
            guard let count = available[c], count > 0 else { return false }
            available[c] = count - 1
        }
        return true
    }
}
