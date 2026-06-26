# Doable — Menubar Todo App Design

**Date:** 2026-06-26
**Status:** Approved design, pending implementation plan

> Working name "Doable" — trivially renameable. Bundle identifier and product name can be adjusted before the first build.

## Purpose

A very basic, native-looking macOS menubar app for tracking todos that can optionally be
"done before a specific date and time." Capture is friction-free: click the menubar icon,
type a todo, press Enter. Completion is one click. Deadlines are optional and surfaced both
in the list and on the menubar icon itself.

## Platform & Tooling

- macOS (target current; developed on macOS 26 / Xcode 26.6 / Swift 6.3).
- SwiftUI `MenuBarExtra` with `.menuBarExtraStyle(.window)` for a real popover panel (so a
  text field can be focused immediately) with native vibrancy/transparency.
- Agent app: `LSUIElement = true` — menubar icon only, no Dock icon, no main window.
- Persistence: **SwiftData** (`@Model`, `@Query`, automatic saving).
- Launch-at-login: `SMAppService.mainApp`.

## Core Interactions

### Adding (click → type → Enter)
- Popover opens with a text field **auto-focused**.
- Pressing Enter creates a `TodoItem` instantly with **no deadline**.
- The field clears and keeps focus, so several items can be added in a row.
- Empty/whitespace-only input does nothing.

### Setting a deadline (optional)
- Each row shows a **clock icon on hover** (right side).
- Clicking it opens a `DeadlineEditor` popover with a date + time picker.
- Deadline is optional and can be changed or cleared later.

### Completing (click beside → undo → archive)
- A completion circle sits on the left of each row.
- Clicking it marks the item done and shows an inline **Undo** affordance, but the row
  **stays visible while the popover is open**.
- When the popover **closes**, all done items are committed to the archive (removed from the
  active list). Undo is only available until close.

### Archive
- A button switches the popover to a **separate archive screen** (with a back button) listing
  completed items. Keeps the main list clean.
- From the archive a user can review completed items. (Restore/delete-from-archive is a
  possible later addition; not required for v1 beyond viewing.)

## List Ordering

Active list is sorted by:
1. Deadline ascending (soonest first); items without a deadline sort after dated items.
2. Newest-first (most recently created) as the tiebreaker and among undated items.

## Deadline States & Styling

A configurable **due-soon window** (default: **today only** — due before end of the current
calendar day; configurable to e.g. 1 hour / 24 hours / 3 days).

Per-item state, worst-case:
- **Overdue** — deadline has passed. Stronger **red** accent in the list.
- **Due-soon** — deadline within the due-soon window. **Orange** accent.
- **Normal** — has a future deadline beyond the window, or no deadline. Default styling.

### Menubar icon
- **Normal:** monochrome template SF Symbol (e.g. `checklist`), no count.
- **Due-soon present (none overdue):** icon tints **orange** and shows a **count**.
- **Overdue present:** icon tints **red** and shows a **count** (red takes priority over orange).
- Count = number of active items that are due-soon **or** overdue.
- Icon state recomputes as items change and as time crosses thresholds (a lightweight timer
  re-evaluates periodically, e.g. each minute).

## Settings

A small settings area (within the popover or a dedicated screen) with:
- **Launch at login** toggle (`SMAppService`).
- **Due-soon window** picker (Today only / 1 hour / 24 hours / 3 days).

## Data Model

`TodoItem` (SwiftData `@Model`):
- `id` — unique identifier.
- `title: String`
- `createdAt: Date`
- `dueDate: Date?` — optional deadline.
- `isDone: Bool` — `false` = active, `true` = archived.
- `completedAt: Date?` — set when committed to archive.

Active = `isDone == false`. Archive = `isDone == true`.

Note on completion: while the popover is open, a completed item is held in a transient
"pending done" state (so Undo works) and only persisted as `isDone = true` on popover close.
Implementation may model this as an in-memory pending set in the store rather than a stored field.

## Components (small, focused units)

- **`DoableApp`** (`@main`) — `MenuBarExtra` scene, SwiftData `ModelContainer`, owns the
  menubar label/state.
- **`MenuBarLabel`** — renders the icon: symbol + color + count based on aggregate state.
- **`MenuContentView`** — popover root: input field, active list, navigation to archive and
  settings. Tracks popover open/close to commit pending-done items.
- **`TodoRowView`** — one row: completion circle, title, hover clock, due styling, inline undo.
- **`DeadlineEditor`** — date/time picker popover for setting/clearing a deadline.
- **`ArchiveView`** — separate screen listing completed items, with back button.
- **`SettingsView`** — launch-at-login toggle + due-soon window picker.
- **`TodoStore`** (or equivalent view model) — create, complete (pending-undo), commit-on-close,
  ordering, and state computation (per-item state + aggregate menubar state).
- **`LoginItemManager`** — wraps `SMAppService` register/unregister + status.
- **`DueSoonWindow`** — enum/value for the configurable window + the date math for classifying
  items into normal / due-soon / overdue.

## Error Handling

- SwiftData save failures: log; non-fatal for this local, single-user app.
- Login-item registration failures: reflect actual status back in the toggle (don't assume).
- Empty input: ignored silently.

## Testing

- `DueSoonWindow` classification logic (normal / due-soon / overdue across window settings and
  day boundaries) — pure, unit-testable.
- Ordering logic (deadline asc, undated last, newest-first tiebreak) — unit-testable.
- Aggregate menubar state (color + count) from a set of items — unit-testable.
- Completion/undo/commit-on-close transitions in `TodoStore` — unit-testable with in-memory store.

## Out of Scope (v1 / YAGNI)

- iCloud / cross-device sync.
- System notifications (deliberately excluded).
- Recurring todos, tags, priorities, subtasks, notes.
- Restore/delete management inside the archive beyond viewing (can be added later).
