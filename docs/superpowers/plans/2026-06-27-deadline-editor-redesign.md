# Deadline Editor Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the focus-losing `.popover` due-date editor with an in-window editor offering quick presets plus a custom picker, switchable between an overlay card (default) and inline row expansion.

**Architecture:** Pure date logic (`DuePreset`) and the placement enum (`DateEditorPlacement`) live in `DoableCore` and are unit-tested. The SwiftUI `DeadlineEditor` is restyled and reused by both placements. Editing state is lifted from each `TodoRowView` up to `MenuContentView` (`editingItemID: UUID?`); placement is read from `@AppStorage("dateEditorPlacement")`. Nothing renders in a second window, so the menubar window never resigns focus.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, XCTest (SwiftPM for Core), XcodeGen for the app target.

## Global Constraints

- macOS deployment target: **14.0**.
- Pure, calendar-driven date logic lives in `DoableCore` and is unit-tested (matches `Workdays`, `StaleRule`, `Classifier`).
- Default due time for presets: **17:00** local.
- Default placement: **overlay**.
- `@AppStorage` key for placement: **`"dateEditorPlacement"`**.
- Enum-backed settings use `id: \.rawValue` in `ForEach` (matches `DueSoonWindow` usage).
- Core tests use the `utcCalendar()` and `date(_:_:_:_:_:calendar:)` helpers in `TestSupport.swift`.
- End commit messages with: `Claude-Session: https://claude.ai/code/session_014RtKbLC7wYagMiCzAJS15e`

---

### Task 1: `DuePreset` date logic in Core

**Files:**
- Create: `Core/Sources/DoableCore/DuePreset.swift`
- Test: `Core/Tests/DoableCoreTests/DuePresetTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  ```swift
  public enum DuePreset: String, CaseIterable, Sendable {
      case today, tomorrow, thisWeekend, nextWeek
      public var displayName: String
      public func date(from now: Date, calendar: Calendar) -> Date
  }
  ```
  `date(from:calendar:)` resolves to the target day at 17:00 local (per `calendar`'s time zone).

- [ ] **Step 1: Write the failing tests**

Create `Core/Tests/DoableCoreTests/DuePresetTests.swift`:

```swift
import XCTest
@testable import DoableCore

// Reference dates: 2026-06-26 Fri, 06-27 Sat, 06-28 Sun, 06-29 Mon, 07-06 Mon.
final class DuePresetTests: XCTestCase {
    let cal = utcCalendar()

    func test_today_is_today_at_1700() {
        let now = date(2026, 6, 26, 9, 0, calendar: cal)
        XCTAssertEqual(DuePreset.today.date(from: now, calendar: cal),
                       date(2026, 6, 26, 17, 0, calendar: cal))
    }

    func test_tomorrow_is_next_day_at_1700() {
        let now = date(2026, 6, 26, 9, 0, calendar: cal)
        XCTAssertEqual(DuePreset.tomorrow.date(from: now, calendar: cal),
                       date(2026, 6, 27, 17, 0, calendar: cal))
    }

    func test_thisWeekend_from_weekday_is_coming_saturday() {
        let friday = date(2026, 6, 26, 9, 0, calendar: cal)
        XCTAssertEqual(DuePreset.thisWeekend.date(from: friday, calendar: cal),
                       date(2026, 6, 27, 17, 0, calendar: cal))
    }

    func test_thisWeekend_when_saturday_is_today() {
        let saturday = date(2026, 6, 27, 9, 0, calendar: cal)
        XCTAssertEqual(DuePreset.thisWeekend.date(from: saturday, calendar: cal),
                       date(2026, 6, 27, 17, 0, calendar: cal))
    }

    func test_thisWeekend_when_sunday_is_today() {
        let sunday = date(2026, 6, 28, 9, 0, calendar: cal)
        XCTAssertEqual(DuePreset.thisWeekend.date(from: sunday, calendar: cal),
                       date(2026, 6, 28, 17, 0, calendar: cal))
    }

    func test_nextWeek_from_friday_is_monday() {
        let friday = date(2026, 6, 26, 9, 0, calendar: cal)
        XCTAssertEqual(DuePreset.nextWeek.date(from: friday, calendar: cal),
                       date(2026, 6, 29, 17, 0, calendar: cal))
    }

    func test_nextWeek_from_sunday_is_monday() {
        let sunday = date(2026, 6, 28, 9, 0, calendar: cal)
        XCTAssertEqual(DuePreset.nextWeek.date(from: sunday, calendar: cal),
                       date(2026, 6, 29, 17, 0, calendar: cal))
    }

