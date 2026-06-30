# Project Overview & PDR — 4 Pics 1 Word

What the app is and the product requirements it must satisfy. Last updated: 2026-06-30.

## Product
Single-player iOS word game. Four pictures share one word; player arranges scrambled letters into answer slots to solve. Coins earned per solve + daily check-in; coins spent on hints.

## Targets
- **App:** `4pics1word` — single Xcode target, no SPM packages, no extensions.
- **Bundle ID:** `org.1588e22dda3a7db8.-pics1word` (iPhone + iPad).
- **Unit tests:** `4pics1wordTests` (Swift Testing, host = app).
- **UI tests:** `4pics1wordUITests` (XCTest, target = app).

## Tech stack
- **Language/UI:** Swift, SwiftUI (declarative, no UIKit view code beyond `UIImage` loading).
- **Toolchain:** Xcode 26.6.
- **Deployment target:** iOS 26.5+.
- **State:** Swift `@Observable` (Observation framework), no Combine.
- **Persistence:** `UserDefaults` (JSON-encoded `Progress` / `Settings`).
- **Assets:** Bundled `.webp` puzzle images loaded from bundle root; SF Symbols for iconography.
- **Code signing:** Automatic, team `CTSG43U4D8`.

## Non-goals (not present)
- No Swift Package Manager dependencies.
- No Fastlane, no CI/CD pipeline.
- No backend / network calls (fully offline).
- No README in repo root.

## Functional requirements (PDR)
- **F1 Gameplay:** 4 pictures → 1 word; scrambled letter bank; tap to fill slots; auto-validate on full board.
- **F2 Hints:** Reveal (60c, lock one correct letter), Remove (90c, discard unneeded bank tiles), Shuffle (free, cosmetic).
- **F3 Progression:** Linear level order; seamless wrap-around after final level (total count hidden).
- **F4 Economy:** Coins persisted; tier-based solve rewards (`25 + 5*tier`); daily check-in streak rewards `[20,25,30,35,40,50,100]`.
- **F5 Daily check-in:** One claim/calendar-day; 7-day rolling streak; jackpot on day 7; clock-rewind protection (120s tolerance).
- **F6 Persistence:** Coins, solved IDs, streak, settings survive app restart; explicit reset in Settings.
- **F7 Accessibility:** Reduce-motion, reduce-transparency, Dynamic-Type (capped at `.accessibility2`) gates throughout.

## Non-functional requirements
- **N1 Performance:** Image cache (`NSCache`); animation drivers cancel on dismiss/replace.
- **N2 Reliability:** Reward/persist/advance synchronous on solve (no progress loss on interrupt).
- **N3 Determinism:** Seeded RNG (`SplitMix64` keyed off `puzzle.id`) → same decoy pool per puzzle.

## Entry point
`4pics1word/_pics1wordApp.swift` → `AppRootView`. See [system-architecture.md](./system-architecture.md).
