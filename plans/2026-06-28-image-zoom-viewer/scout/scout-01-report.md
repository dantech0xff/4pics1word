# Scout Report 01 — Image Zoom Viewer Feature

**Date:** 2026-06-28
**Scope:** Structure/signature audit of `PuzzleImage`, `PictureGrid`, `GameView`, `Models`, `PuzzleState` + confirmation no existing zoom/viewer component.
**Verdict:** Feature is **greenfield**. No tap handlers, no `@Namespace`, no overlay container exist. Clean insertion required at 3 sites.

---

## 1. `4pics1word/Components/PuzzleImage.swift` (38 lines)

```swift
struct PuzzleImage: View {
    let puzzleId: Int          // PuzzleImage.swift:8
    let index: Int             // PuzzleImage.swift:9   (1...4)
    var body: some View        // :11 — Group { Image(uiImage:).resizable().scaledToFill() } | placeholder ZStack
    private static let cache = NSCache<NSNumber, UIImage>()   // :28
    static func load(puzzleId: Int, index: Int) -> UIImage?    // :30
}
```
- **Parameterized:** `PuzzleImage(puzzleId: Int, index: Int)` — no labels in call site, positional args.
- **Load path:** bundle root `<puzzleId>_<index>.webp` (`Bundle.main.url(forResource:withExtension:)`, :33). Bypasses Asset Catalog.
- **Cache:** static `NSCache<NSNumber, UIImage>` keyed `NSNumber(value: puzzleId * 10 + index)` (:31). `load` returns cached or decodes+caches (`UIImage(contentsOfFile:)`, :34-35).
- **Render:** `Image(uiImage:).resizable().scaledToFill()` (:14-16). Fallback: gray rect + `photo` SF Symbol (:18-23).
- **For hero zoom:** reusable as-is; the cached `UIImage` lookup is already O(1). Reuse `PuzzleImage.load` directly in the new viewer.

## 2. `4pics1word/Components/PictureGrid.swift` (19 lines)

```swift
struct PictureGrid: View {
    let puzzleId: Int                                  // PictureGrid.swift:5
    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]  // :7
    var body: some View { LazyVGrid(columns: columns, spacing: 8) { ForEach(1...4, id: \.self) { ... } } }  // :10
}
```
- **Container:** `LazyVGrid` (2 flexible columns, 8pt spacing) — **not** nested HStack/VStack.
- **Iteration:** `ForEach(1...4, id: \.self)` (:11). `index` is a local `Int` 1…4.
- **Cell modifiers** (:12-15) — in order:
  1. `PuzzleImage(puzzleId: puzzleId, index: index)`
  2. `.aspectRatio(1, contentMode: .fit)`   ← square crop
  3. `.clipShape(RoundedRectangle(cornerRadius: 10))`
  4. `.shadow(color: .black.opacity(0.1), radius: 2, y: 1)`
- **Tap handling: NONE.** No `.onTapGesture`, no callback, no `onSelect`. Signature has no closure param.
- **Required change:** add `var onTap: (Int) -> Void = { _ in }` (index → handler) OR accept a tuple of `(Namespace.ID?, onTap:)`. Index 1-4 must map to `copyrights[index-1]`.

## 3. `4pics1word/Views/GameView.swift` (112 lines)

```swift
struct GameView: View {
    let state: PuzzleState            // GameView.swift:7
    let levelNumber: Int              // :8
    let totalLevels: Int              // :9
    var onExit: () -> Void = {}       // :10
    @State private var shakeOffset: CGFloat = 0   // :12 — ONLY @State
}
```
- **OUTERMOST container of `body`:** `VStack(spacing: 16)` (:14-22), then `.padding(.vertical, 12)` → `.background(Color(.systemBackground).ignoresSafeArea())` → `.offset(x: shakeOffset)` → `.onChange(of: state.wrongAttemptToken)`.
- **⚠️ No ZStack at root.** A fullscreen hero overlay cannot simply be appended to the existing VStack — it needs either:
  (a) wrap the entire VStack in a `ZStack` and overlay the viewer with `.fullScreenCover` semantics, or
  (b) inject `.fullScreenCover(item: $selectedImage)` / `.overlay` on the VStack.
  Recommend (a): `ZStack { VStack { ... } ; if let sel = selectedImage { HeroImageView(...) } }`.
- **NO `@Namespace`** anywhere in file. Must add `@Namespace private var heroNamespace` for `matchedGeometryEffect`.
- **NO selection `@State`** for an image. Must add `@State private var selectedImage: Int? = nil` (or a dedicated `Identifiable` struct carrying index+copyright).
- **`state.puzzle.copyrights` access point:** already access `state.puzzle.id` at :57 (`PictureGrid(puzzleId: state.puzzle.id)`). `state.puzzle.copyrights: [String]` is available at the same scope; pass it down to `PictureGrid` + the new viewer.
- **Subviews referenced:** `header` (:34), `content` (:55, contains `PictureGrid` + `AnswerSlots`), `hintBar` (:66), `LetterBank`, `CoinCounter`.
- **PictureGrid call site** (:57): `PictureGrid(puzzleId: state.puzzle.id).padding(.horizontal)` — single arg today.

