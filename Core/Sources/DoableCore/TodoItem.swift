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
