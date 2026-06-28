# Doable CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a `doable` command-line tool (bundled in Doable.app, installed onto PATH from Settings) supporting `doable new "..."` and `doable list`.

**Architecture:** `new` opens a `doable://` URL that the running/auto-launched app handles (single-writer, live UI). `list` opens the app's SwiftData store read-only at its container path and prints active todos. `TodoItem` moves into `DoableCore` so app and CLI share one schema. Pure logic (arg parsing, URL contract, list formatting, path helpers) lives in `DoableCore` under unit test; the executable, the app's URL handler, and the Settings installer are thin shells over it.

**Tech Stack:** Swift 5, SwiftUI + AppKit, SwiftData, XcodeGen (`project.yml`), Swift Package Manager (`DoableCore`), XCTest.

## Global Constraints

- macOS deployment target: **14.0**. Swift version: **5.0**.
- App is **sandboxed** (`com.apple.security.app-sandbox`) + hardened runtime; bundle id **`nl.redkiwi.Doable`**.
- The store is at `<realHome>/Library/Containers/nl.redkiwi.Doable/Data/Library/Application Support/default.store`.
- URL scheme is **`doable`**; the `new` URL form is **`doable://new?title=<percent-encoded>`** (host = `new`, query item `title`).
- The bundled CLI binary lives at **`Doable.app/Contents/MacOS/doable`** and MUST be signed `codesign --force --sign -` with **NO `--entitlements`** (it must not be sandboxed).
- Symlink installs to **`<realHome>/.local/bin/doable`**; `<realHome>` is resolved via `getpwuid(getuid())`, NOT `NSHomeDirectory()` (which returns the sandbox container).
- Pure logic goes in `DoableCore` with XCTest tests; run `swift test` from `Core/`.
- DRY, YAGNI, TDD, frequent commits.

---

## File Structure

- `Core/Sources/DoableCore/TodoItem.swift` — **moved** from `App/Models/`; the shared `@Model` (made `public`).
- `Core/Sources/DoableCore/CLICommand.swift` — `CLICommand` enum + `parse([String])`.
- `Core/Sources/DoableCore/DoableURL.swift` — URL scheme contract (`makeNew`, `parse`).
- `Core/Sources/DoableCore/TodoListFormat.swift` — `TodoRow` + `formatList`.
- `Core/Sources/DoableCore/DoableStore.swift` — store URL + read-only `ModelContainer` factory.
- `Core/Sources/DoableCore/PathCheck.swift` — `isOnPath(dir:path:)` pure helper.
- `Core/Tests/DoableCoreTests/{CLICommand,DoableURL,TodoListFormat,DoableStore,PathCheck}Tests.swift` — unit tests.
- `CLI/main.swift` — the executable entry point (I/O shell).
- `App/System/SharedContainer.swift` — single shared `ModelContainer` for app scenes + AppDelegate.
- `App/System/AppDelegate.swift` — **modify**: add `application(_:open:)` URL handling.
- `App/Models/TodoStore.swift` — **modify**: extract `static insert(title:into:)`.
- `App/DoableApp.swift` — **modify**: use `SharedContainer.shared`.
- `App/Resources/Info.plist` — **modify**: add `CFBundleURLTypes`.
- `App/Doable.entitlements` — **modify**: add temporary-exception home-relative-path entitlement.
- `App/Views/SettingsView.swift` — **modify**: add "Command-line tool" section + `installCLI()`.
- `project.yml` — **modify**: add `doable` tool target, embed into `Contents/MacOS`, migrate + extend the "Copy to /Applications" post-build script.

---

## Task 1: Move `TodoItem` into `DoableCore`

**Files:**
- Create: `Core/Sources/DoableCore/TodoItem.swift`
- Delete: `App/Models/TodoItem.swift`
- Test: (none new — existing `Core` + app build is the gate)

**Interfaces:**
- Produces: `public final class TodoItem: Orderable` (SwiftData `@Model`) with `public` stored properties `id, title, createdAt, dueDate, isDone, completedAt, staleSnoozeUntil` and `public init(title:createdAt:dueDate:)`.

- [ ] **Step 1: Create the model in DoableCore**

`Core/Sources/DoableCore/TodoItem.swift`:

