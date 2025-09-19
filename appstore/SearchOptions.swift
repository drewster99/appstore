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
    // Primary software attributes
    case softwareDeveloper
    case titleTerm
    case descriptionTerm
    case artistTerm

    // Additional useful attributes
    case keywordsTerm
    case languageTerm
    case releaseYearTerm
    case ratingTerm
    case genreIndex
    case ratingIndex
    case allTrackTerm

    // Media attributes (work but less useful for apps)
    case albumTerm
    case songTerm
    case mixTerm
    case composerTerm
    case producerTerm
    case directorTerm
    case actorTerm
    case authorTerm
    case featureFilmTerm
    case movieTerm
    case movieArtistTerm
    case shortFilmTerm
    case showTerm
    case tvEpisodeTerm
    case tvSeasonTerm
    case allArtistTerm

    var description: String {
        switch self {
        // Primary software attributes
        case .softwareDeveloper:
            return "Search developer/publisher names only"
        case .titleTerm:
            return "Search app titles/names only"
        case .descriptionTerm:
            return "Search app descriptions only"
        case .artistTerm:
            return "Search artist/developer names"

        // Additional useful attributes
        case .keywordsTerm:
            return "Search app keywords"
        case .languageTerm:
            return "Search by language"
        case .releaseYearTerm:
            return "Search by release year"
        case .ratingTerm:
            return "Search by content rating"
        case .genreIndex:
            return "Search by genre index"
        case .ratingIndex:
            return "Search by rating index"
        case .allTrackTerm:
            return "Search across all track fields"

        // Media attributes
        case .albumTerm:
            return "Album search (limited use for apps)"
        case .songTerm:
            return "Song search (limited use for apps)"
        case .mixTerm:
            return "Mix search (limited use for apps)"
        case .composerTerm:
            return "Composer search (limited use for apps)"
        case .producerTerm:
            return "Producer search (limited use for apps)"
        case .directorTerm:
            return "Director search (limited use for apps)"
        case .actorTerm:
            return "Actor search (limited use for apps)"
        case .authorTerm:
            return "Author search (limited use for apps)"
        case .featureFilmTerm:
            return "Feature film search (limited use for apps)"
        case .movieTerm:
            return "Movie search (limited use for apps)"
        case .movieArtistTerm:
            return "Movie artist search (limited use for apps)"
        case .shortFilmTerm:
            return "Short film search (limited use for apps)"
        case .showTerm:
            return "TV show search (limited use for apps)"
        case .tvEpisodeTerm:
            return "TV episode search (limited use for apps)"
        case .tvSeasonTerm:
            return "TV season search (limited use for apps)"
        case .allArtistTerm:
            return "All artist search (limited use for apps)"
        }
    }

    var isRecommendedForSoftware: Bool {
        switch self {
        case .softwareDeveloper, .titleTerm, .descriptionTerm, .artistTerm,
             .keywordsTerm, .languageTerm, .releaseYearTerm, .ratingTerm:
            return true
        default:
            return false
        }
    }
}

struct SearchOptions {
    let query: String
    let showRequest: Bool
    let limit: Int  // 0 means no limit
    let outputMode: OutputMode
    let storefront: String?  // Was 'country', using storefront for consistency
    let attribute: String?
    let genre: Int?
    let outputFile: String?
    let inputFile: String?

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
    let storefront: String?  // Was 'country', using storefront for consistency
    let entity: String? // For related content lookups
    let outputFile: String?
    let inputFile: String?
}