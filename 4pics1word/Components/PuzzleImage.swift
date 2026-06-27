import SwiftUI
import UIKit

/// Loads a bundled webp image for a puzzle (file naming: `<puzzleId>_<1-4>.webp`).
/// WebP is decoded natively on iOS 14+; we bypass the Asset Catalog (which prefers PNG/PDF)
/// and load straight from the bundle root, where synchronized groups flatten resources.
struct PuzzleImage: View {
    let puzzleId: Int
    let index: Int

    var body: some View {
        Group {
            if let image = Self.load(puzzleId: puzzleId, index: index) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(Color.secondary.opacity(0.15))
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private static let cache = NSCache<NSNumber, UIImage>()

    static func load(puzzleId: Int, index: Int) -> UIImage? {
        let key = NSNumber(value: puzzleId * 10 + index)
        if let cached = cache.object(forKey: key) { return cached }
        guard let url = Bundle.main.url(forResource: "\(puzzleId)_\(index)", withExtension: "webp"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
