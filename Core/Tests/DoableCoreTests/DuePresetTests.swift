import XCTest
@testable import DoableCore

// Reference dates: 2026-06-26 Fri, 06-27 Sat, 06-28 Sun, 06-29 Mon, 07-06 Mon.
final class DuePresetTests: XCTestCase {
    let cal = utcCalendar()

    func test_today_is_today_at_1700() {
        let now = date(2026, 6, 26, 9, 0, calendar: cal)
        XCTAssertEqual(DuePreset.today.date(from: now, calendar: cal),
                       date(2026, 6, 26, 17, 0, calendar: cal))
    }

    func test_tomorrow_is_next_day_at_1700() {
        let now = date(2026, 6, 26, 9, 0, calendar: cal)
        XCTAssertEqual(DuePreset.tomorrow.date(from: now, calendar: cal),
                       date(2026, 6, 27, 17, 0, calendar: cal))
    }

    func test_thisWeekend_from_weekday_is_coming_saturday() {
        let friday = date(2026, 6, 26, 9, 0, calendar: cal)
        XCTAssertEqual(DuePreset.thisWeekend.date(from: friday, calendar: cal),
                       date(2026, 6, 27, 17, 0, calendar: cal))
    }

    func test_thisWeekend_when_saturday_is_today() {
        let saturday = date(2026, 6, 27, 9, 0, calendar: cal)
        XCTAssertEqual(DuePreset.thisWeekend.date(from: saturday, calendar: cal),
                       date(2026, 6, 27, 17, 0, calendar: cal))
    }

    func test_thisWeekend_when_sunday_is_today() {
        let sunday = date(2026, 6, 28, 9, 0, calendar: cal)
        XCTAssertEqual(DuePreset.thisWeekend.date(from: sunday, calendar: cal),
                       date(2026, 6, 28, 17, 0, calendar: cal))
    }

    func test_nextWeek_from_friday_is_monday() {
        let friday = date(2026, 6, 26, 9, 0, calendar: cal)
        XCTAssertEqual(DuePreset.nextWeek.date(from: friday, calendar: cal),
                       date(2026, 6, 29, 17, 0, calendar: cal))
    }

    func test_nextWeek_from_sunday_is_monday() {
        let sunday = date(2026, 6, 28, 9, 0, calendar: cal)
        XCTAssertEqual(DuePreset.nextWeek.date(from: sunday, calendar: cal),
                       date(2026, 6, 29, 17, 0, calendar: cal))
    }

    func test_nextWeek_from_monday_is_following_monday() {
        let monday = date(2026, 6, 29, 9, 0, calendar: cal)
        XCTAssertEqual(DuePreset.nextWeek.date(from: monday, calendar: cal),
                       date(2026, 7, 6, 17, 0, calendar: cal))
    }

    func test_displayNames() {
        XCTAssertEqual(DuePreset.today.displayName, "Today")
        XCTAssertEqual(DuePreset.tomorrow.displayName, "Tomorrow")
        XCTAssertEqual(DuePreset.thisWeekend.displayName, "This weekend")
        XCTAssertEqual(DuePreset.nextWeek.displayName, "Next week")
    }
}
