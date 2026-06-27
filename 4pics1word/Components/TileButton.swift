import SwiftUI

/// Button style for letter tiles (bank tiles). Default SwiftUI ButtonStyle — no custom drawing.
struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2.weight(.heavy))
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.6) : Color.accentColor.opacity(0.9))
            )
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
    }
}
