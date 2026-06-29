# Bookmark Separator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render a visible thin separator at the bookmarked↔normal boundary in the menu's drag-reorder list, so crossing it (which flips a task's pin state) is obvious instead of accidental.

**Architecture:** Add one pure index helper to `DoableCore.Reorder` that returns where the separator belongs (resting and mid-drag), unit-tested in isolation. `MenuContentView` consumes it to (a) draw a plain divider line that is emphasized during a drag, and (b) make the floating drag-ghost preview its prospective pin state. No change to the existing pin-flip logic in `Reorder.move`.

**Tech Stack:** Swift, SwiftUI, SwiftData, SwiftPM (`DoableCore`), XCTest.

## Global Constraints

- macOS 14+ (`Core/Package.swift` platforms: `.macOS(.v14)`).
- `DoableCore` is pure (no Foundation/SwiftUI imports needed for `Reorder`); keep the new helper dependency-free.
- The separator is purely visual: it must not change `Reorder.move`'s pin-flip rules, must be inert (`.allowsHitTesting(false)`), and must not participate in `targetIndex` drop math (which keys off row midpoints).
- Separator style is a plain thin line (no labels/headers), shown only when both a bookmarked and a normal task exist, emphasized (accent-colored, slightly heavier) during a drag.
- Run Core tests with: `swift test --package-path Core --filter ReorderTests`

---

### Task 1: `Reorder.separatorIndex` pure helper

Returns the display index at which to insert the separator, or `nil` when no boundary should show. The rule mirrors `Reorder.move`: the boundary sits after the pinned items among the **non-dragged** items (`p`), and is shown only when there is at least one pinned-among-others and at least one unpinned task overall.

