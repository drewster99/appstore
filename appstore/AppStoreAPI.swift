import Foundation

// iTunes Search API Documentation:
// https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/index.html
//
// API Endpoints:
// - Search: https://itunes.apple.com/search
// - Lookup: https://itunes.apple.com/lookup
//
// Key Parameters:
// - term: The search text
// - entity: Type of results (software for apps)
// - attribute: Search specific fields (titleTerm, artistTerm, etc.)
// - limit: Number of results (1-200)
// - country: ISO country code (us, gb, jp, etc.)
// - id/bundleId: For lookup endpoint
//
// Rate Limits: ~20 calls per minute (subject to change)

struct AppStoreSearchResult: Codable {
    let resultCount: Int
    let results: [App]
}

struct App: Codable {
    let trackId: Int
    let trackName: String
    let artistName: String
    let averageUserRating: Double?
    let userRatingCount: Int?
    let formattedPrice: String?
    let description: String
    let bundleId: String
    let version: String
    let releaseNotes: String?
    let currentVersionReleaseDate: String?
    let primaryGenreName: String
    let sellerName: String
    let fileSizeBytes: String?
    let minimumOsVersion: String
    let contentAdvisoryRating: String?
    let advisories: [String]?
    let releaseDate: String?
    let trackViewUrl: String?
    let artistViewUrl: String?
    let artworkUrl512: String?
    let languageCodesISO2A: [String]?
    let features: [String]?
    let isGameCenterEnabled: Bool?
    let currency: String?
}

enum AppStoreAPIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for App Store search"
        case .noData:
            return "No data received from App Store"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

class AppStoreAPI {
    private let searchURL = "https://itunes.apple.com/search"
    private let lookupURL = "https://itunes.apple.com/lookup"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String, limit: Int = 20, country: String? = nil, attribute: String? = nil, genre: Int? = nil) async throws -> [App] {
        let result = try await searchWithRawData(query: query, limit: limit, country: country, attribute: attribute, genre: genre)
        return result.apps
    }

    func searchWithRawData(query: String, limit: Int = 20, country: String? = nil, attribute: String? = nil, genre: Int? = nil, showRequest: Bool = false) async throws -> (apps: [App], rawData: Data) {
        guard var urlComponents = URLComponents(string: searchURL) else {
            throw AppStoreAPIError.invalidURL
        }

        var queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "entity", value: "software")
        ]

        // Only add limit if it's not 0 (0 means no limit)
        if limit > 0 {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }

        if let country = country {
            queryItems.append(URLQueryItem(name: "country", value: country))
        }

        if let attribute = attribute {
            queryItems.append(URLQueryItem(name: "attribute", value: attribute))
        }

        if let genre = genre {
            queryItems.append(URLQueryItem(name: "genreId", value: String(genre)))
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw AppStoreAPIError.invalidURL
        }

        if showRequest {
            print("Request URL: \(url.absoluteString)")
            print("Parameters:")
            for item in queryItems {
                print("  \(item.name): \(item.value ?? "")")
            }
            print()
        }

        do {
            let (data, _) = try await session.data(from: url)

            guard !data.isEmpty else {
                throw AppStoreAPIError.noData
            }

            let decoder = JSONDecoder()
            let searchResult = try decoder.decode(AppStoreSearchResult.self, from: data)
            return (apps: searchResult.results, rawData: data)

        } catch let error as DecodingError {
            throw AppStoreAPIError.decodingError(error.localizedDescription)
        } catch let error as AppStoreAPIError {
            throw error
        } catch {
            throw AppStoreAPIError.networkError(error.localizedDescription)
        }
    }

    func lookupWithRawData(lookupType: LookupType, country: String? = nil, entity: String? = nil, showRequest: Bool = false) async throws -> (apps: [App], rawData: Data) {
        guard var urlComponents = URLComponents(string: lookupURL) else {
            throw AppStoreAPIError.invalidURL
        }

        var queryItems: [URLQueryItem] = []

        // Add lookup parameters based on type
        switch lookupType {
        case .id(let id):
            queryItems.append(URLQueryItem(name: "id", value: id))
        case .ids(let ids):
            queryItems.append(URLQueryItem(name: "id", value: ids.joined(separator: ",")))
        case .bundleId(let bundleId):
            queryItems.append(URLQueryItem(name: "bundleId", value: bundleId))
        case .url(let urlString):
            // Extract ID from URL (e.g., https://apps.apple.com/us/app/yelp/id284910350)
            if let id = extractIdFromUrl(urlString) {
                queryItems.append(URLQueryItem(name: "id", value: id))
            } else {
                throw AppStoreAPIError.invalidURL
            }
        }

        // Add optional parameters
        if let country = country {
            queryItems.append(URLQueryItem(name: "country", value: country))
        }

        if let entity = entity {
            queryItems.append(URLQueryItem(name: "entity", value: entity))
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw AppStoreAPIError.invalidURL
        }

        if showRequest {
            print("Request URL: \(url.absoluteString)")
            print("Parameters:")
            for item in queryItems {
                print("  \(item.name): \(item.value ?? "")")
            }
            print()
        }

        do {
            let (data, _) = try await session.data(from: url)

            guard !data.isEmpty else {
                throw AppStoreAPIError.noData
            }

            let decoder = JSONDecoder()
            let searchResult = try decoder.decode(AppStoreSearchResult.self, from: data)
            return (apps: searchResult.results, rawData: data)

        } catch let error as DecodingError {
            throw AppStoreAPIError.decodingError(error.localizedDescription)
        } catch let error as AppStoreAPIError {
            throw error
        } catch {
            throw AppStoreAPIError.networkError(error.localizedDescription)
        }
    }

    private func extractIdFromUrl(_ urlString: String) -> String? {
        // Try to extract ID from various URL formats
        // https://apps.apple.com/us/app/yelp/id284910350
        // https://itunes.apple.com/us/app/id284910350

        let patterns = [
            #"id(\d+)"#,  // Matches id followed by digits
            #"/(\d+)$"#,  // Matches digits at the end of URL
            #"/(\d+)\?"#  // Matches digits followed by query parameters
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: urlString, range: NSRange(location: 0, length: urlString.count)),
               match.numberOfRanges > 1 {
                let range = match.range(at: 1)
                if let swiftRange = Range(range, in: urlString) {
                    return String(urlString[swiftRange])
                }
            }
        }

        return nil
    }
}