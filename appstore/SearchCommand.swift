import Foundation

class SearchCommand {
    private let api = AppStoreAPI()

    func execute(options: SearchOptions) async {
        // Handle input file if specified
        if let inputFile = options.inputFile {
            await handleInputFile(inputFile, options: options)
            return
        }
        if options.outputMode != .json && !options.showRequest {
            print("Searching App Store for: \"\(options.query)\"...")
            print()
        }

        let startTime = Date()

        do {
            let result = try await api.searchWithRawData(
                query: options.query,
                limit: options.limit,
                storefront: options.storefront,
                attribute: options.attribute,
                genre: options.genre,
                showRequest: options.showRequest
            )

            let endTime = Date()
            let durationMs = Int(endTime.timeIntervalSince(startTime) * 1000)

            if result.apps.isEmpty && options.outputMode != .json {
                print("No results found for \"\(options.query)\"")
                return
            }

            // Handle output file if specified
            if let outputFile = options.outputFile {
                try await saveToFile(result: result, options: options, durationMs: durationMs, outputFile: outputFile)
                if options.outputMode != .json {
                    print("Results saved to: \(outputFile)")
                }
                return
            }

            // Check if we should use special format (markdown, html, etc)
            if let format = options.outputFormat, format == .markdown {
                let verbosity = options.verbosity ?? .summary
                let markdownOutput = MarkdownFormatter.formatSearchResults(result.apps, verbosity: verbosity, fullDescription: options.fullDescription)
                print(markdownOutput)
            } else {
                switch options.outputMode {
                case .json:
                    // Show JSON output with metadata wrapper
                    let output = createJSONOutput(result: result, options: options, durationMs: durationMs)
                    print(output)
                case .oneline:
                    print("Found \(result.apps.count) result(s):")
                    printOneline(apps: result.apps)
                case .summary:
                    print("Found \(result.apps.count) result(s):")
                    printSummary(apps: result.apps, fullDescription: options.fullDescription)
                case .expanded:
                    print("Found \(result.apps.count) result(s):")
                    printExpanded(apps: result.apps, fullDescription: options.fullDescription)
                case .verbose:
                    print("Found \(result.apps.count) result(s):")
                    printVerbose(apps: result.apps, fullDescription: options.fullDescription)
                case .complete:
                    print("Found \(result.apps.count) result(s):")
                    printComplete(apps: result.apps, rawData: result.rawData)
                }
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

            print("\(app.trackId) \(app.bundleId) \(app.version) \(price) \(rating) \(ratingCount) \(app.trackName)")
        }
    }

    func printSummary(apps: [App], fullDescription: Bool = false) {
        print(String(repeating: "-", count: 80))

        for (index, app) in apps.enumerated() {
            print("\(index + 1). \(app.trackName)")
            print("   App ID: \(app.trackId)")
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

            if fullDescription {
                print("   Description: \(app.description.replacingOccurrences(of: "\n", with: " "))")
            } else if let description = app.description.split(separator: "\n").first {
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

    func printExpanded(apps: [App], fullDescription: Bool = false) {
        print(String(repeating: "-", count: 80))

        for (index, app) in apps.enumerated() {
            print("\(index + 1). \(app.trackName)")
            print("   App ID: \(app.trackId)")
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

            if fullDescription {
                print("   Description: \(app.description.replacingOccurrences(of: "\n", with: " "))")
            } else if let description = app.description.split(separator: "\n").first {
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

    func printVerbose(apps: [App], fullDescription: Bool = false) {
        print(String(repeating: "-", count: 80))

        for (index, app) in apps.enumerated() {
            print("\(index + 1). \(app.trackName)")
            print("   App ID: \(app.trackId)")
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

            if fullDescription {
                print("   Description: \(app.description.replacingOccurrences(of: "\n", with: " "))")
            } else if let description = app.description.split(separator: "\n").first {
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

    // MARK: - File I/O Support

    private func handleInputFile(_ inputFile: String, options: SearchOptions) async {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: inputFile))

            // Try to parse as our metadata wrapper format first
            if let metadata = try? JSONDecoder().decode(AppStoreResponseMetadata.self, from: data) {
                print("Loaded from file: \(inputFile)")
                print("Original command: \(metadata.command)")
                print("Original timestamp: \(metadata.timestamp)")
                print()
            }

            // Extract the actual results
            let jsonObject = try JSONSerialization.jsonObject(with: data)

            // Check if it's wrapped or raw
            var resultsData: Data
            if let wrapped = jsonObject as? [String: Any], let dataObject = wrapped["data"] {
                resultsData = try JSONSerialization.data(withJSONObject: dataObject)
            } else {
                resultsData = data
            }

            // Parse and display
            let searchResult = try JSONDecoder().decode(AppStoreSearchResult.self, from: resultsData)

            switch options.outputMode {
            case .json:
                let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
                if let jsonString = String(data: prettyData, encoding: .utf8) {
                    print(jsonString)
                }
            case .oneline:
                print("Found \(searchResult.results.count) result(s) from file:")
                printOneline(apps: searchResult.results)
            case .summary:
                print("Found \(searchResult.results.count) result(s) from file:")
                printSummary(apps: searchResult.results)
            case .expanded:
                print("Found \(searchResult.results.count) result(s) from file:")
                printExpanded(apps: searchResult.results)
            case .verbose:
                print("Found \(searchResult.results.count) result(s) from file:")
                printVerbose(apps: searchResult.results)
            case .complete:
                print("Found \(searchResult.results.count) result(s) from file:")
                printComplete(apps: searchResult.results, rawData: resultsData)
            }

        } catch {
            print("Error reading input file: \(error)")
        }
    }

    private func saveToFile(result: (apps: [App], rawData: Data), options: SearchOptions, durationMs: Int, outputFile: String) async throws {
        let output: String
        if options.outputMode == .json {
            output = createJSONOutput(result: result, options: options, durationMs: durationMs)
        } else {
            // For non-JSON modes, save as JSON with metadata
            output = createJSONOutput(result: result, options: options, durationMs: durationMs)
        }

        try output.write(toFile: outputFile, atomically: true, encoding: .utf8)
    }

    private func createJSONOutput(result: (apps: [App], rawData: Data), options: SearchOptions, durationMs: Int) -> String {
        do {
            // Parse the raw data
            let jsonObject = try JSONSerialization.jsonObject(with: result.rawData, options: [])

            // Create metadata
            let metadata: [String: Any] = [
                "version": 1,
                "id": UUID().uuidString,
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "command": "search",
                "parameters": [
                    "query": options.query,
                    "limit": options.limit,
                    "storefront": options.storefront as Any,
                    "attribute": options.attribute as Any,
                    "genre": options.genre as Any
                ],
                "request": [
                    "url": "https://itunes.apple.com/search",
                    "method": "GET"
                ],
                "response": [
                    "httpStatus": 200,
                    "timestamp": ISO8601DateFormatter().string(from: Date()),
                    "durationMs": durationMs,
                    "resultCount": result.apps.count
                ]
            ]

            // Wrap the data
            let wrapped: [String: Any] = [
                "metadata": metadata,
                "data": jsonObject
            ]

            let prettyData = try JSONSerialization.data(withJSONObject: wrapped, options: [.prettyPrinted, .sortedKeys])
            return String(data: prettyData, encoding: .utf8) ?? "{}"

        } catch {
            return "{\"error\": \"Failed to create JSON output: \(error)\"}"
        }
    }
}

