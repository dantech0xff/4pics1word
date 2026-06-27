import Foundation

final class ProgressStore {
    private let key: String
    private let defaults: UserDefaults

    init(key: String = "progress.v1", defaults: UserDefaults = .standard) {
        self.key = key
        self.defaults = defaults
    }

    func load() -> Progress {
        guard let data = defaults.data(forKey: key) else { return Progress() }
        return (try? JSONDecoder().decode(Progress.self, from: data)) ?? Progress()
    }

    func save(_ progress: Progress) {
        if let data = try? JSONEncoder().encode(progress) {
            defaults.set(data, forKey: key)
        }
    }

    func reset() {
        defaults.removeObject(forKey: key)
    }
}
