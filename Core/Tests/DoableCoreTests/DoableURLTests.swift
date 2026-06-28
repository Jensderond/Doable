import XCTest
@testable import DoableCore

final class DoableURLTests: XCTestCase {
    func test_makeNew_builds_expected_url() {
        let url = DoableURL.makeNew(title: "buy milk")
        XCTAssertEqual(url.scheme, "doable")
        XCTAssertEqual(url.host, "new")
        XCTAssertTrue(url.absoluteString.contains("title=buy%20milk"))
    }

    func test_roundtrip_plain() {
        XCTAssertEqual(DoableURL.parse(DoableURL.makeNew(title: "do this and that")),
                       .new(title: "do this and that"))
    }

    func test_roundtrip_special_characters() {
        let titles = ["café ☕️", "a&b=c?d", "quote \"x\"", "100% done"]
        for t in titles {
            XCTAssertEqual(DoableURL.parse(DoableURL.makeNew(title: t)), .new(title: t),
                           "round-trip failed for \(t)")
        }
    }

    func test_parse_rejects_other_urls() {
        XCTAssertNil(DoableURL.parse(URL(string: "doable://list")!))
        XCTAssertNil(DoableURL.parse(URL(string: "https://example.com/new?title=x")!))
        XCTAssertNil(DoableURL.parse(URL(string: "doable://new")!)) // no title
    }
}
