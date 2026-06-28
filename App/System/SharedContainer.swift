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