```swift
import Foundation
import SwiftData

@Model
public final class TodoItem: Orderable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var dueDate: Date?
    public var isDone: Bool
    public var completedAt: Date?
    public var staleSnoozeUntil: Date?

    public init(title: String, createdAt: Date, dueDate: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.isDone = false
        self.completedAt = nil
        self.staleSnoozeUntil = nil
    }
}
```

- [ ] **Step 2: Delete the old app-target model**

```bash
git rm App/Models/TodoItem.swift
```

- [ ] **Step 3: Build the package to confirm it compiles**

Run: `cd Core && swift build`
Expected: builds with no errors (DoableCore now imports SwiftData).

- [ ] **Step 4: Run the package tests (regression guard)**

Run: `cd Core && swift test`
Expected: all existing tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Core/Sources/DoableCore/TodoItem.swift App/Models/TodoItem.swift
git commit -m "refactor: move TodoItem model into DoableCore"
```

> Note: the app target already `import DoableCore`s in `TodoStore`/views, and `TodoItem` is now public, so app references resolve unchanged. The app build is verified end-to-end in Task 9.

---

## Task 2: `CLICommand` argument parsing

**Files:**
- Create: `Core/Sources/DoableCore/CLICommand.swift`
- Test: `Core/Tests/DoableCoreTests/CLICommandTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum CLICommand: Equatable {
      case new(title: String)
      case list
      case help
      case invalid(reason: String)
      public static func parse(_ args: [String]) -> CLICommand
  }
  ```
  `args` is `CommandLine.arguments` **without** the program name. Rules: empty / `help` / `-h` / `--help` → `.help`; `list` → `.list`; `new <words...>` joins the rest with spaces, trims, empty → `.invalid`; anything else → `.invalid`.

- [ ] **Step 1: Write the failing test**

`Core/Tests/DoableCoreTests/CLICommandTests.swift`:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Core && swift test --filter CLICommandTests`
Expected: FAIL — `CLICommand` not defined.

- [ ] **Step 3: Write minimal implementation**

`Core/Sources/DoableCore/CLICommand.swift`:

```swift
import Foundation

public enum CLICommand: Equatable {
    case new(title: String)
    case list
    case help
    case invalid(reason: String)

    public static func parse(_ args: [String]) -> CLICommand {
        guard let verb = args.first else { return .help }
        switch verb {
        case "help", "-h", "--help":
            return .help
        case "list":
            return .list
        case "new":
            let title = args.dropFirst().joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? .invalid(reason: "new requires a title") : .new(title: title)
        default:
            return .invalid(reason: "unknown command: \(verb)")
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Core && swift test --filter CLICommandTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Core/Sources/DoableCore/CLICommand.swift Core/Tests/DoableCoreTests/CLICommandTests.swift
git commit -m "feat(core): CLI command parsing"
```

---

## Task 3: `DoableURL` scheme contract

**Files:**
- Create: `Core/Sources/DoableCore/DoableURL.swift`
- Test: `Core/Tests/DoableCoreTests/DoableURLTests.swift`

**Interfaces:**
- Consumes: `CLICommand` (Task 2).
- Produces:
  ```swift
  public enum DoableURL {
      public static let scheme = "doable"
      public static func makeNew(title: String) -> URL
      public static func parse(_ url: URL) -> CLICommand?   // .new(title:) or nil
  }
  ```
  Invariant: `parse(makeNew(t)) == .new(title: t)` for any non-empty `t`.

- [ ] **Step 1: Write the failing test**

`Core/Tests/DoableCoreTests/DoableURLTests.swift`:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Core && swift test --filter DoableURLTests`
Expected: FAIL — `DoableURL` not defined.

- [ ] **Step 3: Write minimal implementation**

`Core/Sources/DoableCore/DoableURL.swift`:

```swift
import Foundation

public enum DoableURL {
    public static let scheme = "doable"

    public static func makeNew(title: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "new"
        components.queryItems = [URLQueryItem(name: "title", value: title)]
        return components.url!
    }

