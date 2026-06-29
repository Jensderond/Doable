import Foundation

/// Formatting for the optional "most urgent task" text shown in the menu bar.
public enum MenuBarTitle {
    /// Trims and truncates a task title to fit the menu bar, appending an ellipsis when it is
    /// shortened. Whitespace/newlines are collapsed so a multi-line title stays on one line.
    public static func format(_ title: String, max: Int = 24) -> String {
        let collapsed = title
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard collapsed.count > max else { return collapsed }
        let kept = collapsed.prefix(max - 1).trimmingCharacters(in: .whitespaces)
        return kept + "…"
    }
}
