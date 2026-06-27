import SwiftUI

struct SettingsView: View {
    let model: AppModel
    @State private var showResetConfirm = false

    var body: some View {
        Form {
            Section("Sound") {
                Toggle("Sound effects", isOn: Binding(
                    get: { model.settings.soundEnabled },
                    set: { model.updateSound($0) }
                ))
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
                LabeledContent("Levels", value: "\(model.totalLevels)")
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