    func test_nextWeek_from_monday_is_following_monday() {
        let monday = date(2026, 6, 29, 9, 0, calendar: cal)
        XCTAssertEqual(DuePreset.nextWeek.date(from: monday, calendar: cal),
                       date(2026, 7, 6, 17, 0, calendar: cal))
    }

    func test_displayNames() {
        XCTAssertEqual(DuePreset.today.displayName, "Today")
        XCTAssertEqual(DuePreset.tomorrow.displayName, "Tomorrow")
        XCTAssertEqual(DuePreset.thisWeekend.displayName, "This weekend")
        XCTAssertEqual(DuePreset.nextWeek.displayName, "Next week")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd Core && swift test --filter DuePresetTests`
Expected: FAIL — `cannot find 'DuePreset' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Core/Sources/DoableCore/DuePreset.swift`:

```swift
import Foundation

/// Quick due-date choices offered in the deadline editor. All resolve to the
/// target day at 17:00 in the supplied calendar's time zone.
public enum DuePreset: String, CaseIterable, Sendable {
    case today
    case tomorrow
    case thisWeekend
    case nextWeek

    public var displayName: String {
        switch self {
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .thisWeekend: return "This weekend"
        case .nextWeek: return "Next week"
        }
    }

    /// The due date this preset resolves to, relative to `now`.
    public func date(from now: Date, calendar: Calendar) -> Date {
        let dueHour = 17
        let saturday = 7   // Gregorian weekday number
        let monday = 2
        let day: Date
        switch self {
        case .today:
            day = now
        case .tomorrow:
            day = calendar.date(byAdding: .day, value: 1, to: now)!
        case .thisWeekend:
            if calendar.isDateInWeekend(now) {
                day = now
            } else {
                let wd = calendar.component(.weekday, from: now)
                day = calendar.date(byAdding: .day, value: saturday - wd, to: now)!
            }
        case .nextWeek:
            let wd = calendar.component(.weekday, from: now)
            var add = (monday - wd + 7) % 7
            if add == 0 { add = 7 }
            day = calendar.date(byAdding: .day, value: add, to: now)!
        }
        return calendar.date(bySettingHour: dueHour, minute: 0, second: 0, of: day)!
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd Core && swift test --filter DuePresetTests`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add Core/Sources/DoableCore/DuePreset.swift Core/Tests/DoableCoreTests/DuePresetTests.swift
git commit -m "feat(core): DuePreset for quick due-date choices

Claude-Session: https://claude.ai/code/session_014RtKbLC7wYagMiCzAJS15e"
```

---

### Task 2: `DateEditorPlacement` enum in Core

**Files:**
- Create: `Core/Sources/DoableCore/DateEditorPlacement.swift`
- Test: `Core/Tests/DoableCoreTests/DateEditorPlacementTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  ```swift
  public enum DateEditorPlacement: String, CaseIterable, Sendable {
      case overlay, inline
      public var displayName: String
  }
  ```

- [ ] **Step 1: Write the failing tests**

Create `Core/Tests/DoableCoreTests/DateEditorPlacementTests.swift`:

```swift
import XCTest
@testable import DoableCore

final class DateEditorPlacementTests: XCTestCase {
    func test_cases_and_displayNames() {
        XCTAssertEqual(DateEditorPlacement.allCases, [.overlay, .inline])
        XCTAssertEqual(DateEditorPlacement.overlay.displayName, "Overlay")
        XCTAssertEqual(DateEditorPlacement.inline.displayName, "Inline")
    }

    func test_rawValues_are_stable() {
        XCTAssertEqual(DateEditorPlacement.overlay.rawValue, "overlay")
        XCTAssertEqual(DateEditorPlacement.inline.rawValue, "inline")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd Core && swift test --filter DateEditorPlacementTests`
Expected: FAIL — `cannot find 'DateEditorPlacement' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Core/Sources/DoableCore/DateEditorPlacement.swift`:

```swift
import Foundation

/// Where the deadline editor renders inside the menu window.
public enum DateEditorPlacement: String, CaseIterable, Sendable {
    /// A dimmed card centered over the menu list (default).
    case overlay
    /// Expanded directly beneath the edited row.
    case inline

    public var displayName: String {
        switch self {
        case .overlay: return "Overlay"
        case .inline: return "Inline"
        }
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd Core && swift test --filter DateEditorPlacementTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Core/Sources/DoableCore/DateEditorPlacement.swift Core/Tests/DoableCoreTests/DateEditorPlacementTests.swift
git commit -m "feat(core): DateEditorPlacement enum

Claude-Session: https://claude.ai/code/session_014RtKbLC7wYagMiCzAJS15e"
```

---

### Task 3: Restyle `DeadlineEditor` with presets

**Files:**
- Modify: `App/Views/DeadlineEditor.swift` (full rewrite)

**Interfaces:**
- Consumes: `DuePreset` (Task 1); `TodoStore.setDueDate(_:for:in:)`.
- Produces:
  ```swift
  struct DeadlineEditor: View {
      init(store: TodoStore, item: TodoItem, onDismiss: @escaping () -> Void)
  }
  ```
  Replaces the previous `isPresented: Binding<Bool>` initializer with an
  `onDismiss` closure. Callers (Task 4) must be updated.

This task has no unit test (SwiftUI view); it is verified by build in Task 4's run step. Build it standalone here to catch compile errors early.

- [ ] **Step 1: Rewrite the view**

Replace the entire contents of `App/Views/DeadlineEditor.swift`:

```swift
import SwiftUI
import SwiftData
import DoableCore

/// In-window editor for a todo's due date: quick presets plus a custom picker.
/// Rendered by `MenuContentView` (overlay) or `TodoRowView` (inline) — never in a popover.
struct DeadlineEditor: View {
    @Bindable var store: TodoStore
    let item: TodoItem
    @Environment(\.modelContext) private var context
    let onDismiss: () -> Void

    @State private var date: Date

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    init(store: TodoStore, item: TodoItem, onDismiss: @escaping () -> Void) {
        self.store = store
        self.item = item
        self.onDismiss = onDismiss
        self._date = State(initialValue: item.dueDate ?? Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set due date")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(DuePreset.allCases, id: \.rawValue) { preset in
                    Button(preset.displayName) { apply(preset) }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }
            }

            Divider()

            HStack {
                Text("Custom")
                    .foregroundStyle(.secondary)
                Spacer()
                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }

            Divider()

            HStack {
                if item.dueDate != nil {
                    Button("Clear", role: .destructive) {
                        store.setDueDate(nil, for: item, in: context)
                        onDismiss()
                    }
                }
                Spacer()
                Button("Done") {
                    store.setDueDate(date, for: item, in: context)
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 260)
    }

    private func apply(_ preset: DuePreset) {
        store.setDueDate(preset.date(from: Date(), calendar: .current), for: item, in: context)
        onDismiss()
    }
}
```

- [ ] **Step 2: Commit**

Do not build in isolation (callers still reference the old initializer and won't compile until Task 4). Commit the view change together with the wiring is acceptable, but committing now keeps tasks reviewable:

```bash
git add App/Views/DeadlineEditor.swift
git commit -m "feat(app): restyle DeadlineEditor with presets and onDismiss

Claude-Session: https://claude.ai/code/session_014RtKbLC7wYagMiCzAJS15e"
```

---

### Task 4: Wire editing state into `MenuContentView` and `TodoRowView`

**Files:**
- Modify: `App/Views/MenuContentView.swift`
- Modify: `App/Views/TodoRowView.swift`

**Interfaces:**
- Consumes: `DeadlineEditor(store:item:onDismiss:)` (Task 3); `DateEditorPlacement` (Task 2).
- Produces: `TodoRowView(store:item:editingItemID:)` where
  `editingItemID: Binding<UUID?>`.

- [ ] **Step 1: Update `TodoRowView`**

In `App/Views/TodoRowView.swift`:

1. Add the binding and placement, and remove the old local presentation state. Replace:

```swift
    @State private var hovering = false
    @State private var showDeadlineEditor = false
```

with:

```swift
    @AppStorage("dateEditorPlacement") private var placementRaw = DateEditorPlacement.overlay.rawValue
    @State private var hovering = false
    @Binding var editingItemID: UUID?

    private var placement: DateEditorPlacement { DateEditorPlacement(rawValue: placementRaw) ?? .overlay }
```

2. Wrap the existing row in a `VStack` so the inline editor can sit beneath it. Change the start of `body` from:

```swift
    var body: some View {
        HStack(spacing: 8) {
```

to:

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rowContent
            if placement == .inline, editingItemID == item.id {
                DeadlineEditor(store: store, item: item, onDismiss: { editingItemID = nil })
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
```

(The remainder of the old `HStack` body — modifiers `.padding`, `.frame`, `.contentShape`, `.onHover` included — now belongs to `rowContent`; leave it unchanged.)

3. Replace the clock button (which currently sets `showDeadlineEditor` and carries a `.popover`):

```swift
                Button { showDeadlineEditor = true } label: {
                    Image(systemName: "clock")
                        .foregroundStyle(dueColor ?? .secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showDeadlineEditor) {
                    DeadlineEditor(store: store, item: item, isPresented: $showDeadlineEditor)
                }
```

with:

```swift
                Button { editingItemID = item.id } label: {
                    Image(systemName: "clock")
                        .foregroundStyle(dueColor ?? .secondary)
                }
                .buttonStyle(.plain)
```

- [ ] **Step 2: Update `MenuContentView`**

In `App/Views/MenuContentView.swift`:

1. Add state and placement near the other `@State` declarations (after `@State private var screen: Screen = .list`):

```swift
    @State private var editingItemID: UUID?
    @AppStorage("dateEditorPlacement") private var placementRaw = DateEditorPlacement.overlay.rawValue

    private var placement: DateEditorPlacement { DateEditorPlacement(rawValue: placementRaw) ?? .overlay }
```

2. Pass the binding to each row. Change:

```swift
                        ForEach(sortedItems) { item in
                            TodoRowView(store: store, item: item)
                        }
```

to:

```swift
                        ForEach(sortedItems) { item in
                            TodoRowView(store: store, item: item, editingItemID: $editingItemID)
                        }
```

3. Add the overlay card. Change the `listScreen` container modifiers from:

```swift
        .frame(width: 320)
        .onAppear { inputFocused = true }
```

to:

```swift
        .frame(width: 320)
        .onAppear { inputFocused = true }
        .overlay {
            if placement == .overlay, let id = editingItemID,
               let item = rawItems.first(where: { $0.id == id }) {
                ZStack {
                    Color.black.opacity(0.35)
                        .onTapGesture { editingItemID = nil }
                    DeadlineEditor(store: store, item: item, onDismiss: { editingItemID = nil })
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 20)
                }
            }
        }
```

- [ ] **Step 3: Generate the project and build**

Run:
```bash
xcodegen generate && xcodebuild -project Doable.xcodeproj -scheme Doable -destination 'platform=macOS' build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run and verify behavior manually**

Launch the app (via the `run` skill or `xcodebuild` product). Verify:
- Clicking the clock opens the editor; moving the mouse onto it does **not** close it (overlay mode, default).
- A preset (e.g. Tomorrow) sets the due date and dismisses.
- Custom picker + Done sets the chosen date; Clear removes it.
- Clicking the dimmed background dismisses without changing the date.

- [ ] **Step 5: Commit**

```bash
git add App/Views/MenuContentView.swift App/Views/TodoRowView.swift
git commit -m "feat(app): in-window deadline editor with overlay and inline placement

Claude-Session: https://claude.ai/code/session_014RtKbLC7wYagMiCzAJS15e"
```

---

### Task 5: Add placement setting

**Files:**
- Modify: `App/Views/SettingsView.swift`

**Interfaces:**
- Consumes: `DateEditorPlacement` (Task 2); `@AppStorage("dateEditorPlacement")` (read by Task 4).

- [ ] **Step 1: Add the picker**

In `App/Views/SettingsView.swift`:

1. Add the backing storage after the existing `@AppStorage` lines:

```swift
    @AppStorage("dateEditorPlacement") private var placementRaw = DateEditorPlacement.overlay.rawValue
```

2. Add the picker inside the `Form`, after the existing "Due soon" `Picker`:

```swift
            Picker("Date editor", selection: $placementRaw) {
                ForEach(DateEditorPlacement.allCases, id: \.rawValue) { p in
                    Text(p.displayName).tag(p.rawValue)
                }
            }
```

3. Grow the window to fit the new row. Change:

```swift
        .frame(width: 380, height: 200)
```

to:

```swift
        .frame(width: 380, height: 240)
```

- [ ] **Step 2: Build**

Run:
```bash
xcodebuild -project Doable.xcodeproj -scheme Doable -destination 'platform=macOS' build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Run and verify**

Launch the app, open Settings, switch "Date editor" to **Inline**. Reopen the menu, click a clock — the editor now expands beneath the row instead of as an overlay, and still does not close on hover. Switch back to Overlay and confirm it reverts.

- [ ] **Step 4: Commit**

```bash
git add App/Views/SettingsView.swift
git commit -m "feat(app): setting to choose date editor placement

Claude-Session: https://claude.ai/code/session_014RtKbLC7wYagMiCzAJS15e"
```

---

## Notes for the implementer

- `rawItems` in `MenuContentView` is the unsorted `@Query` array; it's fine to look up the editing item there (it contains every active item).
- The overlay's `Color.black.opacity(0.35)` intentionally covers only the `listScreen` frame (320pt wide), not the whole screen — it's confined to the menu window.
- Do not reintroduce `.popover` anywhere; that is the bug being fixed.
- `TodoStore.setDueDate` already clears `staleSnoozeUntil` when a date is set — no extra handling needed in the editor.
