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
