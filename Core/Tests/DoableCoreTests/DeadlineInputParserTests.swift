import XCTest
@testable import DoableCore

// Reference: now = 2026-07-01, a Wednesday. Thu 07-02, Fri 07-03, Sat 07-04,
// Sun 07-05, Mon 07-06, Tue 07-07, next Wed 07-08.
final class DeadlineInputParserTests: XCTestCase {
    let cal = utcCalendar()
    lazy var now = date(2026, 7, 1, 9, 0, calendar: cal)

    private func day(_ label: String, _ y: Int, _ mo: Int, _ d: Int) -> DeadlineInputParser.Match {
        .init(label: label, day: date(y, mo, d, 17, 0, calendar: cal))
    }

    func test_priority_t_prefers_today_over_tuesday_thursday() {
        XCTAssertEqual(DeadlineInputParser.match("t", now: now, calendar: cal),
                       day("today", 2026, 7, 1))
    }

    func test_tom_matches_tomorrow() {
        XCTAssertEqual(DeadlineInputParser.match("tom", now: now, calendar: cal),
                       day("tomorrow", 2026, 7, 2))
    }

    func test_n_matches_next_week_monday() {
        XCTAssertEqual(DeadlineInputParser.match("n", now: now, calendar: cal),
                       day("next week", 2026, 7, 6))
    }

    func test_tu_and_th_fall_through_to_weekdays() {
        XCTAssertEqual(DeadlineInputParser.match("tu", now: now, calendar: cal),
                       day("tuesday", 2026, 7, 7))
        XCTAssertEqual(DeadlineInputParser.match("th", now: now, calendar: cal),
                       day("thursday", 2026, 7, 2))
    }

    func test_f_matches_friday() {
        XCTAssertEqual(DeadlineInputParser.match("f", now: now, calendar: cal),
                       day("friday", 2026, 7, 3))
    }

    func test_s_prefers_saturday_su_matches_sunday() {
        XCTAssertEqual(DeadlineInputParser.match("s", now: now, calendar: cal),
                       day("saturday", 2026, 7, 4))
        XCTAssertEqual(DeadlineInputParser.match("su", now: now, calendar: cal),
                       day("sunday", 2026, 7, 5))
    }

    func test_same_weekday_resolves_strictly_after_today() {
        // "wed" typed on a Wednesday means NEXT Wednesday; "today" covers today.
        XCTAssertEqual(DeadlineInputParser.match("wed", now: now, calendar: cal),
                       day("wednesday", 2026, 7, 8))
    }

    func test_full_names_match() {
        XCTAssertEqual(DeadlineInputParser.match("friday", now: now, calendar: cal),
                       day("friday", 2026, 7, 3))
        XCTAssertEqual(DeadlineInputParser.match("next week", now: now, calendar: cal),
                       day("next week", 2026, 7, 6))
    }

    func test_case_and_whitespace_insensitive() {
        XCTAssertEqual(DeadlineInputParser.match("  FRi ", now: now, calendar: cal),
                       day("friday", 2026, 7, 3))
    }

    func test_no_match_returns_nil() {
        XCTAssertNil(DeadlineInputParser.match("", now: now, calendar: cal))
        XCTAssertNil(DeadlineInputParser.match("   ", now: now, calendar: cal))
        XCTAssertNil(DeadlineInputParser.match("xyz", now: now, calendar: cal))
        XCTAssertNil(DeadlineInputParser.match("fridayx", now: now, calendar: cal))
    }
}
