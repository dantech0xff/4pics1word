# Research: Hero Zoom Image Viewer (SwiftUI, iOS 17+)

## TL;DR
Use `matchedGeometryEffect` + `@Namespace` inside a single `ZStack` overlay in the **same view hierarchy** as the grid. Toggle a `Bool` inside `withAnimation(.spring(...))`. Do **not** use `.fullScreenCover` — it spawns an isolated hierarchy and silently breaks matched geometry. Tap the fullscreen layer to dismiss (same animated toggle).

Refs:
- https://developer.apple.com/documentation/swiftui/view/matchedgeometryeffect(id:in:properties:anchor:issource:)
- https://developer.apple.com/documentation/swiftui/namespace
- https://developer.apple.com/documentation/swiftui/withanimation(_:body:)

---

## 1. `matchedGeometryEffect` hero animation

- Both the thumbnail (grid cell) and the fullscreen image must carry **the same `id`** *and* share the **same `@Namespace`**.
- The fullscreen image is the geometry **source** (defines target frame); the thumbnail is the matching view. Only **one** source per id may exist at a time → render conditionally (`if showFullscreen`), else SwiftUI logs `"multiple matchedGeometryEffect with the same id"` and animation glitches.
- **Hierarchy rule:** matched geometry walks the *current* view tree to read/source frames. The two views MUST be in the same render pass / hierarchy. `.fullScreenCover`, `.sheet`, and `NavigationLink` destinations create a **separate hierarchies** (different render trees, often different windows). The effect cannot read across them → no animation, or a snap.
- `@Namespace` is `@MainActor`-safe; declaring `@Namespace private var ns` in a `@Observable`-hosting `View` is idiomatic. Use a `String`/`Hashable` id per image (e.g. `image.id`) to avoid collisions in a `LazyVGrid`.

## 2. Fullscreen layer: ZStack overlay wins

| Option | matchedGeometry? | Edge-to-edge? | Verdict |
|---|---|---|---|
| `.fullScreenCover` | ❌ separate hierarchy | ✅ | **Breaks animation.** Skip. |
| `.overlay` (View modifier) | ⚠️ ok-ish but constrained to parent bounds | ✅ with `.ignoresSafeArea` | OK for small views; weak for grid-level. |
| **`ZStack { grid; if full { layer } }`** | ✅ same tree | ✅ `.ignoresSafeArea(.all)` | **Use this.** |

The ZStack must be the **top-level** container of the screen (so the layer can cover the nav bar). Put `.ignoresSafeArea()` on the fullscreen image and `.zIndex(1)` to guarantee it paints above the `NavigationStack` content.

## 3. Animation

Wrap the **state mutation** (not the view) in `withAnimation` so both zoom-in and zoom-out animate symmetrically:

```swift
withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
    vm.selectedImageID = tap.imageID   // toggle drives `if showFullscreen`
}
```

- `response: 0.4–0.5`, `dampingFraction: 0.75–0.82` → snappy "zoom/pop" without bounce overshoot.
- Do NOT animate via `.animation(_:value:)` on the layer — double-animates. One source of truth: `withAnimation`.
- `.transition(.opacity)` on the caption only (matched geometry already animates the image).

## 4. Dismiss via tap

```swift
FullImage(image: img)
    .ignoresSafeArea()
    .matchedGeometryEffect(id: img.id, in: ns)
    .onTapGesture {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            vm.selectedImageID = nil
        }
    }
```

- Single `.onTapGesture` → no conflict (no simultaneous drag/zoom). If you later add pinch-to-zoom, use `.simultaneousGesture(TapGesture()...)` to avoid swallowing.
- Dismiss-on-drag-down is optional; adds `DragGesture` complexity — skip for MVP (YAGNI).

## 5. Credit caption pill

Use a `Capsule`/`RoundedRectangle` with `.ultraThinMaterial` for legibility over arbitrary photos:

```swift
Text(img.credit)
    .font(.caption)
    .padding(.horizontal, 12).padding(.vertical, 6)
    .background(Capsule().fill(.black.opacity(0.45)))   // or .ultraThinMaterial
    .padding(16)
```

Place it inside the fullscreen `ZStack` with `.zIndex(2)` and frame-aligned to bottom via `VStack { Spacer(); HStack { pill; Spacer() } }`. Animate with `.transition(.opacity.combined(with: .move(edge: .bottom)))` but **outside** the matched-geometry animation (use a delayed/secondary `withAnimation` or `.animation(.easeOut, value:)`).

## 6. Accessibility

- `.accessibilityLabel("\(img.description). Image.")` on both thumbnail and fullscreen image (same label = consistent VO experience).
- Add `.accessibilityAddTraits(.isButton)` + a custom dismiss action:
  ```swift
  .accessibilityAction(named: "Dismiss") {
      withAnimation(.spring()) { vm.selectedImageID = nil }
  }
  ```
- Ensure the fullscreen container traps VoiceOver focus: `.accessibilityElement(children: .contain)` on the overlay so VO doesn't wander to the grid beneath.
- For reduced motion: gate `withAnimation` — `@Environment(\.accessibilityReduceMotion)` → fall back to `.easeInOut(duration: 0.2)` or instant.

---

## Constraints compliance
- Default SwiftUI only: ✅ (`matchedGeometryEffect`, `@Namespace`, `Capsule`, `.ultraThinMaterial`, `.onTapGesture`, `withAnimation`).
- `@Observable` + MainActor default isolation: store `selectedImageID` on the `@Observable` VM; views read it directly. No `@StateObject` ceremony.
- Works inside `NavigationStack` as long as the ZStack wraps the stack's content.

## Gotchas / Unresolved
- **`LazyVGrid` + matchedGeometry:** lazy cells can be deallocated when scrolled offscreen → if user dismisses while the source cell is offscreen, the "shrink back" has no target frame and snaps. Mitigate by scrolling cell into view before nil-ing, or accept the snap.
- **`.fullScreenCover` temptation:** do not migrate later for "true modal" feel — it WILL break the hero animation. If modal isolation is required, you need a hand-rolled transition (custom `matchedGeometryEffect` is not enough).
- **`@Namespace` scope:** if the grid and fullscreen live in different subviews, pass the same `Namespace.ID` down (init inject) — both must reference the identical namespace instance.
- **Multiple images:** id must be unique across the grid (use the image's stable id, never array index — indices shift on lazy recycling).
- **iOS 17 `@Observable` + `withAnimation`:** mutating an `@Observable` property inside `withAnimation` animates dependent views; verified pattern.
- Unresolved: do we need pinch-to-zoom on the fullscreen image? (Assume no for MVP; revisit.)
- Unresolved: should caption support long-form attribution / tappable link? (Assume plain text pill.)
