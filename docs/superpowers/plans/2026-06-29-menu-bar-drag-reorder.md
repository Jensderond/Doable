# Menu Bar Drag-to-Reorder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user click-and-drag rows in the menu bar todo list to set their own order, with pinned items always on top.

**Architecture:** Add a `sortIndex: Int` to `TodoItem`/`Orderable` and make `Ordering.activeSorted` sort by `(isPinned desc, sortIndex asc)`. The tricky reorder math lives as pure, unit-tested functions in `DoableCore` (`Reorder.move`, `Reorder.placeAtTopOfSection`); `TodoStore` fetches the active items, calls those helpers, writes back `sortIndex`/`isPinned`, and saves. The view makes each whole row `.draggable` with a `.dropDestination` that translates a drop into a `(from, to)` move.

**Tech Stack:** Swift, SwiftUI, SwiftData, XCTest. macOS menu-bar app. Shared logic in the `DoableCore` Swift package.

## Global Constraints

- Deadline and created-date drive **coloring** (overdue red, due-soon orange) and the **Stale** badge only — never order. Do not change `Classifier` or `StaleRule`.
- Pinned items ALWAYS sort above unpinned items. `isPinned` is the primary sort key; this invariant must hold even if `sortIndex` values drift.
- `sortIndex` is defaulted (`= 0`) so the SwiftData schema change is additive and existing stores migrate cleanly.
- Core unit tests run with: `cd Core && swift test`.
- The App target has no unit-test target; App-target changes (`TodoStore`, views) are verified with `xcodebuild -project Doable.xcodeproj -scheme Doable -configuration Debug build` (or `just build`) plus manual drag testing.
- Lower `sortIndex` sorts higher in the list.

---

### Task 1: Data model + sort foundation

Adds the `sortIndex` field and switches `activeSorted` from deadline-based to manual ordering. After this task the whole project still compiles (CLI, views, label all delegate to `activeSorted`) and Core tests pass.

**Files:**
- Modify: `Core/Sources/DoableCore/TodoItem.swift`
- Modify: `Core/Sources/DoableCore/Ordering.swift`
- Test: `Core/Tests/DoableCoreTests/OrderingTests.swift` (rewrite)

**Interfaces:**
- Produces: `TodoItem.sortIndex: Int` (stored, default `0`); `Orderable.sortIndex: Int { get }` (protocol requirement with default `0`); `Ordering.activeSorted` now orders by `(isPinned desc, sortIndex asc, createdAt desc)`.

- [ ] **Step 1: Rewrite the ordering tests for manual order**

Replace the entire contents of `Core/Tests/DoableCoreTests/OrderingTests.swift` with:

