# Doable — Menubar Todo App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native-looking macOS menubar todo app where you click the menubar icon, type a todo, press Enter to capture it instantly; optionally attach a deadline; complete items with one click; and see due-soon/overdue state reflected on the menubar icon.

**Architecture:** All date/classification/ordering logic lives in a pure, dependency-free Swift package `DoableCore` (under `Core/`) that is unit-tested with `swift test` — no SwiftUI or SwiftData, fully deterministic via injected `Calendar`/`now`. The SwiftUI app (`App/`) is a thin shell: a `MenuBarExtra` window-style popover backed by SwiftData, which maps its `@Model TodoItem` onto `DoableCore`'s pure functions. The Xcode project is generated declaratively from `project.yml` via XcodeGen so the entire app builds from the command line.

**Tech Stack:** Swift 6.3 / Xcode 26.6, SwiftUI `MenuBarExtra` (`.window` style), SwiftData, `SMAppService` (login item), XcodeGen, XCTest.

## Global Constraints

- macOS deployment target: **14.0** (SwiftData, `@Observable`, `MenuBarExtra` window style).
- App is an **agent app**: `LSUIElement = true` — menubar icon only, no Dock icon, no main window.
- Product/working name: **Doable**; bundle identifier: **nl.redkiwi.Doable** (renameable later).
- `DoableCore` must remain pure: **no `import SwiftUI`, no `import SwiftData`, no `import AppKit`**. It must not call `Date()` internally — callers inject `now: Date` and `calendar: Calendar`.
- Due-soon window default: **today only** (`DueSoonWindow.todayOnly`). Stale threshold default: **3 workdays**.
- Menubar icon: monochrome when nothing pressing; **orange + count** for due-soon; **red + count** for overdue (red wins). Count = number of active items that are due-soon or overdue.
- Stale styling is informational only and must **not** influence the menubar icon.
- Run core tests from `Core/` with `swift test`. Build the app with `xcodegen generate` then `xcodebuild`.

---

## File Structure

```
Doable/
  Core/
    Package.swift
    Sources/DoableCore/
      Workdays.swift          # weekend-skipping date math
      DueSoonWindow.swift     # configurable window enum
      Classifier.swift        # ItemState: normal/dueSoon/overdue
      StaleRule.swift         # stale detection + snooze date
      Ordering.swift          # Orderable protocol + active sort
      MenuBarState.swift      # aggregate severity + count
    Tests/DoableCoreTests/
      TestSupport.swift       # fixed calendar + date(...) helper
      WorkdaysTests.swift
      ClassifierTests.swift
      StaleRuleTests.swift
      OrderingTests.swift
      MenuBarStateTests.swift
  App/
    DoableApp.swift           # @main, MenuBarExtra scene, ModelContainer
    Models/
      TodoItem.swift          # SwiftData @Model, conforms to Orderable
      TodoStore.swift         # create/complete/undo/commit/snooze ops
    Views/
      MenuContentView.swift   # popover root: input + list + nav
      TodoRowView.swift       # one row: circle, title, clock, due/stale styling
      DeadlineEditor.swift    # date/time picker popover
      ArchiveView.swift       # separate completed-items screen
      SettingsView.swift      # login toggle + window + threshold
      MenuBarLabel.swift      # icon color + count
    System/
      LoginItemManager.swift  # SMAppService wrapper
    Resources/
      Info.plist              # LSUIElement etc.
    Doable.entitlements
  project.yml                 # XcodeGen spec
  Doable.xcodeproj            # generated (gitignored)
```

`Doable.xcodeproj`, `build/`, and `.build/` are gitignored (`.gitignore` already present from the design commit; extend it in Task 6).

---

### Task 1: Core package scaffold + Workdays utility

**Files:**
- Create: `Core/Package.swift`
- Create: `Core/Sources/DoableCore/Workdays.swift`
- Create: `Core/Tests/DoableCoreTests/TestSupport.swift`
- Test: `Core/Tests/DoableCoreTests/WorkdaysTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum Workdays` with:
    - `static func adding(_ count: Int, workdaysTo date: Date, calendar: Calendar) -> Date`
    - `static func workdaysElapsed(from start: Date, to end: Date, calendar: Calendar) -> Int`
  - Test helpers in `TestSupport.swift`: `func utcCalendar() -> Calendar` and `func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, calendar: Calendar) -> Date`.

- [ ] **Step 1: Create the package manifest**

`Core/Package.swift`:
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DoableCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DoableCore", targets: ["DoableCore"]),
    ],
    targets: [
        .target(name: "DoableCore"),
        .testTarget(name: "DoableCoreTests", dependencies: ["DoableCore"]),
    ]
)
```

- [ ] **Step 2: Create the test support helper**

`Core/Tests/DoableCoreTests/TestSupport.swift`:
```swift
import Foundation

/// A deterministic Gregorian calendar pinned to UTC so weekend/day math is stable across machines.
func utcCalendar() -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}

func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0, calendar: Calendar) -> Date {
    calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
}
```

- [ ] **Step 3: Write the failing tests**

`Core/Tests/DoableCoreTests/WorkdaysTests.swift`:
```swift
import XCTest
@testable import DoableCore

// Reference dates: 2026-06-26 is a Friday; 06-27 Sat, 06-28 Sun, 06-29 Mon, 06-30 Tue, 07-01 Wed.
final class WorkdaysTests: XCTestCase {
    let cal = utcCalendar()

    func test_adding_zero_workdays_returns_same_date() {
        let friday = date(2026, 6, 26, 9, 0, calendar: cal)
        XCTAssertEqual(Workdays.adding(0, workdaysTo: friday, calendar: cal), friday)
    }

    func test_adding_workdays_skips_weekend() {
        let friday = date(2026, 6, 26, 9, 0, calendar: cal)
        // +3 workdays from Friday: Mon(1), Tue(2), Wed(3) -> 2026-07-01 09:00
        let expected = date(2026, 7, 1, 9, 0, calendar: cal)
        XCTAssertEqual(Workdays.adding(3, workdaysTo: friday, calendar: cal), expected)
    }

    func test_adding_one_workday_from_friday_is_monday() {
        let friday = date(2026, 6, 26, 12, 0, calendar: cal)
        let expected = date(2026, 6, 29, 12, 0, calendar: cal)
        XCTAssertEqual(Workdays.adding(1, workdaysTo: friday, calendar: cal), expected)
    }

    func test_workdaysElapsed_counts_weekdays_after_start() {
        let friday = date(2026, 6, 26, 9, 0, calendar: cal)
        let wednesday = date(2026, 7, 1, 9, 0, calendar: cal)
        // After Fri: Sat(no), Sun(no), Mon(1), Tue(2), Wed(3)
        XCTAssertEqual(Workdays.workdaysElapsed(from: friday, to: wednesday, calendar: cal), 3)
    }

