import Foundation

final class LevelService {
    let levels: [Puzzle]
    let strategy: Strategy
    private let puzzleById: [Int: Puzzle]
    private let imageIds: Set<Int>

    init(data: PuzzleData, strategy: Strategy, imageIds: Set<Int>) {
        self.puzzleById = Dictionary(data.puzzles.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        self.strategy = strategy
        self.imageIds = imageIds
        var ordered: [Puzzle] = []
        var seen = Set<Int>()
        for pid in strategy.puzzleIds {
            guard !seen.contains(pid), let puzzle = self.puzzleById[pid] else { continue }
            seen.insert(pid)
            if imageIds.contains(pid) {
                ordered.append(puzzle)
            }
        }
        self.levels = ordered
    }

    var count: Int { levels.count }
    subscript(index: Int) -> Puzzle? {
        guard indices.contains(index) else { return nil }
        return levels[index]
    }
    var indices: Range<Int> { levels.indices }

    func puzzle(byId id: Int) -> Puzzle? { puzzleById[id] }
    func hasImages(_ id: Int) -> Bool { imageIds.contains(id) }

    static func load() -> LevelService {
        let data = Bundle.decode("puzzles", as: PuzzleData.self)
        let strategy = Bundle.decode("strategy", as: Strategy.self)
        return LevelService(data: data, strategy: strategy, imageIds: bundledImageIds())
    }

    static func bundledImageIds() -> Set<Int> {
        let urls = Bundle.main.urls(forResourcesWithExtension: "webp", subdirectory: nil) ?? []
        var ids = Set<Int>()
        for url in urls {
            let name = url.deletingPathExtension().lastPathComponent
            guard let underscore = name.lastIndex(of: "_") else { continue }
            let prefix = name[..<underscore]
            if let id = Int(prefix) { ids.insert(id) }
        }
        return ids
    }
}

extension Bundle {
    static func decode<T: Decodable>(_ name: String, as type: T.Type) -> T {
        guard let url = main.url(forResource: name, withExtension: "json") else {
            fatalError("Missing bundle resource: \(name).json")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            fatalError("Failed to decode \(name).json: \(error)")
        }
    }
}
