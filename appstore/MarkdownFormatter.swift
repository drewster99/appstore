import Foundation

class MarkdownFormatter {

    static func formatSearchResults(_ apps: [App], verbosity: Verbosity, fullDescription: Bool = false) -> String {
        var output = ""

        // Header
        output += "# App Store Search Results\n\n"
        output += "Found **\(apps.count)** app(s)\n\n"

        // Table of contents for verbose modes
        if verbosity == .verbose || verbosity == .complete {
            output += "## Table of Contents\n\n"
            for (index, app) in apps.enumerated() {
                output += "\(index + 1). [\(app.trackName)](#\(app.trackName.lowercased().replacingOccurrences(of: " ", with: "-")))\n"
            }
            output += "\n---\n\n"
        }

        // App details
        for (index, app) in apps.enumerated() {
            output += formatApp(app, index: index + 1, verbosity: verbosity, fullDescription: fullDescription)
            if index < apps.count - 1 {
                output += "\n---\n\n"
            }
        }

        return output
    }

    static func formatTopResults(_ entries: [[String: Any]]) -> String {
        var output = ""

        output += "# Top App Store Charts\n\n"
        output += "Found **\(entries.count)** app(s)\n\n"

        for (index, entry) in entries.enumerated() {
            output += "## \(index + 1). "

            let name = (entry["im:name"] as? [String: Any])?["label"] as? String ?? "Unknown"
            let artist = (entry["im:artist"] as? [String: Any])?["label"] as? String ?? "Unknown Developer"
            let price = (entry["im:price"] as? [String: Any])?["label"] as? String ?? "Unknown"
            let category = ((entry["category"] as? [String: Any])?["attributes"] as? [String: Any])?["label"] as? String ?? "Unknown"

            // Get IDs
            let idAttributes = (entry["id"] as? [String: Any])?["attributes"] as? [String: Any]
            let appId = idAttributes?["im:id"] as? String ?? "Unknown"
            let bundleId = idAttributes?["im:bundleId"] as? String

            output += "\(name)\n\n"
            output += "- **App ID:** `\(appId)`\n"
            output += "- **Developer:** \(artist)\n"
            output += "- **Price:** \(price)\n"
            output += "- **Category:** \(category)\n"

            if let bundleId = bundleId {
                output += "- **Bundle ID:** `\(bundleId)`\n"
            }

            if let summary = (entry["summary"] as? [String: Any])?["label"] as? String {
                let maxLength = 200
                let cleanSummary = summary.replacingOccurrences(of: "\n", with: " ")
                let truncated = cleanSummary.count > maxLength ? String(cleanSummary.prefix(maxLength)) + "..." : cleanSummary
                output += "\n### Description\n\(truncated)\n"
            }

            if index < entries.count - 1 {
                output += "\n"
            }
        }

        return output
    }