**Files:**
- Modify: `Core/Sources/DoableCore/Reorder.swift` (add a static func to the `Reorder` enum)
- Test: `Core/Tests/DoableCoreTests/ReorderTests.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces: `public static func separatorIndex(pinFlags: [Bool], dragging: Int?) -> Int?`
  - `pinFlags`: pin state in current visual order (pinned-first overall; the non-dragged items are always contiguous pinned-then-unpinned).
  - `dragging`: index of the item being dragged in that same array, or `nil` at rest.
  - Returns: an insertion index in `0...pinFlags.count` (the separator goes *before* the item at that index; `pinFlags.count` means "after the last row"), or `nil` for no separator.

- [ ] **Step 1: Write the failing tests**

Add to `Core/Tests/DoableCoreTests/ReorderTests.swift`, inside the `ReorderTests` class:

```swift
    // MARK: separatorIndex — at rest

    func test_separator_rest_mixed_sits_before_first_unpinned() {
        XCTAssertEqual(Reorder.separatorIndex(pinFlags: [true, true, false, false], dragging: nil), 2)
    }

    func test_separator_rest_single_each() {
        XCTAssertEqual(Reorder.separatorIndex(pinFlags: [true, false], dragging: nil), 1)
    }

    func test_separator_rest_all_pinned_is_nil() {
        XCTAssertNil(Reorder.separatorIndex(pinFlags: [true, true], dragging: nil))
    }

    func test_separator_rest_all_unpinned_is_nil() {
        XCTAssertNil(Reorder.separatorIndex(pinFlags: [false, false], dragging: nil))
    }

    // MARK: separatorIndex — during a drag (boundary excludes the dragged item)

    func test_separator_drag_unpinned_dragged_to_top_lands_below_pinned_others() {
        // order = [draggedUnpinned, pinned, pinned, unpinned]; boundary after the 2 pinned others.
        XCTAssertEqual(Reorder.separatorIndex(pinFlags: [false, true, true, false], dragging: 0), 3)
    }

    func test_separator_drag_pinned_dragged_down_into_unpinned() {
        // order = [pinnedOther, unpinned, draggedPinned, unpinned]; one pinned other → boundary after it.
        XCTAssertEqual(Reorder.separatorIndex(pinFlags: [true, false, true, false], dragging: 2), 1)
    }

    func test_separator_drag_all_others_pinned_dragged_unpinned_shows_at_end() {
        // order = [draggedUnpinned, pinned, pinned]; both pinned others above → separator after them.
        XCTAssertEqual(Reorder.separatorIndex(pinFlags: [false, true, true], dragging: 0), 3)
    }

    func test_separator_drag_no_pinned_others_is_nil() {
        XCTAssertNil(Reorder.separatorIndex(pinFlags: [false, false, false], dragging: 1))
    }

    func test_separator_drag_all_pinned_is_nil() {
        // No unpinned task anywhere → no boundary to draw.
        XCTAssertNil(Reorder.separatorIndex(pinFlags: [true, true, true], dragging: 0))
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path Core --filter ReorderTests`
Expected: FAIL — compile error, `type 'Reorder' has no member 'separatorIndex'`.

- [ ] **Step 3: Implement the helper**

Add to the `Reorder` enum in `Core/Sources/DoableCore/Reorder.swift` (after `move`):

```swift
    /// Display index at which to draw the pinned↔unpinned separator, or `nil` for none.
    ///
    /// The boundary mirrors `move`: it sits just after the pinned items among the *other*
    /// (non-dragged) items. Shown only when there is at least one pinned non-dragged item AND at
    /// least one unpinned item overall — i.e. only when crossing it can actually flip a pin state.
    /// During a drag the dragged item is excluded from the boundary count, so its live position
    /// relative to the returned index tells the user whether it will become pinned (above) or
    /// unpinned (below). The returned value is an insertion index in `0...pinFlags.count`.
    public static func separatorIndex(pinFlags: [Bool], dragging: Int?) -> Int? {
        let others = pinFlags.indices.filter { $0 != dragging }
        let pinnedOthers = others.filter { pinFlags[$0] }.count
        let unpinnedTotal = pinFlags.filter { !$0 }.count
        guard pinnedOthers >= 1, unpinnedTotal >= 1 else { return nil }

        // Walk the visible rows; place the separator right after the p-th non-dragged item.
        var seen = 0
        for i in pinFlags.indices where i != dragging {
            seen += 1
            if seen == pinnedOthers { return i + 1 }
        }
        return pinFlags.count
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path Core --filter ReorderTests`
Expected: PASS (all `separatorIndex` tests plus the pre-existing `move`/`placeAtTopOfSection` tests).

- [ ] **Step 5: Commit**

```bash
git add Core/Sources/DoableCore/Reorder.swift Core/Tests/DoableCoreTests/ReorderTests.swift
git commit -m "feat(core): add Reorder.separatorIndex for pin boundary marker"
```

---

### Task 2: Draw the separator in the list

Inject the plain divider line at the boundary index in `MenuContentView`'s row stack. Plain/subtle at rest; accent-colored and slightly heavier during a drag.

**Files:**
- Modify: `App/Views/MenuContentView.swift` (the `ForEach(displayItems)` block at lines ~88-92; add a computed `separatorIndex` and a `bookmarkSeparator` view)

**Interfaces:**
- Consumes: `Reorder.separatorIndex(pinFlags:dragging:)` from Task 1; existing `displayItems: [TodoItem]` and `draggingItem: TodoItem?`.
- Produces: `private var separatorIndex: Int?` used again in Task 3.

- [ ] **Step 1: Add the boundary computation**

In `MenuContentView` (e.g. just after the `displayItems` computed property near line 35), add:

```swift
    /// Insertion index in `displayItems` for the pinned↔normal separator, or `nil` when none.
    private var separatorIndex: Int? {
        let flags = displayItems.map(\.isPinned)
        let dragIdx = draggingItem.flatMap { d in displayItems.firstIndex { $0.id == d.id } }
        return Reorder.separatorIndex(pinFlags: flags, dragging: dragIdx)
    }
```

- [ ] **Step 2: Add the separator view**

Add a view builder alongside the other row helpers (e.g. after `ghostRow` near line 177):

```swift
    /// A thin rule marking the bookmarked↔normal boundary. Subtle at rest; accent-colored and a
    /// touch heavier while dragging, so crossing it (which flips the pin state) is obvious.
    private var bookmarkSeparator: some View {
        let dragging = draggingItem != nil
        return Rectangle()
            .fill(dragging ? Color.accentColor.opacity(0.9) : Color.secondary.opacity(0.25))
            .frame(height: dragging ? 2 : 1)
            .padding(.horizontal, 10)
            .padding(.vertical, dragging ? 3 : 2)
            .allowsHitTesting(false)
    }
```

- [ ] **Step 3: Render the separator at the boundary**

Replace the existing rows `VStack` (currently lines ~88-92):

```swift
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(displayItems) { item in
                                listRow(item)
                            }
                        }
```

with a version that interleaves the separator:

```swift
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(displayItems.enumerated()), id: \.element.id) { idx, item in
                                if idx == separatorIndex { bookmarkSeparator }
                                listRow(item)
                            }
                            if separatorIndex == displayItems.count { bookmarkSeparator }
                        }
