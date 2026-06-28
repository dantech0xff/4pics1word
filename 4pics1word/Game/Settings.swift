import Foundation

enum AppearancePreference: String, Codable, CaseIterable {
    case light
    case dark
}

struct Settings: Codable, Equatable {
    var hapticsEnabled: Bool = true
    var appearance: AppearancePreference = .light
    var lastCheckinSheetDay: String?

    static let key = "settings.v1"

    static func load(defaults: UserDefaults = .standard) -> Settings {
        guard let data = defaults.data(forKey: key) else { return Settings() }
        return (try? JSONDecoder().decode(Settings.self, from: data)) ?? Settings()
    }

    func save(defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
