import Foundation

enum OutputMode: String, CaseIterable {
    case oneline
    case summary
    case expanded
    case verbose
    case complete
    case json

    static var `default`: OutputMode {
        return .summary
    }

    var description: String {
        switch self {
        case .oneline:
            return "Single line output with essential info"
        case .summary:
            return "Default output with key app details"
        case .expanded:
            return "Summary plus ratings, size, and advisories"
        case .verbose:
            return "Expanded plus URLs, languages, and features"
        case .complete:
            return "All available fields from the JSON response"
        case .json:
            return "Raw JSON output (pretty-printed)"
        }
    }
}

enum SearchAttribute: String, CaseIterable {
    case softwareDeveloper
    case titleTerm
    case descriptionTerm
    case artistTerm

    var description: String {
        switch self {
        case .softwareDeveloper:
            return "Search developer/publisher names only"
        case .titleTerm:
            return "Search app titles/names only"
        case .descriptionTerm:
            return "Search app descriptions only"
        case .artistTerm:
            return "Search artist/developer names"
        }
    }
}

struct SearchOptions {
    let query: String
    let showRequest: Bool
    let limit: Int  // 0 means no limit
    let outputMode: OutputMode
    let country: String?
    let attribute: String?
    let genre: Int?

    static let defaultLimit = 20
    static let maxLimit = 200
    static let minLimit = 0  // 0 means unlimited
}

enum LookupType {
    case id(String)
    case ids([String])
    case bundleId(String)
    case url(String)
}

struct LookupOptions {
    let lookupType: LookupType
    let showRequest: Bool
    let outputMode: OutputMode
    let country: String?
    let entity: String? // For related content lookups
}