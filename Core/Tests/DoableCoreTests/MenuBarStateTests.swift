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
