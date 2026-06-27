import SwiftUI

/// Presented as a sheet when `model.phase == .won`.
struct WinView: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 20) {
            header
            wordReveal
            reward
            Spacer(minLength: 0)
            actions
        }
        .padding(28)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)
            Text("Solved!")
                .font(.title.weight(.bold))
        }
        .padding(.top, 8)
    }

    private var wordReveal: some View {
        VStack(spacing: 4) {
            Text("The word was")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(model.gameState?.puzzle.solution ?? "")
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(Color.accentColor)
        }
    }

    private var reward: some View {
        HStack(spacing: 16) {
            Label("+\(model.lastReward)", systemImage: "circle.fill")
                .foregroundStyle(.yellow)
            Text("Total: \(model.progress.coins)")
                .foregroundStyle(.secondary)
        }
        .font(.headline)
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 12) {
            if model.hasNextLevel {
                Button {
                    model.nextLevel()
                } label: {
                    Text("Next Level")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Text("🏆 You solved every level!")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            Button("Home") {
                model.exitToHome()
            }
            .controlSize(.large)
        }
    }
}
