# Phase 04 — Claim Animation (Spring + Coin Fly)

## Context links
- Plan: [../plan.md](../plan.md)
- Research: [../research/researcher-02-report.md](../research/researcher-02-report.md) (§7)
- Prev: [phase-03-cell-state-polish.md](./phase-03-cell-state-polish.md)
- Source: `4pics1word/Views/CheckInView.swift:53-99` (header coin counter), `158-178` (claimTapped), `355-369` (scale/stateOpacity)
- Next: [phase-05-tests-a11y-verify.md](./phase-05-tests-a11y-verify.md)

## Overview
- **Date:** 2026-06-29
- **Description:** Spring scale on today-cell tap + coin fly-to-wallet via `matchedGeometryEffect` to header coin counter. Reduce-motion → instant crossfade.
- **Priority:** P2
- **Implementation status:** pending
- **Review status:** pending

## Key insights
- **Highest-ROI micro-interaction** (researcher-02 §7): coin fly-to-wallet = "ok → satisfying". Single most satisfying F2P dopamine anchor.
- **Anchor = header coin counter** (`displayedCoins`, CheckInView.swift:77-82) — same view, simple `@Namespace`. Cross-view Home-HUD fly = out of scope (YAGNI; needs `@Namespace` across sheet boundary, complex).
- **Spring tap (researcher-02 §7):** `.spring(response: 0.3, dampingFraction: 0.6)` on today cell — feels native.
- **Reduce-motion:** replace fly+spring w/ instant crossfade (existing `numericText` content transition already does counter). No confetti when reduce-motion (already gated).
- **Skip (researcher-02 §7):** per-cell particle bursts (noise), 3D flip (gimmicky), haptic-only feedback (always pair w/ visual).
- Current code already has: `pulse` spring scale (1.05), `numericText` counter transition, confetti. Phase 04 **adds** the fly particle + tighter spring; keeps existing pieces.

## Requirements
### Functional
- F1: Tap claim → today cell spring-scales (1.0 → 1.08 → 1.0, response 0.3 damping 0.6).
- F2: Coin icon spawns from today cell, flies along arc to header coin counter, fades on arrival.
- F3: Header counter increments via existing `numericText` transition synced to fly arrival (~0.4s).
- F4: Reduce-motion: no fly, no spring overshoot; counter crossfades instantly (existing path).
- F5: Confetti fires on **Day-7 jackpot claim only** (validated). Everyday claims: coin-fly + haptic only, no confetti. Gate via `if isJackpot { celebrate = true }`.

### Non-functional
- NF1: `matchedGeometryEffect` scoped to single `@Namespace` in `CheckInView` (not propagated across views).
- NF2: Fly animation ~0.4–0.6s; no blocking of dismissal gate (close enables immediately post-claim).
- NF3: No new haptics (existing `Feedback.tap()` + `Feedback.reward()` sequence kept).

## Architecture
Add `@Namespace` to `CheckInView`. Coin fly = transient overlay particle (NOT full matchedGeometry of the cell — simpler). Two viable approaches:

**Approach A (recommended, KISS): Transient coin overlay**
- On claim, spawn 1 coin `Image` at today-cell frame; animate position+opacity to header-counter frame via `withAnimation(.spring)`. Use `GeometryReader`/`anchorPreference` to read frames. No `matchedGeometryEffect` complexity.
- Pros: isolated, debuggable, no namespace conflicts w/ grid.
- Cons: manual frame math.

**Approach B: `matchedGeometryEffect`**
- Coin in today cell + coin in header share `matchedGeometryEffect(id:"flyingCoin", in: ns)`. Toggle a `@State flying` to morph.
- Pros: declarative.
- Cons: matchedGeometry between two persistent views fights when both render; finicky w/ overlays.

**Default: Approach A** (transient overlay). Revisit if frame-read proves flaky.

```swift
// CheckInView — add state
@Namespace private var flyNamespace   // optional, if Approach B
@State private var flyingCoin: FlyingCoin?   // Approach A: frame-based

struct FlyingCoin: Identifiable {
    let id = UUID()
    var fromFrame: CGRect   // today cell anchor
    var toFrame: CGRect     // header counter anchor
}

// claimTapped — extend existing
private func claimTapped(previewedReward: Int) {
    guard model.checkIn() != nil else { return }
    Feedback.tap()
    if reduceMotion {
        displayedCoins = model.progress.coins
        pulse = true
    } else {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { pulse = true }
        spawnFlyingCoin()                          // NEW
        withAnimation(.easeOut(duration: 0.8)) { displayedCoins = model.progress.coins }
        celebrate = true
        celebTask?.cancel()
        celebTask = Task { /* existing reward haptic + celebrate window */ }
    }
}

// Overlay on body: flying coin renders above grid, animates from→to, removes on completion.
```

Frame reading: use `.anchorPreference` or `GeometryReader { proxy in ... }` keyed to today cell + header. Avoid `UIScreen.main.bounds` (multi-scene unsafe).