    private static func formatApp(_ app: App, index: Int, verbosity: Verbosity, fullDescription: Bool = false) -> String {
        var output = ""

        switch verbosity {
        case .minimal:
            // One-line format in markdown
            output += "**\(index).** `\(app.trackId)` | `\(app.bundleId)` | \(app.formattedPrice ?? "Free") | "
            if let rating = app.averageUserRating {
                output += "⭐ \(String(format: "%.1f", rating)) "
            }
            output += "| **\(app.trackName)**\n"

        case .summary:
            output += "## \(index). \(app.trackName)\n\n"
            output += "- **App ID:** `\(app.trackId)`\n"
            output += "- **Developer:** \(app.artistName)\n"
            output += "- **Price:** \(app.formattedPrice ?? "Free")\n"

            if let rating = app.averageUserRating,
               let ratingCount = app.userRatingCount {
                let stars = FormatUtils.formatRatingStars(rating)
                output += "- **Rating:** \(stars) \(String(format: "%.1f", rating)) (\(FormatUtils.formatNumber(ratingCount)) ratings)\n"
            }

            output += "- **Category:** \(app.primaryGenreName)\n"
            output += "- **Version:** \(app.version)\n"
            output += "- **Bundle ID:** `\(app.bundleId)`\n"

            if fullDescription {
                output += "\n### Description\n\(app.description)\n"
            } else if let description = app.description.split(separator: "\n").first {
                let maxLength = 150
                let truncated = description.count > maxLength ? String(description.prefix(maxLength)) + "..." : String(description)
                output += "\n### Description\n\(truncated)\n"
            }

        case .expanded:
            output += "## \(index). \(app.trackName)\n\n"
            output += "### Basic Information\n"
            output += "- **App ID:** `\(app.trackId)`\n"
            output += "- **Developer:** \(app.artistName)\n"
            output += "- **Price:** \(app.formattedPrice ?? "Free")"
            if let currency = app.currency {
                output += " (\(currency))"
            }
            output += "\n"

            if let rating = app.averageUserRating,
               let ratingCount = app.userRatingCount {
                let stars = FormatUtils.formatRatingStars(rating)
                output += "- **Rating:** \(stars) \(String(format: "%.1f", rating)) (\(FormatUtils.formatNumber(ratingCount)) ratings)\n"
            }

            output += "- **Category:** \(app.primaryGenreName)\n"
            output += "- **Version:** \(app.version)\n"
            output += "- **Bundle ID:** `\(app.bundleId)`\n"

            output += "\n### Additional Details\n"

            if let contentRating = app.contentAdvisoryRating {
                output += "- **Content Rating:** \(contentRating)\n"
            }

            if let releaseDate = app.currentVersionReleaseDate {
                output += "- **Current Version Release:** \(FormatUtils.formatDate(releaseDate))\n"
            }

            output += "- **Minimum OS:** \(app.minimumOsVersion)\n"
            output += "- **Size:** \(FormatUtils.formatFileSize(app.fileSizeBytes))\n"

            if let releaseNotes = app.releaseNotes {
                let maxLength = 200
                let truncated = releaseNotes.count > maxLength ? String(releaseNotes.prefix(maxLength)) + "..." : releaseNotes
                output += "\n### What's New\n\(truncated.replacingOccurrences(of: "\n", with: " "))\n"
            }

            if let advisories = app.advisories, !advisories.isEmpty {
                output += "\n### Advisories\n"
                for advisory in advisories {
                    output += "- \(advisory)\n"
                }
            }

            if fullDescription {
                output += "\n### Description\n\(app.description)\n"
            } else if let description = app.description.split(separator: "\n").first {
                let maxLength = 200
                let truncated = description.count > maxLength ? String(description.prefix(maxLength)) + "..." : String(description)
                output += "\n### Description\n\(truncated)\n"
            }

        case .verbose, .complete:
            output += "## \(index). \(app.trackName)\n\n"

            // Basic Information
            output += "### 📱 Basic Information\n"
            output += "| Field | Value |\n"
            output += "|-------|-------|\n"
            output += "| **App ID** | `\(app.trackId)` |\n"
            output += "| **Bundle ID** | `\(app.bundleId)` |\n"
            output += "| **Developer** | \(app.artistName) |\n"
            output += "| **Seller** | \(app.sellerName) |\n"
            output += "| **Price** | \(app.formattedPrice ?? "Free")"
            if let currency = app.currency {
                output += " (\(currency))"
            }
            output += " |\n"

            // Ratings
            if let rating = app.averageUserRating,
               let ratingCount = app.userRatingCount {
                let stars = FormatUtils.formatRatingStars(rating)
                output += "| **Rating** | \(stars) \(String(format: "%.1f", rating)) |\n"
                output += "| **Reviews** | \(FormatUtils.formatNumber(ratingCount)) |\n"
            }

            output += "| **Category** | \(app.primaryGenreName) |\n"
            output += "| **Version** | \(app.version) |\n"

            // Technical Details
            output += "\n### ⚙️ Technical Details\n"
            output += "| Field | Value |\n"
            output += "|-------|-------|\n"
            output += "| **Size** | \(FormatUtils.formatFileSize(app.fileSizeBytes)) |\n"
            output += "| **Minimum OS** | \(app.minimumOsVersion) |\n"

            if let contentRating = app.contentAdvisoryRating {
                output += "| **Content Rating** | \(contentRating) |\n"
            }

            if let currentRelease = app.currentVersionReleaseDate {
                output += "| **Current Version Release** | \(FormatUtils.formatDate(currentRelease)) |\n"
            }

            if let originalRelease = app.releaseDate {
                output += "| **Original Release** | \(FormatUtils.formatDate(originalRelease)) |\n"
            }

            // Links
            if verbosity == .verbose || verbosity == .complete {
                output += "\n### 🔗 Links\n"
                if let trackUrl = app.trackViewUrl {
                    output += "- [View on App Store](\(trackUrl))\n"
                }
                if let artistUrl = app.artistViewUrl {
                    output += "- [Developer Page](\(artistUrl))\n"
                }
                if let artworkUrl = app.artworkUrl512 {
                    output += "- [App Icon](\(artworkUrl))\n"
                }
            }

            // Languages
            output += "\n### 🌍 Languages\n"
            output += FormatUtils.formatLanguages(app.languageCodesISO2A) + "\n"

            // Features
            if let features = app.features, !features.isEmpty {
                output += "\n### ✨ Features\n"
                for feature in features {
                    output += "- \(feature)\n"
                }
            }

            output += "\n### 🎮 Game Center\n"
            output += app.isGameCenterEnabled == true ? "✅ Enabled\n" : "❌ Not Enabled\n"

            // Advisories
            if let advisories = app.advisories, !advisories.isEmpty {
                output += "\n### ⚠️ Advisories\n"
                for advisory in advisories {
                    output += "- \(advisory)\n"
                }
            }

            // Release Notes
            if let releaseNotes = app.releaseNotes {
                output += "\n### 📝 What's New\n"
                output += "```\n\(releaseNotes)\n```\n"
            }

            // Description
            output += "\n### 📄 Description\n"
            output += app.description + "\n"
        }

        return output
    }
}