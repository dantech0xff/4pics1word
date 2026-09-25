import Testing
import Foundation
@testable import _pics1word

@MainActor @Suite(.serialized)
struct DailyReminderTests {

    private func cleanup(_ suite: String) {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    // MARK: - Persistence round-trip

    @Test
    func reminderEnabledPersistsAcrossLoad() {
        let suite = "reminder-persist-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { cleanup(suite) }

        var settings = Settings()
        settings.reminderEnabled = true
        settings.save(defaults: defaults)

        #expect(Settings.load(defaults: defaults).reminderEnabled == true)
    }

    // MARK: - Forward-compat: old blob (no reminderEnabled key) decodes to default

    @Test
    func oldSettingsBlobDecodesReminderToFalse() throws {
        let suite = "reminder-compat-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { cleanup(suite) }

        let legacyJSON = """
        {"hapticsEnabled":false,"appearance":"dark","lastCheckinSheetDay":"2026-09-20"}
        """.data(using: .utf8)!
        defaults.set(legacyJSON, forKey: Settings.key)

        let loaded = Settings.load(defaults: defaults)

        #expect(loaded.hapticsEnabled == false)
        #expect(loaded.appearance == .dark)
        #expect(loaded.reminderEnabled == false)
    }

    // MARK: - Toggle off persists (denial-proof path: disabling never needs permission)

    @Test
    func updateDailyReminderOffPersistsDisabled() {
        let suite = "reminder-off-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { cleanup(suite) }

        var settings = Settings()
        settings.reminderEnabled = true
        let model = AppModel(settings: settings, settingsDefaults: defaults)

        model.updateDailyReminder(false)

        #expect(model.settings.reminderEnabled == false)
        #expect(Settings.load(defaults: defaults).reminderEnabled == false)
    }
}
