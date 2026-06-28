import Foundation

public enum DoableURL {
    public static let scheme = "doable"

    public static func makeNew(title: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "new"
        components.queryItems = [URLQueryItem(name: "title", value: title)]
        return components.url!
    }

    public static func parse(_ url: URL) -> CLICommand? {
        guard url.scheme == scheme, url.host == "new" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let title = components?.queryItems?.first(where: { $0.name == "title" })?.value,
              !title.isEmpty else { return nil }
        return .new(title: title)
    }
}
