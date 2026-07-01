# Phase 01 — Project Config: SPM, Info.plist, PrivacyInfo

## Context links
- Parent plan: `../plan.md`
- Dependency: none (first phase — gates compilation of all later phases).
- Brainstorm: `../../docs/brainstorm/2026-07-02-admob-integration.md` §"Brutal honesty" items 1, 4, 5.
- Source: `4pics1word.xcodeproj/project.pbxproj`, app target Info.plist.

## Overview
- Date: 2026-07-02
- Description: Add `GoogleMobileAds` SPM package (app target only), Info.plist keys (`GADApplicationIdentifier`, `NSUserTrackingUsageDescription`, `SKAdNetworkItems`), and `PrivacyInfo.xcprivacy`. End state: project still builds (SDK imported, no callers yet).
- Priority: P1
- Implementation status: pending
- Review status: pending

## Key Insights
- **App target only.** Adding the package to test targets leaks the SDK into unit tests, defeating the mock seam. `4pics1wordTests/` and `4pics1wordUITests/` MUST stay SDK-free.
- **Hand-edit `project.pbxproj` ONLY for:** (a) SPM package reference, (b) package product link to app target, (c) Info.plist keys (or `INFOPLIST_KEY_*` build settings). **NOT for source-file registration** — file-synchronized groups auto-register new `.swift` files (`AGENTS.md` gotcha #2).
- **⚠️ TEST IDs ONLY (2026-07-02 revision).** No AdMob account yet. Use Google's official sample App ID `ca-app-pub-3940256099942544~1458002511` in `Info.plist`. Test ad-unit IDs flow through `AdsConfiguration` (Phase 03). **This config cannot ship to App Store** — Apple rejects test ads; AdMob pays $0. Submission deferred until a real account + IDs are registered. Swap is config-only when that happens.
- **`NSUserTrackingUsageDescription`** — required or ATT prompt crashes. Copy must explain value ("Help keep the game free…").
- **SKAdNetworkItems** — Google publishes the current list at `developers.google.com/admob/ios/quick-start`. Refresh yearly. Each entry: `<key>SKAdNetworkIdentifier</key><string>cstr6suwn9.skadnetwork</string>` (+ ~40 others).
- **PrivacyInfo.xcprivacy** — Google ships a reference manifest in the SDK; copy their published version. Project itself collects nothing, so no app-specific tracking declarations.
- **Linker flags** — GoogleMobileAds requires `-ObjC` linker flag; modern SPM integration usually auto-adds, but verify build settings.

## Requirements
1. `GoogleMobileAds` SPM package (latest v11+) linked to `4pics1word` app target only.
2. `Info.plist` contains: `GADApplicationIdentifier` = Google's sample App ID, `NSUserTrackingUsageDescription`, `SKAdNetworkItems` array, `UIViewControllerBasedStatusBarAppearance` (if not present).
3. `PrivacyInfo.xcprivacy` added to app bundle.
4. `-ObjC` present in `OTHER_LDFLAGS` (app target).
5. Both Debug + Release build configurations remain green.
6. No source files in test targets reference the SDK.

## Architecture

### Step 1 — Use Google's sample App ID (no AdMob account)
No AdMob account registration needed. Use Google's documented sample App ID everywhere:
- App ID: `ca-app-pub-3940256099942544~1458002511`
- Test ad-unit IDs (used by `AdsConfiguration` in Phase 03):
  - Banner: `ca-app-pub-3940256099942544/2934735716`
  - Interstitial: `ca-app-pub-3940256099942544/4411468910`
  - Rewarded: `ca-app-pub-3940256099942544/1712485313`

> ⚠️ **Cannot ship to App Store with these.** Apple rejects test ads; revenue = $0. When a real AdMob account is registered, swap `GADApplicationIdentifier` (Info.plist) + `AdsConfiguration` IDs only — no architecture change.

### Step 2 — Add SPM package
In Xcode → project → Package Dependencies → `+`:
- URL: `https://github.com/googleads/swift-package-manager-tags`
- Version: exact `11.x.x` (latest stable at implementation time).
- Add Product `GoogleMobileAds` → target **`4pics1word`** ONLY. Do NOT select test targets.

### Step 3 — Info.plist
Project uses `INFOPLIST_KEY_*` build settings OR an explicit `Info.plist` file — inspect `project.pbxproj` to confirm which. Add keys accordingly:
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string>   <!-- Google's sample App ID; replace before shipping -->
<key>NSUserTrackingUsageDescription</key>
<string>Your data is used to show more relevant ads that keep this game free. No personal data leaves your device beyond what's needed for ads.</string>
<key>SKAdNetworkItems</key>
<array>
  <dict><key>SKAdNetworkIdentifier</key><string>cstr6suwn9.skadnetwork</string></dict>
  <!-- + Google's full published list (~40 entries) -->
</array>
```

### Step 4 — PrivacyInfo.xcprivacy
Copy Google's reference manifest for GoogleMobileAds v11. Place at `4pics1word/PrivacyInfo.xcprivacy`. File-synchronized group will auto-register.

### Step 5 — Verify build
```bash
xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```
Both must remain green (no callers yet, so test count = 89 unchanged).

## Implementation Steps
1. Use Google's sample App ID + 3 test ad-unit IDs (from Step 1 — no account needed).
2. In Xcode, add SPM package, link `GoogleMobileAds` to app target only.
3. Add Info.plist keys (use `INFOPLIST_KEY_` style if that's the project convention; check pbxproj).
4. Drop in `PrivacyInfo.xcprivacy`.
5. Verify `-ObjC` in `OTHER_LDFLAGS`.
6. Run build (Debug).
7. Run full test suite — expect 89/89 unchanged.
8. Commit placeholder: `feat(ads): wire GoogleMobileAds SDK + Info.plist keys (test IDs) [phase-01]`.

## todo list
- [ ] Use Google sample App ID + test ad-unit IDs (no AdMob account)
- [ ] Add SPM package, link app target only
- [ ] Add `GADApplicationIdentifier` = sample App ID to Info.plist
- [ ] Add `NSUserTrackingUsageDescription`
- [ ] Add `SKAdNetworkItems` array (Google's published list)
- [ ] Add `PrivacyInfo.xcprivacy`
- [ ] Verify `-ObjC` linker flag
- [ ] Build green (Debug + Release)
- [ ] Test suite 89/89 green
- [ ] Commit

## Success Criteria
- `import GoogleMobileAds` compiles in app target without test-target contamination.
- Build green in both configurations.
- All 89 tests pass unchanged.
- `PrivacyInfo.xcprivacy` present in bundle (verify in built `.app`).

## Risk Assessment
| Risk | Mitigation |
|---|---|
| AdMob account not yet registered | Phase blocked; flag to stakeholder. Can stub App ID with Google's official sample (`ca-app-pub-3940256099942544~1458002511`) under DEBUG only. |
| SKAdNetwork list goes stale | Add a yearly review reminder in `docs/brainstorm/2026-07-02-admob-integration.md` open Q2. |
| `INFOPLIST_KEY_` vs explicit file mismatch | Inspect existing pbxproj; mirror existing style. |
| Package resolution adds to test targets by accident | Xcode checkboxes — manually deselect both test targets. |
| Linker errors (missing `-ObjC`, duplicate symbols) | Add `-ObjC` to `OTHER_LDFLAGS`; if duplicate symbols, the SDK's modulemap is buggy — pin a different v11 patch. |
| Build time regression | Acceptable per brainstorm §1. Note before/after clean-build time in commit message. |

## Security Considerations
- Real `GADApplicationIdentifier` is a public, non-secret value. Safe to commit.
- Real ad-unit IDs are also public — no secrets in code.
- ATT description copy is user-facing — keep honest, no dark patterns (Apple rejects misleading copy).

## Next steps
→ Phase 02 (Progress + Settings schema).
