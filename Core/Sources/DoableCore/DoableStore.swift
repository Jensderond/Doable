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
