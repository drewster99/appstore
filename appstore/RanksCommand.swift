import Foundation

struct RanksCommand {
    func execute(options: RanksOptions) async {
        print("Fetching app details for ID: \(options.appId)...")

        let api = AppStoreAPI()

        do {
            let lookupResult = try await api.lookupWithRawData(
                lookupType: .id(options.appId),
                storefront: options.commonOptions.storefront,
                language: options.commonOptions.language
            )

            guard let app = lookupResult.apps.first else {
                print("Error: No app found with ID \(options.appId)")
                return
            }

            print("Analyzing app: \(app.trackName)")
            print()

            // Generate keywords from app data
            print("Generating keywords...")
            let keywords = generateKeywords(from: app, limit: options.limit)

            print("Found \(keywords.count) keywords to test:")
            for (index, keyword) in keywords.enumerated() {
                print("  \(index + 1). \(keyword)")
            }
            print()

            // Analyze rankings for each keyword
            print("Analyzing rankings...")
            print()

            for (index, keyword) in keywords.enumerated() {
                print("[\(index + 1)/\(keywords.count)] Searching for '\(keyword)'...")

                do {
                    let searchResult = try await api.searchWithRawData(
                        query: keyword,
                        limit: 200,
                        storefront: options.commonOptions.storefront,
                        attribute: nil,
                        genre: nil,
                        language: options.commonOptions.language
                    )

                    // Find the app's rank
                    let rank = findAppRank(appId: options.appId, in: searchResult.apps)

                    // Print results for this keyword
                    printKeywordAnalysis(
                        keyword: keyword,
                        rank: rank,
                        results: searchResult.apps,
                        verbosity: options.commonOptions.verbosity
                    )

                    // Rate limiting delay between searches
                    if index < keywords.count - 1 {
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                    }

                } catch {
                    print("  Error searching for '\(keyword)': \(error.localizedDescription)")
                }
            }

            print()
            print("Analysis complete!")

        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }

    private func findAppRank(appId: String, in results: [App]) -> Int? {
        for (index, app) in results.enumerated() {
            if app.trackId == Int(appId) {
                return index + 1 // Rank is 1-based
            }
        }
        return nil
    }

    private func printKeywordAnalysis(
        keyword: String,
        rank: Int?,
        results: [App],
        verbosity: Verbosity
    ) {
        print()
        print("Keyword: '\(keyword)'")
        print("───────────────────")

        if let rank = rank {
            print("✅ Your app ranks #\(rank) for this keyword")
        } else {
            print("❌ Your app is not in the top 200 for this keyword")
        }

        // Show top competitors
        let topCount = verbosity == .minimal ? 3 : (verbosity == .summary ? 5 : 10)
        let competitors = Array(results.prefix(topCount))

        if !competitors.isEmpty {
            print()
            print("Top competitors:")
            for (index, app) in competitors.enumerated() {
                let ratingStr = String(format: "%.1f", app.averageUserRating ?? 0.0)
                print("  \(index + 1). \(app.trackName)")

                if verbosity != .minimal {
                    print("     Developer: \(app.sellerName)")
                    let ratingCount = app.userRatingCount ?? 0
                    print("     Rating: \(ratingStr) ⭐ (\(ratingCount) reviews)")

                    if verbosity == .expanded || verbosity == .verbose || verbosity == .complete {
                        print("     Price: \(app.formattedPrice ?? "Free")")
                    }
                }
            }
        }

        // Show apps with most reviews (if different from top ranking)
        if verbosity != .minimal {
            let sortedByReviews = results.sorted { ($0.userRatingCount ?? 0) > ($1.userRatingCount ?? 0) }
            let topReviewedCount = verbosity == .summary ? 3 : 5
            let topReviewed = Array(sortedByReviews.prefix(topReviewedCount))

            print()
            print("Apps with most reviews:")
            for app in topReviewed {
                let ratingCount = app.userRatingCount ?? 0
                print("  • \(app.trackName): \(ratingCount) reviews")
            }
        }

        print()
    }

    private func generateKeywords(from app: App, limit: Int) -> [String] {
        var keywords: [String] = []

        // 1. Extract from app name
        let titleWords = app.trackName
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 2 }

        keywords.append(contentsOf: titleWords)

        // 2. Add genre
        keywords.append(app.primaryGenreName.lowercased())

        // Remove duplicates and return
        let unique = Array(Set(keywords))
        return Array(unique.prefix(limit))
    }
}