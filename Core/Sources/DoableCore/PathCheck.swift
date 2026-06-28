import Foundation

public enum PathCheck {
    public static func isOnPath(dir: String, path: String) -> Bool {
        let target = normalize(dir)
        return path.split(separator: ":").contains { normalize(String($0)) == target }
    }

    private static func normalize(_ s: String) -> String {
        s.hasSuffix("/") ? String(s.dropLast()) : s
    }
}