```swift
import XCTest
@testable import DoableCore

private struct Stub: Orderable, Equatable {
    let name: String
    let dueDate: Date?
    let createdAt: Date
    var isPinned: Bool = false
    var sortIndex: Int = 0
}

final class OrderingTests: XCTestCase {
    let cal = utcCalendar()

    private func stub(_ name: String, sortIndex: Int = 0, pinned: Bool = false,
                      created: Int = 1) -> Stub {
        Stub(name: name, dueDate: nil,
             createdAt: date(2026, 6, created, 9, 0, calendar: cal),
             isPinned: pinned, sortIndex: sortIndex)
    }

    func test_activeSorted_orders_by_sortIndex_ascending() {
        let a = stub("a", sortIndex: 2)
        let b = stub("b", sortIndex: 0)
        let c = stub("c", sortIndex: 1)
        XCTAssertEqual(Ordering.activeSorted([a, b, c]).map(\.name), ["b", "c", "a"])
    }

    func test_pinned_always_sort_before_unpinned_regardless_of_sortIndex() {
        let pinned = stub("pinned", sortIndex: 99, pinned: true)
        let unpinned = stub("unpinned", sortIndex: 0)
        XCTAssertEqual(Ordering.activeSorted([unpinned, pinned]).map(\.name),
                       ["pinned", "unpinned"])
    }

    func test_equal_sortIndex_breaks_tie_newest_first() {
        // Migration case: existing items all share sortIndex 0.
        let older = stub("older", sortIndex: 0, created: 20)
        let newer = stub("newer", sortIndex: 0, created: 25)
        XCTAssertEqual(Ordering.activeSorted([older, newer]).map(\.name),
                       ["newer", "older"])
    }

    func test_mostUrgent_is_top_of_manual_list_pinned_first() {
        let pinned = stub("pinned", sortIndex: 5, pinned: true)
        let topUnpinned = stub("top", sortIndex: 0)
        XCTAssertEqual(Ordering.mostUrgent([topUnpinned, pinned])?.name, "pinned")
        XCTAssertEqual(Ordering.mostUrgent([topUnpinned])?.name, "top")
        XCTAssertNil(Ordering.mostUrgent([Stub]()))
    }

    func test_menuBarTask_topTask_surfaces_manual_top() {
        let top = stub("top", sortIndex: 0)
        let next = stub("next", sortIndex: 1)
        XCTAssertEqual(Ordering.menuBarTask([next, top], scope: .topTask)?.name, "top")
        XCTAssertNil(Ordering.menuBarTask([Stub](), scope: .topTask))
    }

    func test_menuBarTask_pinnedOnly_surfaces_pinned_else_nil() {
        let pinned = stub("pinned", sortIndex: 9, pinned: true)
        let unpinned = stub("unpinned", sortIndex: 0)
        XCTAssertEqual(Ordering.menuBarTask([unpinned, pinned], scope: .pinnedOnly)?.name,
                       "pinned")
        XCTAssertNil(Ordering.menuBarTask([unpinned], scope: .pinnedOnly))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd Core && swift test --filter OrderingTests`
Expected: FAIL — `Stub` has no member `sortIndex` and/or `Orderable` has no `sortIndex` (compile error), and the new sort expectations don't hold.

- [ ] **Step 3: Add `sortIndex` to the model**

In `Core/Sources/DoableCore/TodoItem.swift`, add the stored property after `isPinned` (line ~14) and initialize it in `init`:

```swift
    /// User-pinned to the top of the active list. Defaulted so existing stores migrate cleanly.
    public var isPinned: Bool = false
    /// Manual position within the active list. Lower sorts higher. Defaulted so existing
    /// SwiftData stores migrate cleanly (existing items tie at 0 and fall back to createdAt).
    public var sortIndex: Int = 0

    public init(title: String, createdAt: Date, dueDate: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.isDone = false
        self.completedAt = nil
        self.staleSnoozeUntil = nil
        self.isPinned = false
        self.sortIndex = 0
    }
```

- [ ] **Step 4: Add `sortIndex` to `Orderable` and rewrite the sort**

In `Core/Sources/DoableCore/Ordering.swift`, add the protocol requirement and default, rewrite `activeSorted`, update the doc comments on `mostUrgent`/`menuBarTask`, and delete the now-unused `deadlinePrecedes`:

```swift
/// Anything sortable in the active list. The app's SwiftData model conforms to this.
public protocol Orderable {
    var dueDate: Date? { get }
    var createdAt: Date { get }
    var isPinned: Bool { get }
    var sortIndex: Int { get }
}

extension Orderable {
    /// Defaults so lightweight conformances (e.g. tests) need not specify them.
    public var isPinned: Bool { false }
    public var sortIndex: Int { 0 }
}

public enum Ordering {
    /// Active-list order: pinned items first; then by the user's manual `sortIndex`
    /// (ascending — lower sorts higher). `createdAt` descending is the final tiebreaker,
    /// which also gives a stable initial order for migrated stores where every item ties
    /// at `sortIndex == 0`.
    public static func activeSorted<T: Orderable>(_ items: [T]) -> [T] {
        items.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            return lhs.createdAt > rhs.createdAt
        }
    }

    /// The single task to surface in the menu bar: the top of the active list (the user's
    /// manual top — first pinned item, otherwise the first unpinned). `nil` when empty.
    public static func mostUrgent<T: Orderable>(_ items: [T]) -> T? {
        activeSorted(items).first
    }

    /// The task to show in the menu bar for a given scope, or `nil` when nothing qualifies.
    /// `.topTask` surfaces the manual top; `.pinnedOnly` surfaces it only when it is pinned
    /// (which, given pinned items sort first, means "show only when something is pinned").
    public static func menuBarTask<T: Orderable>(_ items: [T], scope: MenuBarScope) -> T? {
        guard let top = mostUrgent(items) else { return nil }
        switch scope {
        case .topTask: return top
        case .pinnedOnly: return top.isPinned ? top : nil
        }
    }
}
```

