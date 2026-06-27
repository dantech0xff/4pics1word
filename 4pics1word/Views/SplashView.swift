import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Image(.splashBackground)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.white)
                Text("4 Pics 1 Word")
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(.white)
                Text("Guess the word")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding()
            .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 24))
        }
        .accessibilityHidden(true)
    }
}
