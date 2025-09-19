import Foundation

// Import OutputMode for compatibility during transition
// This will be removed once fully migrated

// Verbosity levels - controls how much detail to show
enum Verbosity: String, CaseIterable {
    case minimal    // One-line output
    case summary    // Key details (default)
    case expanded   // More details
    case verbose    // All standard fields
    case complete   // All available fields

    static var `default`: Verbosity {
        return .summary
    }

    var description: String {
        switch self {
        case .minimal:
            return "Single line with essential info"
        case .summary:
            return "Key app details (default)"
        case .expanded:
            return "Summary plus size, ratings, and release info"
        case .verbose:
            return "Expanded plus URLs, languages, and features"
        case .complete:
            return "All available fields from the response"
        }
    }
}

// Output formats - controls how to present the data
enum OutputFormat: String, CaseIterable {
    case text       // Console output (default)
    case json       // JSON with metadata wrapper
    case html       // Rich HTML with icons and screenshots
    case htmlOpen   // HTML + auto-open in browser
    case markdown   // Markdown format

    static var `default`: OutputFormat {
        return .text
    }

    var description: String {
        switch self {
        case .text:
            return "Plain text output for console (default)"
        case .json:
            return "JSON with metadata wrapper"
        case .html:
            return "HTML with icons, screenshots, and collapsible sections"
        case .htmlOpen:
            return "HTML output opened in default browser"
        case .markdown:
            return "Markdown formatted output"
        }
    }

    // For CLI parsing compatibility
    var cliName: String {
        switch self {
        case .htmlOpen:
            return "html-open"
        default:
            return self.rawValue
        }
    }

    static func from(cliName: String) -> OutputFormat? {
        switch cliName.lowercased() {
        case "html-open":
            return .htmlOpen
        default:
            return OutputFormat(rawValue: cliName.lowercased())
        }
    }
}

// Combined output options
struct OutputOptions {
    let format: OutputFormat
    let verbosity: Verbosity
    let outputFile: String?
    let inputFile: String?

    // Check if we should respect verbosity for this format
    var shouldUseVerbosity: Bool {
        switch format {
        case .text, .markdown:
            return true
        case .json, .html, .htmlOpen:
            return false // These formats include everything
        }
    }

    // Compatibility: Create from old OutputMode
    static func fromOutputMode(_ mode: OutputMode, outputFile: String? = nil, inputFile: String? = nil) -> OutputOptions {
        switch mode {
        case .json:
            return OutputOptions(format: .json, verbosity: .complete, outputFile: outputFile, inputFile: inputFile)
        case .oneline:
            return OutputOptions(format: .text, verbosity: .minimal, outputFile: outputFile, inputFile: inputFile)
        case .summary:
            return OutputOptions(format: .text, verbosity: .summary, outputFile: outputFile, inputFile: inputFile)
        case .expanded:
            return OutputOptions(format: .text, verbosity: .expanded, outputFile: outputFile, inputFile: inputFile)
        case .verbose:
            return OutputOptions(format: .text, verbosity: .verbose, outputFile: outputFile, inputFile: inputFile)
        case .complete:
            return OutputOptions(format: .text, verbosity: .complete, outputFile: outputFile, inputFile: inputFile)
        }
    }

    // Compatibility: Get equivalent OutputMode (for transition period)
    var asOutputMode: OutputMode? {
        if format == .json {
            return .json
        }
        if format == .text {
            switch verbosity {
            case .minimal:
                return .oneline
            case .summary:
                return .summary
            case .expanded:
                return .expanded
            case .verbose:
                return .verbose
            case .complete:
                return .complete
            }
        }
        return nil
    }
}

// Metadata wrapper for JSON output/input
struct AppStoreResponseMetadata: Codable {
    let version: Int
    let id: String
    let timestamp: Date
    let command: String
    let parameters: [String: String?]
    let request: RequestInfo
    let response: ResponseInfo

    struct RequestInfo: Codable {
        let url: String
        let queryString: String
        let method: String
    }

    struct ResponseInfo: Codable {
        let httpStatus: Int
        let timestamp: Date
        let durationMs: Int?
    }
}

struct AppStoreResponse: Codable {
    let metadata: AppStoreResponseMetadata
    let data: Data // Raw JSON data from API

    // Helper to decode the data
    func decode<T: Codable>(_ type: T.Type) throws -> T {
        return try JSONDecoder().decode(type, from: data)
    }
}