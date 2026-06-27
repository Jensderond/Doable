# Deadline editor redesign

**Date:** 2026-06-27
**Status:** Approved

## Problem

Clicking the clock icon on a todo row opens the due-date editor in a SwiftUI
`.popover`. Because the app is a `MenuBarExtra(.window)`, the popover renders as a
*separate* window. When the pointer moves onto it, the menubar window detects it
resigned key/focus and dismisses itself — taking the popover with it. The editor
is effectively unusable. The editor UI is also the bare default: a compact
`DatePicker` with a number-field + stepper.

## Goals

- Editor stays open and is usable (no close-on-hover).
- Faster common-case date setting via presets.
- Cleaner visual presentation.
- User can choose where the editor appears.

## Root-cause fix

Stop using `.popover`. Render the editor *inside* the menu window so there is no
second window to lose focus to. This removes the dismissal entirely rather than
fighting the focus system.

## Components

### 1. `DuePreset` (new — `DoableCore`)

A pure, unit-tested enum that produces preset due dates from `(now, calendar)`.
Kept in Core to match the repo's pattern of testable date logic
(`Workdays`, `StaleRule`, `Classifier`).

Cases and semantics (default due time **17:00** local):

| Case          | Resolves to                                              |
|---------------|---------------------------------------------------------|
| `today`       | today at 17:00                                           |
| `tomorrow`    | tomorrow (calendar +1 day) at 17:00                      |
| `thisWeekend` | the coming Saturday, or today if today is Sat/Sun, at 17:00 |
| `nextWeek`    | the next Monday strictly after today, at 17:00          |

API:

```swift
public enum DuePreset: String, CaseIterable, Sendable {
    case today, tomorrow, thisWeekend, nextWeek
    public var displayName: String
    public func date(from now: Date, calendar: Calendar) -> Date
}
```

`displayName`: "Today", "Tomorrow", "This weekend", "Next week".

### 2. `DateEditorPlacement` (new — `DoableCore`)

```swift
public enum DateEditorPlacement: String, CaseIterable, Sendable {
    case overlay, inline
    public var displayName: String   // "Overlay", "Inline"
}
```

Default `.overlay`.

### 3. `DeadlineEditor` (App — restyled)

The same view is reused by both placements. Layout, top to bottom:

- Title: "Set due date".
- 2×2 grid of preset buttons (one per `DuePreset.allCases`). Tapping a preset
  calls `store.setDueDate(preset.date(from: Date(), calendar: .current), …)` and
  dismisses immediately.
- Divider.
- "Custom" row: compact `DatePicker` (`[.date, .hourAndMinute]`, labels hidden)
  bound to local `@State date`.
- Divider.
- Footer: `Clear` (shown only when `item.dueDate != nil`) on the left, `Done`
  (default action; sets `date` and dismisses) on the right.

Dismissal is driven by the lifted editing state (below), not a local
`isPresented`/popover.

### 4. Wiring — `MenuContentView` + `TodoRowView`

Lift editing state up so the overlay can render it and rows can detect activeness:

- `MenuContentView`: `@State private var editingItemID: UUID?`.
- `TodoRowView` receives `editingItemID: Binding<UUID?>`. Its clock button sets
  `editingItemID = item.id` (no per-row `.popover` anymore). The row is "active"
  when `editingItemID == item.id`.
- Placement read in both views via `@AppStorage("dateEditorPlacement")`.

**Overlay (default):** when `editingItemID != nil` and placement is `.overlay`,
`MenuContentView` shows a dimmed full-bleed background (semi-transparent) with the
`DeadlineEditor` card centered. Clicking the dimmed background sets
`editingItemID = nil` (dismiss). The editor's Clear/Done/preset actions also clear
`editingItemID`.

**Inline:** when placement is `.inline`, the active `TodoRowView` reveals the
`DeadlineEditor` directly beneath its row content (conditional `VStack`),
pushing rows below it down.

### 5. Settings — `SettingsView`

Add:

```swift
Picker("Date editor", selection: $editorPlacement) {
    ForEach(DateEditorPlacement.allCases, id: \.rawValue) { p in
        Text(p.displayName).tag(p.rawValue)
    }
}
```

backed by `@AppStorage("dateEditorPlacement")`. Increase the settings window
height slightly to fit the new row.

## Data flow

```
SettingsView ──@AppStorage("dateEditorPlacement")──┐
                                                    ▼
clock button (TodoRowView) ─sets→ editingItemID (MenuContentView @State)
                                                    │
                    placement == .overlay ──────────┼──→ overlay card in MenuContentView
                    placement == .inline  ──────────┴──→ inline editor in active TodoRowView
                                                    │
DeadlineEditor ─preset/Done→ store.setDueDate(…) ; editingItemID = nil
              ─Clear────────→ store.setDueDate(nil); editingItemID = nil
```

## Testing

- `DuePresetTests` (Core): each of the four presets, evaluated against a fixed
  calendar and several `now` values spanning weekday and weekend, asserting both
  the resolved day and the 17:00 time-of-day. Edge cases: `thisWeekend` when today
  is Saturday and when Sunday; `nextWeek` from a Friday and from a Sunday.
- View/wiring changes (overlay vs inline, no close-on-hover, settings toggle)
  verified by building and running the app.

## Out of scope

- Configurable default due time (fixed at 17:00 for now).
- Relative/natural-language date entry.
- Localizing preset weekday math beyond the supplied `Calendar`.
