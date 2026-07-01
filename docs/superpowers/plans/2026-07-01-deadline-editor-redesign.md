# Deadline Editor Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the clunky deadline panel with a calendar-first, one-click-apply editor: preset chips + mini month calendar, day-only deadlines, and an opt-in type-to-set text field.

**Architecture:** Two new pure helpers in the `DoableCore` SwiftPM package (`MonthGrid` for month-layout math, `DeadlineInputParser` for prefix-matched keyword parsing), both unit-tested. The SwiftUI `DeadlineEditor` view is rewritten around them. `TodoItem.dueDate` keeps the existing "day at 17:00" storage convention, so `Classifier`, `StaleRule`, and sorting are untouched.

**Tech Stack:** Swift 6 / SwiftUI (macOS menu bar app), SwiftData, XCTest via SwiftPM.

**Spec:** `docs/superpowers/specs/2026-07-01-deadline-editor-redesign-design.md`

## Global Constraints

- Deadlines are day-only in the UI; storage keeps the day-at-17:00 `Date` convention. No schema change.
- Every choice in the panel (chip, calendar day, Enter in the type field) applies immediately and closes the panel. No Done button.
- Type-to-set field appears only when `@AppStorage("typeToSetDeadline")` is true (default `false`).
- Parser keywords are English only, matched case-insensitively by prefix, priority order: `today`, `tomorrow`, `next week`, then weekdays Monday→Sunday.
- A typed weekday resolves strictly after today ("fri" on a Friday → next Friday).
- Core tests: `just test` (runs `cd Core && swift test`). App build: `just build` (also installs to /Applications).
- Commit after every task.

---

### Task 1: `DuePreset.dueTime` — shared day-at-17:00 helper

The 17:00 convention currently lives inline in `DuePreset.date`. The calendar grid and the parser both need it, so extract it once.

**Files:**
- Modify: `Core/Sources/DoableCore/DuePreset.swift`
- Test: `Core/Tests/DoableCoreTests/DuePresetTests.swift`

**Interfaces:**
- Produces: `DuePreset.dueTime(on day: Date, calendar: Calendar) -> Date` — returns `day` with the time set to 17:00:00.

- [ ] **Step 1: Write the failing test**

Append to `Core/Tests/DoableCoreTests/DuePresetTests.swift` (inside the existing `DuePresetTests` class, which already has `let cal = utcCalendar()`):

```swift
    func test_dueTime_sets_1700_on_given_day() {
        let morning = date(2026, 7, 1, 9, 30, calendar: cal)
        XCTAssertEqual(DuePreset.dueTime(on: morning, calendar: cal),
                       date(2026, 7, 1, 17, 0, calendar: cal))
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Core && swift test --filter DuePresetTests`
Expected: compile error — `type 'DuePreset' has no member 'dueTime'`

- [ ] **Step 3: Write minimal implementation**

In `Core/Sources/DoableCore/DuePreset.swift`, add the static helper and use it from `date(from:calendar:)` (replacing the final return line and the `let dueHour = 17` local):

```swift
    /// `day` at the canonical due time (17:00) in `calendar`'s time zone. All
    /// deadlines in the app store this time-of-day, even though the UI is day-only.
    public static func dueTime(on day: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: 17, minute: 0, second: 0, of: day)!
    }
```

And at the end of `date(from:calendar:)`:

```swift
        return Self.dueTime(on: day, calendar: calendar)
```

Delete the now-unused `let dueHour = 17` line.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Core && swift test --filter DuePresetTests`
Expected: all DuePresetTests PASS (existing preset tests prove the refactor changed nothing).

- [ ] **Step 5: Commit**

```bash
git add Core/Sources/DoableCore/DuePreset.swift Core/Tests/DoableCoreTests/DuePresetTests.swift
git commit -m "refactor(core): extract DuePreset.dueTime day-at-17:00 helper"
```

---

### Task 2: `MonthGrid` — month-layout math

**Files:**
- Create: `Core/Sources/DoableCore/MonthGrid.swift`
- Test: `Core/Tests/DoableCoreTests/MonthGridTests.swift`

**Interfaces:**
- Produces:
  - `MonthGrid.weeks(containing date: Date, calendar: Calendar) -> [[Date?]]` — the weeks of `date`'s month as rows of exactly 7 cells; `nil` cells pad before the 1st and after the last day; non-nil cells are that day's start-of-day `Date`. Row order honors `calendar.firstWeekday`.
  - `MonthGrid.weekdaySymbols(calendar: Calendar) -> [String]` — `veryShortStandaloneWeekdaySymbols` rotated so index 0 is `calendar.firstWeekday`.

**Reference facts for tests** (verifiable with `cal`): 2026-07-01 is a Wednesday; July 2026 has 31 days. 2027-02-01 is a Monday; February 2027 has 28 days. 2028-02-01 is a Tuesday; February 2028 has 29 days (leap).

- [ ] **Step 1: Write the failing tests**

Create `Core/Tests/DoableCoreTests/MonthGridTests.swift`:

```swift
import XCTest
@testable import DoableCore