```

- [ ] **Step 4: Build and verify in the app**

Run: `swift build --package-path Core` then build the app per the project's build flow (see `MEMORY.md` — builds auto-install to `/Applications`); or use `/run`.
Expected: With at least one bookmarked and one normal task, a faint line sits between the two groups. With all-pinned or all-normal lists, no line appears. Picking up a row to drag turns the line accent-colored and slightly thicker.

- [ ] **Step 5: Commit**

```bash
git add App/Views/MenuContentView.swift
git commit -m "feat(menu): draw bookmark separator at the pin boundary"
```

---

### Task 3: Ghost previews prospective pin state

While dragging, the floating ghost's title goes bold when it sits above the separator (would become bookmarked) and regular when below, instead of always reflecting the task's current pin state.

**Files:**
- Modify: `App/Views/MenuContentView.swift` (`ghostRow` near lines 163-177; add a `draggedWouldBePinned` computed property)

**Interfaces:**
- Consumes: `separatorIndex` (Task 2), `draggingItem`, `displayItems`.
- Produces: none (terminal task).

- [ ] **Step 1: Add the prospective-state computation**

Add to `MenuContentView` (near `separatorIndex`):

```swift
    /// Whether the dragged item would become bookmarked if dropped now (it sits above the
    /// separator). Falls back to its current pin state when no boundary is shown.
    private var draggedWouldBePinned: Bool {
        guard let d = draggingItem else { return false }
        guard let s = separatorIndex,
              let idx = displayItems.firstIndex(where: { $0.id == d.id }) else { return d.isPinned }
        return idx < s
    }
```

- [ ] **Step 2: Drive the ghost's weight from the prospective state**

In `ghostRow`, change the title's `fontWeight` line from:

```swift
                .fontWeight(item.isPinned ? .bold : .regular)
```

to:

```swift
                .fontWeight(draggedWouldBePinned ? .bold : .regular)
```

- [ ] **Step 3: Build and verify in the app**

Build/run as in Task 2 Step 4.
Expected: Dragging a normal task up across the line makes the floating ghost's title go **bold** (preview: will be bookmarked); dragging a bookmarked task down below the line makes it **regular**. Releasing commits a pin state matching the preview.

- [ ] **Step 4: Run the full Core test suite (no regressions)**

Run: `swift test --package-path Core`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/Views/MenuContentView.swift
git commit -m "feat(menu): ghost previews prospective bookmark state while dragging"
```

---

## Self-Review

**Spec coverage:**
- Plain thin line → Task 2 `bookmarkSeparator`.
- Visible only when both sections non-empty → `separatorIndex` returns `nil` otherwise (Task 1, tested).
- Emphasized during drag → Task 2 (accent color, heavier).
- Boundary excludes dragged item / matches `Reorder.move` → Task 1 rule + tests.
- Prospective-state ghost preview → Task 3.
- Edge cases (no bookmarks, all bookmarked, single each, pending-done untouched, dismiss mid-drag) → covered by `separatorIndex` nil-cases and unchanged drag teardown (`endDrag`).

**Placeholder scan:** none — all steps show concrete code and exact commands.

**Type consistency:** `separatorIndex(pinFlags:dragging:) -> Int?` is defined in Task 1 and consumed verbatim in Tasks 2-3; `separatorIndex` (view computed) and `draggedWouldBePinned` names are used consistently.
