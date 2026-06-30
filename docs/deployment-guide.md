# Deployment Guide — 4 Pics 1 Word

How to build, test, and (eventually) ship the app. Last updated: 2026-06-30.

## Prerequisites
- Xcode 26.6+ (requires recent toolchain for iOS 26.5 SDK).
- No `.xcworkspace` — open `4pics1word.xcodeproj` directly.
- Only scheme: `4pics1word`.

## Pick a simulator
```bash
xcrun simctl list devices available
```
Examples below assume `iPhone 16`; substitute any installed device.

## Build (simulator)
```bash
xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Run all tests (unit + UI)
```bash
xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Run a single Swift Testing unit
```bash
xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test -only-testing:4pics1wordTests/_pics1wordTests/example
```

## Test UI reset path
App honors a `-uitest-reset` launch argument — wipes `progress.v1` + `settings.v1` from `UserDefaults` before UI test runs (see `_pics1wordApp.init`).

## Code signing
- **Style:** Automatic (`CODE_SIGN_STYLE = Automatic`).
- **Team:** `CTSG43U4D8`.
- Bundle ID: `org.1588e22dda3a7db8.-pics1word`.

## What is NOT set up
- **No CI/CD pipeline.** All builds/tests run locally via `xcodebuild`.
- **No Fastlane.** No lanes for screenshots, beta, or store upload.
- **No App Store submission pipeline.** Archive + Transporter + App Store Connect are not yet wired. Shipping would require: `xcodebuild archive` → export signed IPA → upload via `altool`/Transporter/Xcode Organizer → App Store Connect metadata/screenshots.

## Asset bundling
- Puzzle images are `.webp` files at bundle root named `<puzzleId>_<1-4>.webp`. `LevelService.bundledImageIds()` scans the bundle to filter the level list to only fully-imaged puzzles — adding images requires no code change.
- `puzzles.json` + `strategy.json` decoded from bundle via `Bundle.decode`.
