import SwiftUI

struct SettingsView: View {
    let model: AppModel
    @State private var showResetConfirm = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: Binding(
                    get: { model.settings.appearance },
                    set: { model.updateAppearance($0) }
                )) {
                    ForEach(AppearancePreference.allCases, id: \.self) { pref in
                        Text(pref == .light ? "Light" : "Dark").tag(pref)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Feedback") {
                Toggle("Haptic feedback", isOn: Binding(
                    get: { model.settings.hapticsEnabled },
                    set: { model.updateHaptics($0) }
                ))
            }

            Section {
                Toggle("Daily reward reminder", isOn: Binding(
                    get: { model.settings.reminderEnabled },
                    set: { model.updateDailyReminder($0) }
                ))
                .accessibilityIdentifier("DailyReminderToggle")
            } header: {
                Text("Notifications")
            } footer: {
                Text("An evening nudge so your streak doesn't reset.")
            }

            Section("Progress") {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Reset progress", systemImage: "arrow.counterclockwise")
                }
            }

            Section("About") {
                NavigationLink {
                    CreditsView(model: model)
                } label: {
                    Label("Photo credits", systemImage: "photo.stack")
                }
                LabeledContent("Version", value: "1.0")
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Reset all progress? Coins and solved levels will be lost.",
                            isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { model.resetProgress() }
            Button("Cancel", role: .cancel) {}
        }
    }
}
