# Daily Reward Sheet Redesign — Research Report

**Scope:** 4pics1word daily check-in sheet. Focus: weekly grid layout, tile content, sizing, visual hierarchy, claim-gate UX.
**Sources:** Domain knowledge of top-grossing mobile games (Candy Crush, Coin Master, Genshin Impact, Royal Match, Roblox, Duolingo, Township, Marvel Snap). Web fetches failed — synthesized from established, well-documented industry patterns.
**Date:** 2026-06-28

---

## 1. Two-Row Weekly Grid Patterns

How top games lay out 7-day streak rewards:

| Game | Layout | Day 7 (Jackpot) Treatment |
|---|---|---|
| **Coin Master** | Single horizontal strip, 7 cells | Day 7 wider, golden, distinct |
| **Candy Crush** | Single row of 7 | Day 7 slightly larger, sparkly |
| **Genshin Impact** | Horizontal scroll (single row) | Last day same size, "MEGA" badge |
| **Royal Match** | **3 + 4 split** (two rows) | Day 7 full-width below, oversized |
| **Township / Gardenscapes** | **4 + 3 split** | Day 7 full-width banner row |
| **Roblox (Daily Reward)** | Horizontal strip | Equal cells |
| **Marvel Snap** | 7-day row, day 7 highlighted | Equal size, glow only |
| **Duolingo (streak)** | Single row, no "jackpot" | N/A |

