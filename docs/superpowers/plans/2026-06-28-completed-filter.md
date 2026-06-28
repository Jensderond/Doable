# Completed-list Time Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a time-range filter (This week / Last week / Last 30 days, default This week) to the menu bar app's completed list so it stays focused on recent work.

**Architecture:** A pure, unit-tested `CompletedFilter` enum in `DoableCore` computes the `completedAt` date window for each option (Monday-based weeks). `ArchiveView` holds the selected filter in `@State` (default `.thisWeek`), shows a compact menu `Picker`, and filters its existing SwiftData query in memory.

**Tech Stack:** Swift 5.9 / Swift 6 toolchain, SwiftUI, SwiftData, XCTest. Core is a SwiftPM package (`Core/Package.swift`); the app target lives under `App/`.

## Global Constraints

- Weeks are **Monday-based**, computed explicitly via Gregorian weekday `2` (matching `DuePreset.nextWeek`), independent of `Calendar.firstWeekday`.
- Core stays free of SwiftUI/SwiftData — pure Foundation only, mirroring `DuePreset` / `Workdays`.
- All date math takes an injected `calendar` and `now: Date` (no hidden `Date()`/`Calendar.current` inside Core) so it is deterministic under test.
- Tests follow `DuePresetTests` style: `utcCalendar()` and the `date(_:_:_:...)` helper from `TestSupport.swift`, with fixed reference dates.

---

### Task 1: `CompletedFilter` enum in Core

**Files:**
- Create: `Core/Sources/DoableCore/CompletedFilter.swift`
- Test: `Core/Tests/DoableCoreTests/CompletedFilterTests.swift`

**Interfaces:**
- Consumes: nothing (pure Foundation).
- Produces:
  - `public enum CompletedFilter: String, CaseIterable, Sendable { case thisWeek, lastWeek, last30Days }`
  - `public var displayName: String` → `"This week"`, `"Last week"`, `"Last 30 days"`
  - `public func dateRange(now: Date, calendar: Calendar) -> Range<Date>` — half-open `[lower, upper)` window of `completedAt` values to include.

- [ ] **Step 1: Write the failing tests**

Create `Core/Tests/DoableCoreTests/CompletedFilterTests.swift`:

