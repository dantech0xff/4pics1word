import SwiftUI

// TEMPORARY Phase 4 smoke harness — Phase 5 replaces with AppRootView (Home → Game → Win).
struct ContentView: View {
    @State private var state: PuzzleState?

    var body: some View {
        Group {
            if let state {
                GameView(
                    state: state,
                    levelNumber: 1,
                    totalLevels: 250
                )
            } else {
                ProgressView().task { await load() }
            }
        }
    }

    @MainActor
    private func load() async {
        let service = LevelService.load()
        guard let level = service.levels.first else { return }
        state = PuzzleState(puzzle: level, coins: Progress.startingCoins)
    }
}

#Preview {
    ContentView()
}
