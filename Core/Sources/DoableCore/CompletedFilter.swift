import Foundation

/// Time-range choices for the completed list, keeping it focused on recent
/// work. Weeks are Monday-based (Gregorian weekday 2), matching `DuePreset`.
public enum CompletedFilter: String, CaseIterable, Sendable {
    case thisWeek
    case lastWeek
    case last30Days

    public var displayName: String {
        switch self {
        case .thisWeek: return "This week"
        case .lastWeek: return "Last week"
        case .last30Days: return "Last 30 days"
        }
    }

    /// Half-open `[lower, upper)` window of `completedAt` values to include,
    /// relative to `now`.
    public func dateRange(now: Date, calendar: Calendar) -> Range<Date> {
        switch self {
        case .thisWeek:
            return Self.mondayMidnight(of: now, calendar: calendar)..<now
        case .lastWeek:
            let thisMonday = Self.mondayMidnight(of: now, calendar: calendar)
            let lastMonday = calendar.date(byAdding: .day, value: -7, to: thisMonday)!
            return lastMonday..<thisMonday
        case .last30Days:
            let lower = calendar.date(byAdding: .day, value: -30, to: now)!
            return lower..<now
        }
    }

    /// Midnight (start of day) of the Monday on or before `date`.
    private static func mondayMidnight(of date: Date, calendar: Calendar) -> Date {
        let monday = 2 // Gregorian weekday number
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let back = (weekday - monday + 7) % 7
        return calendar.date(byAdding: .day, value: -back, to: startOfDay)!
    }
}
