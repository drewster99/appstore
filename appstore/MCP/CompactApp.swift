import Foundation

/// Token-efficient representation of an App for MCP/LLM consumption.
/// Omits description, releaseNotes, artworkUrl, languages, features, advisories,
/// sellerName, fileSizeBytes, contentAdvisoryRating, currency, isGameCenterEnabled, artistViewUrl.
struct CompactApp: Encodable {
    let id: Int
    let name: String
    let developer: String
    let rating: Double?
    let reviews: Int?
    let price: String?
    let bundleId: String
    let version: String
    let genre: String
    let minOS: String
    let released: String?
    let updated: String?
    let url: String?

    init(from app: App) {
        self.id = app.trackId
        self.name = app.trackName
        self.developer = app.artistName
        self.rating = app.averageUserRating
        self.reviews = app.userRatingCount
        self.price = app.formattedPrice
        self.bundleId = app.bundleId
        self.version = app.version
        self.genre = app.primaryGenreName
        self.minOS = app.minimumOsVersion
        self.released = CompactApp.formatDateString(app.releaseDate)
        self.updated = CompactApp.formatDateString(app.currentVersionReleaseDate)
        self.url = app.trackViewUrl
    }

    static func formatDateString(_ dateString: String?) -> String? {
        guard let dateString = dateString else { return nil }
        // ISO 8601 dates from API look like "2023-01-15T08:00:00Z"
        // Trim to just "2023-01-15" for compactness
        if dateString.count >= 10 {
            return String(dateString.prefix(10))
        }
        return dateString
    }
}

/// Full app representation for lookup_app - includes description and releaseNotes.
struct FullApp: Encodable {
    let id: Int
    let name: String
    let developer: String
    let rating: Double?
    let reviews: Int?
    let price: String?
    let bundleId: String
    let version: String
    let genre: String
    let minOS: String
    let released: String?
    let updated: String?
    let url: String?
    let description: String
    let releaseNotes: String?

    init(from app: App) {
        self.id = app.trackId
        self.name = app.trackName
        self.developer = app.artistName
        self.rating = app.averageUserRating
        self.reviews = app.userRatingCount
        self.price = app.formattedPrice
        self.bundleId = app.bundleId
        self.version = app.version
        self.genre = app.primaryGenreName
        self.minOS = app.minimumOsVersion
        self.released = CompactApp.formatDateString(app.releaseDate)
        self.updated = CompactApp.formatDateString(app.currentVersionReleaseDate)
        self.url = app.trackViewUrl
        self.description = app.description
        self.releaseNotes = app.releaseNotes
    }
}

/// Token-efficient representation of a TopChartEntry for MCP/LLM consumption.
/// Omits summary (RSS description text) to reduce output size.
struct CompactTopChartEntry: Encodable {
    let name: String
    let id: String
    let developer: String
    let price: String
    let category: String
    let url: String?

    init(from entry: TopChartEntry) {
        self.name = entry.name
        self.id = entry.id
        self.developer = entry.developer
        self.price = entry.price
        self.category = entry.category
        self.url = entry.url
    }
}

/// Encode an array of CompactApps to JSON Data.
func encodeCompactApps(_ apps: [App]) throws -> Data {
    let compact = apps.map { CompactApp(from: $0) }
    let encoder = JSONEncoder()
    return try encoder.encode(compact)
}

/// Encode an array of FullApps to JSON Data.
func encodeFullApps(_ apps: [App]) throws -> Data {
    let full = apps.map { FullApp(from: $0) }
    let encoder = JSONEncoder()
    return try encoder.encode(full)
}
