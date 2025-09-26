import Foundation
import FoundationModels

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

    // Structure for AI-generated keywords using FoundationModels
    @Generable(description: "Keywords that users might enter as a search string for when looking for an this app or an app with similar functionality")
    struct Keywords {
        @Guide(description: "Each keyword must be one that a user might enter as a search string when looking for this app or an app with similar functionality. The array should include 12 entries")
        var simpleKeywords: [String]

        @Guide(description: "Keyword phrases. A keyword phrase is 2 or more keywords separated by whitespace. The array should include 12 entries")
        var keywordPhrases: [String]
    }

    func execute(options: RanksOptions) async {
        // For non-text formats, suppress initial output
        let shouldPrintProgress = options.commonOptions.outputFormat == .text

        if shouldPrintProgress {
            print("Fetching app details for ID: \(options.appId)...")
        }

        do {
            // First lookup the app to get its details for keyword generation
            let appDetails = try await AppStoreAPI.lookupAppDetails(
                appIds: [options.appId],
                storefront: options.commonOptions.storefront,
                language: options.commonOptions.language
            )

            guard let app = appDetails.first else {
                if options.commonOptions.outputFormat == .text {
                    print("Error: No app found with ID \(options.appId)")
                } else {
                    // For other formats, output structured error
                    outputError("No app found with ID \(options.appId)", format: options.commonOptions.outputFormat)
                }
                return
            }

            if shouldPrintProgress {
                print("Analyzing app: \(app.trackName)")
                print()
            }

            // Generate keywords from app data
            if shouldPrintProgress {
                print("Generating keywords...")
            }
            let keywords = await generateKeywords(from: app, limit: options.limit, debugOutput: shouldPrintProgress)

            if shouldPrintProgress {
                print("\nComplete list of \(keywords.count) keywords to test:")
                for (index, keyword) in keywords.enumerated() {
                    print("  \(index + 1). \(keyword)")
                }
                print()
            }

            // Analyze rankings for each keyword
            if shouldPrintProgress && options.commonOptions.verbosity != .minimal {
                print("Analyzing rankings...")
                print()
            }

            // Collect all results for minimal verbosity sorting
            var rankings: [KeywordRanking] = []

            for (index, keyword) in keywords.enumerated() {
                if shouldPrintProgress && options.commonOptions.verbosity != .minimal {
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
                    if shouldPrintProgress && options.commonOptions.verbosity != .minimal {
                        print("  Error searching for '\(keyword)': \(error.localizedDescription)")
                    }
                }
            }

            // Output results based on format
            switch options.commonOptions.outputFormat {
            case .text:
                // For minimal verbosity, print sorted table
                if options.commonOptions.verbosity == .minimal {
                    printMinimalRankingsTable(rankings)
                }
                print()
                print("Analysis complete!")
            case .markdown:
                outputMarkdownResults(app: app, keywords: keywords, rankings: rankings, verbosity: options.commonOptions.verbosity)
            case .json, .rawJson:
                outputJSONResults(app: app, keywords: keywords, rankings: rankings, format: options.commonOptions.outputFormat)
            case .html, .htmlOpen:
                // TODO: Implement HTML output
                print("HTML output not yet implemented for ranks command")
            }

        } catch {
            if options.commonOptions.outputFormat == .text {
                print("Error: \(error.localizedDescription)")
            } else {
                outputError(error.localizedDescription, format: options.commonOptions.outputFormat)
            }
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

    private func generateKeywords(from app: App, limit: Int?, debugOutput: Bool = false) async -> [String] {
        // Flag to control whether to include description words
        let includeDescriptionWords = false  // Set to true to include first 5 words from description

        // Step 1: Create a set for base keywords
        var baseKeywords: Set<String> = []

        // Get title words
        let title = app.trackName
        let titleLower = title.lowercased()
        let titleWords = titleLower.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // Add title words to base keywords
        for word in titleWords {
            baseKeywords.insert(word)
        }

        // Step 2: Get first 5 words from description (controlled by flag)
        if includeDescriptionWords {
            let descriptionLower = app.description.lowercased()
            let descriptionWords = descriptionLower.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .prefix(5)

            // Add description words to base keywords
            for word in descriptionWords {
                baseKeywords.insert(word)
            }
        }

        // Step 3: For words with punctuation, add stripped versions
        for word in baseKeywords {
            if word.rangeOfCharacter(from: .punctuationCharacters) != nil {
                let stripped = stripPunctuation(from: word)
                if !stripped.isEmpty {
                    baseKeywords.insert(stripped)
                }
            }
        }

        // Debug: Print base keywords count
        // print("DEBUG: Base keywords count: \(baseKeywords.count)")

        // Step 4: Generate search terms list
        var searchTerms: Set<String> = []

        // Add full app title as first search term
        searchTerms.insert(titleLower)

        // Add all individual keywords
        for keyword in baseKeywords {
            searchTerms.insert(keyword)
        }

        // Add ALL 2-word permutations from our base keywords (both orders)
        let allWords = Array(baseKeywords)
        if allWords.count > 1 {
            for i in 0..<allWords.count {
                for j in 0..<allWords.count {
                    if i != j {  // Don't pair a word with itself
                        let twoWordCombo = "\(allWords[i]) \(allWords[j])"
                        searchTerms.insert(twoWordCombo)
                    }
                }
            }
        }

        if debugOutput {
            print("\n[DEBUG] Title-based keywords (\(searchTerms.count) total):")
            print("  Full title: \"\(titleLower)\"")
            print("  Individual words: \(baseKeywords.sorted().joined(separator: ", "))")
            print("  2-word permutations: \(searchTerms.count - baseKeywords.count - 1) generated")
        }

        // Step 5: Use FoundationModels if available
        let modelAvailable = await isLanguageModelAvailable()
        // print("DEBUG: Language model available: \(modelAvailable)")
        if modelAvailable {
            if let aiKeywords = await generateAIKeywords(app: app) {
                // print("DEBUG: Got AI keywords - simple: \(aiKeywords.simpleKeywords.count), phrases: \(aiKeywords.keywordPhrases.count)")

                if debugOutput {
                    print("\n[DEBUG] AI-generated simple keywords (\(aiKeywords.simpleKeywords.count)):")
                    for keyword in aiKeywords.simpleKeywords {
                        print("  - \(keyword.lowercased())")
                    }

                    print("\n[DEBUG] AI-generated keyword phrases (\(aiKeywords.keywordPhrases.count)):")
                    for phrase in aiKeywords.keywordPhrases {
                        print("  - \(phrase.lowercased())")
                    }
                }

                // Add simple keywords
                for keyword in aiKeywords.simpleKeywords {
                    searchTerms.insert(keyword.lowercased())
                }
                // Add keyword phrases
                for phrase in aiKeywords.keywordPhrases {
                    searchTerms.insert(phrase.lowercased())
                }
            } else {
                if debugOutput {
                    print("\n[DEBUG] AI keyword generation failed or returned nil")
                }
            }
        } else {
            if debugOutput {
                print("\n[DEBUG] Language model not available")
            }
        }

        // Step 6: Convert to array and limit (no sorting to preserve order showing source)
        let allTerms = Array(searchTerms)

        // Return limited to requested count or all if no limit
        if let limit = limit {
            return Array(allTerms.prefix(limit))
        } else {
            return allTerms
        }
    }

    private func stripPunctuation(from word: String) -> String {
        return word.components(separatedBy: .punctuationCharacters).joined()
    }

    private func isLanguageModelAvailable() async -> Bool {
        
        let systemLanguageModel = SystemLanguageModel.default
        
        // Handle the case where the model is unavailable, e.g., display an alert
        // You can inspect systemLanguageModel.availability for the reason
        switch systemLanguageModel.availability {
        case .available:
            print("Foundation Model is available.")
            return true
        case .unavailable(let reason):
            print("Foundation Model is NOT available.")
            switch reason {
            case .deviceNotEligible:
                print("Reason: Device is not eligible to run the model.")
            case .appleIntelligenceNotEnabled:
                print("Reason: Apple Intelligence is not enabled.")
            case .modelNotReady:
                print("Reason: Model not ready.")
            @unknown default:
                print("@unknown reason")
            }
            return false
        }
    }
    
    private func generateAIKeywords(app: App) async -> Keywords? {
        do {
            let session = LanguageModelSession()

            // Use exact prompt from playground file with app's actual data
            let prompt = """
            Below are the title and description of an App on the App Store. Generate two lists of keywords that a user would be likely to type when they were looking for an app like the one described. One list will be simple keywords, where each entry in the array is a single word (not a phrase), and a second list will be keyword phrases (two or more whitespace-separated keywords to be used together as a single search term). Include 12 keywords in each array. Remember to consider synonyms and common misspellings, and remember that every response should be something a person is likely to type on their phone into a search field.

            App title:
            \(app.trackName)

            App description:
            \(app.description)
            """

            let response = try await session.respond(to: prompt, generating: Keywords.self)
            return response.content
        } catch {
            // If AI generation fails, return nil to fallback to traditional keywords
            return nil
        }
    }

    private func outputError(_ message: String, format: OutputFormat) {
        switch format {
        case .json, .rawJson:
            let errorObj = ["error": message]
            if let jsonData = try? JSONSerialization.data(withJSONObject: errorObj, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        case .markdown:
            print("# Error\n\n\(message)")
        default:
            print("Error: \(message)")
        }
    }

    private func outputMarkdownResults(app: App, keywords: [String], rankings: [KeywordRanking], verbosity: Verbosity) {
        var output = ""

        // Header
        output += "# Keyword Ranking Analysis\n\n"
        output += "## App: \(app.trackName)\n\n"
        output += "- **App ID**: `\(app.trackId)`\n"
        output += "- **Bundle ID**: `\(app.bundleId)`\n"
        output += "- **Developer**: \(app.sellerName)\n\n"

        // Keywords tested
        output += "## Keywords Tested\n\n"
        output += "Analyzed **\(keywords.count)** keywords:\n\n"
        for (index, keyword) in keywords.enumerated() {
            output += "\(index + 1). `\(keyword)`\n"
        }
        output += "\n"

        // Results table
        output += "## Ranking Results\n\n"

        // Sort rankings
        let sorted = rankings.sorted { lhs, rhs in
            switch (lhs.rank, rhs.rank) {
            case (let l?, let r?):
                if l == r {
                    return lhs.keyword < rhs.keyword
                }
                return l < r
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.keyword < rhs.keyword
            }
        }

        // Create table
        output += "| Rank | Total Results | Keyword |\n"
        output += "|------|---------------|----------|\n"

        for ranking in sorted {
            let rankStr = ranking.rank.map { String($0) } ?? "-"
            output += "| \(rankStr) | \(ranking.totalResults) | `\(ranking.keyword)` |\n"
        }

        output += "\n"

        // Summary statistics
        let rankedKeywords = rankings.filter { $0.rank != nil }
        if !rankedKeywords.isEmpty {
            output += "## Summary\n\n"
            output += "- **Keywords with rankings**: \(rankedKeywords.count) / \(keywords.count)\n"
            if let bestRank = rankedKeywords.compactMap({ $0.rank }).min() {
                let bestKeyword = rankedKeywords.first { $0.rank == bestRank }?.keyword ?? ""
                output += "- **Best ranking**: #\(bestRank) for `\(bestKeyword)`\n"
            }
            let avgRank = rankedKeywords.compactMap { $0.rank }.reduce(0, +) / rankedKeywords.count
            output += "- **Average rank**: #\(avgRank)\n"
        }

        print(output)
    }

    private func outputJSONResults(app: App, keywords: [String], rankings: [KeywordRanking], format: OutputFormat) {
        var results: [[String: Any]] = []

        for ranking in rankings {
            var result: [String: Any] = [
                "keyword": ranking.keyword,
                "totalResults": ranking.totalResults
            ]
            if let rank = ranking.rank {
                result["rank"] = rank
            }
            results.append(result)
        }

        let output: [String: Any] = [
            "appId": app.trackId,
            "appName": app.trackName,
            "bundleId": app.bundleId,
            "developer": app.sellerName,
            "keywordsTested": keywords.count,
            "results": results
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        } catch {
            print("{\"error\": \"Failed to encode JSON: \(error.localizedDescription)\"}")
        }
    }
}
