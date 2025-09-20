import Foundation

protocol OutputFormatter {
    func formatApps(_ apps: [App], options: CommonOptions) -> String
    func formatTopEntries(_ entries: [[String: Any]], title: String, options: CommonOptions) -> String
    func formatLookupResults(_ apps: [App], options: CommonOptions) -> String
}

extension OutputFormatter {
    func formatLookupResults(_ apps: [App], options: CommonOptions) -> String {
        return formatApps(apps, options: options)
    }
}

class TextFormatter: OutputFormatter {
    func formatApps(_ apps: [App], options: CommonOptions) -> String {
        var output = ""

        if !apps.isEmpty {
            output += "Found \(apps.count) result(s):\n"

            switch options.verbosity {
            case .minimal:
                // Minimal has its own formatting with table headers
                output += formatMinimal(apps: apps)
            default:
                // Other verbosity levels use separator
                output += String(repeating: "-", count: 80) + "\n"

                switch options.verbosity {
                case .summary:
                    output += formatSummary(apps: apps, fullDescription: options.fullDescription)
                case .expanded:
                    output += formatExpanded(apps: apps, fullDescription: options.fullDescription)
                case .verbose:
                    output += formatVerbose(apps: apps, fullDescription: options.fullDescription)
                case .complete:
                    output += formatComplete(apps: apps)
                default:
                    break
                }
            }

            // Add footer separator for all verbosity levels
            output += String(repeating: "-", count: 80)
        } else {
            output += "No results found"
        }

        return output
    }

    func formatTopEntries(_ entries: [[String: Any]], title: String, options: CommonOptions) -> String {
        var output = ""

        output += "\(title):\n"
        output += String(repeating: "-", count: 80) + "\n"

        switch options.verbosity {
        case .minimal:
            output += formatTopMinimal(entries: entries)
        case .summary, .expanded, .verbose:
            output += formatTopSummary(entries: entries)
        case .complete:
            output += formatTopComplete(entries: entries)
        }

        output += String(repeating: "-", count: 80)

        return output
    }

    private func formatMinimal(apps: [App]) -> String {
        var output = ""

        // Add header for table format
        output += "#  App ID      Bundle ID                          Version    Price    Rating  Reviews  Name\n"
        output += String(repeating: "-", count: 80) + "\n"

        for (index, app) in apps.enumerated() {
            let rating = app.averageUserRating.map { String(format: "%.1f", $0) } ?? "N/A"
            let ratingCount = app.userRatingCount.map { String($0) } ?? "0"
            let price = app.formattedPrice ?? "Free"

            // Format with fixed widths for better alignment
            let numStr = String(index + 1).padding(toLength: 2, withPad: " ", startingAt: 0)
            let idStr = String(app.trackId).padding(toLength: 11, withPad: " ", startingAt: 0)
            let bundleStr = app.bundleId.padding(toLength: 35, withPad: " ", startingAt: 0)
            let versionStr = app.version.padding(toLength: 10, withPad: " ", startingAt: 0)
            let priceStr = price.padding(toLength: 8, withPad: " ", startingAt: 0)
            let ratingStr = rating.padding(toLength: 7, withPad: " ", startingAt: 0)
            let countStr = ratingCount.padding(toLength: 8, withPad: " ", startingAt: 0)

            output += "\(numStr) \(idStr) \(bundleStr) \(versionStr) \(priceStr) \(ratingStr) \(countStr) \(app.trackName)\n"
        }

        return output
    }

    private func formatSummary(apps: [App], fullDescription: Bool) -> String {
        var output = ""

        for (index, app) in apps.enumerated() {
            output += "\(index + 1). \(app.trackName)\n"
            output += "   App ID: \(app.trackId)\n"
            output += "   Developer: \(app.artistName)\n"
            output += "   Price: \(app.formattedPrice ?? "Free")\n"

            if let rating = app.averageUserRating,
               let ratingCount = app.userRatingCount {
                let stars = FormatUtils.formatRatingStars(rating)
                output += "   Rating: \(stars) \(String(format: "%.1f", rating)) (\(FormatUtils.formatNumber(ratingCount)) ratings)\n"
            }

            output += "   Category: \(app.primaryGenreName)\n"
            output += "   Version: \(app.version)\n"
            output += "   Bundle ID: \(app.bundleId)\n"

            if fullDescription {
                output += "   Description: \(app.description.replacingOccurrences(of: "\n", with: " "))\n"
            } else if let description = app.description.split(separator: "\n").first {
                let maxLength = 150
                let truncated = description.count > maxLength ? String(description.prefix(maxLength)) + "..." : String(description)
                output += "   Description: \(truncated)\n"
            }

            if index < apps.count - 1 {
                output += String(repeating: "-", count: 80) + "\n"
            }
        }

        return output
    }

