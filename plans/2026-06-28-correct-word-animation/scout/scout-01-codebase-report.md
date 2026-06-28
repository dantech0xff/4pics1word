# Scout Report — Correct-Word Celebration Animation

Scope: locate what changes to animate the answer letter tiles on solve, BEFORE the result bottom sheet appears.

## 1. Word answer tiles UI
**File:** `4pics1word/Components/AnswerSlots.swift` (48 lines)
- `struct AnswerSlots: View` (L4); takes `let state: PuzzleState`.
- Renders `HStack` over `state.slotTile: [Tile?]` (L9).
- `emptySlot` (L20–26): `RoundedRectangle(cornerRadius: 6)` stroke + faint fill; height 48, maxWidth 56.
- `slotTile(_:)` (L28–47): `Text(tile.character)`, `.font(.title2.weight(.heavy))`, height 48 / maxWidth 56, fill `Color.secondary.opacity(0.15)` or **`Color.green.opacity(0.18)` when `tile.locked`** (L37), green stroke when locked (L41). Tap removes non-locked tile (L44–46).
- **Backing model:** `struct Tile` in `4pics1word/Game/PuzzleState.swift` L4–10 (`id, character, slot, locked, discarded`). Derived `slotTile` L55–57. **No per-tile view-state** — style derives purely from `tile.locked`.

## 2. Selection / correctness logic
**File:** `4pics1word/Game/PuzzleState.swift`
- `isSolved` (L65): `zip(slotTile, solution).allSatisfy { $0?.character == $1 }`.
- `evaluate()` (L167–181) — **private**, called when `isFull` from `placeTile` L110 and `revealHint` L134.
  - On solve: `phase = .won` (L169) → `onSolved(self)` (L170).
  - On wrong: clears non-locked tiles, `wrongAttemptToken &+= 1` (L179).
- `onSolved` closure wired in `AppModel.startLevel` (`AppModel.swift` L46–48) → `AppModel.handleSolved` (`AppModel.swift` L54–65): applies reward, persists, **sets `phase = .won` (L64)**.

## 3. Bottom sheet presentation
**File:** `4pics1word/Views/AppRootView.swift`
- `gameLayer` (L43–56): `GameView(...)` with `.sheet(isPresented: showWin) { WinView(model:) }` (L51–54); `interactiveDismissDisabled(true)` (L53).
- `showWin` binding (L65–70): `model.phase == .won`. WinView-driven dismissal.
- `WinView` (`Views/WinView.swift`): `.presentationDetents([.medium])` (L16), `.onAppear { Feedback.win() }` (L18).
- **CRITICAL GAP:** solve is fully synchronous — `evaluate()`→`onSolved`→`handleSolved`→`phase=.won`→sheet immediately. **No window between solve and sheet.** A celebratory phase/delay must be inserted here (e.g. transitional `AppPhase.celebrating` or a `solvedToken` + `Task.sleep` before setting `.won`).

## 4. Existing animation patterns
- `.animation(.snappy, value:)` implicit — `AnswerSlots.swift:17`, `LetterBank.swift:21` (id-array Equatable value).
- `withAnimation(.easeInOut(duration:))` sequenced — shake `GameView.swift:119–122` (4-step offset, 0.05s each + delay); splash `AppRootView.swift:27`.
- `withAnimation(.spring(response: 0.42, dampingFraction: 0.78))` — zoom `GameView.swift:135`.
- `matchedGeometryEffect` + `.transition(.opacity)` — `PictureGrid.swift:47`, `ImageZoomOverlay.swift:19,30`.
- `@Environment(\.accessibilityReduceMotion) private var reduceMotion` (`GameView.swift:14`) — branched on at L132 (skip spring). **Reuse this gate.**
- Token-observer precedent: `GameView.onChange(of: state.wrongAttemptToken)` (L28–31) drives shake+haptic. **A symmetric `solvedToken` is the idiomatic hook for the new animation.**

## 5. Existing haptics
**File:** `4pics1word/Game/Feedback.swift` (23 lines) — `enum Feedback`, `static var enabled` (L7), mirrors `Settings.hapticsEnabled`.
- `tap()` L9–12 `UIImpactFeedbackGenerator(.light)`.
- `wrong()` L14–17 `UINotificationFeedbackGenerator().notificationOccurred(.error)`.
- `win()` L19–22 `UINotificationFeedbackGenerator().notificationOccurred(.success)`.
- Call sites: `LetterBank.swift:14` (tap), `GameView.swift:30` (wrong), `WinView.swift:18` (win — **only after sheet shows**). **No haptic at the solve moment itself; consider firing `win()` (or a new `Feedback.correct()`) when the tile animation starts.** No CoreHaptics / `.sensoryFeedback` anywhere.

