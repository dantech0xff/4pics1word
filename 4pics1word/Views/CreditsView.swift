import SwiftUI

/// Stock-photo attributions for all bundled levels (legal requirement).
struct CreditsView: View {
    let model: AppModel

    var body: some View {
        List(model.allCredits, id: \.self) { credit in
            Text(credit).font(.footnote)
        }
        .navigationTitle("Photo Credits")
        .navigationBarTitleDisplayMode(.inline)
    }
}
