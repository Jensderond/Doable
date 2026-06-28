import Foundation
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
    // Open the URL in the background (`-g`) so Doable handles it without stealing
    // focus from the terminal. NSWorkspace.open would activate the app frontmost.
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    task.arguments = ["-g", url.absoluteString]
    do {
        try task.run()
    } catch {
        fail("could not launch /usr/bin/open: \(error.localizedDescription)")
    }
    task.waitUntilExit()
    guard task.terminationStatus == 0 else {
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