    func test_workdaysElapsed_zero_when_end_not_after_start() {
        let friday = date(2026, 6, 26, 9, 0, calendar: cal)
        XCTAssertEqual(Workdays.workdaysElapsed(from: friday, to: friday, calendar: cal), 0)
    }
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `cd Core && swift test`
Expected: FAIL — `cannot find 'Workdays' in scope`.

- [ ] **Step 5: Implement Workdays**

`Core/Sources/DoableCore/Workdays.swift`:
```swift
import Foundation

/// Weekend-skipping date arithmetic. Saturdays and Sundays (per the supplied calendar) are not workdays.
public enum Workdays {
    /// Advances `date` by `count` workdays, preserving time-of-day. `count` must be >= 0.
    public static func adding(_ count: Int, workdaysTo date: Date, calendar: Calendar) -> Date {
        guard count > 0 else { return date }
        var result = date
        var remaining = count
        while remaining > 0 {
            result = calendar.date(byAdding: .day, value: 1, to: result)!
            if !calendar.isDateInWeekend(result) {
                remaining -= 1
            }
        }
        return result
    }

    /// Whole workdays elapsed from `start` to `end` (weekends excluded). Counts each weekday
    /// strictly after `start`'s day, up to and including `end`'s day. Returns 0 if `end <= start`.
    public static func workdaysElapsed(from start: Date, to end: Date, calendar: Calendar) -> Int {
        guard end > start else { return 0 }
        var count = 0
        var cursor = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        while cursor < endDay {
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
            if !calendar.isDateInWeekend(cursor) {
                count += 1
            }
        }
        return count
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd Core && swift test`
Expected: PASS (5 tests in WorkdaysTests).

- [ ] **Step 7: Commit**

```bash
git add Core/Package.swift Core/Sources Core/Tests
git commit -m "feat(core): add DoableCore package with workday date math"
```

---

### Task 2: DueSoonWindow + ItemState classifier

**Files:**
- Create: `Core/Sources/DoableCore/DueSoonWindow.swift`
- Create: `Core/Sources/DoableCore/Classifier.swift`
- Test: `Core/Tests/DoableCoreTests/ClassifierTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum DueSoonWindow: String, CaseIterable, Codable, Sendable { case todayOnly, oneHour, twentyFourHours, threeDays }`
  - `enum ItemState: String, Sendable { case normal, dueSoon, overdue }`
  - `enum Classifier` with `static func itemState(dueDate: Date?, now: Date, window: DueSoonWindow, calendar: Calendar) -> ItemState`

- [ ] **Step 1: Write the failing tests**

`Core/Tests/DoableCoreTests/ClassifierTests.swift`:
```swift
import XCTest
@testable import DoableCore

final class ClassifierTests: XCTestCase {
    let cal = utcCalendar()
    lazy var now = date(2026, 6, 26, 12, 0, calendar: cal) // Fri noon

    func test_no_due_date_is_normal() {
        XCTAssertEqual(Classifier.itemState(dueDate: nil, now: now, window: .todayOnly, calendar: cal), .normal)
    }

    func test_past_due_date_is_overdue() {
        let past = date(2026, 6, 26, 11, 0, calendar: cal)
        XCTAssertEqual(Classifier.itemState(dueDate: past, now: now, window: .todayOnly, calendar: cal), .overdue)
    }

    func test_todayOnly_later_today_is_dueSoon() {
        let laterToday = date(2026, 6, 26, 18, 0, calendar: cal)
        XCTAssertEqual(Classifier.itemState(dueDate: laterToday, now: now, window: .todayOnly, calendar: cal), .dueSoon)
    }

    func test_todayOnly_tomorrow_is_normal() {
        let tomorrow = date(2026, 6, 27, 9, 0, calendar: cal)
        XCTAssertEqual(Classifier.itemState(dueDate: tomorrow, now: now, window: .todayOnly, calendar: cal), .normal)
    }

    func test_oneHour_window_boundary() {
        let within = date(2026, 6, 26, 12, 59, calendar: cal)
        let beyond = date(2026, 6, 26, 13, 30, calendar: cal)
        XCTAssertEqual(Classifier.itemState(dueDate: within, now: now, window: .oneHour, calendar: cal), .dueSoon)
        XCTAssertEqual(Classifier.itemState(dueDate: beyond, now: now, window: .oneHour, calendar: cal), .normal)
    }

    func test_threeDays_window() {
        let inTwoDays = date(2026, 6, 28, 12, 0, calendar: cal)
        XCTAssertEqual(Classifier.itemState(dueDate: inTwoDays, now: now, window: .threeDays, calendar: cal), .dueSoon)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Core && swift test --filter ClassifierTests`
Expected: FAIL — `cannot find 'Classifier' in scope`.

- [ ] **Step 3: Implement DueSoonWindow**

`Core/Sources/DoableCore/DueSoonWindow.swift`:
```swift
import Foundation

/// The configurable look-ahead window that defines "due soon".
public enum DueSoonWindow: String, CaseIterable, Codable, Sendable {
    case todayOnly
    case oneHour
    case twentyFourHours
    case threeDays

    public var displayName: String {
        switch self {
        case .todayOnly: return "Today only"
        case .oneHour: return "Within 1 hour"
        case .twentyFourHours: return "Within 24 hours"
        case .threeDays: return "Within 3 days"
        }
    }
}
```

- [ ] **Step 4: Implement Classifier**

`Core/Sources/DoableCore/Classifier.swift`:
```swift
import Foundation

/// Per-item due state. Stale-ness is handled separately (see StaleRule).
public enum ItemState: String, Sendable {
    case normal
    case dueSoon
    case overdue
}

public enum Classifier {
    /// Classifies an item by its deadline relative to `now`. Undated items are `.normal`.
    public static func itemState(dueDate: Date?, now: Date, window: DueSoonWindow, calendar: Calendar) -> ItemState {
        guard let dueDate else { return .normal }
        if dueDate < now { return .overdue }
        return isWithinWindow(dueDate: dueDate, now: now, window: window, calendar: calendar) ? .dueSoon : .normal
    }

    static func isWithinWindow(dueDate: Date, now: Date, window: DueSoonWindow, calendar: Calendar) -> Bool {
        switch window {
        case .todayOnly:
            return calendar.isDate(dueDate, inSameDayAs: now)
        case .oneHour:
            return dueDate <= now.addingTimeInterval(60 * 60)
        case .twentyFourHours:
            return dueDate <= now.addingTimeInterval(24 * 60 * 60)
        case .threeDays:
            return dueDate <= now.addingTimeInterval(3 * 24 * 60 * 60)
        }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd Core && swift test --filter ClassifierTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Core/Sources/DoableCore/DueSoonWindow.swift Core/Sources/DoableCore/Classifier.swift Core/Tests/DoableCoreTests/ClassifierTests.swift
git commit -m "feat(core): add DueSoonWindow and item state classifier"
```

---

### Task 3: StaleRule

**Files:**
- Create: `Core/Sources/DoableCore/StaleRule.swift`
- Test: `Core/Tests/DoableCoreTests/StaleRuleTests.swift`

**Interfaces:**
- Consumes: `Workdays` (Task 1).
- Produces:
  - `enum StaleRule` with:
    - `static func isStale(createdAt: Date, dueDate: Date?, snoozeUntil: Date?, now: Date, thresholdWorkdays: Int, calendar: Calendar) -> Bool`
    - `static func snoozeDate(from now: Date, thresholdWorkdays: Int, calendar: Calendar) -> Date`

- [ ] **Step 1: Write the failing tests**

`Core/Tests/DoableCoreTests/StaleRuleTests.swift`:
```swift
import XCTest
@testable import DoableCore

final class StaleRuleTests: XCTestCase {
    let cal = utcCalendar()
    let created = date(2026, 6, 26, 9, 0, calendar: utcCalendar()) // Friday

    func test_dated_item_is_never_stale() {
        let now = date(2026, 7, 10, 9, 0, calendar: cal) // well past threshold
        let due = date(2026, 8, 1, 9, 0, calendar: cal)
        XCTAssertFalse(StaleRule.isStale(createdAt: created, dueDate: due, snoozeUntil: nil, now: now, thresholdWorkdays: 3, calendar: cal))
    }

    func test_undated_item_below_threshold_is_not_stale() {
        let now = date(2026, 6, 30, 9, 0, calendar: cal) // Tue: workdays elapsed = Mon,Tue = 2
        XCTAssertFalse(StaleRule.isStale(createdAt: created, dueDate: nil, snoozeUntil: nil, now: now, thresholdWorkdays: 3, calendar: cal))
    }

    func test_undated_item_at_threshold_is_stale() {
        let now = date(2026, 7, 1, 9, 0, calendar: cal) // Wed: workdays elapsed = Mon,Tue,Wed = 3
        XCTAssertTrue(StaleRule.isStale(createdAt: created, dueDate: nil, snoozeUntil: nil, now: now, thresholdWorkdays: 3, calendar: cal))
    }

    func test_snoozed_item_is_not_stale_until_snooze_passes() {
        let now = date(2026, 7, 1, 9, 0, calendar: cal)
        let snooze = date(2026, 7, 6, 9, 0, calendar: cal) // future
        XCTAssertFalse(StaleRule.isStale(createdAt: created, dueDate: nil, snoozeUntil: snooze, now: now, thresholdWorkdays: 3, calendar: cal))
    }

    func test_snooze_in_past_does_not_suppress() {
        let now = date(2026, 7, 8, 9, 0, calendar: cal)
        let snooze = date(2026, 7, 6, 9, 0, calendar: cal) // already passed
        XCTAssertTrue(StaleRule.isStale(createdAt: created, dueDate: nil, snoozeUntil: snooze, now: now, thresholdWorkdays: 3, calendar: cal))
    }

    func test_snoozeDate_advances_by_threshold_workdays() {
        let now = date(2026, 6, 26, 9, 0, calendar: cal) // Friday
        let expected = date(2026, 7, 1, 9, 0, calendar: cal) // +3 workdays -> Wed
        XCTAssertEqual(StaleRule.snoozeDate(from: now, thresholdWorkdays: 3, calendar: cal), expected)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Core && swift test --filter StaleRuleTests`
Expected: FAIL — `cannot find 'StaleRule' in scope`.

- [ ] **Step 3: Implement StaleRule**

`Core/Sources/DoableCore/StaleRule.swift`:
```swift
import Foundation

/// Determines whether an undated item has gone "stale" (sat untouched too long) and computes
/// the snooze date used by the Postpone action.
public enum StaleRule {
    /// True when the item has no deadline, is not currently snoozed, and at least
    /// `thresholdWorkdays` workdays have elapsed since `createdAt`.
    public static func isStale(createdAt: Date,
                               dueDate: Date?,
                               snoozeUntil: Date?,
                               now: Date,
                               thresholdWorkdays: Int,
                               calendar: Calendar) -> Bool {
        guard dueDate == nil else { return false }
        if let snoozeUntil, now < snoozeUntil { return false }
        return Workdays.workdaysElapsed(from: createdAt, to: now, calendar: calendar) >= thresholdWorkdays
    }

    /// The date until which the stale label should be suppressed after a Postpone.
    public static func snoozeDate(from now: Date, thresholdWorkdays: Int, calendar: Calendar) -> Date {
        Workdays.adding(thresholdWorkdays, workdaysTo: now, calendar: calendar)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Core && swift test --filter StaleRuleTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Core/Sources/DoableCore/StaleRule.swift Core/Tests/DoableCoreTests/StaleRuleTests.swift
git commit -m "feat(core): add stale-item rule with workday snooze"
```

---

### Task 4: Ordering

**Files:**
- Create: `Core/Sources/DoableCore/Ordering.swift`
- Test: `Core/Tests/DoableCoreTests/OrderingTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `protocol Orderable { var dueDate: Date? { get }; var createdAt: Date { get } }`
  - `enum Ordering` with `static func activeSorted<T: Orderable>(_ items: [T]) -> [T]`

- [ ] **Step 1: Write the failing tests**

`Core/Tests/DoableCoreTests/OrderingTests.swift`:
```swift
import XCTest
@testable import DoableCore

private struct Stub: Orderable, Equatable {
    let name: String
    let dueDate: Date?
    let createdAt: Date
}

final class OrderingTests: XCTestCase {
    let cal = utcCalendar()