    public static func parse(_ url: URL) -> CLICommand? {
        guard url.scheme == scheme, url.host == "new" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let title = components?.queryItems?.first(where: { $0.name == "title" })?.value,
              !title.isEmpty else { return nil }
        return .new(title: title)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Core && swift test --filter DoableURLTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Core/Sources/DoableCore/DoableURL.swift Core/Tests/DoableCoreTests/DoableURLTests.swift
git commit -m "feat(core): doable:// URL scheme contract"
```

---

## Task 4: `TodoRow` + `formatList`

**Files:**
- Create: `Core/Sources/DoableCore/TodoListFormat.swift`
- Test: `Core/Tests/DoableCoreTests/TodoListFormatTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct TodoRow: Equatable {
      public let title: String
      public let due: Date?
      public init(title: String, due: Date?)
  }
  public func formatList(_ rows: [TodoRow], calendar: Calendar = .current) -> String
  ```
  Empty → `"No todos."`. Each row → `"• <title>"`, with `"  (due YYYY-MM-DD)"` appended when `due != nil` (date rendered in `calendar`'s time zone). Rows joined by newlines.

- [ ] **Step 1: Write the failing test**

`Core/Tests/DoableCoreTests/TodoListFormatTests.swift`:

```swift
import XCTest
@testable import DoableCore

final class TodoListFormatTests: XCTestCase {
    let cal = utcCalendar()

    func test_empty_message() {
        XCTAssertEqual(formatList([], calendar: cal), "No todos.")
    }

    func test_undated_row() {
        XCTAssertEqual(formatList([TodoRow(title: "buy milk", due: nil)], calendar: cal),
                       "• buy milk")
    }

    func test_dated_row() {
        let due = date(2026, 6, 30, 17, 0, calendar: cal)
        XCTAssertEqual(formatList([TodoRow(title: "ship it", due: due)], calendar: cal),
                       "• ship it  (due 2026-06-30)")
    }

    func test_multiple_rows_joined_by_newline() {
        let due = date(2026, 7, 1, 9, 0, calendar: cal)
        let out = formatList([TodoRow(title: "a", due: due), TodoRow(title: "b", due: nil)],
                             calendar: cal)
        XCTAssertEqual(out, "• a  (due 2026-07-01)\n• b")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Core && swift test --filter TodoListFormatTests`
Expected: FAIL — `formatList` / `TodoRow` not defined.

- [ ] **Step 3: Write minimal implementation**

`Core/Sources/DoableCore/TodoListFormat.swift`:

```swift
import Foundation

public struct TodoRow: Equatable {
    public let title: String
    public let due: Date?
    public init(title: String, due: Date?) {
        self.title = title
        self.due = due
    }
}

public func formatList(_ rows: [TodoRow], calendar: Calendar = .current) -> String {
    guard !rows.isEmpty else { return "No todos." }
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return rows.map { row in
        if let due = row.due {
            return "• \(row.title)  (due \(formatter.string(from: due)))"
        }
        return "• \(row.title)"
    }.joined(separator: "\n")
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Core && swift test --filter TodoListFormatTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Core/Sources/DoableCore/TodoListFormat.swift Core/Tests/DoableCoreTests/TodoListFormatTests.swift
git commit -m "feat(core): todo list formatting"
```

---

## Task 5: `DoableStore` (store URL + read-only container) and `PathCheck`

**Files:**
- Create: `Core/Sources/DoableCore/DoableStore.swift`
- Create: `Core/Sources/DoableCore/PathCheck.swift`
- Test: `Core/Tests/DoableCoreTests/DoableStoreTests.swift`
- Test: `Core/Tests/DoableCoreTests/PathCheckTests.swift`

**Interfaces:**
- Consumes: `TodoItem` (Task 1).
- Produces:
  ```swift
  public enum DoableStore {
      public static let bundleID = "nl.redkiwi.Doable"
      public static func storeURL(home: URL) -> URL
      public static var defaultStoreURL: URL { get }          // uses real home
      public static func makeReadOnlyContainer(url: URL = defaultStoreURL) throws -> ModelContainer
  }
  public enum PathCheck {
      public static func isOnPath(dir: String, path: String) -> Bool
  }
  ```
  `storeURL(home:)` appends `Library/Containers/nl.redkiwi.Doable/Data/Library/Application Support/default.store`. `isOnPath` splits `path` on `":"` and checks membership (trailing slashes normalized).

- [ ] **Step 1: Write the failing tests**

`Core/Tests/DoableCoreTests/DoableStoreTests.swift`:

```swift
import XCTest
@testable import DoableCore

final class DoableStoreTests: XCTestCase {
    func test_storeURL_is_built_under_container() {
        let home = URL(fileURLWithPath: "/Users/test")
        XCTAssertEqual(DoableStore.storeURL(home: home).path,
            "/Users/test/Library/Containers/nl.redkiwi.Doable/Data/Library/Application Support/default.store")
    }
}
```

`Core/Tests/DoableCoreTests/PathCheckTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Core && swift test --filter DoableStoreTests && swift test --filter PathCheckTests`
Expected: FAIL — types not defined.

- [ ] **Step 3: Write minimal implementations**

`Core/Sources/DoableCore/DoableStore.swift`:

```swift
import Foundation
import SwiftData

public enum DoableStore {
    public static let bundleID = "nl.redkiwi.Doable"

    public static func storeURL(home: URL) -> URL {
        home.appendingPathComponent("Library/Containers/\(bundleID)/Data/Library/Application Support/default.store")
    }

    public static var defaultStoreURL: URL {
        storeURL(home: FileManager.default.homeDirectoryForCurrentUser)
    }

    public static func makeReadOnlyContainer(url: URL = defaultStoreURL) throws -> ModelContainer {
        let config = ModelConfiguration(url: url, allowsSave: false)
        return try ModelContainer(for: TodoItem.self, configurations: config)
    }
}
```

`Core/Sources/DoableCore/PathCheck.swift`:

```swift
import Foundation

public enum PathCheck {
    public static func isOnPath(dir: String, path: String) -> Bool {
        let target = normalize(dir)
        return path.split(separator: ":").contains { normalize(String($0)) == target }
    }

    private static func normalize(_ s: String) -> String {
        s.hasSuffix("/") ? String(s.dropLast()) : s
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Core && swift test --filter DoableStoreTests && swift test --filter PathCheckTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Core/Sources/DoableCore/DoableStore.swift Core/Sources/DoableCore/PathCheck.swift \
        Core/Tests/DoableCoreTests/DoableStoreTests.swift Core/Tests/DoableCoreTests/PathCheckTests.swift
git commit -m "feat(core): store URL + read-only container + PATH helper"
```

> Note: `makeReadOnlyContainer` is not unit-tested (it needs a live store); it's exercised in Task 6's manual verification. Only the pure URL/path math is unit-tested here.

---

## Task 6: The `doable` executable + XcodeGen tool target

**Files:**
- Create: `CLI/main.swift`
- Modify: `project.yml` (add the `doable` tool target only — embedding/post-build come in Task 9)

**Interfaces:**
- Consumes: `CLICommand`, `DoableURL`, `DoableStore`, `formatList`, `TodoRow`, `Ordering`, `TodoItem` (all from `DoableCore`).

- [ ] **Step 1: Add the tool target to `project.yml`**

Under `targets:`, add a sibling to `Doable`:

```yaml
  doable:
    type: tool
    platform: macOS
    sources:
      - CLI
    dependencies:
      - package: DoableCore
        product: DoableCore
    settings:
      base:
        PRODUCT_NAME: doable
        PRODUCT_BUNDLE_IDENTIFIER: nl.redkiwi.doable
        CODE_SIGN_STYLE: Automatic
        SWIFT_VERSION: "5.0"
```

(No entitlements, no sandbox — this is a plain command-line tool.)

- [ ] **Step 2: Write the executable**

`CLI/main.swift`:

```swift
import Foundation
import AppKit
import SwiftData
import DoableCore

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("error: " + message + "\n").utf8))
    exit(1)
}

let usage = """
doable — manage your Doable todos

Usage:
  doable new "buy milk"   Add a todo
  doable list             List active todos
  doable help             Show this help
"""

let command = CLICommand.parse(Array(CommandLine.arguments.dropFirst()))

switch command {
case .help:
    print(usage)

case .invalid(let reason):
    fail(reason + "\n\n" + usage)

case .new(let title):
    let url = DoableURL.makeNew(title: title)
    guard NSWorkspace.shared.open(url) else {
        fail("could not reach Doable. Is the app installed in /Applications and launched at least once?")
    }
    print("Added: \(title)")

case .list:
    let storeURL = DoableStore.defaultStoreURL
    guard FileManager.default.fileExists(atPath: storeURL.path) else {
        print("No todos.")
        exit(0)
    }
    do {
        let container = try DoableStore.makeReadOnlyContainer(url: storeURL)
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.isDone == false })
        let items = try context.fetch(descriptor)
        let rows = Ordering.activeSorted(items).map { TodoRow(title: $0.title, due: $0.dueDate) }
        print(formatList(rows))
    } catch {
        fail("could not read todos: \(error.localizedDescription)")
    }
}
```

- [ ] **Step 3: Regenerate the Xcode project and build the tool**

Run:
```bash
cd /Users/jens/Sites/remove-me/Doable
xcodegen generate
xcodebuild -project Doable.xcodeproj -scheme doable -configuration Debug build
```
Expected: `doable` builds. (If there is no `doable` scheme, run `xcodebuild -project Doable.xcodeproj -list` and build the target via `-target doable`.)

- [ ] **Step 4: Smoke-test `list` and `help` against the real store**

Run (locate the built binary path from build output, e.g. under DerivedData or `Core/.build`):
```bash
"$(find ~/Library/Developer/Xcode/DerivedData -name doable -type f -perm +111 2>/dev/null | head -1)" help
"$(find ~/Library/Developer/Xcode/DerivedData -name doable -type f -perm +111 2>/dev/null | head -1)" list
```
Expected: `help` prints usage; `list` prints active todos (or `No todos.`) without crashing.

- [ ] **Step 5: Commit**

```bash
git add project.yml CLI/main.swift Doable.xcodeproj
git commit -m "feat(cli): doable executable with new + list"
```

> `new` is verified end-to-end after the app's URL handler (Task 7) and bundling (Task 9) land.

---

## Task 7: App URL handling via shared container

**Files:**
- Create: `App/System/SharedContainer.swift`
- Modify: `App/Models/TodoStore.swift` (extract `static insert`)
- Modify: `App/System/AppDelegate.swift` (add `application(_:open:)`)
- Modify: `App/DoableApp.swift` (use shared container)
- Modify: `App/Resources/Info.plist` (register `doable` scheme)

**Interfaces:**
- Consumes: `DoableURL.parse`, `TodoItem`, `SharedContainer.shared`.
- Produces: `SharedContainer.shared: ModelContainer`; `TodoStore.insert(title:into:)`.

- [ ] **Step 1: Create the shared container**

`App/System/SharedContainer.swift`:

```swift
import SwiftData
import DoableCore

@MainActor
enum SharedContainer {
    static let shared: ModelContainer = {
        do {
            return try ModelContainer(for: TodoItem.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}
```

- [ ] **Step 2: Extract reusable insert logic in `TodoStore`**

In `App/Models/TodoStore.swift`, replace the body of `create` to delegate to a new static, so the AppDelegate can reuse the exact trimming/guard/save:

```swift
    func create(title: String, in context: ModelContext) {
        TodoStore.insert(title: title, into: context)
    }

    /// Trims, guards against empty, inserts a new active todo, and saves.
    static func insert(title: String, into context: ModelContext) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        context.insert(TodoItem(title: trimmed, createdAt: Date()))
        do { try context.save() } catch { print("SwiftData save failed: \(error)") }
    }
```

- [ ] **Step 3: Use the shared container in `DoableApp`**

In `App/DoableApp.swift`, remove the `private let container` + `init()` that builds it, and reference `SharedContainer.shared`:

```swift
@main
struct DoableApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = TodoStore()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(store: store)
        } label: {
            MenuBarLabel()
                .modelContainer(SharedContainer.shared)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(SharedContainer.shared)

        Settings {
            SettingsView()
        }
    }
}
```

- [ ] **Step 4: Handle the URL in `AppDelegate`**

In `App/System/AppDelegate.swift`, add `import DoableCore` and `import SwiftData` at the top, and add:

```swift
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if case .new(let title) = DoableURL.parse(url) {
                Task { @MainActor in
                    TodoStore.insert(title: title, into: SharedContainer.shared.mainContext)
                }
            }
        }
    }
