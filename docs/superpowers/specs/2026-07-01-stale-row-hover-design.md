# Stale Row & Hover Stability Redesign

**Date:** 2026-07-01
**Status:** Approved

## Problem

Two related issues in the menu list rows (`App/Views/TodoRowView.swift`):

1. **Hover layout shift.** The bookmark (pin) button is conditionally inserted into the
   trailing HStack on hover. Its appearance steals ~26pt of title width, so longer titles
   rewrap, the row grows taller, and the click target shifts under the cursor.
2. **Noisy stale presentation.** Stale items render an extra sub-row with a "Stale"
   capsule badge and an inline "Postpone" text button, making stale rows tall and busy.

## Design

Both changes are presentation-only, confined to `TodoRowView.swift`. No changes to
`StaleRule`, `TodoStore.postponeStale`, or anything in Core.

### 1. Stale indication — subtle, no extra row

- Remove the `Stale` capsule + inline `Postpone` sub-row entirely. Stale rows have the
  same height as normal rows.
- A stale item shows a small `hourglass` SF Symbol (caption size, `.secondary` color) in
  the trailing control cluster, placed before the bookmark slot. Always visible (not
  hover-dependent), with a `.help` tooltip: "Stale — untouched for N workdays" where N is
  the configured `staleThresholdWorkdays`.
- The title keeps its normal color so stale-ness never competes with the red/orange
  overdue/due-soon coloring.
- **Postpone** moves into the "…" menu (shown only when the item is stale, above
  "Set deadline") and into the right-click context menu under the same condition.

### 2. Hover fix — reserve the bookmark slot

- The bookmark button becomes a permanent member of the trailing HStack instead of being
  conditionally inserted.
- When the item is not pinned and not hovered: `opacity(0)` + `allowsHitTesting(false)`.
  On hover (or when pinned) it fades in.
- Title width is identical hovered vs. unhovered, so text never rewraps and the click
  target never moves. Every row gives up ~26pt of title width; that is the accepted price
  of stability.

## Row anatomy (after)

```
◯  Title text that may wrap onto a     ⏳ 🔖 ⋯
   second line
   Tue, Jul 1                          (⏳ only when stale;
                                        🔖 opacity 0 unless
                                        pinned or hovered)
```

## Testing

- Existing Core tests untouched (no Core changes).
- Visual verification via a build: stale row shows the hourglass with tooltip, hover
  causes zero reflow on long titles, Postpone works from both the "…" menu and the
  context menu, pinned items keep their always-visible filled bookmark.