```swift
import XCTest
@testable import DoableCore

// Reference dates (UTC): 2026-06-29 Mon, 06-30 Tue ... 07-05 Sun (this week);
// 06-22 Mon ... 06-28 Sun (last week); 06-15 Mon (two weeks ago).
final class CompletedFilterTests: XCTestCase {
    let cal = utcCalendar()

    func test_displayNames() {
        XCTAssertEqual(CompletedFilter.thisWeek.displayName, "This week")
        XCTAssertEqual(CompletedFilter.lastWeek.displayName, "Last week")
        XCTAssertEqual(CompletedFilter.last30Days.displayName, "Last 30 days")
    }

    func test_allCases_order() {
        XCTAssertEqual(CompletedFilter.allCases, [.thisWeek, .lastWeek, .last30Days])
    }

    // This week = [Monday 00:00 of current week, now]
    func test_thisWeek_lowerBound_is_monday_midnight() {
        let now = date(2026, 7, 1, 14, 30, calendar: cal) // Wednesday
        let range = CompletedFilter.thisWeek.dateRange(now: now, calendar: cal)
        XCTAssertEqual(range.lowerBound, date(2026, 6, 29, 0, 0, calendar: cal))
        XCTAssertEqual(range.upperBound, now)
    }

    func test_thisWeek_includes_earlier_today_excludes_last_week() {
        let now = date(2026, 7, 1, 14, 30, calendar: cal)
        let range = CompletedFilter.thisWeek.dateRange(now: now, calendar: cal)
        XCTAssertTrue(range.contains(date(2026, 6, 29, 9, 0, calendar: cal)))  // Mon this week
        XCTAssertFalse(range.contains(date(2026, 6, 28, 23, 0, calendar: cal))) // Sun last week
    }

    func test_thisWeek_from_monday_lowerBound_is_same_day_midnight() {
        let monday = date(2026, 6, 29, 9, 0, calendar: cal)
        let range = CompletedFilter.thisWeek.dateRange(now: monday, calendar: cal)
        XCTAssertEqual(range.lowerBound, date(2026, 6, 29, 0, 0, calendar: cal))
    }

    func test_thisWeek_from_sunday_lowerBound_is_that_weeks_monday() {
        let sunday = date(2026, 7, 5, 9, 0, calendar: cal)
        let range = CompletedFilter.thisWeek.dateRange(now: sunday, calendar: cal)
        XCTAssertEqual(range.lowerBound, date(2026, 6, 29, 0, 0, calendar: cal))
    }

    // Last week = [Monday 00:00 prev week, Monday 00:00 this week)
    func test_lastWeek_bounds() {
        let now = date(2026, 7, 1, 14, 30, calendar: cal) // Wednesday
        let range = CompletedFilter.lastWeek.dateRange(now: now, calendar: cal)
        XCTAssertEqual(range.lowerBound, date(2026, 6, 22, 0, 0, calendar: cal))
        XCTAssertEqual(range.upperBound, date(2026, 6, 29, 0, 0, calendar: cal))
    }

    func test_lastWeek_includes_prev_week_excludes_this_monday_and_two_weeks_ago() {
        let now = date(2026, 7, 1, 14, 30, calendar: cal)
        let range = CompletedFilter.lastWeek.dateRange(now: now, calendar: cal)
        XCTAssertTrue(range.contains(date(2026, 6, 24, 12, 0, calendar: cal)))  // Wed last week
        XCTAssertFalse(range.contains(date(2026, 6, 29, 0, 0, calendar: cal)))  // this Monday (upper exclusive)
        XCTAssertFalse(range.contains(date(2026, 6, 21, 12, 0, calendar: cal))) // Sun two weeks ago
    }

    // Last 30 days = [now - 30 days, now]
    func test_last30Days_bounds() {
        let now = date(2026, 7, 1, 14, 30, calendar: cal)
        let range = CompletedFilter.last30Days.dateRange(now: now, calendar: cal)
        XCTAssertEqual(range.lowerBound, date(2026, 6, 1, 14, 30, calendar: cal))
        XCTAssertEqual(range.upperBound, now)
    }

    func test_last30Days_includes_29_days_ago_excludes_31_days_ago() {
        let now = date(2026, 7, 1, 14, 30, calendar: cal)
        let range = CompletedFilter.last30Days.dateRange(now: now, calendar: cal)
        XCTAssertTrue(range.contains(date(2026, 6, 2, 14, 30, calendar: cal)))  // 29 days ago
        XCTAssertFalse(range.contains(date(2026, 5, 31, 14, 30, calendar: cal))) // 31 days ago
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Core && swift test --filter CompletedFilterTests`
Expected: FAIL — `cannot find 'CompletedFilter' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Core/Sources/DoableCore/CompletedFilter.swift`:

```swift
import Foundation

/// Time-range choices for the completed list, keeping it focused on recent
/// work. Weeks are Monday-based (Gregorian weekday 2), matching `DuePreset`.
public enum CompletedFilter: String, CaseIterable, Sendable {
    case thisWeek
    case lastWeek
    case last30Days

    public var displayName: String {
        switch self {
        case .thisWeek: return "This week"
        case .lastWeek: return "Last week"
        case .last30Days: return "Last 30 days"
        }
    }

    /// Half-open `[lower, upper)` window of `completedAt` values to include,
    /// relative to `now`.
    public func dateRange(now: Date, calendar: Calendar) -> Range<Date> {
        switch self {
        case .thisWeek:
            return Self.mondayMidnight(of: now, calendar: calendar)..<now
        case .lastWeek:
            let thisMonday = Self.mondayMidnight(of: now, calendar: calendar)
            let lastMonday = calendar.date(byAdding: .day, value: -7, to: thisMonday)!
            return lastMonday..<thisMonday
        case .last30Days:
            let lower = calendar.date(byAdding: .day, value: -30, to: now)!
            return lower..<now
        }
    }

    /// Midnight (start of day) of the Monday on or before `date`.
    private static func mondayMidnight(of date: Date, calendar: Calendar) -> Date {
        let monday = 2 // Gregorian weekday number
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let back = (weekday - monday + 7) % 7
        return calendar.date(byAdding: .day, value: -back, to: startOfDay)!
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Core && swift test --filter CompletedFilterTests`
Expected: PASS (all tests green).