```

- [ ] **Step 5: Register the URL scheme in `Info.plist`**

In `App/Resources/Info.plist`, add inside the top-level `<dict>`:

```xml
    <key>CFBundleURLTypes</key>
    <array>
      <dict>
        <key>CFBundleURLName</key>
        <string>nl.redkiwi.Doable.url</string>
        <key>CFBundleURLSchemes</key>
        <array>
          <string>doable</string>
        </array>
      </dict>
    </array>
```

- [ ] **Step 6: Build the app to confirm it compiles**

Run:
```bash
cd /Users/jens/Sites/remove-me/Doable
xcodegen generate
xcodebuild -project Doable.xcodeproj -scheme Doable -configuration Debug build
```
Expected: app builds. (Full end-to-end `new` round-trip is verified in Task 9, after the CLI is bundled and the build installs to /Applications.)

- [ ] **Step 7: Commit**

```bash
git add App/System/SharedContainer.swift App/Models/TodoStore.swift App/System/AppDelegate.swift \
        App/DoableApp.swift App/Resources/Info.plist Doable.xcodeproj
git commit -m "feat(app): handle doable:// new URLs via shared container"
```

---

## Task 8: Settings install section

**Files:**
- Modify: `App/Views/SettingsView.swift`
- Modify: `App/Doable.entitlements`

**Interfaces:**
- Consumes: `PathCheck.isOnPath`, `Bundle.main`.

- [ ] **Step 1: Add the home-relative-path entitlement**

`App/Doable.entitlements` — add inside the `<dict>`:

```xml
    <key>com.apple.security.temporary-exception.files.home-relative-path.read-write</key>
    <array>
      <string>/.local/bin/</string>
    </array>
