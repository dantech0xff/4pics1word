import SwiftUI

/// One-shot pre-prompt explainer shown before the system ATT dialog (after the first solve).
/// Value-framed copy lifts opt-in; Apple rejects misleading descriptions, so keep it honest.
/// "Continue" triggers `ATTRequester.requestIfNeeded` — AppRootView wires that closure.
struct ATTExplainerView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
            Text("Keep the Game Free")
                .font(.title.weight(.bold))
            Text("4 Pics 1 Word is free because of ads. Allowing tracking helps advertisers show you more relevant ads, which keeps the game free for everyone. Your choice is respected either way — no personal data is sold.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button {
                onContinue()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(28)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    ATTExplainerView(onContinue: {})
}
