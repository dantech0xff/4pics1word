# Researcher 01 — iOS Bottom Sheet Detents (Non-Expandable)

**Goal:** Lock `CheckInView` sheet to a compact size; prevent drag-to-full-screen.
**Current code** (`AppRootView.swift:25-27`): `.presentationDetents([.medium, .large])` + `.presentationDragIndicator(.visible)` + `.interactiveDismissDisabled(!model.canCheckInToday)`.
**Root cause of bug:** two detents (`.medium, .large`) give the user a snap target at 100% — that *is* the expand path. Fix = single detent.

## 1. Detent options
`.presentationDetents(_:)` takes a `Set<PresentationDetent>` (iOS 16+, stable iOS 26).
| Detent | Meaning |
|---|---|
| `.large` | Full available height (the one we must drop) |
| `.medium` | ~½ screen |
| `.fraction(Double)` | 0.0–1.0 of container |
| `.height(CGFloat)` | Absolute points |
| Custom `PresentationDetent` | `resolve(in:)` → dynamic (e.g. fit-content via `maxDetentValue`) |

**Non-expandable = exactly one detent.** Multiple detents = multiple snap stops = expandable by design.

## 2. Single vs multi detent
- **`[.medium]` alone disables drag-to-expand** — there is no second stop to snap to, so an upward drag has nowhere to go.
- It does **NOT** disable drag-to-dismiss (swipe down still closes) unless `interactiveDismissDisabled(true)`.
- It does **NOT** auto-hide the drag indicator.
- No keyboard / VoiceOver / Accessibility path forces expansion on iPhone. Only the iPad form-sheet grabber can still resize (see §5).
- `.presentationContentInteraction(.resizes)` (iOS 17+) can be added so any drag resizes the sheet rather than scrolling content — but with a single detent it's a no-op for expansion.

## 3. Drag indicator
- `.presentationDragIndicator(.visible | .hidden | .automatic)`.
- `.automatic` (default) shows the pill when ≥2 detents OR when SwiftUI judges the sheet draggable; with a single detent it is usually hidden.
- **Hiding the indicator does NOT prevent dragging/expansion** — it's a visual affordance only; the sheet edge remains draggable. Do not rely on `.hidden` as a lock.
- Recommendation: keep `.visible` so users understand they can swipe down to dismiss (or `.hidden` if `interactiveDismissDisabled` is on, since there's nothing to drag for).

## 4. interactiveDismissDisabled scope
- Per Apple's signature, `interactiveDismissDisabled(_:)` blocks **dismissal only** (the swipe-down-to-close gesture and the system's interactive pop). It does **not** block detent resizing/expansion.
- In practice it is irrelevant to expansion here because §2 already removes the expand target.
- Net effect for the gate: `.interactiveDismissDisabled(!model.canCheckInToday)` still correctly stops the user closing the sheet before claiming — keep it.

## 5. iPad form-sheet caveat
- App supports iPad (AGENTS.md). In **regular horizontal size class** (iPad), `.sheet` renders as a **form-sheet** (centered card), and **`.presentationDetents` is ignored** — there are no bottom detents.
- Form-sheets expose a **bottom-right resize grabber** letting the user cycle small/medium/large presets. As of iOS 26 there is **no public SwiftUI API to disable that grabber**.
- Options:
  1. Accept form-sheet behavior (resize is harmless; content reflows).
  2. Force a bottom-sheet everywhere via `.presentationCompactAdaptation(.sheet)` — but that only adapts *compact* → *sheet*; it does not force a regular-iPad form-sheet into a bottom sheet.
  3. Build a custom overlay/`.zStack` modal for iPad if hard-lock is truly required (YAGNI — likely unnecessary for a reward sheet).
- Recommendation: accept form-sheet on iPad; lock only iPhone via single detent. Verify with iPad sim.

