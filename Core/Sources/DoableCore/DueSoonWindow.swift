import Foundation

/// The configurable look-ahead window that defines "due soon".
public enum DueSoonWindow: String, CaseIterable, Codable, Sendable {
    case todayOnly
    case oneHour
    case twentyFourHours
    case threeDays

    public var displayName: String {
        switch self {
        case .todayOnly: return "Today only"
        case .oneHour: return "Within 1 hour"
        case .twentyFourHours: return "Within 24 hours"
        case .threeDays: return "Within 3 days"
        }
    }
}
