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
        XCTAssertEqual(DuePreset.nextWeek.displayName, "Next week")
    }

    func test_dueTime_sets_1700_on_given_day() {
        let morning = date(2026, 7, 1, 9, 30, calendar: cal)
        XCTAssertEqual(DuePreset.dueTime(on: morning, calendar: cal),
                       date(2026, 7, 1, 17, 0, calendar: cal))
    }

    // Availability: `tomorrow` is offered only when tomorrow is a workday.

    func test_available_on_monday_through_thursday_includes_tomorrow() {
        for day in [29, 30] {                              // Mon 06-29, Tue 06-30
            let now = date(2026, 6, day, 9, 0, calendar: cal)
            XCTAssertEqual(DuePreset.available(on: now, calendar: cal),
                           [.today, .tomorrow, .nextWeek],
                           "expected tomorrow on day \(day)")
        }
    }

    func test_available_on_friday_drops_tomorrow() {
        let friday = date(2026, 6, 26, 9, 0, calendar: cal) // tomorrow = Saturday
        XCTAssertEqual(DuePreset.available(on: friday, calendar: cal),
                       [.today, .nextWeek])
    }

    func test_available_on_weekend_drops_tomorrow() {
        let saturday = date(2026, 6, 27, 9, 0, calendar: cal) // tomorrow = Sunday
        let sunday = date(2026, 6, 28, 9, 0, calendar: cal)   // tomorrow = Monday — still dropped (today is weekend)
        XCTAssertEqual(DuePreset.available(on: saturday, calendar: cal), [.today, .nextWeek])
        XCTAssertEqual(DuePreset.available(on: sunday, calendar: cal), [.today, .tomorrow, .nextWeek])
    }
}
