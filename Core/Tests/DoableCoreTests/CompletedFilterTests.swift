import XCTest
@testable import DoableCore

// Reference dates (UTC): 2026-06-29 Mon, 06-30 Tue ... 07-05 Sun (this week);
// 06-22 Mon ... 06-28 Sun (last week); 06-15 Mon (two weeks ago).
final class CompletedFilterTests: XCTestCase {
    let cal = utcCalendar()

    func test_displayNames() {
        XCTAssertEqual(CompletedFilter.thisWeek.displayName, "This week")
        XCTAssertEqual(CompletedFilter.lastWeek.displayName, "Last week")
        XCTAssertEqual(CompletedFilter.last30Days.displayName, "Last 30 days")
    }

    func test_allCases_order() {
        XCTAssertEqual(CompletedFilter.allCases, [.thisWeek, .lastWeek, .last30Days])
    }

    // This week = [Monday 00:00 of current week, now]
    func test_thisWeek_lowerBound_is_monday_midnight() {
        let now = date(2026, 7, 1, 14, 30, calendar: cal) // Wednesday
        let range = CompletedFilter.thisWeek.dateRange(now: now, calendar: cal)
        XCTAssertEqual(range.lowerBound, date(2026, 6, 29, 0, 0, calendar: cal))
        XCTAssertEqual(range.upperBound, now)
    }

    func test_thisWeek_includes_earlier_today_excludes_last_week() {
        let now = date(2026, 7, 1, 14, 30, calendar: cal)
        let range = CompletedFilter.thisWeek.dateRange(now: now, calendar: cal)
        XCTAssertTrue(range.contains(date(2026, 6, 29, 9, 0, calendar: cal)))  // Mon this week
        XCTAssertFalse(range.contains(date(2026, 6, 28, 23, 0, calendar: cal))) // Sun last week
    }

    func test_thisWeek_from_monday_lowerBound_is_same_day_midnight() {
        let monday = date(2026, 6, 29, 9, 0, calendar: cal)
        let range = CompletedFilter.thisWeek.dateRange(now: monday, calendar: cal)
        XCTAssertEqual(range.lowerBound, date(2026, 6, 29, 0, 0, calendar: cal))
    }

    func test_thisWeek_from_sunday_lowerBound_is_that_weeks_monday() {
        let sunday = date(2026, 7, 5, 9, 0, calendar: cal)
        let range = CompletedFilter.thisWeek.dateRange(now: sunday, calendar: cal)
        XCTAssertEqual(range.lowerBound, date(2026, 6, 29, 0, 0, calendar: cal))
    }

    // Last week = [Monday 00:00 prev week, Monday 00:00 this week)
    func test_lastWeek_bounds() {
        let now = date(2026, 7, 1, 14, 30, calendar: cal) // Wednesday
        let range = CompletedFilter.lastWeek.dateRange(now: now, calendar: cal)
        XCTAssertEqual(range.lowerBound, date(2026, 6, 22, 0, 0, calendar: cal))
        XCTAssertEqual(range.upperBound, date(2026, 6, 29, 0, 0, calendar: cal))
    }

    func test_lastWeek_includes_prev_week_excludes_this_monday_and_two_weeks_ago() {
        let now = date(2026, 7, 1, 14, 30, calendar: cal)
        let range = CompletedFilter.lastWeek.dateRange(now: now, calendar: cal)
        XCTAssertTrue(range.contains(date(2026, 6, 24, 12, 0, calendar: cal)))  // Wed last week
        XCTAssertFalse(range.contains(date(2026, 6, 29, 0, 0, calendar: cal)))  // this Monday (upper exclusive)
        XCTAssertFalse(range.contains(date(2026, 6, 21, 12, 0, calendar: cal))) // Sun two weeks ago
    }

    // Last 30 days = [now - 30 days, now]
    func test_last30Days_bounds() {
        let now = date(2026, 7, 1, 14, 30, calendar: cal)
        let range = CompletedFilter.last30Days.dateRange(now: now, calendar: cal)
        XCTAssertEqual(range.lowerBound, date(2026, 6, 1, 14, 30, calendar: cal))
        XCTAssertEqual(range.upperBound, now)
    }

    func test_last30Days_includes_29_days_ago_excludes_31_days_ago() {
        let now = date(2026, 7, 1, 14, 30, calendar: cal)
        let range = CompletedFilter.last30Days.dateRange(now: now, calendar: cal)
        XCTAssertTrue(range.contains(date(2026, 6, 2, 14, 30, calendar: cal)))  // 29 days ago
        XCTAssertFalse(range.contains(date(2026, 5, 31, 14, 30, calendar: cal))) // 31 days ago
    }
}