    private func formatExpanded(apps: [App], fullDescription: Bool) -> String {
        var output = ""

        for (index, app) in apps.enumerated() {
            output += "\(index + 1). \(app.trackName)\n"
            output += "   App ID: \(app.trackId)\n"
            output += "   Developer: \(app.artistName)\n"
            output += "   Price: \(app.formattedPrice ?? "Free")\n"

            if let rating = app.averageUserRating,
               let ratingCount = app.userRatingCount {
                let stars = FormatUtils.formatRatingStars(rating)
                output += "   Rating: \(stars) \(String(format: "%.1f", rating)) (\(FormatUtils.formatNumber(ratingCount)) ratings)\n"
            }

            output += "   Category: \(app.primaryGenreName)\n"
            output += "   Version: \(app.version)\n"
            output += "   Bundle ID: \(app.bundleId)\n"

            if let contentRating = app.contentAdvisoryRating {
                output += "   Content Rating: \(contentRating)\n"
            }

            if let releaseDate = app.currentVersionReleaseDate {
                output += "   Current Version Release: \(FormatUtils.formatDate(releaseDate))\n"
            }

            output += "   Minimum OS: \(app.minimumOsVersion)\n"
            output += "   Size: \(FormatUtils.formatFileSize(app.fileSizeBytes))\n"

            if let releaseNotes = app.releaseNotes {
                let maxLength = 200
                let truncated = releaseNotes.count > maxLength ? String(releaseNotes.prefix(maxLength)) + "..." : releaseNotes
                output += "   What's New: \(truncated.replacingOccurrences(of: "\n", with: " "))\n"
            }

            if let advisories = app.advisories, !advisories.isEmpty {
                output += "   Advisories:\n"
                for advisory in advisories {
                    output += "     • \(advisory)\n"
                }
            }

            if fullDescription {
                output += "   Description: \(app.description.replacingOccurrences(of: "\n", with: " "))\n"
            } else if let description = app.description.split(separator: "\n").first {
                let maxLength = 150
                let truncated = description.count > maxLength ? String(description.prefix(maxLength)) + "..." : String(description)
                output += "   Description: \(truncated)\n"
            }

            if index < apps.count - 1 {
                output += String(repeating: "-", count: 80) + "\n"
            }
        }

        return output
    }

