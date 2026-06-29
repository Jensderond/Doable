import XCTest
@testable import DoableCore

private struct Stub: Orderable, Equatable {
    let name: String
    let dueDate: Date?
    let createdAt: Date
    var isPinned: Bool = false
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

    func test_pinned_items_sort_before_unpinned_even_with_later_deadline() {
        let pinned = Stub(name: "pinned", dueDate: nil, createdAt: date(2026, 6, 1, 9, 0, calendar: cal), isPinned: true)
        let dated = Stub(name: "dated", dueDate: date(2026, 6, 28, 9, 0, calendar: cal), createdAt: date(2026, 6, 1, 9, 0, calendar: cal))
        let sorted = Ordering.activeSorted([dated, pinned])
        XCTAssertEqual(sorted.map(\.name), ["pinned", "dated"])
    }

    func test_deadline_rules_apply_within_pinned_group() {
        let late = Stub(name: "late", dueDate: date(2026, 7, 5, 9, 0, calendar: cal), createdAt: date(2026, 6, 1, 9, 0, calendar: cal), isPinned: true)
        let soon = Stub(name: "soon", dueDate: date(2026, 6, 28, 9, 0, calendar: cal), createdAt: date(2026, 6, 1, 9, 0, calendar: cal), isPinned: true)
        let unpinned = Stub(name: "unpinned", dueDate: date(2026, 6, 27, 9, 0, calendar: cal), createdAt: date(2026, 6, 1, 9, 0, calendar: cal))
        let sorted = Ordering.activeSorted([unpinned, late, soon])
        XCTAssertEqual(sorted.map(\.name), ["soon", "late", "unpinned"])
    }

    func test_mostUrgent_is_pinned_top_then_soonest_deadline() {
        let pinned = Stub(name: "pinned", dueDate: nil, createdAt: date(2026, 6, 1, 9, 0, calendar: cal), isPinned: true)
        let soon = Stub(name: "soon", dueDate: date(2026, 6, 28, 9, 0, calendar: cal), createdAt: date(2026, 6, 1, 9, 0, calendar: cal))
        XCTAssertEqual(Ordering.mostUrgent([soon, pinned])?.name, "pinned")
        XCTAssertEqual(Ordering.mostUrgent([soon])?.name, "soon")
        XCTAssertNil(Ordering.mostUrgent([Stub]()))
    }

    func test_menuBarTask_topTask_surfaces_most_urgent_regardless_of_pin() {
        let soon = Stub(name: "soon", dueDate: date(2026, 6, 28, 9, 0, calendar: cal), createdAt: date(2026, 6, 1, 9, 0, calendar: cal))
        XCTAssertEqual(Ordering.menuBarTask([soon], scope: .topTask)?.name, "soon")
        XCTAssertNil(Ordering.menuBarTask([Stub](), scope: .topTask))
    }

    func test_menuBarTask_pinnedOnly_surfaces_pinned_else_nil() {
        let pinned = Stub(name: "pinned", dueDate: nil, createdAt: date(2026, 6, 1, 9, 0, calendar: cal), isPinned: true)
        let soon = Stub(name: "soon", dueDate: date(2026, 6, 28, 9, 0, calendar: cal), createdAt: date(2026, 6, 1, 9, 0, calendar: cal))
        // A pinned item sorts to the top, so it is surfaced.
        XCTAssertEqual(Ordering.menuBarTask([soon, pinned], scope: .pinnedOnly)?.name, "pinned")
        // Nothing pinned → no task shown (the plain status icon is used instead).
        XCTAssertNil(Ordering.menuBarTask([soon], scope: .pinnedOnly))
    }
}
