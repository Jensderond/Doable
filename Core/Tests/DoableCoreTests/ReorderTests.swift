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
