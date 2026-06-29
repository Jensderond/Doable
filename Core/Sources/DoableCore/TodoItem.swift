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
    /// User-pinned to the top of the active list. Defaulted so existing stores migrate cleanly.
    public var isPinned: Bool = false

    public init(title: String, createdAt: Date, dueDate: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.isDone = false
        self.completedAt = nil
        self.staleSnoozeUntil = nil
        self.isPinned = false
    }
}
