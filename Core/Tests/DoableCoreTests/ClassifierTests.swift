import XCTest
@testable import DoableCore

final class ClassifierTests: XCTestCase {
    let cal = utcCalendar()
    lazy var now = date(2026, 6, 26, 12, 0, calendar: cal) // Fri noon

    func test_no_due_date_is_normal() {
        XCTAssertEqual(Classifier.itemState(dueDate: nil, now: now, window: .todayOnly, calendar: cal), .normal)
    }

    func test_past_due_date_is_overdue() {
        let past = date(2026, 6, 26, 11, 0, calendar: cal)
        XCTAssertEqual(Classifier.itemState(dueDate: past, now: now, window: .todayOnly, calendar: cal), .overdue)
    }

    func test_todayOnly_later_today_is_dueSoon() {
        let laterToday = date(2026, 6, 26, 18, 0, calendar: cal)
        XCTAssertEqual(Classifier.itemState(dueDate: laterToday, now: now, window: .todayOnly, calendar: cal), .dueSoon)
    }

    func test_todayOnly_tomorrow_is_normal() {
        let tomorrow = date(2026, 6, 27, 9, 0, calendar: cal)
        XCTAssertEqual(Classifier.itemState(dueDate: tomorrow, now: now, window: .todayOnly, calendar: cal), .normal)
    }

    func test_oneHour_window_boundary() {
        let within = date(2026, 6, 26, 12, 59, calendar: cal)
        let beyond = date(2026, 6, 26, 13, 30, calendar: cal)
        XCTAssertEqual(Classifier.itemState(dueDate: within, now: now, window: .oneHour, calendar: cal), .dueSoon)
        XCTAssertEqual(Classifier.itemState(dueDate: beyond, now: now, window: .oneHour, calendar: cal), .normal)
    }

    func test_threeDays_window() {
        let inTwoDays = date(2026, 6, 28, 12, 0, calendar: cal)
        XCTAssertEqual(Classifier.itemState(dueDate: inTwoDays, now: now, window: .threeDays, calendar: cal), .dueSoon)
    }
}
