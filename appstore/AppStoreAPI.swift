import Foundation

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
    private let baseURL = "https://itunes.apple.com/search"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String, limit: Int = 20) async throws -> [App] {
        guard var urlComponents = URLComponents(string: baseURL) else {
            throw AppStoreAPIError.invalidURL
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "entity", value: "software"),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = urlComponents.url else {
            throw AppStoreAPIError.invalidURL
        }

        do {
            let (data, _) = try await session.data(from: url)

            guard !data.isEmpty else {
                throw AppStoreAPIError.noData
            }

            let decoder = JSONDecoder()
            let searchResult = try decoder.decode(AppStoreSearchResult.self, from: data)
            return searchResult.results

        } catch let error as DecodingError {
            throw AppStoreAPIError.decodingError(error.localizedDescription)
        } catch let error as AppStoreAPIError {
            throw error
        } catch {
            throw AppStoreAPIError.networkError(error.localizedDescription)
        }
    }
}