    private func formatVerbose(apps: [App], fullDescription: Bool) -> String {
        var output = ""

        for (index, app) in apps.enumerated() {
            output += "\(index + 1). \(app.trackName)\n"
            output += "   App ID: \(app.trackId)\n"
            output += "   Developer: \(app.artistName)\n"

            let priceInfo = if let currency = app.currency {
                "\(app.formattedPrice ?? "Free") (\(currency))"
            } else {
                app.formattedPrice ?? "Free"
            }
            output += "   Price: \(priceInfo)\n"

            if let rating = app.averageUserRating,
               let ratingCount = app.userRatingCount {
                let stars = FormatUtils.formatRatingStars(rating)
                output += "   Rating: \(stars) \(String(format: "%.1f", rating)) (\(FormatUtils.formatNumber(ratingCount)) ratings)\n"
            }

            output += "   Category: \(app.primaryGenreName)\n"
            output += "   Version: \(app.version)\n"
            output += "   Bundle ID: \(app.bundleId)\n"

            if let contentRating = app.contentAdvisoryRating {
                output += "   Content Rating: \(contentRating)\n"
            }

            if let currentRelease = app.currentVersionReleaseDate {
                output += "   Current Version Release: \(FormatUtils.formatDate(currentRelease))\n"
            }

            if let originalRelease = app.releaseDate {
                output += "   Original Release: \(FormatUtils.formatDate(originalRelease))\n"
            }

            output += "   Minimum OS: \(app.minimumOsVersion)\n"
            output += "   Size: \(FormatUtils.formatFileSize(app.fileSizeBytes))\n"

            if let releaseNotes = app.releaseNotes {
                let maxLength = 250
                let truncated = releaseNotes.count > maxLength ? String(releaseNotes.prefix(maxLength)) + "..." : releaseNotes
                output += "   What's New: \(truncated.replacingOccurrences(of: "\n", with: " "))\n"
            }

            if let trackUrl = app.trackViewUrl {
                output += "   App Store URL: \(trackUrl)\n"
            }

            if let artistUrl = app.artistViewUrl {
                output += "   Developer URL: \(artistUrl)\n"
            }

            if let artworkUrl = app.artworkUrl512 {
                output += "   Artwork URL: \(artworkUrl)\n"
            }

            output += "   Languages: \(FormatUtils.formatLanguages(app.languageCodesISO2A))\n"

            if let features = app.features, !features.isEmpty {
                output += "   Features: \(features.joined(separator: ", "))\n"
            }

            output += "   Game Center Enabled: \(app.isGameCenterEnabled == true ? "Yes" : "No")\n"

            if let advisories = app.advisories, !advisories.isEmpty {
                output += "   Advisories:\n"
                for advisory in advisories {
                    output += "     • \(advisory)\n"
                }
            }

            if fullDescription {
                output += "   Description: \(app.description.replacingOccurrences(of: "\n", with: " "))\n"
            } else if let description = app.description.split(separator: "\n").first {
                let maxLength = 200
                let truncated = description.count > maxLength ? String(description.prefix(maxLength)) + "..." : String(description)
                output += "   Description: \(truncated)\n"
            }

            if index < apps.count - 1 {
                output += String(repeating: "-", count: 80) + "\n"
            }
        }

        return output
    }

    private func formatComplete(apps: [App]) -> String {
        var output = ""

        for (index, app) in apps.enumerated() {
            output += "\n[\(index + 1)] \(app.trackName)\n"
            output += String(repeating: "-", count: 40) + "\n"

            if let data = try? JSONEncoder().encode(app),
               let jsonObject = try? JSONSerialization.jsonObject(with: data),
               let dict = jsonObject as? [String: Any] {
                output += formatCompleteJSONString(dict, indent: 1)
            }

            if index < apps.count - 1 {
                output += "\n" + String(repeating: "-", count: 80) + "\n"
            }
        }

        return output
    }

    private func formatTopMinimal(entries: [[String: Any]]) -> String {
        var output = ""

        // Add header for table format
        output += "Rank  App ID      Bundle ID                          Price    Name\n"
        output += String(repeating: "-", count: 80) + "\n"

        for (index, entry) in entries.enumerated() {
            let rank = String(format: "%3d", index + 1)
            let name = (entry["im:name"] as? [String: Any])?["label"] as? String ?? "Unknown"

            let priceInfo = entry["im:price"] as? [String: Any]
            let priceAttributes = priceInfo?["attributes"] as? [String: Any]
            let amount = priceAttributes?["amount"] as? String ?? "0.00"
            let currency = priceAttributes?["currency"] as? String ?? "USD"

            let price = currency == "USD" ? "$\(amount)" : "\(amount) \(currency)"

            let idAttributes = (entry["id"] as? [String: Any])?["attributes"] as? [String: Any]
            let appId = idAttributes?["im:id"] as? String ?? "unknown"
            let bundleId = idAttributes?["im:bundleId"] as? String ?? "unknown"

            // Format with fixed widths for better alignment
            let idStr = appId.padding(toLength: 11, withPad: " ", startingAt: 0)
            let bundleStr = bundleId.padding(toLength: 35, withPad: " ", startingAt: 0)
            let priceStr = price.padding(toLength: 8, withPad: " ", startingAt: 0)

            output += "\(rank).  \(idStr) \(bundleStr) \(priceStr) \(name)\n"
        }

        return output
    }