## 4. `4pics1word/Data/Models.swift` — `Puzzle.copyrights`

```swift
struct Puzzle: Codable, Identifiable, Hashable {
    let id: Int                          // Models.swift:4
    let solution: String                 // :5
    let copyrights: [String]             // :6   ← String array
    let time: Int                        // :7
    let rating: Double                   // :8
    let difficulty: String?              // :9
}
```
- **Type confirmed:** `copyrights: [String]` — plain String array, no nested struct. Each entry is the photo credit for the matching picture index.
- **4 entries per puzzle — CONFIRMED** via `4pics1word/Resources/puzzles.json` (game data) + `asset/core/puzzles.json` (source). Sample:
  - `["BillionPhotos.com/stock.adobe.com","dimedrol68/stock.adobe.com","prima91/stock.adobe.com","sararoom/stock.adobe.com"]`
  - `["Okea/stock.adobe.com","tete_escape/Shutterstock.com","Sergey Nivens/stock.adobe.com","Petair/stock.adobe.com"]`
- **Mapping convention:** `copyrights[index-1]` ↔ `PuzzleImage(puzzleId:, index:)` for `index ∈ 1...4` (PictureGrid's `ForEach(1...4)` is 1-based). Ensure off-by-one handled in viewer.

## 5. Existing fullscreen/zoom/viewer component — **NONE**

Searched all Swift sources for: `fullscreen|fullScreen|Zoom|ImageViewer|PhotoViewer|hero|matchedGeometryEffect|@Namespace`.
- **Zero hits** for `Zoom`, `ImageViewer`, `PhotoViewer`, `hero`, `matchedGeometryEffect`, `@Namespace`.
- Only `fullScreenCover` occurrence: `AppRootView.swift:19` — `.fullScreenCover(isPresented: showGame)` presents `GameView` itself. **Unrelated** to this feature; safe.
- Conclusion: build new. Suggested file: `4pics1word/Components/ImageZoomViewer.swift` (keep `_` prefix rule in mind only for top-level module types — component names are fine).

---

## Direct answers to scout questions

| Question | Answer |
|---|---|
| Does `PictureGrid` accept a callback/tap handler today? | **No.** Signature is `struct PictureGrid: View { let puzzleId: Int }` only (PictureGrid.swift:4-5). No closure, no `.onTapGesture` on cells. |
| Outermost container of `GameView.body`? | **`VStack(spacing: 16)`** (GameView.swift:14), wrapped in `.padding/.background/.offset/.onChange`. **Not a ZStack** — must wrap in ZStack (or use `.overlay`/`.fullScreenCover`) to host a top-most hero overlay. |
| How is `PuzzleImage` parameterized? | **`PuzzleImage(puzzleId: Int, index: Int)`** (PuzzleImage.swift:7-9). Call sites use positional: `PuzzleImage(puzzleId: puzzleId, index: index)`. `index` is 1-based (1…4). |
| `Puzzle.copyrights` type & count? | `[String]`, exactly **4 entries** per puzzle. Confirmed in `Models.swift:6` + `Resources/puzzles.json`. |

## Insertion points (for the planner)

1. **New file:** `4pics1word/Components/ImageZoomViewer.swift` — fullscreen `ZStack` with `matchedGeometryEffect`, shows `PuzzleImage.load(...)` + `copyrights[index-1]` + close gesture.
2. **Edit `PictureGrid.swift`:** add `var onTap: (Int) -> Void = { _ in }`; apply `.onTapGesture { onTap(index) }` + `.matchedGeometryEffect(id: index, in: namespace)` to each cell; accept a `Namespace.ID`.
3. **Edit `GameView.swift`:** add `@Namespace private var heroNamespace`, `@State private var selectedImage: Int? = nil`; pass `copyrights` + namespace + `onTap` into `PictureGrid`; wrap root `VStack` in `ZStack`; conditionally render `ImageZoomViewer` when `selectedImage != nil`.

## Unresolved questions

- Should tapping outside the picture (on dimmed backdrop) dismiss, or require an explicit close button? (UX decision for planner.)
- Should the viewer support pinch-zoom in addition to the hero zoom-in transition, or is a single fitted display sufficient? (Scope decision.)
- Accessibility: does the tap target need a `Button` wrapper + `accessibilityLabel("Photo \(index) of 4, credit \(copyright)")` rather than raw `.onTapGesture`? (Recommended.)