    func test_dated_items_sort_before_undated() {
        let dated = Stub(name: "dated", dueDate: date(2026, 7, 1, 9, 0, calendar: cal), createdAt: date(2026, 6, 1, 9, 0, calendar: cal))
        let undated = Stub(name: "undated", dueDate: nil, createdAt: date(2026, 6, 26, 9, 0, calendar: cal))
        let sorted = Ordering.activeSorted([undated, dated])
        XCTAssertEqual(sorted.map(\.name), ["dated", "undated"])
    }

    func test_dated_items_sort_by_soonest_first() {
        let late = Stub(name: "late", dueDate: date(2026, 7, 5, 9, 0, calendar: cal), createdAt: date(2026, 6, 1, 9, 0, calendar: cal))
        let soon = Stub(name: "soon", dueDate: date(2026, 6, 28, 9, 0, calendar: cal), createdAt: date(2026, 6, 1, 9, 0, calendar: cal))
        let sorted = Ordering.activeSorted([late, soon])
        XCTAssertEqual(sorted.map(\.name), ["soon", "late"])
    }

    func test_undated_items_sort_newest_first() {
        let older = Stub(name: "older", dueDate: nil, createdAt: date(2026, 6, 20, 9, 0, calendar: cal))
        let newer = Stub(name: "newer", dueDate: nil, createdAt: date(2026, 6, 25, 9, 0, calendar: cal))
        let sorted = Ordering.activeSorted([older, newer])
        XCTAssertEqual(sorted.map(\.name), ["newer", "older"])
    }

