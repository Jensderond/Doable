import XCTest
@testable import DoableCore

final class DoableStoreTests: XCTestCase {
    func test_storeURL_is_built_under_container() {
        let home = URL(fileURLWithPath: "/Users/test")
        XCTAssertEqual(DoableStore.storeURL(home: home).path,
            "/Users/test/Library/Containers/nl.redkiwi.Doable/Data/Library/Application Support/default.store")
    }
}
