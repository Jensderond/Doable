import XCTest
@testable import DoableCore

final class CLICommandTests: XCTestCase {
    func test_empty_is_help() {
        XCTAssertEqual(CLICommand.parse([]), .help)
    }

    func test_help_flags() {
        XCTAssertEqual(CLICommand.parse(["help"]), .help)
        XCTAssertEqual(CLICommand.parse(["-h"]), .help)
        XCTAssertEqual(CLICommand.parse(["--help"]), .help)
    }

    func test_list() {
        XCTAssertEqual(CLICommand.parse(["list"]), .list)
    }

    func test_new_single_quoted_arg() {
        XCTAssertEqual(CLICommand.parse(["new", "do this and that"]),
                       .new(title: "do this and that"))
    }

    func test_new_joins_unquoted_words() {
        XCTAssertEqual(CLICommand.parse(["new", "buy", "milk"]),
                       .new(title: "buy milk"))
    }

    func test_new_trims_whitespace() {
        XCTAssertEqual(CLICommand.parse(["new", "  spaced  "]),
                       .new(title: "spaced"))
    }

    func test_new_without_title_is_invalid() {
        if case .invalid = CLICommand.parse(["new"]) { } else { XCTFail("expected .invalid") }
        if case .invalid = CLICommand.parse(["new", "   "]) { } else { XCTFail("expected .invalid") }
    }

    func test_unknown_verb_is_invalid() {
        if case .invalid = CLICommand.parse(["frobnicate"]) { } else { XCTFail("expected .invalid") }
    }
}
