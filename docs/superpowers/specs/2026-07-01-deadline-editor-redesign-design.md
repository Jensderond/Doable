# Deadline Editor Redesign

**Date:** 2026-07-01
**Status:** Approved

## Problem

Setting a deadline on a todo is clunky. The current inline `DeadlineEditor` panel
(preset button grid + compact macOS `DatePicker` + Clear/Done buttons) feels bad to
use, and picking a custom date through the tiny compact picker is fiddly. The entry
point (row "…" menu → Set/Edit deadline) is fine and stays as is.

## Decisions

- Deadlines are **day-only**. Time-of-day disappears from the UI entirely.
- The panel is **calendar-first**: a mini month calendar is always visible.
- Every choice is **one-click apply**: clicking a preset chip or a calendar day sets
  the deadline and closes the panel. No Done button.
- An **opt-in "type to set" text field** (Settings toggle, default off) parses
  weekday names and keywords.

## UI

The panel still renders inline beneath the edited row (unchanged wiring in
`TodoRowView` / `MenuContentView`), sized to the 320 pt popover.

Layout, top to bottom:

1. **Type-to-set field** — only when the setting is on (see below).
2. **Preset chips** — Today / Tomorrow / Next week in one compact row, driven by the
   existing `DuePreset` (including its weekend rule that hides Tomorrow on
   Fri/Sat/Sun).
3. **Month calendar** — custom SwiftUI grid:
   - Header: ◀ / ▶ month navigation around a "July 2026" label.
   - Opens on the month of the existing deadline, else the current month.
   - Today is outlined; the current deadline day has an accent fill.
   - Days before today are disabled and dimmed. Days outside the displayed month
     are not shown (blank cells).
   - Week starts on the user's calendar `firstWeekday`.
4. **Clear deadline** — shown only when the item already has a deadline. Clears and
   closes.

Clicking a chip or an enabled day applies immediately and dismisses. Dismissing the
popover mid-edit keeps its existing cleanup behavior.

We use a custom grid rather than `.datePickerStyle(.graphical)` so the calendar
matches the app's look and fits the popover width predictably.

## Type-to-set field (opt-in)

- **Setting:** "Type to set deadlines" toggle in the General settings pane,
  `@AppStorage("typeToSetDeadline")`, default `false`. When off, the field is not
  rendered and the panel is presets + calendar only.
- **Focus:** when the setting is on, the field is focused as the panel opens.
- **Matching:** prefix match against a priority-ordered candidate list:
  `today`, `tomorrow`, `next week`, then weekday names (full and 3-letter forms:
  `monday`/`mon` … `sunday`/`sun`). First match wins: `t` → today, `tom` →
  tomorrow, `tu` → Tuesday, `f` → Friday. English keywords only. Matching is
  case-insensitive; surrounding whitespace is ignored.
- **Resolution:** a weekday resolves to its next occurrence *strictly after* today
  ("fri" typed on a Friday → next Friday; "today" covers today). `today`,
  `tomorrow`, and `next week` resolve via the existing `DuePreset` logic.
- **Preview:** while typing, the field shows the resolved match inline, e.g.
  `f` → "fri → Fri, Jul 3". No match → no preview.
- **Keys:** Enter applies the previewed day and closes; Enter with no match does
  nothing. Esc clears the field if it has text; Esc on an empty field closes the
  panel.

## Data model & display

- **No schema change.** `TodoItem.dueDate` remains a `Date`; all writes keep the
  existing day-at-17:00 convention (presets already do this; calendar picks and
  typed dates adopt it). `Classifier`, `StaleRule`, and sorting are untouched.
- **Display:** `TodoRowView` drops hour/minute from the due-date line — "Tue, Jul 1"
  instead of "Tue Jul 1 17:00". Existing stored deadlines render day-only
  automatically.

## Components

| Unit | Location | Responsibility |
|------|----------|----------------|
| `MonthGrid` | `Core/Sources/DoableCore` | Pure month-layout math: weeks of a given month as rows of optional days, honoring `firstWeekday`. Unit-tested. |
| `DeadlineInputParser` | `Core/Sources/DoableCore` | Pure prefix-match parser: input string + reference date → matched label + resolved day (or nil). Unit-tested. |
| `DeadlineEditor` | `App/Views` | Rewritten panel: optional type field, preset chips, calendar grid, Clear. |
| `GeneralSettingsView` | `App/Views/Settings` | Adds the "Type to set deadlines" toggle. |
| `TodoRowView` | `App/Views` | Due-date line format change only. |

`DuePreset` is unchanged.

## Error handling

There are no failure states to surface: unparseable text simply shows no preview,
past calendar days are disabled rather than validated after the fact, and all
writes go through the existing `TodoStore.setDueDate`.

## Testing

- `MonthGrid`: month layouts across `firstWeekday` values, month boundaries,
  leap February.
- `DeadlineInputParser`: priority order (`t`/`to`/`tom`/`tu`/`th`), full and short
  weekday names, strictly-after resolution on the same weekday, case/whitespace
  handling, no-match inputs.
- UI behavior (one-click apply, Clear visibility, setting toggle) is verified
  manually in the running app, consistent with how the app's other views are tested.
