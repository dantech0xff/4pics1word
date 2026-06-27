# AGENTS.md

iOS SwiftUI app — single-target "4 pics 1 word" game. Fresh Xcode template (Xcode 26.6); no SPM packages, no Fastlane, no CI, no README yet.

## Build / test

No `.xcworkspace`. Use the project directly; the only scheme is `4pics1word`.

```bash
# Build (simulator)
xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Unit + UI tests
xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word \
  -destination 'platform=iOS Simulator,name=iPhone 16' test

# Single Swift Testing test
xcodebuild ... test -only-testing:4pics1wordTests/_pics1wordTests/example
```

Pick an installed simulator via `xcrun simctl list devices available`. Deployment target is iOS 26.5 — requires a recent Xcode toolchain.

## Non-obvious gotchas

- **Module name is `_pics1word`, not `4pics1word`.** Swift identifiers can't start with a digit, so Xcode prefixes source files with `_` and the import is `@testable import _pics1word`. Keep this prefix when naming new top-level Swift types/files in the app target.
- **File-system synchronized groups are on.** The three source folders (`4pics1word/`, `4pics1wordTests/`, `4pics1wordUITests/`) are `PBXFileSystemSynchronizedRootGroup`s — any `.swift` file added to these directories is automatically part of the target. **Do not hand-edit `project.pbxproj` to register new files.**
- **Unit tests use Swift Testing, not XCTest.** `4pics1wordTests/` uses `import Testing` with `struct` + `@Test func`. UI tests (`4pics1wordUITests/`) use `XCTestCase`. Don't mix the styles per target.
- **Default actor isolation is `MainActor`** (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`) with `SWIFT_APPROACHABLE_CONCURRENCY = YES`. New code is `@MainActor`-isolated by default; mark types `nonisolated` explicitly when needed instead of fighting the compiler.
- **Asset catalog generates Swift symbol extensions** (`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES`). Reference colors/images via the generated symbols (e.g. `AssetCatalog`-derived) rather than string names where possible.

## Targets

| Target | Bundle ID | Type |
|---|---|---|
| `4pics1word` | `org.1588e22dda3a7db8.-pics1word` | App (iPhone + iPad) |
| `4pics1wordTests` | `…Tests` | Unit tests (Swift Testing), host = app |
| `4pics1wordUITests` | `…UITests` | UI tests (XCTest), target = app |

App entrypoint: `4pics1word/_pics1wordApp.swift` (`@main`). Code signing is Automatic with team `CTSG43U4D8`.
