import XCTest
@testable import DoableCore

// Reference dates: 2026-07-01 Wed (31 days), 2027-02-01 Mon (28 days),
// 2028-02-01 Tue (29 days, leap year).
final class MonthGridTests: XCTestCase {
    let cal = utcCalendar()   // firstWeekday defaults to 1 (Sunday)

    private func mondayFirst() -> Calendar {
        var c = utcCalendar()
        c.firstWeekday = 2
        return c
    }

    private func days(_ weeks: [[Date?]], calendar: Calendar) -> [[Int?]] {
        weeks.map { $0.map { $0.map { calendar.component(.day, from: $0) } } }
    }

    func test_july2026_sundayFirst() {
        let weeks = MonthGrid.weeks(containing: date(2026, 7, 15, calendar: cal), calendar: cal)
        XCTAssertEqual(days(weeks, calendar: cal), [
            [nil, nil, nil, 1, 2, 3, 4],
            [5, 6, 7, 8, 9, 10, 11],
            [12, 13, 14, 15, 16, 17, 18],
            [19, 20, 21, 22, 23, 24, 25],
            [26, 27, 28, 29, 30, 31, nil],
        ])
    }

    func test_july2026_mondayFirst() {
        let cal = mondayFirst()
        let weeks = MonthGrid.weeks(containing: date(2026, 7, 15, calendar: cal), calendar: cal)
        XCTAssertEqual(days(weeks, calendar: cal), [
            [nil, nil, 1, 2, 3, 4, 5],
            [6, 7, 8, 9, 10, 11, 12],
            [13, 14, 15, 16, 17, 18, 19],
            [20, 21, 22, 23, 24, 25, 26],
            [27, 28, 29, 30, 31, nil, nil],
        ])
    }

    func test_february2027_mondayFirst_fills_exactly_four_weeks() {
        let cal = mondayFirst()
        let weeks = MonthGrid.weeks(containing: date(2027, 2, 10, calendar: cal), calendar: cal)
        XCTAssertEqual(weeks.count, 4)
        XCTAssertEqual(days(weeks, calendar: cal).first, [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(days(weeks, calendar: cal).last, [22, 23, 24, 25, 26, 27, 28])
    }

    func test_leap_february2028_mondayFirst() {
        let cal = mondayFirst()
        let weeks = MonthGrid.weeks(containing: date(2028, 2, 10, calendar: cal), calendar: cal)
        XCTAssertEqual(days(weeks, calendar: cal).last, [28, 29, nil, nil, nil, nil, nil])
    }

    func test_cells_are_startOfDay_dates() {
        let weeks = MonthGrid.weeks(containing: date(2026, 7, 15, 14, 30, calendar: cal), calendar: cal)
        let first = weeks[0][3]!   // July 1
        XCTAssertEqual(first, date(2026, 7, 1, calendar: cal))
    }

    func test_weekdaySymbols_rotate_to_firstWeekday() {
        let sundayFirst = MonthGrid.weekdaySymbols(calendar: cal)
        let mondayFirst = MonthGrid.weekdaySymbols(calendar: mondayFirst())
        XCTAssertEqual(sundayFirst.count, 7)
        XCTAssertEqual(Array(sundayFirst[1...]) + [sundayFirst[0]], mondayFirst)
    }
}
