import Foundation
import GameKit
import UIKit

/// Game Center integration: authenticates the local player, submits "levels solved"
/// scores to the leaderboard, and opens the dashboard via `GKAccessPoint`
/// (the iOS 26 replacement for presenting `GKGameCenterViewController`).
/// Entirely best-effort — every entry point no-ops when the player isn't signed in,
/// so gameplay never depends on Game Center availability.
@MainActor
enum GameCenter {
    /// Leaderboard ID — must exist in App Store Connect (App > Game Center > Leaderboards)
    /// or score submissions are silently dropped. Classic "Levels Solved" board.
    static let leaderboardID = "org.1588e22dda3a7db8.-pics1word.levelsSolved"

    static var isAuthenticated: Bool { GKLocalPlayer.local.isAuthenticated }

    /// Kicks off authentication at launch. GameKit invokes the handler with a sign-in
    /// view controller when credentials are needed, which we present on the key window.
    /// When the player is already signed in the handler fires once with a banner.
    static func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { viewController, _ in
            if let viewController {
                present(viewController)
            }
        }
    }

    /// Submits the solved-count as the leaderboard score. Fire-and-forget: offline or
    /// GameCenterRestricted players just skip — scores re-sync on the next submission.
    static func submitScore(_ levelsSolved: Int) {
        guard GKLocalPlayer.local.isAuthenticated, levelsSolved > 0 else { return }
        GKLeaderboard.submitScore(
            levelsSolved,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [leaderboardID]
        ) { _ in }
    }

    /// Opens the Game Center dashboard straight onto the leaderboard —
    /// as if the user tapped the access point widget. Re-runs authentication
    /// first when needed so an unsigned player gets the sign-in sheet.
    static func showLeaderboard() {
        if !GKLocalPlayer.local.isAuthenticated {
            authenticate()
        }
        GKAccessPoint.shared.trigger(
            leaderboardID: leaderboardID,
            playerScope: .global,
            timeScope: .allTime
        ) {}
    }

    private static func present(_ viewController: UIViewController) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        top?.present(viewController, animated: true)
    }
}
