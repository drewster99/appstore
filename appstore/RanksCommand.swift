import Foundation

struct RanksCommand {
    // IMPORTANT: This command uses the MZStore API (via ScrapeCommand.fetchRankedAppIds)
    // to get CORRECT rankings that match the App Store app.
    // It does NOT use the iTunes Search API which has different/incorrect rankings.
    // After getting the rank, it enriches with iTunes Lookup API for consistent data format.
    // See CLAUDE.md for architecture details.

    // Structure to hold ranking results for minimal verbosity output
    struct KeywordRanking {
        let keyword: String
        let rank: Int?
        let totalResults: Int
    }

    func execute(options: RanksOptions) async {
        print("Fetching app details for ID: \(options.appId)...")

        do {
            // First lookup the app to get its details for keyword generation
            let appDetails = try await AppStoreAPI.lookupAppDetails(
                appIds: [options.appId],
                storefront: options.commonOptions.storefront,
                language: options.commonOptions.language
            )

            guard let app = appDetails.first else {
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
            if options.commonOptions.verbosity != .minimal {
                print("Analyzing rankings...")
                print()
            }

            // Collect all results for minimal verbosity sorting
            var rankings: [KeywordRanking] = []

            for (index, keyword) in keywords.enumerated() {
                if options.commonOptions.verbosity != .minimal {
                    print("[\(index + 1)/\(keywords.count)] Searching for '\(keyword)'...")
                }

                do {
                    // Use MZStore API to get CORRECT rankings (same as App Store app)
                    let rankedAppIds = try await ScrapeCommand.fetchRankedAppIds(
                        term: keyword,
                        storefront: options.commonOptions.storefront ?? "US",
                        language: options.commonOptions.language,
                        limit: 200,
                        showRequest: options.commonOptions.showRequest
                    )

                    // Find the app's rank by its position in the ranked array
                    var rank: Int? = nil
                    for (idx, appId) in rankedAppIds.enumerated() {
                        if appId == options.appId {
                            rank = idx + 1  // Rank is 1-based
                            break
                        }
                    }

                    // Store ranking for minimal verbosity
                    if options.commonOptions.verbosity == .minimal {
                        rankings.append(KeywordRanking(
                            keyword: keyword,
                            rank: rank,
                            totalResults: rankedAppIds.count
                        ))
                    } else {
                        // Get full details for all apps to display
                        let topAppIds = rankedAppIds

                        var topApps: [App] = []
                        if !topAppIds.isEmpty {
                            topApps = try await AppStoreAPI.lookupAppDetails(
                                appIds: topAppIds,
                                storefront: options.commonOptions.storefront,
                                language: options.commonOptions.language
                            )
                        }

                        // Print results for this keyword
                        printKeywordAnalysis(
                            keyword: keyword,
                            rank: rank,
                            results: topApps,
                            verbosity: options.commonOptions.verbosity
                        )
                    }

                    // Rate limiting delay between searches
                    if index < keywords.count - 1 {
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                    }

                } catch {
                    if options.commonOptions.verbosity != .minimal {
                        print("  Error searching for '\(keyword)': \(error.localizedDescription)")
                    }
                }
            }

            // For minimal verbosity, print sorted table
            if options.commonOptions.verbosity == .minimal {
                printMinimalRankingsTable(rankings)
            }

            print()
            print("Analysis complete!")

        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }

    private func printMinimalRankingsTable(_ rankings: [KeywordRanking]) {
        // Sort by rank (nil ranks go last), then alphabetically
        let sorted = rankings.sorted { lhs, rhs in
            switch (lhs.rank, rhs.rank) {
            case (let l?, let r?):
                // Both have ranks, sort by rank then keyword
                if l == r {
                    return lhs.keyword < rhs.keyword
                }
                return l < r
            case (_?, nil):
                // lhs has rank, rhs doesn't
                return true
            case (nil, _?):
                // rhs has rank, lhs doesn't
                return false
            case (nil, nil):
                // Neither have ranks, sort alphabetically
                return lhs.keyword < rhs.keyword
            }
        }

        // Print header
        print()
        print("Rank    #Results     Keyword searched")

        // Print each result
        for ranking in sorted {
            let rankStr = ranking.rank.map { String(format: "%4d", $0) } ?? "   -"
            let resultsStr = String(format: "%3d", ranking.totalResults)
            print("\(rankStr)    \(resultsStr)          ``\(ranking.keyword)’’")
        }
    }

    private func printKeywordAnalysis(
        keyword: String,
        rank: Int?,
        results: [App],
        verbosity: Verbosity
    ) {
        // Minimal is now handled by printMinimalRankingsTable
        if verbosity == .minimal {
            return
        }

        // Summary and above: Full format
        print()
        print("Keyword: '\(keyword)'")
        print("───────────────────")

        if let rank = rank {
            print("✅ Your app ranks #\(rank) for this keyword")
        } else {
            print("❌ Your app is not in the top 200 for this keyword")
        }

        // Determine how many competitors to show based on verbosity
        let competitorLimit: Int?
        switch verbosity {
        case .minimal:
            competitorLimit = 0  // Already handled above
        case .summary:
            competitorLimit = 5
        case .expanded:
            competitorLimit = 10
        case .verbose:
            competitorLimit = 25
        case .complete:
            competitorLimit = nil  // Show all
        }

        let competitors = competitorLimit != nil ? Array(results.prefix(competitorLimit!)) : results

        if !competitors.isEmpty {
            print()
            print("Top competitors:")
            for (index, app) in competitors.enumerated() {
                let ratingStr = String(format: "%.1f", app.averageUserRating ?? 0.0)
                print("  \(index + 1). \(app.trackName)")

                if verbosity != .summary {
                    print("     Developer: \(app.sellerName)")
                    let ratingCount = app.userRatingCount ?? 0
                    print("     Rating: \(ratingStr) ⭐ (\(ratingCount) reviews)")

                    if verbosity == .expanded || verbosity == .verbose || verbosity == .complete {
                        print("     Price: \(app.formattedPrice ?? "Free")")
                    }
                }
            }
        }

        // Show apps with most reviews
        if verbosity != .minimal {
            let sortedByReviews = results.sorted { ($0.userRatingCount ?? 0) > ($1.userRatingCount ?? 0) }

            // Determine how many to show based on verbosity
            let reviewLimit: Int?
            switch verbosity {
            case .minimal:
                reviewLimit = 0  // Already handled
            case .summary:
                reviewLimit = 3
            case .expanded:
                reviewLimit = 5
            case .verbose:
                reviewLimit = 10
            case .complete:
                reviewLimit = nil  // Show all
            }

            let topReviewed = reviewLimit != nil ? Array(sortedByReviews.prefix(reviewLimit!)) : sortedByReviews

            if !topReviewed.isEmpty {
                print()
                print("Apps with most reviews:")
                for app in topReviewed {
                    let ratingCount = app.userRatingCount ?? 0
                    print("  • \(app.trackName): \(ratingCount) reviews")
                }
            }
        }

        print()
    }

    private func generateKeywords(from app: App, limit: Int) -> [String] {
        var keywords: Set<String> = []

        let title = app.trackName
        let titleLower = title.lowercased()

        // 1. Add the full app title
        keywords.insert(titleLower)

        // 2. Split by whitespace to get all words (keeping punctuation)
        let words = titleLower.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // 3. Add each individual word
        for word in words {
            keywords.insert(word)
        }

        // 4. Add every two-word combination
        if words.count > 1 {
            for i in 0..<words.count-1 {
                let twoWordCombo = "\(words[i]) \(words[i+1])"
                keywords.insert(twoWordCombo)
            }
        }

        // 5. Add genre
        keywords.insert(app.primaryGenreName.lowercased())

        // Return as array, limited to requested count
        return Array(keywords.prefix(limit))
    }
}
