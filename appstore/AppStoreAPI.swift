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
    case httpError(statusCode: Int, message: String)

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
        case .httpError(let statusCode, let message):
            return "HTTP \(statusCode): \(message)"
        }
    }
}

class AppStoreAPI {
    private let searchURL = "https://itunes.apple.com/search"
    private let lookupURL = "https://itunes.apple.com/lookup"

    // IMPORTANT: Static method for shared lookup functionality.
    // This ensures all commands that need app details use the same lookup logic.
    // Always use this after getting ranked app IDs from the MZStore API.
    // See CLAUDE.md for architecture details.
    static func lookupAppDetails(appIds: [String], storefront: String?, language: String) async throws -> [App] {
        let api = AppStoreAPI()
        let result = try await api.lookupWithRawData(
            lookupType: .ids(appIds),
            storefront: storefront,
            entity: nil,
            language: language,
            showRequest: false,
            showResponseHeaders: false
        )
        return result.apps
    }
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private func handleAPIResponse(data: Data, response: URLResponse, storefront: String? = nil, attribute: String? = nil) throws {
        // Check HTTP response for errors
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 403 {
                // Try to parse error message from response
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorJson["errorMessage"] as? String {
                    // Check for specific known errors
                    if errorMessage.contains("Invalid value") {
                        if errorMessage.contains("attribute") && attribute != nil {
                            throw AppStoreAPIError.decodingError("Invalid attribute parameter '\(attribute ?? "")'. Use 'appstore search --attribute' to see valid options.")
                        } else if errorMessage.contains("country") && storefront != nil {
                            throw AppStoreAPIError.decodingError("Invalid storefront code '\(storefront ?? "")'. Use two-letter ISO country codes (e.g., us, gb, jp).")
                        }
                    }
                    throw AppStoreAPIError.decodingError("API Error: \(errorMessage)")
                }
                throw AppStoreAPIError.decodingError("Invalid request parameters (HTTP \(httpResponse.statusCode))")
            }
        }
    }

    func search(query: String, limit: Int = 200, storefront: String? = nil, attribute: String? = nil, genre: Int? = nil, language: String? = nil) async throws -> [App] {
        let result = try await searchWithRawData(query: query, limit: limit, storefront: storefront, attribute: attribute, genre: genre, language: language)
        return result.apps
    }

    func searchWithRawData(query: String, limit: Int = 200, storefront: String? = nil, attribute: String? = nil, genre: Int? = nil, language: String? = nil, showRequest: Bool = false, showResponseHeaders: Bool = false) async throws -> (apps: [App], rawData: Data) {
        guard var urlComponents = URLComponents(string: searchURL) else {
            throw AppStoreAPIError.invalidURL
        }

        var queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "media", value: "software"),  // Broad category for apps
            URLQueryItem(name: "entity", value: "software")  // Specifically iPhone/iOS apps
        ]

        // Only add limit if it's not 0 (0 means no limit)
        if limit > 0 {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }

        // Always include storefront, defaulting to US
        queryItems.append(URLQueryItem(name: "country", value: storefront ?? "US"))  // API uses 'country' parameter

        if let attribute = attribute {
            queryItems.append(URLQueryItem(name: "attribute", value: attribute))
        }

        if let genre = genre {
            queryItems.append(URLQueryItem(name: "genreId", value: String(genre)))
        }

        if let language = language {
            queryItems.append(URLQueryItem(name: "lang", value: language))
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw AppStoreAPIError.invalidURL
        }

        // Create request with 12-hour cache control
        var request = URLRequest(url: url)
        request.setValue("max-age=43200", forHTTPHeaderField: "Cache-Control")

        if showRequest {
            print("Request URL: \(url.absoluteString)")
            print("Request Headers:")
            print("  Cache-Control: max-age=43200")
            print("Parameters:")
            for item in queryItems {
                print("  \(item.name): \(item.value ?? "")")
            }
            print()
        }

        do {
            // Rate limit before API call
            await waitForRateLimit()

            let (data, response) = try await session.data(for: request)

            // Show response headers if requested
            if showResponseHeaders {
                print("Response Headers:")
                if let httpResponse = response as? HTTPURLResponse {
                    for (key, value) in httpResponse.allHeaderFields {
                        print("  \(key): \(value)")
                    }
                    print()
                }
            }

            // Check for HTTP errors
            try handleAPIResponse(data: data, response: response, storefront: storefront, attribute: attribute)

            guard !data.isEmpty else {
                throw AppStoreAPIError.noData
            }

            let decoder = JSONDecoder()
            do {
                let searchResult = try decoder.decode(AppStoreSearchResult.self, from: data)
                return (apps: searchResult.results, rawData: data)
            } catch {
                // Try to extract error message from response if decoding failed
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorJson["errorMessage"] as? String {
                    throw AppStoreAPIError.decodingError(errorMessage)
                }
                throw AppStoreAPIError.decodingError("Failed to parse App Store response. This may be due to invalid parameters.")
            }

        } catch let error as AppStoreAPIError {
            throw error
        } catch {
            throw AppStoreAPIError.networkError(error.localizedDescription)
        }
    }

    func lookupWithRawData(lookupType: LookupType, storefront: String? = nil, entity: String? = nil, language: String? = nil, showRequest: Bool = false, showResponseHeaders: Bool = false) async throws -> (apps: [App], rawData: Data) {
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
        // Always include storefront, defaulting to US
        queryItems.append(URLQueryItem(name: "country", value: storefront ?? "US"))  // API uses 'country' parameter

        if let entity = entity {
            queryItems.append(URLQueryItem(name: "entity", value: entity))
        }

        if let language = language {
            queryItems.append(URLQueryItem(name: "lang", value: language))
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw AppStoreAPIError.invalidURL
        }

        // Create request with 12-hour cache control
        var request = URLRequest(url: url)
        request.setValue("max-age=43200", forHTTPHeaderField: "Cache-Control")

        if showRequest {
            print("Request URL: \(url.absoluteString)")
            print("Request Headers:")
            print("  Cache-Control: max-age=43200")
            print("Parameters:")
            for item in queryItems {
                print("  \(item.name): \(item.value ?? "")")
            }
            print()
        }

        do {
            // Rate limit before API call
            await waitForRateLimit()

            let (data, response) = try await session.data(for: request)

            // Show response headers if requested
            if showResponseHeaders {
                print("Response Headers:")
                if let httpResponse = response as? HTTPURLResponse {
                    for (key, value) in httpResponse.allHeaderFields {
                        print("  \(key): \(value)")
                    }
                    print()
                }
            }

            // Check for HTTP errors
            try handleAPIResponse(data: data, response: response, storefront: storefront)

            guard !data.isEmpty else {
                throw AppStoreAPIError.noData
            }

            let decoder = JSONDecoder()
            do {
                let searchResult = try decoder.decode(AppStoreSearchResult.self, from: data)
                return (apps: searchResult.results, rawData: data)
            } catch {
                // Try to extract error message from response if decoding failed
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorJson["errorMessage"] as? String {
                    throw AppStoreAPIError.decodingError(errorMessage)
                }
                throw AppStoreAPIError.decodingError("Failed to parse App Store response. This may be due to invalid parameters.")
            }

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