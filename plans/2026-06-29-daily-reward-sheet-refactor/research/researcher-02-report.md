# Researcher 02 — Daily Reward Cell UI/UX Rework

Scope: 7-day streak reward cell for "4 pics 1 word" SwiftUI game. Findings synthesised from Apple HIG, Material 3 game guidance, and observed patterns in Duolingo, Wordle, Headspace, Genshin Impact, Candy Crush (2024–2026).

## 1. State vocabulary

Essential for a 7-day loop (keep these, drop the rest — YAGNI):
- **Claimed** — done today/earlier. ✓ icon, lowest visual weight.
- **Today / available** — claimable NOW. Highest visual weight + CTA.
- **Locked / upcoming** — visible but not claimable. Drives anticipation.
- **Jackpot (day 7)** — escalation variant; re-skins today/locked.

YAGNI for a 7-day streak: **mystery** (random reward — adds code, confuses economy), **missed/broken** (Duolingo needs it because streaks break; a daily-bonus modal that resets weekly does not), **frozen/protect** (streak-shield mechanic — not in scope). Genshin/Wordle/Headspace all collapse to the 4 essentials; mystery chests belong in battle-pass UX (Genshin BP), not a 7-tile loop.

## 2. Visual hierarchy (today cell)

Most prominent should be the **reward value + icon**, NOT "DAY N" caption. Rationale: the player already knows it's today (the sheet opened for them); the actionable draw is "I get 80 coins". Duolingo's streak banner leads with the number; Wordle's solution leads with the result. "DAY N" is wayfinding — keep it `caption2`/secondary as the current code does (good).

"Tap me" affordance: combine (a) **elevation** (shadow/glow), (b) **scale 1.05–1.08** with spring, (c) **accent ring + filled bg** vs neighbours' muted bg, (d) optional **shimmer sweep** (2-3s loop). Candy Crush and Genshin both use a pulsing glow + scale on the claimable cell; a finger-tap hint animation on first session is a strong signal. Current code's pulse+ring+shadow is correct instinct — execution needs polish.

## 3. Iconography

For a word/puzzle game, **`gift.fill` reads fastest** across cultures (universally "reward"), beats coin/coin-sign for clarity. Coins (`bitcoinsign.circle.fill`) signal currency but are cold/transactional. Current `bitcoinsign.circle.fill` is fine for consistency with in-game currency IF the wallet icon is also a coin — keep currency semantic aligned.

Recommendation: keep **coin icon** for days 1–6 (matches economy), use **`gift.fill`** for jackpot day 7 to differentiate. Avoid `star.fill` (achievement conflation), `wand.and.stars` (power-up conflation), `seal.fill` (badge conflation). SF Symbols all render well at small sizes with `.foregroundStyle`.

## 4. Color & contrast (locked state)

30% black scrim is **too harsh and flattens depth** — it reads as "disabled/broken" not "coming soon". Best practice (Headspace, Genshin upcoming tiers):
- Drop **saturation ~40%** + **lightness +5%** (HSL shift), not black overlay.
- Keep reward **fully legible** (WCAG AA 4.5:1 on value text).
- Use a **soft lock chip** (`lock.fill` in a `ultraThinMaterial` circle, not black) — matches iOS 26 glass direction.
- Reserved vibrancy for today/jackpot; locked cells should look *slightly desaturated*, not dark.

Green/red alone is colour-blind unsafe (§9). Use shape+icon (`lock.fill`, `checkmark`) as primary signal, colour secondary.

## 5. Shape & depth

- **Squircle / continuous corner** (current `RoundedRectangle(...style: .continuous)`) is correct — iOS 26 standard. Keep.
- Uniform grid size; do NOT break the grid for jackpot (breaks scan rhythm, complicates layout math). Differentiate jackpot via **gradient + badge + scale 1.05**, not cell footprint.
- iOS 26 / visionOS influence: prefer **`.regularMaterial` backgrounds with subtle gradient overlays** over flat fills; add 1px inner highlight. Depth > flat colour. Avoid heavy shadows; favour soft ambient shadow (radius 12, opacity 0.2).

Circles/capsules: circles lose label space; capsules only work for horizontal strips. Stick with squircle.

## 6. Progress indication

For 7 items, **linear row of filled dots/checkmarks above or below the grid** is the clearest (Wordle-style). Duolingo's winding path is overkill for 7 (designed for 30+ day streaks). Options ranked:
1. **7 small dots** row: filled = claimed, ring = today, hollow = locked. Compact, instant. ✓ recommended.
2. **"Day 3 of 7"** caption in header — cheap, accessible, complements dots.
3. Connected checkmark trail — visually busy at 7 width.

Skip: progress bar (implies continuous %, wrong for discrete days), winding path (YAGNI).

## 7. Animation polish

