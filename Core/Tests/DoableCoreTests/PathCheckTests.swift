import XCTest
@testable import DoableCore

final class PathCheckTests: XCTestCase {
    func test_present() {
        XCTAssertTrue(PathCheck.isOnPath(dir: "/Users/test/.local/bin",
                                         path: "/usr/bin:/Users/test/.local/bin:/bin"))
    }
    func test_absent() {
        XCTAssertFalse(PathCheck.isOnPath(dir: "/Users/test/.local/bin",
                                          path: "/usr/bin:/bin"))
    }
    func test_trailing_slash_normalized() {
        XCTAssertTrue(PathCheck.isOnPath(dir: "/Users/test/.local/bin/",
                                         path: "/Users/test/.local/bin"))
    }
}
