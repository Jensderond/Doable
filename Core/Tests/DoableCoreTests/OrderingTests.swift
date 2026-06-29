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