Worth the effort (high ROI):
- **Spring scale on tap** (`.spring(response: 0.3, dampingFraction: 0.6)`) — feels native.
- **Coin fly-to-wallet** — single most satisfying F2P micro-interaction; strong dopamine anchor. Use `matchedGeometryEffect` or particle emit toward wallet icon.
- **Shimmer sweep on today cell** — 2.5s loop, diagonal gradient mask.
- **Confetti on jackpot claim only** (current code has it — keep, but gate to day 7).

Over-engineered / skip:
- Per-cell particle bursts on every claim (noise).
- 3D flip (gimmicky, slow).
- Haptic-only feedback (always pair haptic WITH visual, never alone).

Always gate motion behind `@Environment(\.accessibilityReduceMotion)` — provide instant crossfade fallback.

## 8. Layout (grid vs strip vs list)

Current **3+4 grid** is awkward — two row sizes (`threeHeight`/`fourHeight`) break visual rhythm and complicate Dynamic Type. Trade-offs:

| Layout | Compact | Legible | Verdict |
|---|---|---|---|
| **7-in-a-row strip** (current 4-row) | ✓ | ✗ too narrow on iPhone SE | reject |
| **Horizontal scroll 7-strip** | ✓ | ✓ each cell ~110pt | good for compact, loses "see all" |
| **7-in-a-4+3 or 3+4 grid** | ✓ | ✓ | current — fine but tune sizes |
| **2-col list** | ✗ tall | ✓✓ | wastes vertical space |

**Recommendation: single row of 7 cells (uniform size ~52–60pt wide) inside a horizontally-fit container** — on iPhone 16 width (~390pt) each cell gets ~52pt, tight but workable with vertical DAY/stacked icon. If too cramped, fall back to **uniform 4+3 grid (all same size)** — drop the dual row-size. Uniformity > irregularity for a 7-day mental model (matches calendar week metaphor).

## 9. Accessibility

- **Dynamic Type**: cap at `.accessibility2` (current `.accessibility3` risks overflow in 7-wide layout). Use `@ScaledMetric` for cell height (already done ✓) but also min-width on value text.
- **VoiceOver per state** — current label is good; refine to: `"Day 3, 50 coins, available to claim"` / `"Day 1, 20 coins, claimed"` / `"Day 5, 100 coins, locked, claim in 2 days"`. Add `.isButton` + action only on `today` cell; others `.isStaticText`.
- **Reduce Motion**: replace pulse/shimmer with static emphasis (ring + scale-free). Confetti → none.
- **Reduce Transparency**: fall back `.regularMaterial` → solid fill.
- **Colour-blind**: never rely on green check vs red lock alone — icon shape carries meaning (✓). Add **pattern/texture** or **stroke style** difference for claimed vs locked if colour is the only hue delta. Test with Sim Daltonism.

## Recommendations (top 3 concrete wins)

1. **Soften the locked state**: replace `Color.black.opacity(0.3)` scrim with **desaturation + `.ultraThinMaterial` lock chip**. Immediate depth/polish uplift; accessible.
2. **Unify the grid to 7 uniform cells** (or 4+3 same-size); kill dual `threeHeight/fourHeight`. Cleaner Dynamic Type, calendar-week metaphor, simpler code (DRY).
3. **Add coin fly-to-wallet + spring tap** on claim (reduce-motion-gated). Highest perceived-quality ROI for ~30 lines; turns "ok" into "satisfying".

Bonus quick wins: switch day-7 icon to `gift.fill`; add 7-dot progress row; refine VoiceOver labels with "claim in N days".

## Citations

- Apple HIG — Motion (animations: spring, easing, reduce-motion): developer.apple.com/design/human-interface-guidelines/motion
- Apple HIG — Materials (iOS 26 glass/depth): developer.apple.com/design/human-interface-guidelines/materials
- Material Design 3 — Game UI patterns, state layers, accessibility (colour contrast, semantics): m3.material.io
- Duolingo streak UX (winding path, frozen/missed states — referenced for contrast, not adoption): Duolingo blog "Designing streaks" (2023–2024)
- Wordle (NYT) — daily reward/progress dot pattern
- Genshin Impact Battle Pass — tier escalation, mystery-reward contrast
- Candy Crush daily bonus — pulsing claimable cell, fly-to-hud coin animation
- Headspace — desaturated "locked" upcoming content (saturation technique)
- WCAG 2.2 SC 1.4.3 (contrast), 1.4.11 (non-text contrast) — w3.org/TR/WCAG22

## Unresolved questions

1. Does the game persist a **broken-streak** concept (skip a day → reset to day 1)? If yes, a `missed` state becomes essential (currently assumed no). 
2. Is there an **in-game wallet HUD** with a coin counter to anchor the `matchedGeometryEffect` fly-to target? Needs the parent view hierarchy.
3. Day 7 jackpot — is it **coins only**, or a **variable reward** (hint, letter reveal)? Affects whether mystery-box icon is ever warranted.
4. Should the sheet support **claim-all / auto-claim on open**, or require explicit tap each day (engagement vs friction trade-off)?
5. Localisation — "DAY N" / "TODAY" / "JACKPOT" pill widths in DE/FR/JP may overflow 9pt heavy caps; needs string-width audit.