```

- [ ] **Step 2: Add the install logic + UI to `SettingsView`**

In `App/Views/SettingsView.swift`, add `import AppKit` and these helpers + a new `Section`. Append to the `Form`:

```swift
    @State private var installMessage: String?

    private var realHome: URL {
        guard let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir else {
            return FileManager.default.homeDirectoryForCurrentUser
        }
        return URL(fileURLWithPath: String(cString: dir))
    }

    private var binDir: URL { realHome.appendingPathComponent(".local/bin") }
    private var linkURL: URL { binDir.appendingPathComponent("doable") }
    private var bundledTool: URL {
        Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/doable")
    }

    private func installCLI() {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: binDir, withIntermediateDirectories: true)
            if fm.fileExists(atPath: linkURL.path) || (try? linkURL.checkResourceIsReachable()) == true {
                try? fm.removeItem(at: linkURL)
            }
            try fm.createSymbolicLink(at: linkURL, withDestinationURL: bundledTool)
            let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
            if PathCheck.isOnPath(dir: binDir.path, path: path) {
                installMessage = "Installed: doable is ready to use."
            } else {
                installMessage = "Installed to \(linkURL.path).\nAdd to ~/.zshrc:\nexport PATH=\"$HOME/.local/bin:$PATH\""
            }
        } catch {
            installMessage = "Could not install automatically (\(error.localizedDescription)). "
                + "Run in Terminal:\nln -sf \"\(bundledTool.path)\" \"\(linkURL.path)\""
        }
    }