// Reference dates: 2026-07-01 Wed (31 days), 2027-02-01 Mon (28 days),
// 2028-02-01 Tue (29 days, leap year).
final class MonthGridTests: XCTestCase {
    let cal = utcCalendar()   // firstWeekday defaults to 1 (Sunday)

    private func mondayFirst() -> Calendar {
        var c = utcCalendar()
        c.firstWeekday = 2
        return c
    }

    private func days(_ weeks: [[Date?]], calendar: Calendar) -> [[Int?]] {
        weeks.map { $0.map { $0.map { calendar.component(.day, from: $0) } } }
    }

    func test_july2026_sundayFirst() {
        let weeks = MonthGrid.weeks(containing: date(2026, 7, 15, calendar: cal), calendar: cal)
        XCTAssertEqual(days(weeks, calendar: cal), [
            [nil, nil, nil, 1, 2, 3, 4],
            [5, 6, 7, 8, 9, 10, 11],
            [12, 13, 14, 15, 16, 17, 18],
            [19, 20, 21, 22, 23, 24, 25],
            [26, 27, 28, 29, 30, 31, nil],
        ])
    }

    func test_july2026_mondayFirst() {
        let cal = mondayFirst()
        let weeks = MonthGrid.weeks(containing: date(2026, 7, 15, calendar: cal), calendar: cal)
        XCTAssertEqual(days(weeks, calendar: cal), [
            [nil, nil, 1, 2, 3, 4, 5],
            [6, 7, 8, 9, 10, 11, 12],
            [13, 14, 15, 16, 17, 18, 19],
            [20, 21, 22, 23, 24, 25, 26],
            [27, 28, 29, 30, 31, nil, nil],
        ])
    }

    func test_february2027_mondayFirst_fills_exactly_four_weeks() {
        let cal = mondayFirst()
        let weeks = MonthGrid.weeks(containing: date(2027, 2, 10, calendar: cal), calendar: cal)
        XCTAssertEqual(weeks.count, 4)
        XCTAssertEqual(days(weeks, calendar: cal).first, [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(days(weeks, calendar: cal).last, [22, 23, 24, 25, 26, 27, 28])
    }

    func test_leap_february2028_mondayFirst() {
        let cal = mondayFirst()
        let weeks = MonthGrid.weeks(containing: date(2028, 2, 10, calendar: cal), calendar: cal)
        XCTAssertEqual(days(weeks, calendar: cal).last, [28, 29, nil, nil, nil, nil, nil])
    }

    func test_cells_are_startOfDay_dates() {
        let weeks = MonthGrid.weeks(containing: date(2026, 7, 15, 14, 30, calendar: cal), calendar: cal)
        let first = weeks[0][3]!   // July 1
        XCTAssertEqual(first, date(2026, 7, 1, calendar: cal))
    }

    func test_weekdaySymbols_rotate_to_firstWeekday() {
        let sundayFirst = MonthGrid.weekdaySymbols(calendar: cal)
        let mondayFirst = MonthGrid.weekdaySymbols(calendar: mondayFirst())
        XCTAssertEqual(sundayFirst.count, 7)
        XCTAssertEqual(Array(sundayFirst[1...]) + [sundayFirst[0]], mondayFirst)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Core && swift test --filter MonthGridTests`
Expected: compile error — `cannot find 'MonthGrid' in scope`

- [ ] **Step 3: Write the implementation**

Create `Core/Sources/DoableCore/MonthGrid.swift`:

```swift
import Foundation

/// Pure month-layout math for the deadline editor's mini calendar: the weeks
/// of a month as rows of 7 optional days, honoring the calendar's first weekday.
public enum MonthGrid {
    /// The weeks of `date`'s month. Each row has exactly 7 cells; `nil` pads
    /// before the 1st and after the last day. Non-nil cells are start-of-day dates.
    public static func weeks(containing date: Date, calendar: Calendar) -> [[Date?]] {
        let comps = calendar.dateComponents([.year, .month], from: date)
        let firstOfMonth = calendar.date(from: comps)!
        let dayCount = calendar.range(of: .day, in: .month, for: firstOfMonth)!.count
        let leading = (calendar.component(.weekday, from: firstOfMonth) - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: firstOfMonth)!)
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<($0 + 7)]) }
    }

