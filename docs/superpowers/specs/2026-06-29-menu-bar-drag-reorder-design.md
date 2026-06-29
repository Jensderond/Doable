# Menu bar list: drag-to-reorder

**Date:** 2026-06-29
**Status:** Approved (design)

## Problem

The active todo list in the menu bar popover is sorted entirely by rules
(`Ordering.activeSorted`: pinned first, then soonest deadline, then newest).
Users have no way to arrange items in their own order. We want click-and-drag
reordering so the user controls the sequence.

## Decisions

Confirmed with the user during brainstorming:

1. **Manual order wins, fully.** Dragging sets an explicit position that
   overrides deadline/created sorting. The list becomes whatever the user
   arranges.
2. **Pinned always on top.** Pinned items always sort above unpinned items;
   `isPinned` remains the primary sort key so this invariant holds even if
   indices drift.
3. **Cross-boundary drag toggles pin.** Dragging an unpinned item up across the
   pinned/unpinned boundary pins it; dragging a pinned item down past the last
   pinned item unpins it. When there are zero pinned items there is no boundary,
   so dragging to the top does **not** auto-pin.
4. **New items land at the top of the unpinned section** (just below any pinned
   items).
5. **Drag mechanism: approach A** — custom `.draggable` + `.dropDestination` on
   the existing rows, preserving the compact look and the content-height-driven
   popover sizing. (Not a SwiftUI `List`, which would fight auto-sizing and add
   chrome.)
6. **Menu-bar label follows the top of the manual list.** `MenuBarLabel` shows
   `Ordering.menuBarTask` → `activeSorted().first`. With manual ordering this
   becomes "whatever the user dragged to the top" (first pinned, else first
   unpinned) rather than the soonest deadline. This is intended.

Deadline and created-date still drive **coloring** (overdue red, due-soon
orange) and the **Stale** badge. Only ordering changes.

## Design

### Data model — `Core/Sources/DoableCore/TodoItem.swift`

Add a stored property:

```swift
/// Manual position within the active list. Lower sorts higher. Defaulted so
/// existing SwiftData stores migrate cleanly.
public var sortIndex: Int = 0
```

Because the property is defaulted, this is a lightweight SwiftData migration —
existing items get `0`. On first launch after upgrade, all existing active
items share `sortIndex == 0` and fall back to a stable tiebreaker (see below)
until the user first reorders or the store normalizes them.

### `Orderable` protocol + sort — `Core/Sources/DoableCore/Ordering.swift`

- Add `var sortIndex: Int { get }` to `Orderable`, with a protocol-extension
  default of `0` so lightweight test conformances need not specify it.
- Rewrite `activeSorted` to sort by `(isPinned desc, sortIndex asc)` with a
  stable final tiebreaker of `createdAt` descending (handles the migration case
  where indices are equal, and keeps ordering deterministic):

```swift
public static func activeSorted<T: Orderable>(_ items: [T]) -> [T] {
    items.sorted { lhs, rhs in
        if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
        if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
        return lhs.createdAt > rhs.createdAt
    }
}
```

- `mostUrgent` and `menuBarTask` are unchanged in code (they delegate to
  `activeSorted`); only their behavior shifts to "top of manual list". Update
  their doc comments to reflect this. Consider renaming is out of scope —
  keep the names to limit ripple, fix the comments.
- `deadlinePrecedes` is no longer used by `activeSorted`. Remove it (it has no
  other callers).

### Store mutations — `App/Models/TodoStore.swift`

Index assignment uses a **full renumber of the visible active list** on each
mutation. The list is small (menu-bar scale), so renumbering is simple and
robust; no fractional-index scheme needed.

Add/adjust:

- **New item placement.** `create`/`insert` must put the new item at the top of
  the unpinned section. Implementation: fetch active items, and assign the new
  item a `sortIndex` lower than every unpinned item but not above pinned items.
  Simplest robust approach — after inserting, renumber: pinned items keep their
  relative order, then the new item, then the remaining unpinned items. Assign
  `sortIndex = visualPosition` across the whole active list.

- **`move`** — the reorder entry point called by the view. Given the current
  sorted array, a source index, and a destination index, produce the new visual
  order, apply pin/unpin for cross-boundary moves, then renumber `sortIndex` to
  match the new visual order and save.

  Pin/unpin rule inside `move`:
  - Determine the post-move neighbors of the dragged item.
  - If the item lands among pinned items (i.e. there is at least one pinned item
    and the drop position is within/above the pinned block), set
    `isPinned = true`.
  - If a pinned item lands below the last pinned item (among unpinned), set
    `isPinned = false`.
  - With zero pinned items, no boundary exists, so pin state is left unchanged.

  After adjusting `isPinned`, re-sort by the intended visual order and renumber
  `sortIndex = 0..<n`.

- **`togglePin`** stays, but after toggling it should renumber so the item takes
  a sensible position (top of its new section). Keeping the explicit bookmark
  button working alongside drag.

A private helper `renumber(_ orderedItems: [TodoItem])` assigns
`item.sortIndex = offset` for each item in visual order, then saves once.

### View — drag UI

**`App/Views/MenuContentView.swift`**
- Keep the `ScrollView { VStack { ForEach(sortedItems) } }` structure and the
  `ListHeightKey` auto-sizing.
- Each row becomes `.draggable` (payload: the item's `UUID` as a transferable)
  and a `.dropDestination` that computes source/destination indices within
  `sortedItems` and calls `store.move(...)`.
- Provide drop-target visual feedback (e.g. an insertion line or row highlight)
  while dragging.
- Disable dragging for rows in `pendingDone` state (a checked-off item showing
  "Undo") to avoid reordering items about to be archived.

**`App/Views/TodoRowView.swift`**
- Add a drag affordance. Options: make the whole row draggable, or show a grip
  handle (`line.3.horizontal`) on hover next to the existing hover controls.
  Default: whole-row drag with a subtle grip on hover, so it doesn't collide
  with the checkbox/bookmark/`…` menu hit targets. Final affordance to be
  settled in the plan; must not interfere with existing tap targets.

### CLI — `CLI/main.swift`

No change required; it calls `Ordering.activeSorted` and will follow the new
sort automatically. Verify the build still compiles given the protocol change.

### Tests — `Core/Tests/DoableCoreTests/OrderingTests.swift`

Rewrite the ordering tests for manual order:
- `activeSorted` sorts by `sortIndex` ascending within a pin group.
- Pinned items always precede unpinned regardless of `sortIndex`.
- Equal `sortIndex` falls back to `createdAt` descending (migration case).
- `mostUrgent` returns the top of the manual list (pinned-first).
- `menuBarTask` `.topTask` returns the manual top; `.pinnedOnly` returns it only
  when pinned.

Add store-level coverage if practical for the `move` reindex and the
cross-boundary pin/unpin behavior (may require a SwiftData in-memory context;
if that's heavy, cover the pure index math in a testable helper in Core).

## Out of scope

- Reordering completed/archived items.
- Fractional/gap-based index schemes (unnecessary at this scale).
- Renaming `mostUrgent`/`menuBarTask`.
- Any change to deadline coloring or the Stale rule.

## Migration notes

`sortIndex` is defaulted to `0`, so the SwiftData schema change is additive and
non-breaking. On first run, existing items tie on `sortIndex` and fall back to
`createdAt` descending — a reasonable initial order. The first reorder (or a
one-time normalize on launch, if we choose to add it) gives every item a
distinct index.