## Related code files
- **Modify:** `4pics1word/Views/CheckInView.swift:10-13` — add `@Namespace` + `@State private var flyingCoin`.
- **Modify:** `4pics1word/Views/CheckInView.swift:53-69` — `body`: add `.overlay(flyingCoinOverlay)` for transient coin.
- **Modify:** `4pics1word/Views/CheckInView.swift:71-99` — `header`: tag coin counter w/ geometry anchor (preference key).
- **Modify:** `4pics1word/Views/CheckInView.swift:158-178` — `claimTapped`: add `spawnFlyingCoin()`; tighten spring to `(response:0.3, dampingFraction:0.6)`.
- **Modify:** `4pics1word/Views/CheckInView.swift:217-237` — `DayTile.body`: tag today cell w/ geometry anchor; bump scale 1.05 → 1.08 on pulse.
- **Create:** `FlyingCoin` struct + `CoinFramePreferenceKey` (PreferenceKey) + `flyingCoinOverlay` View.
- **No change:** `CheckIn.swift`, `AppModel.swift`, `Feedback.swift`, `AppRootView.swift`.

## Implementation steps
1. Define `CoinFramePreferenceKey: PreferenceKey` (today cell frame + header counter frame).
2. Add `@State private var flyingCoin: FlyingCoin?` + `FlyingCoin` struct to `CheckInView`.
3. Tag header coin counter (CheckInView.swift:78) w/ `.anchorPreference(...)` emitting to key.
4. Tag today-cell content (CheckInView.swift DayTile body) w/ `.anchorPreference(...)` — only when `state == .today`.
5. Read preferences at body level via `.onPreferenceChange`; store frames in `@State`.
6. Write `spawnFlyingCoin()` — populate `flyingCoin` from current frames; schedule `Task` to clear after ~0.6s.
7. Add `flyingCoinOverlay` — `Image(systemName:"bitcoinsign.circle.fill")` positioned via `GeometryReader`, animate `.offset` + `.opacity` from→to w/ `.spring`. Remove on arrival.
8. In `claimTapped`: call `spawnFlyingCoin()` after `model.checkIn()`; tighten pulse spring to `(response:0.3, dampingFraction:0.6)`; bump today scale to 1.08. **Gate confetti:** `if todayIsJackpot { celebrate = true }` (D7-only, validated).
9. Verify reduce-motion branch untouched (no fly, instant counter).
10. Build iPhone 16 sim; manual claim — confirm fly arc + counter sync + spring. Verify D1 claim = NO confetti, D7 claim = confetti.
11. Verify dismissal gate enables immediately post-claim (not blocked by animation).

## Todo
- [ ] `CoinFramePreferenceKey` PreferenceKey
- [ ] `FlyingCoin` struct + `@State` in CheckInView
- [ ] `.anchorPreference` on header coin counter
- [ ] `.anchorPreference` on today cell (today-only)
- [ ] `.onPreferenceChange` frame capture
- [ ] `spawnFlyingCoin()` + clear Task
- [ ] `flyingCoinOverlay` (transient coin, spring offset/opacity)
- [ ] Tighten pulse spring (0.3/0.6); scale 1.05 → 1.08
- [ ] Verify reduce-motion branch (no fly)
- [ ] Build green; manual claim visual check
- [ ] Confirm close-gate enables immediately post-claim

## Success criteria
- Tap claim → today cell springs (1.08 overshoot) + coin flies arc to header counter.
- Header counter increments (numericText) synced to fly arrival (~0.4s).
- Reduce-motion: instant counter crossfade, no fly, no spring overshoot.
- Confetti fires on Day-7 jackpot claim only (non-reduce-motion); everyday claims = fly + haptic only.
- Close button enables immediately post-claim (animation non-blocking).
- No `matchedGeometryEffect` namespace conflicts; no frame-reading via `UIScreen.main`.

## Risk assessment
| Risk | Likelihood | Mitigation |
|---|---|---|
| `anchorPreference` frame math flaky across detent resize | Med | Approach A isolates to single render pass; verify post-Phase-01 (locked detent = stable frames) |
| Fly coin renders above confetti/sheet | Med | `.overlay` z-order: flyingCoinOverlay above confetti; or below if confetti should win |
| Counter increments before fly arrives (desync) | Med | Delay `displayedCoins` set to match fly duration (~0.4s) |
| Spring overshoot on small cells looks jarring | Low | dampingFraction 0.6 tuned; verify SE vs Pro Max |
| matchedGeometry (Approach B) conflicts | Low | Default Approach A; B only if A proves insufficient |

## Security considerations
None. Animation only. No persistence/logic change.

## Next steps
→ Phase 05 (tests + a11y verify). Update UI tests, build+test green, Dynamic Type / VoiceOver audit.

## Resolved decisions (validation interview 2026-06-29)
1. **Fly anchor** → header counter inside sheet (KISS, same view). ✅
2. **Confetti scope** → Day-7 jackpot only. ✅

## Open questions (minor / empirical)
1. **Multiple coins** — fly 1 coin (KISS default) vs N-coin swarm (= reward value)? Default 1; revisit if feels weak.
2. **Approach A vs B** — frame-based overlay (default) vs `matchedGeometryEffect`? A more debuggable; confirm after prototype.
3. **Counter sync delay** — delay `displayedCoins` set 0.4s to match fly, or set immediately (current)? Delay feels more connected; confirm in sim.