Note: remove the entire `private static func deadlinePrecedes(...)` method — it has no remaining callers.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd Core && swift test --filter OrderingTests`
Expected: PASS (all 6 tests).

- [ ] **Step 6: Run the full Core suite to confirm nothing else broke**

Run: `cd Core && swift test`
Expected: PASS. (`MenuBarStateTests`' `Stub` does not declare `sortIndex`; the protocol default covers it.)

- [ ] **Step 7: Commit**

```bash
git add Core/Sources/DoableCore/TodoItem.swift Core/Sources/DoableCore/Ordering.swift Core/Tests/DoableCoreTests/OrderingTests.swift
git commit -m "feat(core): manual sortIndex ordering for the active list"
```

---

### Task 2: Pure reorder math in Core

The order-recomputation logic, isolated as pure functions so it is unit-testable without SwiftData. `move` handles drag-and-drop including the cross-boundary pin/unpin rule; `placeAtTopOfSection` handles new-item placement and pin-toggle repositioning.

**Files:**
- Create: `Core/Sources/DoableCore/Reorder.swift`
- Test: `Core/Tests/DoableCoreTests/ReorderTests.swift`

**Interfaces:**
- Consumes: nothing (pure functions over `[Bool]` pin flags).
- Produces:
  - `Reorder.Plan` — `struct Plan: Equatable { let order: [Int]; let pinned: [Bool] }` where `order` is the new visual order as indices into the input, and `pinned` is the post-move pin state indexed by **original** index.
  - `Reorder.move(pinFlags: [Bool], from: Int, to: Int) -> Plan` — `from` is the moved item's index in the current visual order; `to` is the **post-removal insertion index** (the index in the array with the moved item removed, where it should be reinserted; `0` = top, `count` = bottom).
  - `Reorder.placeAtTopOfSection(pinFlags: [Bool], moving: Int) -> [Int]` — returns the new visual order (indices into input) with `moving` placed at the top of the section matching `pinFlags[moving]`, others keeping their relative order, pinned-first overall.

- [ ] **Step 1: Write the failing tests**

Create `Core/Tests/DoableCoreTests/ReorderTests.swift`:

```swift
import XCTest
@testable import DoableCore

final class ReorderTests: XCTestCase {

    // MARK: move — plain reorder within a section

    func test_move_reorders_within_unpinned_section() {
        let plan = Reorder.move(pinFlags: [false, false, false], from: 2, to: 0)
        XCTAssertEqual(plan.order, [2, 0, 1])
        XCTAssertEqual(plan.pinned, [false, false, false]) // unchanged
    }

    // MARK: move — cross-boundary pin/unpin

    func test_move_unpinned_up_into_pinned_zone_pins_it() {
        // item 0 pinned; drag item 2 to the very top (above the pinned item).
        let plan = Reorder.move(pinFlags: [true, false, false], from: 2, to: 0)
        XCTAssertEqual(plan.order, [2, 0, 1])
        XCTAssertEqual(plan.pinned, [true, false, true]) // item 2 became pinned
    }

    func test_move_pinned_down_past_pinned_block_unpins_it() {
        // items 0,1 pinned, item 2 unpinned; drag item 0 to the bottom.
        let plan = Reorder.move(pinFlags: [true, true, false], from: 0, to: 2)
        XCTAssertEqual(plan.order, [1, 2, 0])
        XCTAssertEqual(plan.pinned, [false, true, false]) // item 0 became unpinned
    }

