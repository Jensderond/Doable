import XCTest
@testable import DoableCore

// Reference dates: 2026-06-26 is a Friday; 06-27 Sat, 06-28 Sun, 06-29 Mon, 06-30 Tue, 07-01 Wed.
final class WorkdaysTests: XCTestCase {
    let cal = utcCalendar()

    func test_adding_zero_workdays_returns_same_date() {
        let friday = date(2026, 6, 26, 9, 0, calendar: cal)
        XCTAssertEqual(Workdays.adding(0, workdaysTo: friday, calendar: cal), friday)
    }

    func test_adding_workdays_skips_weekend() {
        let friday = date(2026, 6, 26, 9, 0, calendar: cal)
        // +3 workdays from Friday: Mon(1), Tue(2), Wed(3) -> 2026-07-01 09:00
        let expected = date(2026, 7, 1, 9, 0, calendar: cal)
        XCTAssertEqual(Workdays.adding(3, workdaysTo: friday, calendar: cal), expected)
    }

    func test_adding_one_workday_from_friday_is_monday() {
        let friday = date(2026, 6, 26, 12, 0, calendar: cal)
        let expected = date(2026, 6, 29, 12, 0, calendar: cal)
        XCTAssertEqual(Workdays.adding(1, workdaysTo: friday, calendar: cal), expected)
    }

    func test_workdaysElapsed_counts_weekdays_after_start() {
        let friday = date(2026, 6, 26, 9, 0, calendar: cal)
        let wednesday = date(2026, 7, 1, 9, 0, calendar: cal)
        // After Fri: Sat(no), Sun(no), Mon(1), Tue(2), Wed(3)
        XCTAssertEqual(Workdays.workdaysElapsed(from: friday, to: wednesday, calendar: cal), 3)
    }

    func test_workdaysElapsed_zero_when_end_not_after_start() {
        let friday = date(2026, 6, 26, 9, 0, calendar: cal)
        XCTAssertEqual(Workdays.workdaysElapsed(from: friday, to: friday, calendar: cal), 0)
    }
}
