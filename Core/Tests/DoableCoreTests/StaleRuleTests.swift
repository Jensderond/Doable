import XCTest
@testable import DoableCore

final class StaleRuleTests: XCTestCase {
    let cal = utcCalendar()
    let created = date(2026, 6, 26, 9, 0, calendar: utcCalendar()) // Friday

    func test_dated_item_is_never_stale() {
        let now = date(2026, 7, 10, 9, 0, calendar: cal) // well past threshold
        let due = date(2026, 8, 1, 9, 0, calendar: cal)
        XCTAssertFalse(StaleRule.isStale(createdAt: created, dueDate: due, snoozeUntil: nil, now: now, thresholdWorkdays: 3, calendar: cal))
    }

    func test_undated_item_below_threshold_is_not_stale() {
        let now = date(2026, 6, 30, 9, 0, calendar: cal) // Tue: workdays elapsed = Mon,Tue = 2
        XCTAssertFalse(StaleRule.isStale(createdAt: created, dueDate: nil, snoozeUntil: nil, now: now, thresholdWorkdays: 3, calendar: cal))
    }

    func test_undated_item_at_threshold_is_stale() {
        let now = date(2026, 7, 1, 9, 0, calendar: cal) // Wed: workdays elapsed = Mon,Tue,Wed = 3
        XCTAssertTrue(StaleRule.isStale(createdAt: created, dueDate: nil, snoozeUntil: nil, now: now, thresholdWorkdays: 3, calendar: cal))
    }

    func test_snoozed_item_is_not_stale_until_snooze_passes() {
        let now = date(2026, 7, 1, 9, 0, calendar: cal)
        let snooze = date(2026, 7, 6, 9, 0, calendar: cal) // future
        XCTAssertFalse(StaleRule.isStale(createdAt: created, dueDate: nil, snoozeUntil: snooze, now: now, thresholdWorkdays: 3, calendar: cal))
    }

    func test_snooze_in_past_does_not_suppress() {
        let now = date(2026, 7, 8, 9, 0, calendar: cal)
        let snooze = date(2026, 7, 6, 9, 0, calendar: cal) // already passed
        XCTAssertTrue(StaleRule.isStale(createdAt: created, dueDate: nil, snoozeUntil: snooze, now: now, thresholdWorkdays: 3, calendar: cal))
    }

    func test_snoozeDate_advances_by_threshold_workdays() {
        let now = date(2026, 6, 26, 9, 0, calendar: cal) // Friday
        let expected = date(2026, 7, 1, 9, 0, calendar: cal) // +3 workdays -> Wed
        XCTAssertEqual(StaleRule.snoozeDate(from: now, thresholdWorkdays: 3, calendar: cal), expected)
    }
}
