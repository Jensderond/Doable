import XCTest
@testable import DoableCore

final class TodoListFormatTests: XCTestCase {
    let cal = utcCalendar()

    func test_empty_message() {
        XCTAssertEqual(formatList([], calendar: cal), "No todos.")
    }

    func test_undated_row() {
        XCTAssertEqual(formatList([TodoRow(title: "buy milk", due: nil)], calendar: cal),
                       "• buy milk")
    }

    func test_dated_row() {
        let due = date(2026, 6, 30, 17, 0, calendar: cal)
        XCTAssertEqual(formatList([TodoRow(title: "ship it", due: due)], calendar: cal),
                       "• ship it  (due 2026-06-30)")
    }

    func test_multiple_rows_joined_by_newline() {
        let due = date(2026, 7, 1, 9, 0, calendar: cal)
        let out = formatList([TodoRow(title: "a", due: due), TodoRow(title: "b", due: nil)],
                             calendar: cal)
        XCTAssertEqual(out, "• a  (due 2026-07-01)\n• b")
    }
}
