# Code Standards — 4 Pics 1 Word

Conventions and gotchas every contributor must follow. Last updated: 2026-06-30.

## Module name (critical)
- Module/import is **`_pics1word`**, not `4pics1word`. Swift identifiers cannot start with a digit.
- App entrypoint file is `_pics1wordApp.swift`; tests use `@testable import _pics1word`.
- Keep the `_` prefix when naming new top-level Swift types/files in the app target.

## Project structure
- **File-system synchronized groups are ON.** `4pics1word/`, `4pics1wordTests/`, `4pics1wordUITests/` are `PBXFileSystemSynchronizedRootGroup`s — any `.swift` file dropped into these dirs is auto-registered to the target.
- **Do NOT hand-edit `project.pbxproj` to register new files.** Only edit it for build settings changes.

## Actor isolation & concurrency
- **Default actor isolation is `MainActor`** (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
- `SWIFT_APPROACHABLE_CONCURRENCY = YES`.
- New code is `@MainActor`-isolated by default — mark types/functions `nonisolated` explicitly when needed; do not fight the compiler.
- Long-running work uses `Task { @MainActor in ... }` with `try? await Task.sleep(...)` and explicit `Task.isCancelled` checks.

## Testing styles (per target — do not mix)
- **Unit (`4pics1wordTests/`):** Swift Testing — `import Testing`, `struct _pics1wordTests { @Test func ...() }`.
- **UI (`4pics1wordUITests/`):** `XCTestCase` — `func test...() throws { ... }` with `app.launch()`.

## State management
- Use `@Observable final class` (Observation framework) for model objects — `AppModel`, `PuzzleState`.
- Views hold model as `@State` (ownership) or plain `let` (passed down); never `@ObservedObject`/`@Published`.
- Single mutation gate per model (e.g. `PuzzleState.canMutate`) — guard all mutating fns.

## Asset references
- `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES`.
- Reference colors/images via generated symbols: `Image(.splashBackground)` not `Image("splashBackground")`.
- Puzzle `.webp` images are **not** in the asset catalog — loaded from bundle root by `PuzzleImage` (`<puzzleId>_<1-4>.webp`).

## Commits
Conventional Commits, scope = subsystem:
- `feat(ui): ...`, `feat(game): ...`
- `test(ui): ...`, `test(game): ...`
- `docs(plan): ...` for plan/research/scout docs.
Each feature lands as `feat` + companion `test`; plans precede with `docs(plan)`.

## File organization
| Folder | Contents |
|---|---|
| `4pics1word/Views/` | Screens (`AppRootView`, `HomeView`, `GameView`, `CheckInView`, `WinView`, `SplashView`, `SettingsView`, `CreditsView`). |
| `4pics1word/Components/` | Reusable SwiftUI views (`LetterBank`, `PictureGrid`, `TileButton`, etc.). |
| `4pics1word/Game/` | Domain logic (`AppModel`, `PuzzleState`, `CheckIn`, `Economy`, `Feedback`, `Settings`). |
| `4pics1word/Data/` | Persistence + loading (`LevelService`, `Models`, `ProgressStore`, `PoolFactory`, `SplitMix64`). |

See [codebase-summary.md](./codebase-summary.md) for per-file detail.