- [ ] **Step 5: Commit**

```bash
git add Core/Sources/DoableCore/CompletedFilter.swift Core/Tests/DoableCoreTests/CompletedFilterTests.swift
git commit -m "feat(core): add CompletedFilter time ranges"
```

---

### Task 2: Wire the filter into `ArchiveView`

**Files:**
- Modify: `App/Views/ArchiveView.swift`

**Interfaces:**
- Consumes: `CompletedFilter` from `DoableCore` (Task 1) — `displayName`, `allCases`, `dateRange(now:calendar:)`.
- Produces: UI only; no exported API.

This task has no unit test (it's a SwiftUI view in the app target, which has no
test harness). Verification is a successful app build. The filtering logic it
relies on is already covered by Task 1's tests.

- [ ] **Step 1: Add filter state and the import**

`ArchiveView.swift` already has `import SwiftUI` and `import SwiftData`. Add the
Core import at the top, after the existing imports:

```swift
import DoableCore
```

Add the selection state alongside the existing `@Query` (inside the struct, after the `@Query` line):

```swift
@State private var filter: CompletedFilter = .thisWeek
```

- [ ] **Step 2: Add the filtered-items computed property**

Add this computed property to `ArchiveView` (e.g. just above `var body`):

```swift
private var filteredItems: [TodoItem] {
    let range = filter.dateRange(now: Date(), calendar: .current)
    return items.filter { item in
        guard let completedAt = item.completedAt else { return false }
        return range.contains(completedAt)
    }
}
```

- [ ] **Step 3: Add the picker to the header**

In the header `HStack`, replace the trailing symmetry spacer with the picker so
the control balances the back button and keeps the title centered. Change:

```swift
                Spacer()
                // Symmetry spacer to keep the title centered.
                Label("Back", systemImage: "chevron.left").hidden()
            }
            .padding(10)
```

to:

```swift
                Spacer()
                Picker("Range", selection: $filter) {
                    ForEach(CompletedFilter.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }
            .padding(10)
```

- [ ] **Step 4: Use `filteredItems` for the list and empty state**

Replace the `if items.isEmpty { ... } else { ... ForEach(items) ... }` block so
both the empty check and the `ForEach` use `filteredItems`, and the empty
message reflects the active filter. Change:

```swift
            if items.isEmpty {
                Text("Nothing archived yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(items) { item in
```

to:

```swift
            if filteredItems.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredItems) { item in
```

Add the `emptyMessage` computed property next to `filteredItems`:

```swift
private var emptyMessage: String {
    switch filter {
    case .thisWeek: return "Nothing completed this week"
    case .lastWeek: return "Nothing completed last week"
    case .last30Days: return "Nothing completed in the last 30 days"
    }
}
```

- [ ] **Step 5: Build the app to verify it compiles**

Run: `swift build --package-path Core` to confirm Core still builds, then build
the app. Use the project's normal build path — there is an Xcode project/scheme
under the repo root; build it:

Run: `xcodebuild -scheme Doable -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`.

(If the scheme name differs, run `xcodebuild -list` to find it.)

- [ ] **Step 6: Commit**

```bash
git add App/Views/ArchiveView.swift
git commit -m "feat(app): filter completed list by time range"
```

---

## Self-Review

- **Spec coverage:** `CompletedFilter` enum + three ranges + Monday-based weeks → Task 1. Default `.thisWeek`, menu picker, in-memory filter, filter-aware empty state → Task 2. Tests for week/30-day boundaries → Task 1. No "All" option, no persistence, no Settings control — correctly absent. ✓
- **Placeholder scan:** All steps contain concrete code and commands; no TBD/TODO. ✓
- **Type consistency:** `dateRange(now:calendar:)`, `displayName`, `allCases` used in Task 2 match the signatures defined in Task 1. `filteredItems` / `emptyMessage` names consistent across Task 2 steps. ✓