```

And the UI section in the `Form` body:

```swift
            Section("Command-line tool") {
                Button("Install \u{201C}doable\u{201D} command") { installCLI() }
                if let installMessage {
                    Text(installMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
```

- [ ] **Step 3: Build the app**

Run:
```bash
cd /Users/jens/Sites/remove-me/Doable
xcodegen generate
xcodebuild -project Doable.xcodeproj -scheme Doable -configuration Debug build
```
Expected: app builds with the new Settings section.

- [ ] **Step 4: Commit**

```bash
git add App/Views/SettingsView.swift App/Doable.entitlements Doable.xcodeproj
git commit -m "feat(app): install doable CLI onto PATH from Settings"
```

> Functional verification of the install (clicking the button, entitlement honored under ad-hoc signing, PATH guidance) happens in Task 9 against the `/Applications` build.

---

## Task 9: Bundle the CLI + migrate/extend the install build phase + full verification

**Files:**
- Modify: `project.yml` (embed `doable` into `Contents/MacOS`; add `postBuildScripts`)

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Embed the tool and add the post-build script in `project.yml`**

On the `Doable` target, add the tool dependency (embedding into `Contents/MacOS`) and the post-build script. The `dependencies` list gains a target entry; add a `postBuildScripts` block:

```yaml
    dependencies:
      - package: DoableCore
        product: DoableCore
      - target: doable
        embed: true
        copy:
          destination: executables
    postBuildScripts:
      - name: "Copy to /Applications"
        script: |
          # Install the built app into /Applications on every build. This phase runs
          # before Xcode's final code-signing step, so the copy is unsigned; we ad-hoc
          # re-sign it (matching CODE_SIGN_IDENTITY "-") so the sandboxed app launches
          # and shares the same data container. The nested CLI is signed WITHOUT
          # entitlements so it is NOT sandboxed (it must read the container store and
          # drive LaunchServices).
          DEST="/Applications/${FULL_PRODUCT_NAME}"
          SRC="${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}"
          if [ ! -d "$SRC" ]; then
            echo "warning: $SRC not found; skipping install to /Applications"
            exit 0
          fi
          rm -rf "$DEST"
          cp -R "$SRC" "$DEST"
          find "$DEST/Contents/MacOS" -name '*.dylib' -exec codesign --force --sign - --timestamp=none {} +
          codesign --force --sign - --timestamp=none "$DEST/Contents/MacOS/doable"
          codesign --force --sign - --timestamp=none --entitlements "${SRCROOT}/${CODE_SIGN_ENTITLEMENTS}" "$DEST"
          echo "Installed signed ${FULL_PRODUCT_NAME} to /Applications"
```

- [ ] **Step 2: Regenerate and build (auto-installs to /Applications)**

Run:
```bash
cd /Users/jens/Sites/remove-me/Doable
xcodegen generate
xcodebuild -project Doable.xcodeproj -scheme Doable -configuration Debug build
```
Expected: build succeeds and prints "Installed signed Doable.app to /Applications".

- [ ] **Step 3: Verify the nested CLI is bundled, signed, and NOT sandboxed**

Run:
```bash
ls -l /Applications/Doable.app/Contents/MacOS/doable
codesign -d --entitlements - /Applications/Doable.app/Contents/MacOS/doable 2>&1
```
Expected: the binary exists; entitlements output shows **no** `com.apple.security.app-sandbox` key.

- [ ] **Step 4: Launch the app and install the CLI from Settings**

Run: `open /Applications/Doable.app`
Then open Settings → "Command-line tool" → click **Install**. Confirm the message reports success (or PATH guidance). Verify the symlink:
```bash
ls -l ~/.local/bin/doable
readlink ~/.local/bin/doable    # → /Applications/Doable.app/Contents/MacOS/doable
```
Expected: symlink resolves to the bundled binary. (If install reports a sandbox error, the entitlement isn't honored under ad-hoc signing — fall back per the spec's `NSOpenPanel` plan; record the result in the spec's Risks.)

- [ ] **Step 5: End-to-end command test**

Run (ensure `~/.local/bin` is on PATH for this shell, or call the symlink directly):
```bash
~/.local/bin/doable new "ship the CLI 🚀"
~/.local/bin/doable list
```
Expected: the new item appears live in the open menu-bar popover AND in `doable list` output (with the emoji intact). Quit the app, run `doable list` again — it still lists items (read works with app closed). `doable new` while quit relaunches the app and adds the item.

- [ ] **Step 6: Commit**

```bash
git add project.yml Doable.xcodeproj
git commit -m "build: bundle non-sandboxed doable CLI + install to /Applications"
```

---

## Self-Review

**Spec coverage:**
- `new` via URL scheme → Tasks 3, 6, 7. `list` via read-only store → Tasks 4, 5, 6. Shared `TodoItem` in DoableCore → Task 1. Testable logic (CLICommand/DoableURL/formatList/DoableStore/PathCheck) → Tasks 2–5. CLI executable + failure paths → Task 6. App URL handling via AppDelegate + shared container → Task 7. URL scheme registration → Task 7. Settings install + real-home + PATH guidance + entitlement (leading slash) → Task 8. Bundle in `Contents/MacOS` + migrate/extend re-sign (CLI signed with no entitlements) → Task 9. Manual integration + entitlement-validation → Task 9. All spec sections map to a task.

**Placeholder scan:** No TBD/TODO; every code step shows complete code; commands have expected output. GUI/build tasks (7–9) carry explicit manual verification because they can't be unit-tested.

**Type consistency:** `CLICommand` cases (`.new(title:)`, `.list`, `.help`, `.invalid(reason:)`) are consistent across Tasks 2/3/6. `DoableURL.makeNew`/`parse`, `DoableStore.defaultStoreURL`/`makeReadOnlyContainer(url:)`, `TodoRow(title:due:)`/`formatList(_:calendar:)`, `PathCheck.isOnPath(dir:path:)`, `TodoStore.insert(title:into:)`, `SharedContainer.shared` — all referenced with the same signatures where consumed. `Ordering.activeSorted` matches the existing public API in `DoableCore`.
