import SwiftUI

struct HomeView: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 24) {
            toolbar
            Spacer()
            titleBlock
            Spacer()
            playButton
            progressLabel
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .navigationBarHidden(true)
    }

    private var toolbar: some View {
        HStack {
            CoinCounter(coins: model.progress.coins)
            Spacer()
            NavigationLink(value: Route.settings) {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .padding(8)
            }
        }
        .padding(.top, 8)
    }

    private var titleBlock: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(Color.accentColor)
            Text("4 Pics 1 Word")
                .font(.largeTitle.weight(.heavy))
            Text("Find the word that links the pictures")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var playButton: some View {
        Button {
            model.continueGame()
        } label: {
            Text(model.progress.currentLevelIndex == 0 ? "Play" : "Continue")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var progressLabel: some View {
        Text("Level \(model.currentLevelNumber)")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
