import Foundation
import SwiftData
import DoableCore

@Model
final class TodoItem: Orderable {
    var id: UUID
    var title: String
    var createdAt: Date
    var dueDate: Date?
    var isDone: Bool
    var completedAt: Date?
    var staleSnoozeUntil: Date?

    init(title: String, createdAt: Date, dueDate: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.isDone = false
        self.completedAt = nil
        self.staleSnoozeUntil = nil
    }
}
