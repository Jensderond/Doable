import XCTest
@testable import DoableCore

final class MenuBarTitleTests: XCTestCase {
    func test_short_title_is_unchanged() {
        XCTAssertEqual(MenuBarTitle.format("buy milk"), "buy milk")
    }

    func test_long_title_is_truncated_with_ellipsis() {
        let result = MenuBarTitle.format("call the dentist about the appointment", max: 10)
        XCTAssertEqual(result, "call the…")
        XCTAssertLessThanOrEqual(result.count, 10)
    }

    func test_whitespace_and_newlines_are_collapsed() {
        XCTAssertEqual(MenuBarTitle.format("  finish\n the   report  "), "finish the report")
    }

    func test_exactly_max_is_not_truncated() {
        XCTAssertEqual(MenuBarTitle.format("0123456789", max: 10), "0123456789")
    }
}
