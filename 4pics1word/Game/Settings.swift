import Foundation

enum AppearancePreference: String, Codable, CaseIterable {
    case light
    case dark
}

struct Settings: Codable, Equatable {
    var hapticsEnabled: Bool = true
    var appearance: AppearancePreference = .light
    var lastCheckinSheetDay: String?
    var reminderEnabled: Bool = false

    static let key = "settings.v1"

    private enum CodingKeys: String, CodingKey {
        case hapticsEnabled, appearance, lastCheckinSheetDay, reminderEnabled
    }

    init() {}

    /// decodeIfPresent everywhere so older blobs missing newer keys still decode.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        appearance = try c.decodeIfPresent(AppearancePreference.self, forKey: .appearance) ?? .light
        lastCheckinSheetDay = try c.decodeIfPresent(String.self, forKey: .lastCheckinSheetDay)
        reminderEnabled = try c.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? false
    }

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