## 6. UX recommendation (medium vs custom height)
- Content = 7-day reward strip + claim button + coin counter. Compact, finite, list-like → fits a half sheet.
- **Apple HIG — Modality:** prefer sheets for brief, focused, optional tasks; people should see context behind. `.medium` is the canonical "secondary, dismissible" size.
- **Apple HIG — Sheets:** use `.medium` when underlying content should remain partly visible.
- Duolingo daily-reward & Wordle stats both use ~half-screen modals, not full-screen — consistent with `.medium`.
- **Recommendation: `[.medium]` (single).** Avoid custom `.height(_)` / `.fraction(_)` unless a measured design calls for it — custom heights drift across SE/Pro Max and break the platform feel. `.medium` adapts to every iPhone for free.

## 7. Scroll vs fixed-size
- If content slightly overflows: prefer **sizing the detent to fit** over an internal `ScrollView`.
- Reason: a `ScrollView` inside a single-detent sheet competes with the sheet's own drag gesture (dismiss/resize), producing drag ambiguity — Apple specifically added `.presentationContentInteraction` to mitigate this, which signals the friction is real.
- For a 7-tile strip + button + counter, the content should *fit* in `.medium` by design. If it doesn't, trim paddings / use a horizontal strip rather than introducing a scroll.
- Trade-off summary: fixed = snappy, predictable, matches "brief reward moment"; scroll = flexible but gesture-conflict-prone and signals "too much content for the moment."

## Decision (one line)
Change `AppRootView.swift:25` from `.presentationDetents([.medium, .large])` → **`.presentationDetents([.medium])`**. Keep `.interactiveDismissDisabled(!model.canCheckInToday)`. Drop or keep `.presentationDragIndicator(.visible)` per taste (cosmetic only). Accept iPad form-sheet as-is.

## Citations
- [presentationDetents(_:) — Apple Docs](https://developer.apple.com/documentation/swiftui/view/presentationdetents(_:)) (iOS 16+)
- [PresentationDetent — Apple Docs](https://developer.apple.com/documentation/swiftui/presentationdetent) (`.large/.medium/.fraction/.height` + custom `resolve`)
- [interactiveDismissDisabled(_:) — Apple Docs](https://developer.apple.com/documentation/swiftui/view/interactivedismissdisabled(_:)) (dismissal-only)
- [presentationDragIndicator(_:) — Apple Docs](https://developer.apple.com/documentation/swiftui/view/presentationdragindicator(_:))
- [presentationContentInteraction(_:) — Apple Docs](https://developer.apple.com/documentation/swiftui/view/presentationcontentinteraction(_:)) (iOS 17+, drag-vs-scroll priority)
- [presentationCompactAdaptation(_:) — Apple Docs](https://developer.apple.com/documentation/swiftui/view/presentationcompactadaptation(_:))
- [Apple HIG — Modality](https://developer.apple.com/design/human-interface-guidelines/modality)
- [Apple HIG — Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)
- In-repo prior research: `plans/2026-06-28-daily-checkin/research/researcher-02-checkin-ui.md`, `plans/2026-06-28-daily-reward-sheet-redesign/research/researcher-01-report.md`

## Unresolved questions
1. **iPad grabber lock** — no public API to disable the form-sheet resize grabber as of iOS 26; needs empirical test on iPad sim to confirm whether `[.medium]` even applies (expected: ignored). If a hard lock is required on iPad, expect a custom overlay modal (out of scope — YAGNI).
2. **`.presentationContentInteraction(.snaps)` case** — could not fully verify enum cases (`automatic/scrolls/resizes` vs a `snaps` variant) from offline knowledge; if expansion leakage appears on drag, re-verify this modifier's cases in the live toolchain. Not needed if single-detent fix holds.
3. **Accessibility** — unverified whether Switch Control / VoiceOver exposes an "expand" action when only `.large` is omitted; low risk but not confirmed.
4. **SE (375pt) fit** — 7 tiles + button + counter must be visually verified in `.medium` on iPhone SE sim; if cramped, consider `.fraction(0.6)` single detent (still non-expandable).