    func test_move_at_exact_boundary_keeps_pin_state() {
        // item 0 pinned, item 1 unpinned; drop item 1 exactly at the boundary (index 1).
        let plan = Reorder.move(pinFlags: [true, false], from: 1, to: 1)
        XCTAssertEqual(plan.order, [0, 1])
        XCTAssertEqual(plan.pinned, [true, false]) // unchanged
    }

    func test_move_with_no_pinned_items_does_not_auto_pin() {
        // No pinned items → no boundary; dragging to the top stays unpinned.
        let plan = Reorder.move(pinFlags: [false, false], from: 1, to: 0)
        XCTAssertEqual(plan.order, [1, 0])
        XCTAssertEqual(plan.pinned, [false, false])
    }

    // MARK: placeAtTopOfSection

    func test_place_unpinned_goes_to_top_of_unpinned_below_pinned() {
        // item 0 pinned, items 1,2 unpinned; place item 2 at top of its (unpinned) section.
        let order = Reorder.placeAtTopOfSection(pinFlags: [true, false, false], moving: 2)
        XCTAssertEqual(order, [0, 2, 1])
    }

    func test_place_pinned_goes_to_very_top() {
        // item 1 is pinned; placing it tops the whole list.
        let order = Reorder.placeAtTopOfSection(pinFlags: [false, true], moving: 1)
        XCTAssertEqual(order, [1, 0])
    }

