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