    func test_same_deadline_breaks_tie_newest_first() {
        let due = date(2026, 7, 1, 9, 0, calendar: cal)
        let older = Stub(name: "older", dueDate: due, createdAt: date(2026, 6, 20, 9, 0, calendar: cal))
        let newer = Stub(name: "newer", dueDate: due, createdAt: date(2026, 6, 25, 9, 0, calendar: cal))
        let sorted = Ordering.activeSorted([older, newer])
        XCTAssertEqual(sorted.map(\.name), ["newer", "older"])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Core && swift test --filter OrderingTests`
Expected: FAIL — `cannot find type 'Orderable' in scope`.

- [ ] **Step 3: Implement Ordering**

`Core/Sources/DoableCore/Ordering.swift`:
```swift
import Foundation

/// Anything sortable in the active list. The app's SwiftData model conforms to this.
public protocol Orderable {
    var dueDate: Date? { get }
    var createdAt: Date { get }
}

public enum Ordering {
    /// Active-list order: dated items first (soonest deadline ascending); undated items after;
    /// newest-first (`createdAt` descending) as the tiebreaker and among undated items.
    public static func activeSorted<T: Orderable>(_ items: [T]) -> [T] {
        items.sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?):
                if l != r { return l < r }
                return lhs.createdAt > rhs.createdAt
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.createdAt > rhs.createdAt
            }
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Core && swift test --filter OrderingTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Core/Sources/DoableCore/Ordering.swift Core/Tests/DoableCoreTests/OrderingTests.swift
git commit -m "feat(core): add active-list ordering"
```

---

### Task 5: MenuBarState aggregation

**Files:**
- Create: `Core/Sources/DoableCore/MenuBarState.swift`
- Test: `Core/Tests/DoableCoreTests/MenuBarStateTests.swift`

**Interfaces:**
- Consumes: `Orderable` (Task 4), `Classifier` + `DueSoonWindow` (Task 2).
- Produces:
  - `enum Severity: String, Sendable { case normal, dueSoon, overdue }`
  - `struct MenuBarState: Equatable, Sendable { let severity: Severity; let count: Int }`
  - `enum MenuBarStateCalculator` with `static func state<T: Orderable>(items: [T], now: Date, window: DueSoonWindow, calendar: Calendar) -> MenuBarState`

- [ ] **Step 1: Write the failing tests**

`Core/Tests/DoableCoreTests/MenuBarStateTests.swift`:
```swift
import XCTest
@testable import DoableCore

private struct Stub: Orderable {
    let dueDate: Date?
    let createdAt: Date
}

final class MenuBarStateTests: XCTestCase {
    let cal = utcCalendar()
    lazy var now = date(2026, 6, 26, 12, 0, calendar: cal) // Fri noon
    private func stub(due: Date?) -> Stub { Stub(dueDate: due, createdAt: date(2026, 6, 1, 9, 0, calendar: cal)) }

    func test_empty_is_normal_zero() {
        let s = MenuBarStateCalculator.state(items: [Stub](), now: now, window: .todayOnly, calendar: cal)
        XCTAssertEqual(s, MenuBarState(severity: .normal, count: 0))
    }

    func test_only_future_items_is_normal_zero() {
        let items = [stub(due: date(2026, 7, 10, 9, 0, calendar: cal)), stub(due: nil)]
        let s = MenuBarStateCalculator.state(items: items, now: now, window: .todayOnly, calendar: cal)
        XCTAssertEqual(s, MenuBarState(severity: .normal, count: 0))
    }

    func test_dueSoon_only() {
        let items = [stub(due: date(2026, 6, 26, 18, 0, calendar: cal)), stub(due: date(2026, 6, 26, 20, 0, calendar: cal))]
        let s = MenuBarStateCalculator.state(items: items, now: now, window: .todayOnly, calendar: cal)
        XCTAssertEqual(s, MenuBarState(severity: .dueSoon, count: 2))
    }

    func test_overdue_takes_priority_and_counts_both() {
        let items = [
            stub(due: date(2026, 6, 26, 11, 0, calendar: cal)), // overdue
            stub(due: date(2026, 6, 26, 18, 0, calendar: cal)),  // due soon
        ]
        let s = MenuBarStateCalculator.state(items: items, now: now, window: .todayOnly, calendar: cal)
        XCTAssertEqual(s, MenuBarState(severity: .overdue, count: 2))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Core && swift test --filter MenuBarStateTests`
Expected: FAIL — `cannot find 'MenuBarStateCalculator' in scope`.

- [ ] **Step 3: Implement MenuBarState**

`Core/Sources/DoableCore/MenuBarState.swift`:
```swift
import Foundation

public enum Severity: String, Sendable {
    case normal
    case dueSoon
    case overdue
}

public struct MenuBarState: Equatable, Sendable {
    public let severity: Severity
    public let count: Int
    public init(severity: Severity, count: Int) {
        self.severity = severity
        self.count = count
    }
}

public enum MenuBarStateCalculator {
    /// Aggregates active items: severity is the worst present (overdue > dueSoon > normal);
    /// count is the number of items that are due-soon or overdue.
    public static func state<T: Orderable>(items: [T], now: Date, window: DueSoonWindow, calendar: Calendar) -> MenuBarState {
        var count = 0
        var hasOverdue = false
        var hasDueSoon = false
        for item in items {
            switch Classifier.itemState(dueDate: item.dueDate, now: now, window: window, calendar: calendar) {
            case .overdue:
                hasOverdue = true
                count += 1
            case .dueSoon:
                hasDueSoon = true
                count += 1
            case .normal:
                break
            }
        }
        let severity: Severity = hasOverdue ? .overdue : (hasDueSoon ? .dueSoon : .normal)
        return MenuBarState(severity: severity, count: count)
    }
}
```

- [ ] **Step 4: Run all core tests to verify they pass**

Run: `cd Core && swift test`
Expected: PASS (all suites).

- [ ] **Step 5: Commit**

```bash
git add Core/Sources/DoableCore/MenuBarState.swift Core/Tests/DoableCoreTests/MenuBarStateTests.swift
git commit -m "feat(core): add aggregate menubar state calculator"
```

---

### Task 6: App scaffold — XcodeGen project that builds and shows a menubar icon

**Files:**
- Create: `project.yml`
- Create: `App/Resources/Info.plist`
- Create: `App/Doable.entitlements`
- Create: `App/DoableApp.swift`
- Create: `App/Views/MenuContentView.swift` (placeholder)
- Create: `App/Views/MenuBarLabel.swift` (static placeholder)
- Modify: `.gitignore`

**Interfaces:**
- Consumes: `DoableCore` package (Tasks 1–5) as a local SPM dependency.
- Produces: a buildable `Doable.xcodeproj`, `@main struct DoableApp`, and the menubar scene. Later tasks replace the placeholder views.

**Prerequisite:** `xcodegen` must be installed (`brew install xcodegen`). Confirmed available in this environment.

- [ ] **Step 1: Extend .gitignore**

Append to `.gitignore`:
```
Doable.xcodeproj/
build/
.build/
*.xcuserstate
```

- [ ] **Step 2: Write the XcodeGen spec**

`project.yml`:
```yaml
name: Doable
options:
  bundleIdPrefix: nl.redkiwi
  deploymentTarget:
    macOS: "14.0"
packages:
  DoableCore:
    path: Core
targets:
  Doable:
    type: application
    platform: macOS
    sources:
      - App
    dependencies:
      - package: DoableCore
        product: DoableCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: nl.redkiwi.Doable
        PRODUCT_NAME: Doable
        MARKETING_VERSION: "1.0"
        CURRENT_PROJECT_VERSION: "1"
        GENERATE_INFOPLIST_FILE: NO
        INFOPLIST_FILE: App/Resources/Info.plist
        CODE_SIGN_ENTITLEMENTS: App/Doable.entitlements
        CODE_SIGN_STYLE: Automatic
        ENABLE_HARDENED_RUNTIME: YES
        SWIFT_VERSION: "5.0"
```

- [ ] **Step 3: Write Info.plist (agent app)**

`App/Resources/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Doable</string>
    <key>CFBundleDisplayName</key>
    <string>Doable</string>
    <key>CFBundleIdentifier</key>
    <string>nl.redkiwi.Doable</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
```

- [ ] **Step 4: Write entitlements**

`App/Doable.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 5: Write a static placeholder MenuBarLabel**

`App/Views/MenuBarLabel.swift`:
```swift
import SwiftUI

struct MenuBarLabel: View {
    var body: some View {
        Image(systemName: "checklist")
    }
}
```

- [ ] **Step 6: Write a placeholder MenuContentView**

`App/Views/MenuContentView.swift`:
```swift
import SwiftUI

struct MenuContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Doable")
                .font(.headline)
            Text("Hello from the menubar.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 320)
    }
}
```

- [ ] **Step 7: Write the app entry point**

`App/DoableApp.swift`:
```swift
import SwiftUI

@main
struct DoableApp: App {
    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 8: Generate the Xcode project**

Run: `xcodegen generate`
Expected: `Created project at .../Doable.xcodeproj`.

- [ ] **Step 9: Build**

Run: `xcodebuild -project Doable.xcodeproj -scheme Doable -configuration Debug -derivedDataPath build build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 10: Run and verify manually**

Run: `open build/Build/Products/Debug/Doable.app`
Verify:
- A `checklist` icon appears in the menubar.
- **No** Dock icon appears (agent app).
- Clicking the icon shows a small native popover panel with "Doable / Hello from the menubar."

Quit before continuing: `osascript -e 'quit app "Doable"'` (or click away and `pkill -x Doable`).

- [ ] **Step 11: Commit**

```bash
git add .gitignore project.yml App
git commit -m "feat(app): scaffold MenuBarExtra agent app via XcodeGen"
```

---

### Task 7: SwiftData model, store, and the type-and-enter active list

**Files:**
- Create: `App/Models/TodoItem.swift`
- Create: `App/Models/TodoStore.swift`
- Modify: `App/DoableApp.swift`
- Modify: `App/Views/MenuContentView.swift`

**Interfaces:**
- Consumes: `Ordering` (Task 4) and the SwiftData framework.
- Produces:
  - `@Model final class TodoItem: Orderable` with `id: UUID`, `title: String`, `createdAt: Date`, `dueDate: Date?`, `isDone: Bool`, `completedAt: Date?`, `staleSnoozeUntil: Date?`.
  - `@Observable final class TodoStore` with `var pendingDone: Set<UUID>`, `func create(title:in:)`, `func markDone(_:)`, `func undo(_:)`, `func setDueDate(_:for:in:)`, `func postponeStale(_:now:thresholdWorkdays:calendar:in:)`, `func commitPendingDone(in:)`.

- [ ] **Step 1: Create the SwiftData model**

`App/Models/TodoItem.swift`:
```swift
import Foundation
import SwiftData
import DoableCore

@Model
final class TodoItem: Orderable {
    var id: UUID
    var title: String
    var createdAt: Date
    var dueDate: Date?
    var isDone: Bool
    var completedAt: Date?
    var staleSnoozeUntil: Date?

    init(title: String, createdAt: Date, dueDate: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.isDone = false
        self.completedAt = nil
        self.staleSnoozeUntil = nil
    }
}
```

- [ ] **Step 2: Create the store**

`App/Models/TodoStore.swift`:
```swift
import Foundation
import SwiftData
import Observation
import DoableCore

/// Coordinates todo mutations and holds the transient "pending done" set used for the
/// undo-until-popover-closes behavior.
@Observable
final class TodoStore {
    /// IDs of items the user has checked off while the popover is open. Committed on close.
    var pendingDone: Set<UUID> = []

    func create(title: String, in context: ModelContext) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        context.insert(TodoItem(title: trimmed, createdAt: Date()))
        save(context)
    }

    func markDone(_ item: TodoItem) {
        pendingDone.insert(item.id)
    }

    func undo(_ item: TodoItem) {
        pendingDone.remove(item.id)
    }

    func setDueDate(_ date: Date?, for item: TodoItem, in context: ModelContext) {
        item.dueDate = date
        if date != nil { item.staleSnoozeUntil = nil }
        save(context)
    }

    func postponeStale(_ item: TodoItem, now: Date, thresholdWorkdays: Int, calendar: Calendar, in context: ModelContext) {
        item.staleSnoozeUntil = StaleRule.snoozeDate(from: now, thresholdWorkdays: thresholdWorkdays, calendar: calendar)
        save(context)
    }

    /// Commits all pending-done items to the archive. Called when the popover closes.
    func commitPendingDone(in context: ModelContext) {
        guard !pendingDone.isEmpty else { return }
        let ids = pendingDone
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.isDone == false })
        if let items = try? context.fetch(descriptor) {
            let now = Date()
            for item in items where ids.contains(item.id) {
                item.isDone = true
                item.completedAt = now
            }
        }
        pendingDone.removeAll()
        save(context)
    }

    private func save(_ context: ModelContext) {
        do { try context.save() } catch { print("SwiftData save failed: \(error)") }
    }
}
```

- [ ] **Step 3: Wire the ModelContainer and store into the app**

Replace `App/DoableApp.swift` with:
```swift
import SwiftUI
import SwiftData

@main
struct DoableApp: App {
    @State private var store = TodoStore()
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: TodoItem.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(store: store)
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
        .modelContainer(container)
    }
}
```

- [ ] **Step 4: Build the input field + active list**

Replace `App/Views/MenuContentView.swift` with:
```swift
import SwiftUI
import SwiftData
import DoableCore

struct MenuContentView: View {
    @Bindable var store: TodoStore
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<TodoItem> { $0.isDone == false }) private var rawItems: [TodoItem]

    @State private var newTitle = ""
    @FocusState private var inputFocused: Bool

    private var sortedItems: [TodoItem] { Ordering.activeSorted(rawItems) }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Add a todo…", text: $newTitle)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(10)
                .focused($inputFocused)
                .onSubmit(addItem)

            Divider()

            if sortedItems.isEmpty {
                Text("No todos")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(sortedItems) { item in
                            Text(item.title)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 320)
        .onAppear { inputFocused = true }
    }

    private func addItem() {
        store.create(title: newTitle, in: context)
        newTitle = ""
        inputFocused = true
    }
}
```

- [ ] **Step 5: Regenerate, build**

Run: `xcodegen generate && xcodebuild -project Doable.xcodeproj -scheme Doable -configuration Debug -derivedDataPath build build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Run and verify manually**

Run: `open build/Build/Products/Debug/Doable.app`
Verify:
- Clicking the menubar icon shows the popover with a focused text field (cursor blinking).
- Typing a title and pressing Enter adds it to the list and clears the field, focus retained.
- Adding several in a row works.
- Closing and reopening the popover (and quitting/relaunching the app) preserves items (SwiftData persistence).

Quit: `pkill -x Doable`.

- [ ] **Step 7: Commit**

```bash
git add App
git commit -m "feat(app): SwiftData todo model, store, and type-and-enter list"
```

---

### Task 8: Completion circle, undo-while-open, commit-on-close

**Files:**
- Create: `App/Views/TodoRowView.swift`
- Modify: `App/Views/MenuContentView.swift`

**Interfaces:**
- Consumes: `TodoStore` (Task 7), `TodoItem` (Task 7).
- Produces: `struct TodoRowView: View` taking `store: TodoStore` and `item: TodoItem`. Renders a completion circle on the left, the title, and an inline Undo for pending-done items. `MenuContentView` gains `.onDisappear { store.commitPendingDone(in: context) }`.

- [ ] **Step 1: Create the row view**

`App/Views/TodoRowView.swift`:
```swift
import SwiftUI
import SwiftData
import DoableCore

struct TodoRowView: View {
    @Bindable var store: TodoStore
    let item: TodoItem
    @Environment(\.modelContext) private var context

    private var isPendingDone: Bool { store.pendingDone.contains(item.id) }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: toggleDone) {
                Image(systemName: isPendingDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isPendingDone ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)

            Text(item.title)
                .strikethrough(isPendingDone)
                .foregroundStyle(isPendingDone ? Color.secondary : Color.primary)

            Spacer(minLength: 8)

            if isPendingDone {
                Button("Undo") { store.undo(item) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggleDone() {
        if isPendingDone { store.undo(item) } else { store.markDone(item) }
    }
}
```

- [ ] **Step 2: Use the row view and commit on close**

In `App/Views/MenuContentView.swift`, replace the `ForEach` body:
```swift
                        ForEach(sortedItems) { item in
                            Text(item.title)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
```
with:
```swift
                        ForEach(sortedItems) { item in
                            TodoRowView(store: store, item: item)
                        }
```
and add this modifier to the root `VStack` (after `.onAppear { inputFocused = true }`):
```swift
        .onDisappear { store.commitPendingDone(in: context) }
```

- [ ] **Step 3: Regenerate, build**

Run: `xcodegen generate && xcodebuild -project Doable.xcodeproj -scheme Doable -configuration Debug -derivedDataPath build build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run and verify manually**

Run: `open build/Build/Products/Debug/Doable.app`
Verify:
- Each row has a circle on the left; clicking it fills the circle, strikes through the title, and shows "Undo".
- Clicking "Undo" (while the popover is still open) restores the item.
- Closing the popover then reopening it: the checked items are gone from the active list (archived). Items left unchecked remain.

Quit: `pkill -x Doable`.

- [ ] **Step 5: Commit**

```bash
git add App
git commit -m "feat(app): completion circle with undo-until-close archiving"
```

---

### Task 9: Hover clock + deadline editor + due styling

**Files:**
- Create: `App/Views/DeadlineEditor.swift`
- Modify: `App/Views/TodoRowView.swift`

**Interfaces:**
- Consumes: `Classifier`, `DueSoonWindow` (Task 2), `TodoStore.setDueDate` (Task 7).
- Produces: `struct DeadlineEditor: View` taking `item: TodoItem`, `store: TodoStore`, and a binding/closure to dismiss; presents a `DatePicker` (date + time), a "Clear" action, and a "Done" action. `TodoRowView` gains a hover-revealed clock button and due-state coloring.

- [ ] **Step 1: Create the deadline editor**

`App/Views/DeadlineEditor.swift`:
```swift
import SwiftUI
import SwiftData

struct DeadlineEditor: View {
    @Bindable var store: TodoStore
    let item: TodoItem
    @Environment(\.modelContext) private var context
    @Binding var isPresented: Bool

    @State private var date: Date

    init(store: TodoStore, item: TodoItem, isPresented: Binding<Bool>) {
        self.store = store
        self.item = item
        self._isPresented = isPresented
        self._date = State(initialValue: item.dueDate ?? Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker("Due", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .labelsHidden()

            HStack {
                if item.dueDate != nil {
                    Button("Clear") {
                        store.setDueDate(nil, for: item, in: context)
                        isPresented = false
                    }
                }
                Spacer()
                Button("Done") {
                    store.setDueDate(date, for: item, in: context)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 240)
    }
}
```

- [ ] **Step 2: Add hover clock + due coloring to the row**

Replace `App/Views/TodoRowView.swift` with:
```swift
import SwiftUI
import SwiftData
import DoableCore

struct TodoRowView: View {
    @Bindable var store: TodoStore
    let item: TodoItem
    @Environment(\.modelContext) private var context
    @AppStorage("dueSoonWindow") private var windowRaw = DueSoonWindow.todayOnly.rawValue

    @State private var hovering = false
    @State private var showDeadlineEditor = false

    private var isPendingDone: Bool { store.pendingDone.contains(item.id) }
    private var window: DueSoonWindow { DueSoonWindow(rawValue: windowRaw) ?? .todayOnly }

    private var dueColor: Color? {
        guard !isPendingDone else { return nil }
        switch Classifier.itemState(dueDate: item.dueDate, now: Date(), window: window, calendar: .current) {
        case .overdue: return .red
        case .dueSoon: return .orange
        case .normal: return nil
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: toggleDone) {
                Image(systemName: isPendingDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isPendingDone ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .strikethrough(isPendingDone)
                    .foregroundStyle(titleColor)
                if let due = item.dueDate {
                    Text(due, format: .dateTime.weekday().month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(dueColor ?? .secondary)
                }
            }

            Spacer(minLength: 8)

            if isPendingDone {
                Button("Undo") { store.undo(item) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            } else if hovering || item.dueDate != nil {
                Button { showDeadlineEditor = true } label: {
                    Image(systemName: "clock")
                        .foregroundStyle(dueColor ?? .secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showDeadlineEditor) {
                    DeadlineEditor(store: store, item: item, isPresented: $showDeadlineEditor)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    private var titleColor: Color {
        if isPendingDone { return .secondary }
        return dueColor ?? .primary
    }

    private func toggleDone() {
        if isPendingDone { store.undo(item) } else { store.markDone(item) }
    }
}
```

- [ ] **Step 3: Regenerate, build**

Run: `xcodegen generate && xcodebuild -project Doable.xcodeproj -scheme Doable -configuration Debug -derivedDataPath build build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run and verify manually**

Run: `open build/Build/Products/Debug/Doable.app`
Verify:
- Hovering a row reveals a clock icon on the right; clicking it opens a date+time picker popover.
- Setting a deadline shows the formatted date under the title and persists.
- A deadline later **today** colors the row orange; a **past** deadline colors it red; a deadline several days out is neutral (with `todayOnly` window).
- "Clear" removes the deadline; the clock then only appears on hover.

Quit: `pkill -x Doable`.

- [ ] **Step 5: Commit**

```bash
git add App
git commit -m "feat(app): hover clock, deadline editor, and due-state coloring"
```

---

### Task 10: Stale label + Postpone

**Files:**
- Modify: `App/Views/TodoRowView.swift`

**Interfaces:**
- Consumes: `StaleRule` (Task 3), `TodoStore.postponeStale` (Task 7).
- Produces: a "Stale" badge with a Postpone control shown for undated items past the threshold.

- [ ] **Step 1: Add stale state + badge to the row**

In `App/Views/TodoRowView.swift`, add an `@AppStorage` for the threshold below the existing `windowRaw` line:
```swift
    @AppStorage("staleThresholdWorkdays") private var staleThreshold = 3
```

Add a computed property below `dueColor`:
```swift
    private var isStale: Bool {
        guard !isPendingDone else { return false }
        return StaleRule.isStale(createdAt: item.createdAt,
                                 dueDate: item.dueDate,
                                 snoozeUntil: item.staleSnoozeUntil,
                                 now: Date(),
                                 thresholdWorkdays: staleThreshold,
                                 calendar: .current)
    }
```

In the `VStack(alignment: .leading, spacing: 2)` that holds the title, add — after the `if let due` block — a stale badge:
```swift
                if isStale {
                    HStack(spacing: 6) {
                        Text("Stale")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.2), in: Capsule())
                            .foregroundStyle(.secondary)
                        Button("Postpone") {
                            store.postponeStale(item, now: Date(), thresholdWorkdays: staleThreshold, calendar: .current, in: context)
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                    }
                }
```

- [ ] **Step 2: Regenerate, build**

Run: `xcodegen generate && xcodebuild -project Doable.xcodeproj -scheme Doable -configuration Debug -derivedDataPath build build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Run and verify manually**

Because staleness depends on creation date, verify the logic via the unit tests (already covered in Task 3) and a runtime smoke check:
Run: `open build/Build/Products/Debug/Doable.app`
Verify:
- Newly added undated items show **no** stale badge (threshold not yet elapsed).
- Giving an item a deadline never shows a stale badge.
- (Optional deeper check) Temporarily set the threshold to a small value to confirm the badge and that **Postpone** hides it; revert afterward. The exact-threshold/snooze behavior is already proven by `StaleRuleTests`.

Quit: `pkill -x Doable`.

- [ ] **Step 4: Commit**

```bash
git add App
git commit -m "feat(app): stale badge and postpone for undated items"
```

---

### Task 11: Live menubar icon (color + count)

**Files:**
- Modify: `App/Views/MenuBarLabel.swift`

**Interfaces:**
- Consumes: `MenuBarStateCalculator`, `MenuBarState`, `Severity`, `DueSoonWindow` (Tasks 2 & 5), `TodoItem` (Task 7).
- Produces: a `MenuBarLabel` that queries active items, recomputes state on a 60s timeline, and renders monochrome / orange+count / red+count.

- [ ] **Step 1: Replace the placeholder label**

Replace `App/Views/MenuBarLabel.swift` with:
```swift
import SwiftUI
import SwiftData
import DoableCore

struct MenuBarLabel: View {
    @Query(filter: #Predicate<TodoItem> { $0.isDone == false }) private var items: [TodoItem]
    @AppStorage("dueSoonWindow") private var windowRaw = DueSoonWindow.todayOnly.rawValue

    private var window: DueSoonWindow { DueSoonWindow(rawValue: windowRaw) ?? .todayOnly }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let state = MenuBarStateCalculator.state(items: items, now: context.date, window: window, calendar: .current)
            content(for: state)
        }
    }

    @ViewBuilder
    private func content(for state: MenuBarState) -> some View {
        switch state.severity {
        case .normal:
            Image(systemName: "checklist")
        case .dueSoon:
            label(count: state.count, tint: .orange)
        case .overdue:
            label(count: state.count, tint: .red)
        }
    }

    private func label(count: Int, tint: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "checklist")
            Text("\(count)")
        }
        .foregroundStyle(tint)
    }
}
```

- [ ] **Step 2: Regenerate, build**

Run: `xcodegen generate && xcodebuild -project Doable.xcodeproj -scheme Doable -configuration Debug -derivedDataPath build build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Run and verify manually**

Run: `open build/Build/Products/Debug/Doable.app`
Verify:
- With no due/overdue items, the menubar shows the plain `checklist` icon, no number.
- Add an item due **later today** → icon turns orange and shows a count.
- Add an item with a **past** deadline → icon turns red (priority over orange) with the combined count.
- Completing/archiving those items returns the icon to plain.

Quit: `pkill -x Doable`.

- [ ] **Step 4: Commit**

```bash
git add App
git commit -m "feat(app): live menubar icon color and count"
```

---

### Task 12: Archive screen + navigation

**Files:**
- Create: `App/Views/ArchiveView.swift`
- Modify: `App/Views/MenuContentView.swift`

**Interfaces:**
- Consumes: `TodoItem` (Task 7).
- Produces: `struct ArchiveView: View` taking `onBack: () -> Void`, listing completed items newest-first. `MenuContentView` gains a `Screen` enum and a footer toolbar to switch between list and archive.

- [ ] **Step 1: Create the archive view**

`App/Views/ArchiveView.swift`:
```swift
import SwiftUI
import SwiftData

struct ArchiveView: View {
    var onBack: () -> Void
    @Query(filter: #Predicate<TodoItem> { $0.isDone == true },
           sort: \TodoItem.completedAt, order: .reverse) private var items: [TodoItem]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { onBack() } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                Spacer()
                Text("Completed")
                    .font(.headline)
                Spacer()
                // Symmetry spacer to keep the title centered.
                Label("Back", systemImage: "chevron.left").hidden()
            }
            .padding(10)

            Divider()

            if items.isEmpty {
                Text("Nothing archived yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(items) { item in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                Text(item.title)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 320)
    }
}
```

- [ ] **Step 2: Add navigation to MenuContentView**

In `App/Views/MenuContentView.swift`, add a screen enum and state. Add below `@FocusState private var inputFocused: Bool`:
```swift
    @State private var screen: Screen = .list
    private enum Screen { case list, archive }
```

Wrap the existing body content in a screen switch. Replace the entire `var body` with:
```swift
    var body: some View {
        Group {
            switch screen {
            case .list:
                listScreen
            case .archive:
                ArchiveView(onBack: { screen = .list })
            }
        }
        .onDisappear { store.commitPendingDone(in: context) }
    }

    private var listScreen: some View {
        VStack(spacing: 0) {
            TextField("Add a todo…", text: $newTitle)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(10)
                .focused($inputFocused)
                .onSubmit(addItem)

            Divider()

            if sortedItems.isEmpty {
                Text("No todos")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(sortedItems) { item in
                            TodoRowView(store: store, item: item)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }

            Divider()

            HStack {
                Button { screen = .archive } label: {
                    Label("Completed", systemImage: "archivebox")
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(10)
        }
        .frame(width: 320)
        .onAppear { inputFocused = true }
    }
```
(Keep the existing `addItem()` and the `sortedItems`/`rawItems`/`store`/`context` declarations.)

- [ ] **Step 3: Regenerate, build**

Run: `xcodegen generate && xcodebuild -project Doable.xcodeproj -scheme Doable -configuration Debug -derivedDataPath build build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run and verify manually**

Run: `open build/Build/Products/Debug/Doable.app`
Verify:
- A "Completed" button at the bottom switches to the archive screen.
- The archive lists items you've completed (after a popover close committed them), newest-first.
- "Back" returns to the active list.

Quit: `pkill -x Doable`.

- [ ] **Step 5: Commit**

```bash
git add App
git commit -m "feat(app): completed-items archive screen with navigation"
```

---

### Task 13: Settings — login item, due-soon window, stale threshold

**Files:**
- Create: `App/System/LoginItemManager.swift`
- Create: `App/Views/SettingsView.swift`
- Modify: `App/Views/MenuContentView.swift`

**Interfaces:**
- Consumes: `DueSoonWindow` (Task 2), `SMAppService` (ServiceManagement). Reads/writes `@AppStorage("dueSoonWindow")` and `@AppStorage("staleThresholdWorkdays")` shared with `MenuBarLabel`/`TodoRowView`.
- Produces:
  - `enum LoginItemManager` with `static var isEnabled: Bool` and `static func setEnabled(_ enabled: Bool)`.
  - `struct SettingsView: View` taking `onBack: () -> Void`.
  - `MenuContentView.Screen` gains a `.settings` case and a gear button.

- [ ] **Step 1: Create the login item manager**

`App/System/LoginItemManager.swift`:
```swift
import Foundation
import ServiceManagement

/// Thin wrapper over SMAppService for registering the app as a login item.
enum LoginItemManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters the app as a login item. Returns the resulting enabled state.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Login item update failed: \(error)")
        }
        return isEnabled
    }
}
```

- [ ] **Step 2: Create the settings view**

`App/Views/SettingsView.swift`:
```swift
import SwiftUI
import DoableCore

struct SettingsView: View {
    var onBack: () -> Void

    @AppStorage("dueSoonWindow") private var windowRaw = DueSoonWindow.todayOnly.rawValue
    @AppStorage("staleThresholdWorkdays") private var staleThreshold = 3
    @State private var launchAtLogin = LoginItemManager.isEnabled

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { onBack() } label: { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
                Spacer()
                Text("Settings").font(.headline)
                Spacer()
                Label("Back", systemImage: "chevron.left").hidden()
            }
            .padding(10)

            Divider()

            Form {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        launchAtLogin = LoginItemManager.setEnabled(newValue)
                    }

                Picker("Due soon", selection: $windowRaw) {
                    ForEach(DueSoonWindow.allCases, id: \.rawValue) { window in
                        Text(window.displayName).tag(window.rawValue)
                    }
                }

                Stepper("Stale after \(staleThreshold) workday\(staleThreshold == 1 ? "" : "s")",
                        value: $staleThreshold, in: 1...30)
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 320)
    }
}
```

- [ ] **Step 3: Add settings navigation to MenuContentView**

In `App/Views/MenuContentView.swift`, extend the `Screen` enum:
```swift
    private enum Screen { case list, archive, settings }
```
Add to the `switch screen` in `body`:
```swift
            case .settings:
                SettingsView(onBack: { screen = .list })
```
In `listScreen`'s footer `HStack`, add a gear button after the `Spacer()`:
```swift
                Button { screen = .settings } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
```

- [ ] **Step 4: Regenerate, build**

Run: `xcodegen generate && xcodebuild -project Doable.xcodeproj -scheme Doable -configuration Debug -derivedDataPath build build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Run and verify manually**

Run: `open build/Build/Products/Debug/Doable.app`
Verify:
- The gear button opens Settings; "Back" returns.
- Changing "Due soon" to e.g. "Within 3 days" immediately changes which items color orange and the menubar count (reflecting the shared `@AppStorage`).
- Changing the stale stepper affects when undated items show "Stale".
- Toggling "Launch at login" on then checking `System Settings → General → Login Items` shows Doable; toggling off removes it. (Login-item registration is most reliable when the app is in `/Applications` and signed; for a Debug build it may prompt or require the build to be moved. Note any discrepancy.)

Quit: `pkill -x Doable`.

- [ ] **Step 6: Final full test pass**

Run: `cd Core && swift test`
Expected: PASS (all suites).
Run: `cd .. && xcodebuild -project Doable.xcodeproj -scheme Doable -configuration Debug -derivedDataPath build build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add App
git commit -m "feat(app): settings with login item, due-soon window, stale threshold"
```

---

## Self-Review

**Spec coverage:**
- Type-and-enter capture → Task 7. ✓
- Optional deadline via hover clock → Task 9. ✓
- Complete with undo-until-close, then archive → Task 8. ✓
- Separate archive screen → Task 12. ✓
- Ordering (deadline asc, undated after, newest-first tiebreak) → Task 4 + used in Task 7. ✓
- Due-soon highlight + overdue stronger (red) → Task 9 (rows) + Task 11 (icon). ✓
- Menubar color + count, worst-state priority → Task 5 (logic) + Task 11 (UI). ✓
- Configurable due-soon window (default today only) → Tasks 2, 13. ✓
- Stale undated items after configurable workday threshold + postpone → Tasks 3, 10, 13. ✓
- Launch at login toggle → Task 13. ✓
- Native transparent look (`MenuBarExtra` `.window`), `LSUIElement` agent app → Task 6. ✓
- SwiftData model with all fields incl. `staleSnoozeUntil` → Task 7. ✓
- Core purity (no SwiftUI/SwiftData/AppKit; injected now/calendar) → enforced across Tasks 1–5. ✓
- Tests for classification, ordering, menubar state, stale workday math → Tasks 1–5. ✓

**Placeholder scan:** No TBD/TODO; every code step contains complete code; every test step contains real assertions. ✓

**Type consistency:** `Orderable` (Task 4) is adopted by `TodoItem` (Task 7) and consumed by `Ordering`/`MenuBarStateCalculator`. `DueSoonWindow.rawValue` stored in `@AppStorage("dueSoonWindow")` is read identically in `TodoRowView`, `MenuBarLabel`, `SettingsView`. `@AppStorage("staleThresholdWorkdays")` (Int, default 3) used consistently in `TodoRowView` and `SettingsView`. Store method names (`create`, `markDone`, `undo`, `setDueDate`, `postponeStale`, `commitPendingDone`) match between `TodoStore` (Task 7) and call sites (Tasks 8–10). ✓
