import Foundation

/// Where the deadline editor renders inside the menu window.
public enum DateEditorPlacement: String, CaseIterable, Sendable {
    /// A dimmed card centered over the menu list (default).
    case overlay
    /// Expanded directly beneath the edited row.
    case inline

    public var displayName: String {
        switch self {
        case .overlay: return "Overlay"
        case .inline: return "Inline"
        }
    }
}