## 6. Design tokens / styling
- **No asset-catalog color symbols referenced** despite `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS=YES`. Everything hardcoded semantic.
- Colors in use: `Color.accentColor`, `Color.green` (correct/locked), `Color.yellow` (coins), `Color.secondary.opacity(...)`, `.primary`, `.black.opacity(...)`, `Color(.systemBackground)`.
- Corner radii hardcoded by component: answer tiles **6**, bank tiles 8, pictures/hints 10.
- Shadows hardcoded: `.shadow(color: .black.opacity(0.15), radius: 1, y: 1)` (bank tile `TileButton.swift:14`), `.shadow(color: .black.opacity(0.1), radius: 2, y: 1)` (PictureGrid).
- **Tile celebration should reuse `Color.green` + `.opacity(0.18)` fill convention (the locked style at `AnswerSlots.swift:37,41`).**

## 7. MVVM / state ownership
- `@Observable final class AppModel` (`AppModel.swift:12`) — owns `phase: AppPhase` (L17), `gameState: PuzzleState?` (L18), `lastReward` (L19). Held as `@State` in `AppRootView` L10. `AppPhase` enum L4 (`home/playing/won`).
- `@Observable final class PuzzleState` (`PuzzleState.swift:23`) — owns `phase: PuzzlePhase` (L29), `wrongAttemptToken` (L32), `onSolved` closure (L35). `PuzzlePhase` enum L12 (`playing/won`).
- **Two parallel phases** (app-level + puzzle-level) both flip to `.won` at solve; AppModel's drives the sheet.
- `@MainActor` is the **default actor isolation** (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`) — these classes are implicitly MainActor; `Task.sleep` delays stay isolated. No explicit `@MainActor`/`nonisolated` annotations in scanned files.

## 8. Module-name `_` prefix gotcha
- Prefix used **only** by the app entrypoint: `struct _pics1wordApp: App` (`_pics1wordApp.swift:11`). All other 26 top-level types (`AnswerSlots`, `GameView`, `AppModel`, `PuzzleState`, `Tile`, `WinView`, `Feedback`, …) use **no** `_` prefix (confirmed via `rg "^(public )?(struct|class|enum|actor|protocol) "`). The prefix is an Xcode-creation artifact for the digit-leading target name, not a project-wide rule. New types/files (e.g. a `SolvedTileModifier` or `CelebrationOverlay`) do **not** need the prefix; only a top-level identifier matching the target name would. Tests import `@testable import _pics1word`.

## Integration notes for the goal (where to change)
1. **Hook the solve moment without blocking on the sheet:** add a transitional flag/phase. Cleanest — mirror `wrongAttemptToken`: add `private(set) var solvedToken: Int = 0` to `PuzzleState`, increment in `evaluate()` solve branch (L168) BEFORE `onSolved`; gate `onSolved`/`phase=.won` behind a completion so the animation runs first. OR add `AppPhase.celebrating` and have `GameView` run the animation then call `model.completeSolve()`.
2. **Animate tiles:** observe the token/phase in `AnswerSlots` (or wrap `slotTile` styling in a `solved` bool); apply green fill + a `withAnimation` scale/`rotationEffect`/`symbolEffect`-like pop per tile. Gate with `accessibilityReduceMotion`.
3. **Fire `Feedback.win()`** when animation starts (currently only in `WinView.onAppear`).
4. **Delay sheet:** introduce the celebratory `AppPhase` or defer `phase = .won` by animation duration (e.g. `Task { try? await Task.sleep(...); phase = .won }` on MainActor).

## Unresolved questions
- Should the celebration be a per-tile sequential reveal (staggered) or a whole-row pulse? (Affects whether stagger indices are needed — `slotTile` is positional, so `enumerated()` stagger is easy in `AnswerSlots`.)
- Should the existing green "locked" tiles be visually merged with newly-solved tiles during celebration, or distinguished? (Currently locked tiles are already green pre-solve.)
