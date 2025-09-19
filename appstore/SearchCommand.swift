import Foundation

class SearchCommand {
    private let api = AppStoreAPI()

    func execute(options: SearchOptions) async {
        if options.outputMode != .json && !options.showRequest {
            print("Searching App Store for: \"\(options.query)\"...")
            print()
        }

        do {
            let result = try await api.searchWithRawData(
                query: options.query,
                limit: options.limit,
                storefront: options.storefront,
                attribute: options.attribute,
                genre: options.genre,
                showRequest: options.showRequest
            )

            if result.apps.isEmpty {
                print("No results found for \"\(options.query)\"")
                return
            }

            switch options.outputMode {
            case .json:
                // Show JSON output
                let jsonObject = try JSONSerialization.jsonObject(with: result.rawData, options: [])
                let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])

                if let jsonString = String(data: prettyData, encoding: .utf8) {
                    print(jsonString)
                }
            case .oneline:
                print("Found \(result.apps.count) result(s):")
                printOneline(apps: result.apps)
            case .summary:
                print("Found \(result.apps.count) result(s):")
                printSummary(apps: result.apps)
            case .expanded:
                print("Found \(result.apps.count) result(s):")
                printExpanded(apps: result.apps)
            case .verbose:
                print("Found \(result.apps.count) result(s):")
                printVerbose(apps: result.apps)
            case .complete:
                print("Found \(result.apps.count) result(s):")
                printComplete(apps: result.apps, rawData: result.rawData)
            }

        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }

    func printOneline(apps: [App]) {
        for app in apps {
            let rating = app.averageUserRating.map { String(format: "%.1f", $0) } ?? "N/A"
            let ratingCount = app.userRatingCount.map { String($0) } ?? "0"
            let price = app.formattedPrice ?? "Free"

            print("\(app.bundleId) \(app.version) \(price) \(rating) \(ratingCount) \(app.trackName)")
        }
    }

    func printSummary(apps: [App]) {
        print(String(repeating: "-", count: 80))

        for (index, app) in apps.enumerated() {
            print("\(index + 1). \(app.trackName)")
            print("   Developer: \(app.artistName)")
            print("   Price: \(app.formattedPrice ?? "Free")")

            if let rating = app.averageUserRating,
               let ratingCount = app.userRatingCount {
                let stars = FormatUtils.formatRatingStars(rating)
                print("   Rating: \(stars) \(String(format: "%.1f", rating)) (\(FormatUtils.formatNumber(ratingCount)) ratings)")
            }

            print("   Category: \(app.primaryGenreName)")
            print("   Version: \(app.version)")
            print("   Bundle ID: \(app.bundleId)")

            if let description = app.description.split(separator: "\n").first {
                let maxLength = 150
                let truncated = description.count > maxLength ? String(description.prefix(maxLength)) + "..." : String(description)
                print("   Description: \(truncated)")
            }

            if index < apps.count - 1 {
                print(String(repeating: "-", count: 80))
            }
        }

        print(String(repeating: "=", count: 80))
    }

    func printExpanded(apps: [App]) {
        print(String(repeating: "-", count: 80))

        for (index, app) in apps.enumerated() {
            print("\(index + 1). \(app.trackName)")
            print("   Developer: \(app.artistName)")
            print("   Price: \(app.formattedPrice ?? "Free")")

            if let rating = app.averageUserRating,
               let ratingCount = app.userRatingCount {
                let stars = FormatUtils.formatRatingStars(rating)
                print("   Rating: \(stars) \(String(format: "%.1f", rating)) (\(FormatUtils.formatNumber(ratingCount)) ratings)")
            }

            print("   Category: \(app.primaryGenreName)")
            print("   Version: \(app.version)")
            print("   Bundle ID: \(app.bundleId)")

            // Additional expanded fields
            if let contentRating = app.contentAdvisoryRating {
                print("   Content Rating: \(contentRating)")
            }

            if let releaseDate = app.currentVersionReleaseDate {
                print("   Current Version Release: \(FormatUtils.formatDate(releaseDate))")
            }

            print("   Minimum OS: \(app.minimumOsVersion)")
            print("   Size: \(FormatUtils.formatFileSize(app.fileSizeBytes))")

            if let releaseNotes = app.releaseNotes {
                let maxLength = 200
                let truncated = releaseNotes.count > maxLength ? String(releaseNotes.prefix(maxLength)) + "..." : releaseNotes
                print("   What's New: \(truncated.replacingOccurrences(of: "\n", with: " "))")
            }

            if let advisories = app.advisories, !advisories.isEmpty {
                print("   Advisories:")
                for advisory in advisories {
                    print("     • \(advisory)")
                }
            }

            if let description = app.description.split(separator: "\n").first {
                let maxLength = 150
                let truncated = description.count > maxLength ? String(description.prefix(maxLength)) + "..." : String(description)
                print("   Description: \(truncated)")
            }

            if index < apps.count - 1 {
                print(String(repeating: "-", count: 80))
            }
        }

        print(String(repeating: "=", count: 80))
    }

    func printVerbose(apps: [App]) {
        print(String(repeating: "-", count: 80))

        for (index, app) in apps.enumerated() {
            print("\(index + 1). \(app.trackName)")
            print("   Developer: \(app.artistName)")

            let priceInfo = if let currency = app.currency {
                "\(app.formattedPrice ?? "Free") (\(currency))"
            } else {
                app.formattedPrice ?? "Free"
            }
            print("   Price: \(priceInfo)")

            if let rating = app.averageUserRating,
               let ratingCount = app.userRatingCount {
                let stars = FormatUtils.formatRatingStars(rating)
                print("   Rating: \(stars) \(String(format: "%.1f", rating)) (\(FormatUtils.formatNumber(ratingCount)) ratings)")
            }

            print("   Category: \(app.primaryGenreName)")
            print("   Version: \(app.version)")
            print("   Bundle ID: \(app.bundleId)")

            // Expanded fields
            if let contentRating = app.contentAdvisoryRating {
                print("   Content Rating: \(contentRating)")
            }

            if let currentRelease = app.currentVersionReleaseDate {
                print("   Current Version Release: \(FormatUtils.formatDate(currentRelease))")
            }

            if let originalRelease = app.releaseDate {
                print("   Original Release: \(FormatUtils.formatDate(originalRelease))")
            }

            print("   Minimum OS: \(app.minimumOsVersion)")
            print("   Size: \(FormatUtils.formatFileSize(app.fileSizeBytes))")

            if let releaseNotes = app.releaseNotes {
                let maxLength = 250
                let truncated = releaseNotes.count > maxLength ? String(releaseNotes.prefix(maxLength)) + "..." : releaseNotes
                print("   What's New: \(truncated.replacingOccurrences(of: "\n", with: " "))")
            }

            // Verbose-specific fields
            if let trackUrl = app.trackViewUrl {
                print("   App Store URL: \(trackUrl)")
            }

            if let artistUrl = app.artistViewUrl {
                print("   Developer URL: \(artistUrl)")
            }

            if let artworkUrl = app.artworkUrl512 {
                print("   Artwork URL: \(artworkUrl)")
            }

            print("   Languages: \(FormatUtils.formatLanguages(app.languageCodesISO2A))")

            if let features = app.features, !features.isEmpty {
                print("   Features: \(features.joined(separator: ", "))")
            }

            print("   Game Center Enabled: \(app.isGameCenterEnabled == true ? "Yes" : "No")")

            if let advisories = app.advisories, !advisories.isEmpty {
                print("   Advisories:")
                for advisory in advisories {
                    print("     • \(advisory)")
                }
            }

            if let description = app.description.split(separator: "\n").first {
                let maxLength = 200
                let truncated = description.count > maxLength ? String(description.prefix(maxLength)) + "..." : String(description)
                print("   Description: \(truncated)")
            }

            if index < apps.count - 1 {
                print(String(repeating: "-", count: 80))
            }
        }

        print(String(repeating: "=", count: 80))
    }

    func printComplete(apps: [App], rawData: Data) {
        do {
            guard let jsonObject = try JSONSerialization.jsonObject(with: rawData, options: []) as? [String: Any],
                  let results = jsonObject["results"] as? [[String: Any]] else {
                print("Error parsing JSON data")
                return
            }

            print(String(repeating: "-", count: 80))

            for (index, appDict) in results.enumerated() {
                if index < apps.count {
                    print("\n[\(index + 1)] \(apps[index].trackName)")
                    print(String(repeating: "-", count: 40))
                    FormatUtils.printCompleteJSON(appDict, indent: 1)
                }

                if index < results.count - 1 {
                    print("\n" + String(repeating: "-", count: 80))
                }
            }

            print("\n" + String(repeating: "=", count: 80))

        } catch {
            print("Error processing complete output: \(error)")
        }
    }
}

