# Completed-list time filter — design

## Problem

The menu bar app's completed list (`ArchiveView`) shows every item ever
completed, sorted by `completedAt` descending. After months of use this becomes
an unbounded wall of history. We want a default time filter so the list stays
focused on recent work.

## Goal

Add a time-range filter to the completed view with three options — **This
week**, **Last week**, **Last 30 days** — defaulting to **This week**. No
"show everything" option in the menu bar (keeps the popover tight); it can be
revisited in Settings later if missed.

## Design

### Core: `CompletedFilter` (pure, tested)

New file `Core/Sources/DoableCore/CompletedFilter.swift`.

```swift
public enum CompletedFilter: String, CaseIterable, Sendable {
    case thisWeek
    case lastWeek
    case last30Days

    public var displayName: String { ... }   // "This week" / "Last week" / "Last 30 days"

    /// Half-open [lower, upper) window of `completedAt` values to include,
    /// relative to `now`. Weeks are Monday-based.
    public func dateRange(now: Date, calendar: Calendar) -> Range<Date>
}
```

Range definitions (all half-open, `[lower, upper)`):

- **This week**: `[Monday 00:00 of the current week, now]`. Upper bound is `now`
  so future-dated edge cases can't leak in; in practice `completedAt <= now`.
- **Last week**: `[Monday 00:00 of previous week, Monday 00:00 of current week)`
  — the full prior Mon–Sun calendar week.
- **Last 30 days**: `[now − 30 days, now]`. Rolling window, not calendar month.

Monday is computed explicitly (Gregorian weekday `2`, same approach as
`DuePreset.nextWeek`) rather than relying on `Calendar.firstWeekday`, so the
result is independent of locale/first-weekday settings.

"Start of current week's Monday" helper: from `now`, take `startOfDay`, then
subtract `(weekday - 2 + 7) % 7` days to land on Monday.

### App: `ArchiveView`

- Add `@State private var filter: CompletedFilter = .thisWeek`.
- Header gains a `Picker` (`.menu` style, `.labelsHidden()`) bound to `filter`,
  placed beside the "Completed" title. A 3-option segmented control is borderline
  in the 320pt popover; the menu style is compact and consistent.
- Keep the existing `@Query` (all `isDone == true`, sorted by `completedAt`
  descending). Add a computed property that filters the queried items by
  `filter.dateRange(now:calendar:)` using `completedAt` (items with `nil`
  `completedAt` are excluded — a done item always has one, but guard anyway).
  In-memory filtering is simple and the volume is small; no dynamic-query
  reconstruction needed.
- Empty state reflects the active filter, e.g. "Nothing completed this week",
  "Nothing completed last week", "Nothing completed in the last 30 days".
- `now` comes from `Date()`; calendar from `Calendar.current`.

### Tests

`Core/Tests/DoableCoreTests/CompletedFilterTests.swift`, following the
`DuePresetTests` style with a UTC calendar and fixed reference dates:

- `displayName` values.
- This week: an item completed earlier today / earlier this week is inside; an
  item completed last week (before Monday 00:00) is outside.
- Last week: prior Mon–Sun is inside; this Monday 00:00 onward is outside; the
  Monday two weeks ago is outside (lower bound is exclusive of the week before).
- Last 30 days: 29 days ago inside, 31 days ago outside, boundary at exactly
  30 days.
- Week-boundary edges using Sunday vs Monday `now` values (reuse the existing
  2026-06-26 Fri … 06-29 Mon reference dates).

## Out of scope (YAGNI)

- Persisting the filter selection across app launches — resets to "This week"
  each time the completed view opens.
- An "All" / show-everything option (dropped per discussion).
- Any Settings-window control (deferred).
