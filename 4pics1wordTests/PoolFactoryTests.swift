import Testing
import Foundation
@testable import _pics1word

@MainActor @Suite(.serialized)
struct PoolFactoryTests {
    @Test
    func poolSizeMatchesSpec() {
        #expect(PoolFactory.poolSize(for: 3) == 12)
        #expect(PoolFactory.poolSize(for: 5) == 12)
        #expect(PoolFactory.poolSize(for: 9) == 12)
        #expect(PoolFactory.poolSize(for: 10) == 13)
    }

    @Test
    func poolContainsSolutionMultiset() {
        let puzzle = Puzzle(id: 477, solution: "MOUSE", copyrights: [], time: 3, rating: 0.9, difficulty: nil)
        let pool = PoolFactory.makePool(for: puzzle)
        #expect(pool.count == 12)
        #expect(PoolFactory.containsSolution(pool, solution: puzzle.solutionCharacters))
    }

    @Test
    func poolHandlesDuplicateLetters() {
        // "BOOK" needs two O tiles
        let puzzle = Puzzle(id: 1, solution: "BOOK", copyrights: [], time: 1, rating: 1.0, difficulty: nil)
        let pool = PoolFactory.makePool(for: puzzle)
        let oCount = pool.filter { $0 == "O" }.count
        #expect(oCount >= 2, "Pool must contain at least 2 O tiles for BOOK, got \(oCount)")
        #expect(PoolFactory.containsSolution(pool, solution: puzzle.solutionCharacters))
    }

    @Test
    func poolIsDeterministicPerId() {
        let puzzle = Puzzle(id: 931816090, solution: "ICE", copyrights: [], time: 4, rating: 0.81, difficulty: nil)
        let pool1 = PoolFactory.makePool(for: puzzle)
        let pool2 = PoolFactory.makePool(for: puzzle)
        #expect(pool1 == pool2, "Same puzzle id must produce identical pool order (I4)")
    }

    @Test
    func differentIdsProduceDifferentPools() {
        let a = Puzzle(id: 1, solution: "ICE", copyrights: [], time: 1, rating: 1.0, difficulty: nil)
        let b = Puzzle(id: 2, solution: "ICE", copyrights: [], time: 1, rating: 1.0, difficulty: nil)
        #expect(PoolFactory.makePool(for: a) != PoolFactory.makePool(for: b))
    }
}

@MainActor @Suite(.serialized)
struct LevelServiceTests {
    @Test
    func loadsBundledLevels() throws {
        let service = LevelService.load()
        #expect(service.count == 250, "Expected 250 image-backed levels, got \(service.count)")
        #expect(service.indices == 0..<250)
    }

    @Test
    func firstLevelIsStrategyHead() throws {
        let service = LevelService.load()
        let first = try #require(service.levels.first)
        // strategy.json head is puzzle id 477 (MOUSE)
        #expect(first.id == 477)
        #expect(first.solution == "MOUSE")
    }

    @Test
    func everyLevelHasFourImagesBundled() throws {
        let service = LevelService.load()
        for puzzle in service.levels {
            for index in 1...4 {
                let name = "\(puzzle.id)_\(index)"
                let url = Bundle.main.url(forResource: name, withExtension: "webp")
                #expect(url != nil, "Missing image \(name).webp for puzzle \(puzzle.id)")
            }
        }
    }

    @Test
    func everyGeneratedPoolIsSolvable() throws {
        let service = LevelService.load()
        for puzzle in service.levels.prefix(50) {
            let pool = PoolFactory.makePool(for: puzzle)
            #expect(PoolFactory.containsSolution(pool, solution: puzzle.solutionCharacters),
                   "Level \(puzzle.id) (\(puzzle.solution)) pool is unsolvable")
            #expect(pool.count == PoolFactory.poolSize(for: puzzle.solution.count))
        }
    }

    @Test
    func tierCalculationMatchesRateLevels() {
        let strategy = Strategy(id: "test", puzzleIds: [], rateLevels: [27, 47, 67])
        #expect(strategy.tier(for: 0) == 0)
        #expect(strategy.tier(for: 26) == 0)
        #expect(strategy.tier(for: 27) == 1)
        #expect(strategy.tier(for: 46) == 1)
        #expect(strategy.tier(for: 47) == 2)
        #expect(strategy.tier(for: 67) == 3)
        #expect(strategy.tier(for: 100) == 3)
    }
}