    /// Very-short weekday symbols ("S", "M", …) rotated so index 0 is
    /// `calendar.firstWeekday`, matching the column order of `weeks`.
    public static func weekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Core && swift test --filter MonthGridTests`
Expected: 6 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Core/Sources/DoableCore/MonthGrid.swift Core/Tests/DoableCoreTests/MonthGridTests.swift
git commit -m "feat(core): add MonthGrid month-layout helper"
```

---

### Task 3: `DeadlineInputParser` — prefix-matched keyword parsing

**Files:**
- Create: `Core/Sources/DoableCore/DeadlineInputParser.swift`
- Test: `Core/Tests/DoableCoreTests/DeadlineInputParserTests.swift`

**Interfaces:**
- Consumes: `DuePreset` (`.today/.tomorrow/.nextWeek` + `date(from:calendar:)`), `DuePreset.dueTime(on:calendar:)` from Task 1.
- Produces:
  - `DeadlineInputParser.Match` — `struct { let label: String; let day: Date }`, `Equatable`, `Sendable`. `label` is the full matched keyword (e.g. `"friday"`); `day` is the resolved day at 17:00.
  - `DeadlineInputParser.match(_ input: String, now: Date, calendar: Calendar) -> Match?`

- [ ] **Step 1: Write the failing tests**

Create `Core/Tests/DoableCoreTests/DeadlineInputParserTests.swift`:

```swift
import XCTest
@testable import DoableCore

// Reference: now = 2026-07-01, a Wednesday. Thu 07-02, Fri 07-03, Sat 07-04,
// Sun 07-05, Mon 07-06, Tue 07-07, next Wed 07-08.
final class DeadlineInputParserTests: XCTestCase {
    let cal = utcCalendar()
    lazy var now = date(2026, 7, 1, 9, 0, calendar: cal)

    private func day(_ label: String, _ y: Int, _ mo: Int, _ d: Int) -> DeadlineInputParser.Match {
        .init(label: label, day: date(y, mo, d, 17, 0, calendar: cal))
    }

    func test_priority_t_prefers_today_over_tuesday_thursday() {
        XCTAssertEqual(DeadlineInputParser.match("t", now: now, calendar: cal),
                       day("today", 2026, 7, 1))
    }

    func test_tom_matches_tomorrow() {
        XCTAssertEqual(DeadlineInputParser.match("tom", now: now, calendar: cal),
                       day("tomorrow", 2026, 7, 2))
    }

    func test_n_matches_next_week_monday() {
        XCTAssertEqual(DeadlineInputParser.match("n", now: now, calendar: cal),
                       day("next week", 2026, 7, 6))
    }

    func test_tu_and_th_fall_through_to_weekdays() {
        XCTAssertEqual(DeadlineInputParser.match("tu", now: now, calendar: cal),
                       day("tuesday", 2026, 7, 7))
        XCTAssertEqual(DeadlineInputParser.match("th", now: now, calendar: cal),
                       day("thursday", 2026, 7, 2))
    }

    func test_f_matches_friday() {
        XCTAssertEqual(DeadlineInputParser.match("f", now: now, calendar: cal),
                       day("friday", 2026, 7, 3))
    }

    func test_s_prefers_saturday_su_matches_sunday() {
        XCTAssertEqual(DeadlineInputParser.match("s", now: now, calendar: cal),
                       day("saturday", 2026, 7, 4))
        XCTAssertEqual(DeadlineInputParser.match("su", now: now, calendar: cal),
                       day("sunday", 2026, 7, 5))
    }

    func test_same_weekday_resolves_strictly_after_today() {
        // "wed" typed on a Wednesday means NEXT Wednesday; "today" covers today.
        XCTAssertEqual(DeadlineInputParser.match("wed", now: now, calendar: cal),
                       day("wednesday", 2026, 7, 8))
    }

    func test_full_names_match() {
        XCTAssertEqual(DeadlineInputParser.match("friday", now: now, calendar: cal),
                       day("friday", 2026, 7, 3))
        XCTAssertEqual(DeadlineInputParser.match("next week", now: now, calendar: cal),
                       day("next week", 2026, 7, 6))
    }

    func test_case_and_whitespace_insensitive() {
        XCTAssertEqual(DeadlineInputParser.match("  FRi ", now: now, calendar: cal),
                       day("friday", 2026, 7, 3))
    }

    func test_no_match_returns_nil() {
        XCTAssertNil(DeadlineInputParser.match("", now: now, calendar: cal))
        XCTAssertNil(DeadlineInputParser.match("   ", now: now, calendar: cal))
        XCTAssertNil(DeadlineInputParser.match("xyz", now: now, calendar: cal))
        XCTAssertNil(DeadlineInputParser.match("fridayx", now: now, calendar: cal))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Core && swift test --filter DeadlineInputParserTests`
Expected: compile error — `cannot find 'DeadlineInputParser' in scope`

- [ ] **Step 3: Write the implementation**

Create `Core/Sources/DoableCore/DeadlineInputParser.swift`:

```swift
import Foundation

/// Parses the deadline editor's type-to-set input. English keywords only,
/// matched case-insensitively by prefix against a priority-ordered candidate
/// list: today, tomorrow, next week, then weekdays Monday→Sunday. A weekday
/// resolves to its next occurrence strictly after today ("fri" typed on a
/// Friday means next Friday — "today" already covers today).
public enum DeadlineInputParser {
    public struct Match: Equatable, Sendable {
        /// The full matched keyword, e.g. "friday" for input "f".
        public let label: String
        /// The resolved day at the canonical 17:00 due time.
        public let day: Date

        public init(label: String, day: Date) {
            self.label = label
            self.day = day
        }
    }

    /// Weekday keywords in priority (Monday-first) order, with their
    /// Gregorian weekday numbers (Sunday = 1).
    private static let weekdays: [(label: String, weekday: Int)] = [
        ("monday", 2), ("tuesday", 3), ("wednesday", 4), ("thursday", 5),
        ("friday", 6), ("saturday", 7), ("sunday", 1),
    ]

    public static func match(_ input: String, now: Date, calendar: Calendar) -> Match? {
        let query = input.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return nil }

        let presets: [(label: String, preset: DuePreset)] = [
            ("today", .today), ("tomorrow", .tomorrow), ("next week", .nextWeek),
        ]
        for (label, preset) in presets where label.hasPrefix(query) {
            return Match(label: label, day: preset.date(from: now, calendar: calendar))
        }
        for (label, weekday) in weekdays where label.hasPrefix(query) {
            return Match(label: label, day: next(weekday: weekday, after: now, calendar: calendar))
        }
        return nil
    }

    /// The next `weekday` strictly after `now`'s day, at 17:00.
    private static func next(weekday: Int, after now: Date, calendar: Calendar) -> Date {
        let current = calendar.component(.weekday, from: now)
        var add = (weekday - current + 7) % 7
        if add == 0 { add = 7 }
        let day = calendar.date(byAdding: .day, value: add, to: now)!
        return DuePreset.dueTime(on: day, calendar: calendar)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Core && swift test`
Expected: full suite PASS (new parser tests plus everything existing).

- [ ] **Step 5: Commit**

```bash
git add Core/Sources/DoableCore/DeadlineInputParser.swift Core/Tests/DoableCoreTests/DeadlineInputParserTests.swift
git commit -m "feat(core): add DeadlineInputParser for type-to-set deadlines"
```

---

### Task 4: Rewrite `DeadlineEditor` as the calendar-first panel

**Files:**
- Modify: `App/Views/DeadlineEditor.swift` (full rewrite of the file body)

**Interfaces:**
- Consumes: `MonthGrid.weeks/weekdaySymbols` (Task 2), `DeadlineInputParser.match` (Task 3), `DuePreset.available/date/dueTime` (Task 1), `TodoStore.setDueDate(_:for:in:)` (existing, `App/Models/TodoStore.swift:76`).
- Produces: same view signature as before — `DeadlineEditor(store:item:onDismiss:)` — so `TodoRowView` needs no changes for this task.

- [ ] **Step 1: Replace the contents of `App/Views/DeadlineEditor.swift`**

```swift
import SwiftUI
import SwiftData
import DoableCore

/// In-window editor for a todo's due date: preset chips above a mini month
/// calendar, plus an opt-in type-to-set field. Deadlines are day-only; every
/// choice applies immediately and closes the panel. Rendered inline beneath
/// the edited row by `TodoRowView`.
struct DeadlineEditor: View {
    @Bindable var store: TodoStore
    let item: TodoItem
    @Environment(\.modelContext) private var context
    let onDismiss: () -> Void

    @AppStorage("typeToSetDeadline") private var typeToSet = false
    @State private var displayedMonth: Date
    @State private var query = ""
    @FocusState private var queryFocused: Bool

    private let calendar = Calendar.current

    init(store: TodoStore, item: TodoItem, onDismiss: @escaping () -> Void) {
        self.store = store
        self.item = item
        self.onDismiss = onDismiss
        self._displayedMonth = State(initialValue: item.dueDate ?? Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if typeToSet { typeField }
            presetChips
            calendarGrid
            if item.dueDate != nil {
                Button("Clear deadline", role: .destructive) { apply(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Type-to-set field

    private var currentMatch: DeadlineInputParser.Match? {
        DeadlineInputParser.match(query, now: Date(), calendar: calendar)
    }

    private var typeField: some View {
        HStack(spacing: 6) {
            TextField("Type a day… (fri, tomorrow)", text: $query)
                .textFieldStyle(.plain)
                .font(.callout)
                .focused($queryFocused)
                .onSubmit {
                    guard let match = currentMatch else { return }
                    apply(match.day)
                }
                .onExitCommand {
                    if query.isEmpty { onDismiss() } else { query = "" }
                }
            if let match = currentMatch {
                Text("\(match.label) → \(match.day, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .onAppear { queryFocused = true }
    }

    // MARK: - Preset chips

    private var presetChips: some View {
        HStack(spacing: 6) {
            ForEach(DuePreset.available(on: Date(), calendar: calendar), id: \.rawValue) { preset in
                Button(preset.displayName) {
                    apply(preset.date(from: Date(), calendar: calendar))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Calendar

    private var calendarGrid: some View {
        VStack(spacing: 2) {
            monthHeader
            weekdayHeader
            ForEach(Array(MonthGrid.weeks(containing: displayedMonth, calendar: calendar).enumerated()),
                    id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        dayCell(day)
                    }
                }
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Text(displayedMonth, format: .dateTime.month(.wide).year())
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button { stepMonth(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            Button { stepMonth(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
        }
        .padding(.bottom, 4)
    }

    // Weekday symbols can repeat ("T", "T", "S", "S"), so identify columns by
    // offset, not by the symbol string.
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(MonthGrid.weekdaySymbols(calendar: calendar).enumerated()),
                    id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date?) -> some View {
        if let day {
            let isSelected = item.dueDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
            let isPast = day < calendar.startOfDay(for: Date())
            Button {
                apply(DuePreset.dueTime(on: day, calendar: calendar))
            } label: {
                Text("\(calendar.component(.day, from: day))")
                    .font(.callout)
                    .frame(width: 26, height: 26)
                    .background {
                        if isSelected {
                            Circle().fill(Color.accentColor)
                        } else if calendar.isDateInToday(day) {
                            Circle().strokeBorder(Color.accentColor, lineWidth: 1)
                        }
                    }
                    .foregroundStyle(isSelected ? Color.white
                                     : isPast ? Color.secondary.opacity(0.5)
                                     : Color.primary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isPast)
        } else {
            Color.clear.frame(height: 26).frame(maxWidth: .infinity)
        }
    }

    // MARK: - Actions

    private func stepMonth(_ months: Int) {
        displayedMonth = calendar.date(byAdding: .month, value: months, to: displayedMonth)!
    }

    /// Applies the deadline (or clears it, for `nil`) and closes the panel.
    private func apply(_ date: Date?) {
        store.setDueDate(date, for: item, in: context)
        onDismiss()
    }
}
```

- [ ] **Step 2: Build**

Run: `just build`
Expected: `** BUILD SUCCEEDED **` (also installs to /Applications).

- [ ] **Step 3: Manual verification**

Run: `open /Applications/Doable.app`, open the menu bar popover, and check on a todo's "…" menu → Set deadline:

1. Panel shows Today / Tomorrow / Next week chips (Tomorrow hidden if run on Fri–Sun) above a July 2026 calendar. No type field yet (setting defaults off).
2. Today (Jul 1) is outlined; days before today are dimmed and unclickable.
3. Clicking a chip or a future day sets the deadline and closes the panel instantly — no Done button anywhere.
4. Reopen the editor on that item: its day has an accent-filled circle, and "Clear deadline" appears; clicking it removes the deadline and closes.
5. ◀ ▶ navigate months; days outside the displayed month are blank.
6. Temporarily enable the type field with `defaults write nl.jens.Doable typeToSetDeadline -bool true` — reopen the editor, field is focused; type `f` → preview "friday → Fri, Jul 3"; Enter applies and closes. Esc with text clears the field; Esc when empty closes the panel. Then `defaults delete nl.jens.Doable typeToSetDeadline`.
   (If the bundle id differs, get it with `defaults domains | tr ',' '\n' | grep -i doable` or `osascript -e 'id of app "Doable"'`.)

If Esc handling conflicts with the popover's own dismiss, keep `.onExitCommand` behavior as close to the spec as the popover allows and note the deviation in the commit message.

- [ ] **Step 4: Commit**

```bash
git add App/Views/DeadlineEditor.swift
git commit -m "feat(menu): calendar-first one-click deadline editor"
```

---

### Task 5: Day-only due-date display in `TodoRowView`

**Files:**
- Modify: `App/Views/TodoRowView.swift:63`

**Interfaces:**
- Consumes: nothing new. Display-only change; `Classifier`/`StaleRule` inputs are untouched.

- [ ] **Step 1: Change the due-date line format**

In `App/Views/TodoRowView.swift`, replace:

```swift
                    Text(due, format: .dateTime.weekday().month().day().hour().minute())
```

with:

```swift
                    Text(due, format: .dateTime.weekday().month().day())
```

- [ ] **Step 2: Build and verify**

Run: `just build`
Expected: `** BUILD SUCCEEDED **`

Open the popover: an item with a deadline shows "Tue, Jul 1"-style text with no time, including deadlines that were stored before this change.

- [ ] **Step 3: Commit**

```bash
git add App/Views/TodoRowView.swift
git commit -m "feat(menu): show due dates day-only"
```

---

### Task 6: "Type to set deadlines" setting

**Files:**
- Modify: `App/Views/Settings/GeneralSettingsView.swift`

**Interfaces:**
- Consumes: the `@AppStorage("typeToSetDeadline")` key that `DeadlineEditor` (Task 4) reads. Key name must match exactly: `typeToSetDeadline`.

- [ ] **Step 1: Add the toggle**

In `App/Views/Settings/GeneralSettingsView.swift`, add the property alongside the other `@AppStorage` properties:

```swift
    @AppStorage("typeToSetDeadline") private var typeToSetDeadline = false
```

And in the `Form`, after the `Stepper("Stale after …")` line, add:

```swift
            Toggle("Type to set deadlines", isOn: $typeToSetDeadline)
```

- [ ] **Step 2: Build and verify**

Run: `just build`
Expected: `** BUILD SUCCEEDED **`

In the app: Settings (⌘,) → General shows the toggle, default off. Turn it on, open a todo's deadline editor — the type field is present and focused. Turn it off — the field is gone.

- [ ] **Step 3: Commit**

```bash
git add App/Views/Settings/GeneralSettingsView.swift
git commit -m "feat(settings): add type-to-set deadlines toggle"
```

---

## Final verification

- [ ] `just test` — full Core suite passes.
- [ ] `just build` — app builds and installs.
- [ ] Walk the spec's UI section end-to-end in the running app (chips, calendar states, one-click apply, Clear, type field on/off, day-only rows).
