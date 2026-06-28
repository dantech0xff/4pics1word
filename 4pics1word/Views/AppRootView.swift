import SwiftUI

enum Route: Hashable {
    case settings
    case credits
}

/// Root navigation shell: splash → Home (NavigationStack) → Game (fullScreenCover) → Win (sheet).
struct AppRootView: View {
    @State private var model = AppModel()
    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                SplashView()
            } else {
                navigationStack
                    .fullScreenCover(isPresented: showGame) {
                        gameLayer
                    }
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
        }
    }

    private var navigationStack: some View {
        NavigationStack {
            HomeView(model: model)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .settings: SettingsView(model: model)
                    case .credits: CreditsView(model: model)
                    }
                }
        }
    }

    @ViewBuilder
    private var gameLayer: some View {
        if let state = model.gameState {
            GameView(
                state: state,
                levelNumber: model.currentLevelNumber,
                onExit: { model.exitToHome() }
            )
            .sheet(isPresented: showWin) {
                WinView(model: model)
                    .interactiveDismissDisabled(true)
            }
        }
    }

    private var showGame: Binding<Bool> {
        Binding(
            get: { model.phase == .playing || model.phase == .won },
            set: { if !$0 { model.exitToHome() } }
        )
    }

    private var showWin: Binding<Bool> {
        Binding(
            get: { model.phase == .won },
            set: { _ in }  // WinView drives dismissal via Next/Home
        )
    }
}
