import XCTest
@testable import DoableCore

final class DateEditorPlacementTests: XCTestCase {
    func test_cases_and_displayNames() {
        XCTAssertEqual(DateEditorPlacement.allCases, [.overlay, .inline])
        XCTAssertEqual(DateEditorPlacement.overlay.displayName, "Overlay")
        XCTAssertEqual(DateEditorPlacement.inline.displayName, "Inline")
    }

    func test_rawValues_are_stable() {
        XCTAssertEqual(DateEditorPlacement.overlay.rawValue, "overlay")
        XCTAssertEqual(DateEditorPlacement.inline.rawValue, "inline")
    }
}
