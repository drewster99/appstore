import Foundation

enum Command {
    case search(query: String)
    case help
    case searchHelp
    case unknown(String)
}

class CommandParser {
    private let arguments: [String]

    init(arguments: [String] = CommandLine.arguments) {
        self.arguments = arguments
    }

    func parse() -> Command {
        guard arguments.count > 1 else {
            return .help
        }

        let command = arguments[1].lowercased()

        switch command {
        case "--help", "-h", "help":
            return .help

        case "search":
            if arguments.count > 2 {
                if arguments[2] == "--help" || arguments[2] == "-h" {
                    return .searchHelp
                }

                let searchTerms = Array(arguments.dropFirst(2))
                let query = searchTerms.joined(separator: " ")
                return .search(query: query)
            } else {
                return .searchHelp
            }

        default:
            return .unknown(command)
        }
    }
}