**Split conventions when 2 rows are forced (portrait iPhone):**
- **3+4**: Row 1 = D1–D3, Row 2 = D4–D7 (Royal Match). Day 7 sits in-grid but bigger.
- **4+3**: Row 1 = D1–D4, Row 2 = D5–D7 (Playrix titles).
- **3+3+1 (jackpot banner)**: Two 3-up rows, day 7 spans full width as a hero banner (highest engagement — used by Royal Match's premium variant, Toon Blast).
- **2+2+2+1**: Rare; only when cells must be large.

**Verdict:** **3+3+1 (jackpot full-width banner)** is the strongest pattern for portrait. Maximizes jackpot emphasis + keeps D1–D6 cells equal & predictable. Avoids the "which cell is bigger?" ambiguity of 3+4/4+3.

## 2. Reward Cell Content — Ranked by Retention Impact

Ranked high → low (based on what drives D1/D7 retention in cited games):

1. **Numeric value + reward icon** (coins icon + "500"). Mandatory. Perceived value clarity.
2. **"TODAY" badge + pulse glow on current day** — single biggest "come back tomorrow" driver. Royal Match, Coin Master.
3. **Day-7 jackpot emphasis** (badge "MEGA"/"JACKPOT", larger tile, golden gradient). Creates goal/horizon.
4. **Progress indicator** — checkmark ✓ on claimed days (Royal Match, Duolingo). Closure signal.
5. **Locked state** — padlock 🔒 on future days. Anticipation; visible reward but inaccessible.
6. **Day label** ("Day 3" or "Wed") — anchors streak; "Day N" beats weekday for retention (language-agnostic).
7. **Streak counter** ("🔥 5 day streak") — Duolingo-style; fear of loss.
8. **Mystery "?" tile** — variable reward (Coin Master, Genshin). Powerful but risky; only for D4–D6 to avoid jackpot dilution.
9. **"Reset warning"** — "Don't lose your streak!" microcopy near dismiss.
10. **Countdown timer** to next claim ("Next in 18h 23m"). Strongest re-open signal.

**Behavioral psych:** Variable reward (Skinner), loss aversion (streak), goal-gradient effect (jackpot horizon), endowed progress (start at D1 w/ freebie).

## 3. Tile Sizing/Spacing — Portrait iPhone

Consensus from top games (390–430pt wide screens):

- **Cell aspect:** square or slightly tall (1:1 to 1:1.1). 4-up row → ~**80–90pt square**; 3-up → **110–120pt square**.
- **Jackpot banner (full width):** ~**90–110pt tall**, full content width minus margins.
- **Corner radius:** **16–20pt** (matches iOS HIG "large" controls; `continuousCorner`). Avoid 4–8pt (feels dated).
- **Spacing between cells:** **8–12pt**. Tighter than typical list spacing for grid cohesion.
- **Horizontal margin (sheet → grid):** **16pt** each side (HIG standard).
- **Jackpot emphasis ratio:** jackpot area ≈ **1.5–2.0×** a single regular cell. Don't exceed 2× or D1–D6 feel negligible.
- **Hit target:** each cell ≥ **60×60pt** (HIG min 44pt → games push bigger for thumb-tap).
- **Icon size inside cell:** 36–48pt; value text 15–17pt bold; day label 11–12pt caps.

## 4. Visual Hierarchy — Come-Back-Tomorrow Hooks

**State contrast (claimed / today / locked / future):**
- **Claimed:** grayscale/dimmed, green ✓ overlay, slight scale-down (0.95).
- **Today:** saturated, golden/yellow glow, pulsing border (1.2s loop), subtle bounce idle, "TODAY" pill badge top-center.
- **Locked (future):** full color but padlock overlay + ~30% dark scrim.
- **Unclaimed-past (broken streak):** red "missed" tint or hidden (reset).

**Animation (SwiftUI):**
- **Pulse:** `scaleEffect` 1.0↔1.05, 1.2s repeatForever, easeInOut. Today only.
- **Shimmer:** gradient sweep across locked jackpot → anticipation.
- **Bounce on tap:** spring(response 0.3, dampingFraction 0.6) on claim.
- **Confetti/particle burst** on jackpot claim (high ROI, low effort with `Canvas`).

**Color:** warm palette (gold #FFB800, orange #FF7A00) for "active"; cool muted (slate #6B7280) for claimed. Today = highest luminance.

**Psych triggers:** near-miss (show jackpot giant but locked), anticipation (shimmer), variable reward (mystery tile), loss aversion (streak flame).

## 5. Forced-Claim Gate UX

**Do games force a claim before dismissing?** Mostly **no** — but with strong nudges.

| Game | Force-claim? | Already-claimed-today state |
|---|---|---|
| Coin Master | No (X dismissable) | Sheet auto-closes; shows "Come back tomorrow" toast |
| Candy Crush | No | Quietly skips sheet if already claimed |
| Genshin | No | "Claimed" greyed; gentle "Already claimed today" |
| Royal Match | **Soft force** — dismiss button hidden behind scroll; must tap reward or "Collect" | Reward auto-credited on first open, sheet = confirmation only |
| Duolingo | N/A (streak auto-tracked) | — |

**Best-practice conventions:**
- **First-open w/ unclaimed reward:** auto-present sheet; "Collect" = primary CTA; dismiss (X) allowed but small/top-right.
- **Already-claimed:** don't show sheet automatically. If user opens via menu, show read-only grid w/ "Come back in Xh" timer.
- **Dismissal affordance:** X in top-right (24–28pt), ` chevron`/swipe-down on sheet. Royal Match-style "soft force" (hide X, rely on tap-outside) **increases claim rate but hurts trust** — use cautiously.
- **Reward auto-credit:** safest — always credit on first open, sheet is celebratory confirmation. Avoids "did I get it?" anxiety.

---

## Top 3 Recommendations (adopt for 4pics1word)

1. **3+3+1 layout, jackpot = full-width banner.** Day 7 spans content width below a 3-up × 2 grid of D1–D6. Maximizes jackpot aspiration; cleanest on portrait iPhone; matches Royal Match premium feel. Cells ~115pt square, jackpot banner ~95pt.
2. **Today tile = pulse + glow + "TODAY" pill; auto-credit reward on first open.** Don't gate; celebrate. Add countdown timer ("Next reward in 18h") + streak flame counter to drive re-open. Claimed = green ✓ + dim; locked = padlock + scrim; future = full color locked.
3. **State system w/ clear visual contract.** 4 states (claimed/today/locked/future), warm-gold active vs slate-grey claimed, corner radius 18pt, 10pt spacing, 16pt margins. Confetti burst on jackpot. Mystery "?" tile optional on D4 only.

## Unresolved Questions

- **Reward economy:** coin values per day? Need reward curve to size jackpot emphasis correctly.
- **Streak-reset policy:** skip a day → reset to D1, or grace period (Duolingo gives 1 freeze)? Affects "missed" UI need.
- **Mystery tile appetite:** does 4pics1word's brand allow surprise rewards, or must every reward be deterministic?
- **Sheet vs full-screen:** bottom sheet (current?) or full-screen modal? Sizing math differs.
- **Localization:** "Day N" vs weekday label — confirm target locales before locking label format.
- **Offline/restore:** behavior if user opens app, closes before sheet renders — auto-credit must be server- or UserDefaults- gated to avoid double-claim.