    func test_place_new_item_appended_unpinned_lands_atop_unpinned() {
        // Simulates a new item: existing [pinned, unpinned] + new unpinned appended.
        let order = Reorder.placeAtTopOfSection(pinFlags: [true, false, false], moving: 2)
        XCTAssertEqual(order, [0, 2, 1]) // new item (index 2) sits just below the pinned item
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd Core && swift test --filter ReorderTests`
Expected: FAIL — `Reorder` is not defined.

- [ ] **Step 3: Implement `Reorder`**

Create `Core/Sources/DoableCore/Reorder.swift`:

```swift
import Foundation

/// Pure index math for the manually-ordered active list. Operates on a list of pin flags
/// in current visual order (pinned-first) and returns the new ordering as indices into the
/// input, so the SwiftData layer can apply `sortIndex`/`isPinned` without any ordering logic.
public enum Reorder {

    public struct Plan: Equatable {
        /// New visual order, as indices into the input `pinFlags`.
        public let order: [Int]
        /// Post-move pin state, indexed by the item's ORIGINAL index in `pinFlags`.
        public let pinned: [Bool]

        public init(order: [Int], pinned: [Bool]) {
            self.order = order
            self.pinned = pinned
        }
    }

    /// Move the item at `from` to post-removal insertion index `to`.
    ///
    /// Pinned items always remain above unpinned. The moved item flips its pin state when it
    /// lands strictly inside the opposite section: dropped above the pinned/unpinned boundary
    /// it becomes pinned, dropped below it becomes unpinned, dropped exactly at the boundary it
    /// keeps its state. With no other pinned items there is no boundary, so the state is kept.
    public static func move(pinFlags: [Bool], from: Int, to: Int) -> Plan {
        var pinned = pinFlags
        var others = Array(0..<pinFlags.count)
        others.remove(at: from)

        // Boundary = number of pinned items among the *other* items. others[0..<p] are pinned.
        let p = others.filter { pinFlags[$0] }.count
        let d = max(0, min(to, others.count))

        if d < p { pinned[from] = true }
        else if d > p { pinned[from] = false }
        // d == p → boundary, keep existing state.

        var order = others
        order.insert(from, at: d)
        return Plan(order: order, pinned: pinned)
    }

    /// Place `moving` at the top of the section matching `pinFlags[moving]`, keeping all other
    /// items in their current relative order and pinned-first overall. Used for new-item
    /// placement (append the new item to `pinFlags` as `false`, pass its index) and for
    /// repositioning an item right after its pin state was toggled.
    public static func placeAtTopOfSection(pinFlags: [Bool], moving: Int) -> [Int] {
        var others = Array(0..<pinFlags.count)
        others.remove(at: moving)

        if pinFlags[moving] {
            return [moving] + others
        }
        let pinnedOthers = others.filter { pinFlags[$0] }
        let unpinnedOthers = others.filter { !pinFlags[$0] }
        return pinnedOthers + [moving] + unpinnedOthers
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd Core && swift test --filter ReorderTests`
Expected: PASS (all 8 tests).

- [ ] **Step 5: Commit**

```bash
git add Core/Sources/DoableCore/Reorder.swift Core/Tests/DoableCoreTests/ReorderTests.swift
git commit -m "feat(core): pure reorder math for manual ordering"
```

---

### Task 3: TodoStore — assign indices, move, pin repositioning

Wires the Core helpers into the SwiftData layer: new items land atop the unpinned section, `move(from:to:)` applies a drag, and `togglePin` repositions the toggled item to the top of its new section.

**Files:**
- Modify: `App/Models/TodoStore.swift`

**Interfaces:**
- Consumes: `Reorder.move`, `Reorder.placeAtTopOfSection`, `Ordering.activeSorted` (Tasks 1–2).
- Produces:
  - `TodoStore.move(from: Int, to: Int, in: ModelContext)` — `from`/`to` are indices into the current `Ordering.activeSorted(activeItems)` (the same order the view renders); `to` is a post-removal insertion index.
  - Updated `create`/`insert` placing new items atop the unpinned section.
  - Updated `togglePin` repositioning the item.

- [ ] **Step 1: Add an active-items fetch helper**

In `App/Models/TodoStore.swift`, add a private helper (place it just above the existing `private func save`):

```swift
    /// Fetches the active (not done) items in current visual order.
    private func activeItems(in context: ModelContext) -> [TodoItem] {
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.isDone == false })
        let items = (try? context.fetch(descriptor)) ?? []
        return Ordering.activeSorted(items)
    }

    /// Writes `sortIndex = visual position` for `items` reordered by `order`
    /// (indices into `items`), then saves.
    private func renumber(_ items: [TodoItem], by order: [Int], in context: ModelContext) {
        for (position, originalIndex) in order.enumerated() {
            items[originalIndex].sortIndex = position
        }
        save(context)
    }
```

- [ ] **Step 2: Place new items atop the unpinned section**

Replace the existing `create` / `insert` (lines ~13–23). `insert` is `static`; convert new-item placement into an instance method so it can renumber, and have `create` call it. Replace both with:

```swift
    func create(title: String, in context: ModelContext) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = TodoItem(title: trimmed, createdAt: Date())
        context.insert(item)

        // Place the new (unpinned) item at the top of the unpinned section.
        let items = activeItems(in: context)
        guard let moving = items.firstIndex(where: { $0.id == item.id }) else {
            save(context); return
        }
        let order = Reorder.placeAtTopOfSection(pinFlags: items.map(\.isPinned), moving: moving)
        renumber(items, by: order, in: context)
    }
```

Then check for other callers of the old `static func insert`. Run:

`grep -rn "TodoStore.insert\|\.insert(title" --include="*.swift" .`

If any callers exist (e.g. tests, CLI, an onboarding seed), update them to use `create(title:in:)`. If none exist, the removal is clean.

- [ ] **Step 3: Add `move(from:to:)`**

Add this method (place it near `togglePin`):

```swift
    /// Applies a drag-reorder. `from`/`to` index into the current visual order
    /// (`Ordering.activeSorted` of the active items); `to` is the post-removal insertion index.
    func move(from: Int, to: Int, in context: ModelContext) {
        let items = activeItems(in: context)
        guard items.indices.contains(from) else { return }
        let plan = Reorder.move(pinFlags: items.map(\.isPinned), from: from, to: to)
        for (originalIndex, item) in items.enumerated() {
            item.isPinned = plan.pinned[originalIndex]
        }
        renumber(items, by: plan.order, in: context)
    }
```

- [ ] **Step 4: Reposition on pin toggle**

Replace the existing `togglePin` (lines ~48–51) with:

```swift
    /// Pins or unpins an item, then moves it to the top of its new section so the change
    /// is visible and the manual order stays consistent (pinned always above unpinned).
    func togglePin(_ item: TodoItem, in context: ModelContext) {
        let items = activeItems(in: context)
        guard let moving = items.firstIndex(where: { $0.id == item.id }) else { return }
        item.isPinned.toggle() // `items` holds the same reference, so the flag below reflects this.
        let order = Reorder.placeAtTopOfSection(pinFlags: items.map(\.isPinned), moving: moving)
        renumber(items, by: order, in: context)
    }
```

- [ ] **Step 5: Build to verify the App target compiles**

Run: `xcodebuild -project Doable.xcodeproj -scheme Doable -configuration Debug build`
Expected: `BUILD SUCCEEDED`. (No App unit-test target exists; the ordering math is covered by Tasks 1–2.)

- [ ] **Step 6: Commit**

```bash
git add App/Models/TodoStore.swift
git commit -m "feat(store): assign sortIndex on create, add move + pin repositioning"
```

---

### Task 4: Whole-row drag-and-drop in the menu list

Makes each row a drag source and drop target, translating a drop into a `(from, to)` call to `store.move`. Includes a trailing drop zone for dropping at the bottom and minimal drag/drop visual feedback.

**Files:**
- Modify: `App/Views/TodoRowView.swift`
- Modify: `App/Views/MenuContentView.swift`

**Interfaces:**
- Consumes: `TodoStore.move(from:to:in:)` (Task 3).
- Produces: drag-reorder UI. No new public API.

- [ ] **Step 1: Make each row draggable (whole row)**

In `App/Views/TodoRowView.swift`, attach `.draggable` to the `rowContent` so the whole row is the drag handle. Modify the `body` (lines ~38–47). The item's checkbox/bookmark/`…` menu remain tappable; a press-and-drag on the row body starts the drag. Do not allow dragging an item that is pending-done (it is about to be archived):

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isPendingDone {
                rowContent
            } else {
                rowContent
                    .draggable(item.id.uuidString) {
                        // Drag preview: the row's title on a subtle background.
                        Text(item.title)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
            }
            if isEditing {
                DeadlineEditor(store: store, item: item, onDismiss: { editingItemID = nil })
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
        }
    }
```

- [ ] **Step 2: Add drop handling in the list**

In `App/Views/MenuContentView.swift`, replace the `ForEach` block (lines ~70–77, the `VStack(alignment: .leading, spacing: 0) { ForEach(...) }` and its `.background`) so each row is a drop target that inserts the dragged item **above** the dropped-on row, plus a trailing drop zone for the bottom. Add a `@State` to track the active drop target for a subtle indicator.

Add near the other `@State` declarations (after line ~22):

```swift
    /// The id of the row currently highlighted as a drop target (for an insertion indicator).
    @State private var dropTargetID: UUID?
```

Replace the list `VStack` with:

```swift
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(sortedItems) { item in
                            TodoRowView(store: store, item: item, editingItemID: $editingItemID)
                                .overlay(alignment: .top) {
                                    if dropTargetID == item.id {
                                        Rectangle()
                                            .fill(Color.accentColor)
                                            .frame(height: 2)
                                    }
                                }
                                .dropDestination(for: String.self) { ids, _ in
                                    handleDrop(ids, onto: item)
                                } isTargeted: { targeted in
                                    dropTargetID = targeted ? item.id : (dropTargetID == item.id ? nil : dropTargetID)
                                }
                        }
                        // Trailing zone so an item can be dropped at the very bottom.
                        Color.clear
                            .frame(height: 8)
                            .contentShape(Rectangle())
                            .dropDestination(for: String.self) { ids, _ in
                                handleDrop(ids, onto: nil)
                            }
                    }
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: ListHeightKey.self, value: proxy.size.height)
                    })
                }
```

- [ ] **Step 3: Add the drop translation helper**

In `App/Views/MenuContentView.swift`, add this method to the struct (place it just below `addItem()`):

```swift
    /// Translates a dropped item id into a `(from, to)` move. Dropping onto `target` inserts the
    /// dragged item immediately above `target`; a `nil` target drops it at the bottom. `to` is the
    /// post-removal insertion index that `TodoStore.move` expects.
    @discardableResult
    private func handleDrop(_ ids: [String], onto target: TodoItem?) -> Bool {
        dropTargetID = nil
        guard let draggedID = ids.first.flatMap({ UUID(uuidString: $0) }),
              let from = sortedItems.firstIndex(where: { $0.id == draggedID }),
              draggedID != target?.id
        else { return false }

        let reduced = sortedItems.filter { $0.id != draggedID }
        let to: Int
        if let target, let idx = reduced.firstIndex(where: { $0.id == target.id }) {
            to = idx
        } else {
            to = reduced.count // dropped on the trailing zone → bottom
        }
        store.move(from: from, to: to, in: context)
        return true
    }
```

- [ ] **Step 4: Build to verify the App target compiles**

Run: `xcodebuild -project Doable.xcodeproj -scheme Doable -configuration Debug build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Manual verification**

The build phase auto-installs to `/Applications`. Launch and verify:

Run: `open /Applications/Doable.app`

Check each behavior:
1. Add several todos; the newest appears at the top of the unpinned section.
2. Drag a row up/down within the unpinned section — it stays where dropped after reopening the popover.
3. Pin one item (bookmark); it jumps to the top. Drag an unpinned item above it → the dragged item becomes pinned (bookmark fills).
4. Drag a pinned item below the pinned block → it becomes unpinned.
5. With no pinned items, drag a row to the very top → it does NOT become pinned.
6. The checkbox, bookmark button, and `…` menu still respond to clicks (drag did not eat the taps).
7. The menu bar label shows whatever item is at the very top of the list.

- [ ] **Step 6: Commit**

```bash
git add App/Views/TodoRowView.swift App/Views/MenuContentView.swift
git commit -m "feat(menu): whole-row drag-and-drop reordering"
```

---

## Self-Review

**Spec coverage:**
- Manual order overrides deadline/created → Task 1 (`activeSorted` by `sortIndex`). ✓
- Pinned always on top → Task 1 (primary sort key) + invariant preserved by `Reorder` (Task 2). ✓
- Cross-boundary drag pins/unpins; no auto-pin with zero pinned → Task 2 `move` + tests. ✓
- New item at top of unpinned → Task 2 `placeAtTopOfSection` + Task 3 `create`. ✓
- Whole-row drag (approach A), preserves auto-sizing, doesn't break tap targets → Task 4. ✓
- Menu-bar label follows manual top → Task 1 (`menuBarTask` delegates to `activeSorted`) + manual check 7. ✓
- Deadline coloring / Stale untouched → no changes to `Classifier`/`StaleRule`; `dueColor`/`isStale` in `TodoRowView` left intact. ✓
- Additive SwiftData migration → Task 1 defaulted `sortIndex`; tie-break test covers the migration case. ✓
- CLI follows automatically → no CLI change needed (delegates to `activeSorted`). ✓

**Placeholder scan:** No TBD/TODO; every code step shows complete code; every test step shows assertions and the run command with expected result.

**Type consistency:** `Reorder.Plan { order: [Int]; pinned: [Bool] }`, `Reorder.move(pinFlags:from:to:) -> Plan`, `Reorder.placeAtTopOfSection(pinFlags:moving:) -> [Int]`, `TodoStore.move(from:to:in:)`, `activeItems(in:)`, `renumber(_:by:in:)`, and `handleDrop(_:onto:)` are referenced consistently across Tasks 2–4. The drag payload is `String` (`item.id.uuidString`) on both the `.draggable` and `.dropDestination(for: String.self)` sides.
