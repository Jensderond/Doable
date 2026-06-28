import Foundation

public enum CLICommand: Equatable {
    case new(title: String)
    case list
    case help
    case invalid(reason: String)

    public static func parse(_ args: [String]) -> CLICommand {
        guard let verb = args.first else { return .help }
        switch verb {
        case "help", "-h", "--help":
            return .help
        case "list":
            return .list
        case "new":
            let title = args.dropFirst().joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? .invalid(reason: "new requires a title") : .new(title: title)
        default:
            return .invalid(reason: "unknown command: \(verb)")
        }
    }
}
