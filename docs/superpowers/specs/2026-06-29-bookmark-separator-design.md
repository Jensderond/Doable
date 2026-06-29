# Bookmark Separator — Design

**Date:** 2026-06-29
**Status:** Approved

## Problem

The menu's active list sorts bookmarked (pinned) tasks above normal ones. Drag-reordering
(`MenuContentView` + `Reorder.move`) lets a task cross the pinned↔unpinned boundary, and crossing
it flips the task's pin state. But that boundary is **invisible**, so dragging a normal task up one
slot can silently turn it into a bookmark — surprising and easy to do by accident.

## Goal

Render a visible **plain thin line** at the pinned↔unpinned boundary so the user can see the barrier
and understand that dragging a task across it changes whether it's bookmarked.

## Decisions (from brainstorming)

- **Style:** a single subtle divider line, matching the existing `Divider()` aesthetic. No label, no
  section headers.
- **Visibility:** shown only when there is **at least one bookmarked task AND at least one normal
  task** — i.e. only when a real boundary exists. (With zero bookmarks, `Reorder.move` cannot pin a
  task by dragging anyway, so no separator is meaningful.)
- **During drag:** the line is **emphasized** (accent-colored, slightly heavier) so the barrier is
  obvious exactly when the user might cross it.

## Behavior

### At rest

`displayItems` is `Ordering.activeSorted` (pinned-first). Insert the separator immediately before the
first unpinned item, but only when at least one pinned and one unpinned item exist. Otherwise render
nothing extra.

### During a drag

The separator must mark where the **pin/unpin flip** will occur, which `Reorder.move` computes from
the *other* (non-dragged) items. So the boundary is defined excluding the dragged item:

- Let `others` = `order` with the dragging item removed.
- The boundary sits **after the last pinned item in `others`** (equivalently, before the first
  unpinned item in `others`).
- The dragged ghost's live index in `order` then falls **above** the separator (→ would become
  bookmarked) or **below** it (→ would become normal). This matches `Reorder.move` exactly:
  `d < p → pinned`, `d > p → unpinned`, `d == p → keep`. At the exact boundary (`d == p`) `move`
  *keeps* the current state, so the ghost preview must also show the dragged item's current state
  there rather than flipping — a strict above/below test would mislead at that one position.

Show the separator during a drag whenever there is **at least one pinned and one unpinned task
overall** (counting the dragged item). Note the subtle case: when the dragged item is the *sole*
pinned task there are no pinned *others*, yet a flip is still possible — dragging it down unpins it —
so the boundary sits at the very top (index 0) and the barrier must be shown. (An earlier draft of
this spec wrongly claimed no flip was possible with no pinned others; that omission was a Critical
bug caught in final review.)

#### Prospective-state preview (part of this design)

To make the outcome unmistakable, the floating ghost row previews the **prospective** pin state: its
title renders **bold when it sits above the boundary** (would-be-bookmarked) and regular when below,
rather than always reflecting the task's current pin state. This is the direct payoff of showing the
barrier — the user sees the task "become a bookmark" as they cross the line.

## Implementation sketch

All changes are in `App/Views/MenuContentView.swift`. No `Core`/`Reorder` changes — the pin-flip
logic is unchanged; we only visualize the boundary it already uses.

1. **Boundary computation** — a small helper that, given `displayItems` and the optional dragging
   item, returns the display index at which the separator should appear, or `nil` when no boundary
   should show. At rest: index of first unpinned item (nil if either section empty). During drag:
   index just past the last pinned non-dragged item (nil if no pinned non-dragged item).

2. **Rendering** — in the `VStack` that currently does `ForEach(displayItems) { listRow }`, inject
   the separator view before the row at the boundary index. Keep iterating by item id so
   `RowFramesKey` still reports each row's frame; the separator is inert
   (`.allowsHitTesting(false)`) and does not participate in `targetIndex` math (which keys off row
   midpoints only).

3. **Separator view** — a thin rule with small horizontal inset. Resting: `Color.secondary`-ish at
   low opacity (visually a `Divider`). Dragging: `Color.accentColor`, slightly thicker/opaque,
   animated in with the existing `.easeInOut(duration: 0.15)` used by `reorder`.

4. **Ghost preview** — in `ghostRow`, drive `fontWeight` from the *prospective* pin state (above
   boundary = bold) instead of `item.isPinned`. Compute "above boundary" from `dragGhostY` vs. the
   boundary row's position, or from the dragged item's index relative to the computed boundary index.

## Edge cases

- **No bookmarks:** no separator, at rest or during drag. With zero pinned tasks, dragging cannot
  pin (matches `Reorder`).
- **All bookmarked:** no unpinned section → no separator. (Dragging to the bottom keeps state per
  `Reorder`; out of scope to change.)
- **Single pinned + single unpinned:** separator shows between them at rest.
- **Sole bookmarked task being dragged:** the separator shows at the top (index 0); dragging the
  task below row 0 unpins it, and the ghost preview reflects that as it crosses. Verified by
  exhaustive simulation that the ghost preview always agrees with the committed pin state.
- **Pending-done rows:** unchanged; they can't be dragged and don't affect the boundary beyond their
  normal pin flag.
- **Popover dismissed mid-drag:** `endDrag()` already resets drag state; separator returns to its
  resting rule automatically.

## Testing

- `Reorder` logic is untouched, so existing `ReorderTests`/`OrderingTests` continue to cover the
  pin-flip rules. If the boundary-index helper is extracted as a pure function, add a focused unit
  test for it (resting and during-drag cases, including the no-boundary `nil` cases).
- Manual verification in the running app (per `/run`): confirm the line appears only with mixed
  sections, emphasizes during drag, and that the ghost goes bold/regular as it crosses, with the
  committed pin state matching.

## Out of scope

- Labels or section headers on the separator.
- Changing the all-pinned bottom-drop behavior.
- Any change to how pinning is toggled via the bookmark button or menus.