    private func formatTopSummary(entries: [[String: Any]]) -> String {
        var output = ""

        for (index, entry) in entries.enumerated() {
            let name = (entry["im:name"] as? [String: Any])?["label"] as? String ?? "Unknown"
            let artist = (entry["im:artist"] as? [String: Any])?["label"] as? String ?? "Unknown Developer"

            let priceInfo = entry["im:price"] as? [String: Any]
            let priceAttributes = priceInfo?["attributes"] as? [String: Any]
            let amount = priceAttributes?["amount"] as? String ?? "0.00"
            let currency = priceAttributes?["currency"] as? String ?? "USD"

            let price = currency == "USD" ? "$\(amount)" : "\(amount) \(currency)"

            let category = ((entry["category"] as? [String: Any])?["attributes"] as? [String: Any])?["label"] as? String ?? "Unknown"

            let idAttributes = (entry["id"] as? [String: Any])?["attributes"] as? [String: Any]
            let appId = idAttributes?["im:id"] as? String ?? "Unknown"
            let bundleId = idAttributes?["im:bundleId"] as? String

            output += "\(index + 1). \(name)\n"
            output += "   App ID: \(appId)\n"
            output += "   Developer: \(artist)\n"
            output += "   Price: \(price)\n"
            output += "   Category: \(category)\n"

            if let bundleId = bundleId {
                output += "   Bundle ID: \(bundleId)\n"
            }

            if let summary = (entry["summary"] as? [String: Any])?["label"] as? String {
                let maxLength = 150
                let cleanSummary = summary.replacingOccurrences(of: "\n", with: " ")
                let truncated = cleanSummary.count > maxLength ? String(cleanSummary.prefix(maxLength)) + "..." : cleanSummary
                output += "   Description: \(truncated)\n"
            }

            if index < entries.count - 1 {
                output += String(repeating: "-", count: 80) + "\n"
            }
        }

        return output
    }

    private func formatTopComplete(entries: [[String: Any]]) -> String {
        var output = ""

        for (index, entry) in entries.enumerated() {
            output += "\n[\(index + 1)]\n"
            output += formatCompleteJSONString(entry, indent: 1)
            if index < entries.count - 1 {
                output += String(repeating: "-", count: 80) + "\n"
            }
        }

        return output
    }

    private func formatCompleteJSONString(_ dictionary: [String: Any], indent: Int = 0) -> String {
        var output = ""
        let indentString = String(repeating: "  ", count: indent)

        let sortedKeys = dictionary.keys.sorted()
        for key in sortedKeys {
            guard let value = dictionary[key] else { continue }

            if let dict = value as? [String: Any] {
                output += "\(indentString)\(key):\n"
                output += formatCompleteJSONString(dict, indent: indent + 1)
            } else if let array = value as? [[String: Any]] {
                output += "\(indentString)\(key): [\(array.count) items]\n"
                for (index, item) in array.enumerated() {
                    output += "\(indentString)  [\(index)]:\n"
                    output += formatCompleteJSONString(item, indent: indent + 2)
                }
            } else if let array = value as? [Any] {
                if array.isEmpty {
                    output += "\(indentString)\(key): []\n"
                } else {
                    output += "\(indentString)\(key): \(array.map { String(describing: $0) }.joined(separator: ", "))\n"
                }
            } else {
                output += "\(indentString)\(key): \(value)\n"
            }
        }
        return output
    }
}

class JSONFormatter: OutputFormatter {
    func formatApps(_ apps: [App], options: CommonOptions) -> String {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(["results": apps])
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"Failed to encode JSON: \(error)\"}"
        }
    }

    func formatTopEntries(_ entries: [[String: Any]], title: String, options: CommonOptions) -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: ["feed": ["entry": entries]], options: [.prettyPrinted, .sortedKeys])
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"Failed to encode JSON: \(error)\"}"
        }
    }
}

class MarkdownOutputFormatter: OutputFormatter {
    func formatApps(_ apps: [App], options: CommonOptions) -> String {
        return MarkdownFormatter.formatSearchResults(apps, verbosity: options.verbosity, fullDescription: options.fullDescription)
    }

    func formatTopEntries(_ entries: [[String: Any]], title: String, options: CommonOptions) -> String {
        return MarkdownFormatter.formatTopResults(entries)
    }
}