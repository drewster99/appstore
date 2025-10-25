import Foundation

struct AnalyzeOptions {
    let term: String
    let storefront: String
    let language: String
    let showRequest: Bool
    let commonOptions: CommonOptions

    init(term: String, commonOptions: CommonOptions) {
        self.term = term
        self.storefront = commonOptions.storefront ?? "US"
        self.language = commonOptions.language
        self.showRequest = commonOptions.showRequest
        self.commonOptions = commonOptions
    }
}

struct AnalyzeCommand {
    private static let filterWords = Set([
        "a", "an", "the", "and", "or", "but", "&",
        "for", "with", "of", "in", "on", "at", "to", "from", "by"
    ])

    func execute(options: AnalyzeOptions) async {
        do {
            // Generate unique ID for this search
            let searchId = UUID().uuidString
            let startTime = Date()

            // Step 1: Get ranked app IDs from MZStore API (using existing scrape functionality)
            let appIds = try await ScrapeCommand.fetchRankedAppIds(
                term: options.term,
                storefront: options.storefront,
                language: options.language,
                limit: 20,
                showRequest: options.showRequest
            )

            if appIds.isEmpty {
                print("No results found")
                return
            }

            // Step 2: Enrich with full details from iTunes Lookup API
            let apps = try await AppStoreAPI.lookupAppDetails(
                appIds: appIds,
                storefront: options.storefront,
                language: options.language
            )

            let endTime = Date()
            let durationMs = Int(endTime.timeIntervalSince(startTime) * 1000)

            // Step 3: Generate word variants for matching
            let searchWords = options.term.lowercased().split(separator: " ").map(String.init)
            let wordVariants = searchWords.map { generateWordVariants($0) }

            // Debug output: show word variants
            print("Search term: \"\(options.term)\"")
            print("Word variants being matched:")
            for (word, variants) in zip(searchWords, wordVariants) {
                print("  \"\(word)\" → [\(variants.joined(separator: ", "))]")
            }
            print()

            // Step 4: Analyze each app and calculate scores
            let analyzedApps = apps.prefix(20).map { app in
                analyzeApp(app, searchTerm: options.term, searchWords: searchWords, wordVariants: wordVariants)
            }

            // Step 5: Calculate summary statistics
            let summary = calculateSummary(analyzedApps: analyzedApps)

            // Step 6: Output CSV with header
            outputCSV(analyzedApps: analyzedApps, summary: summary, durationMs: durationMs)

            // Step 7: Save to database
            do {
                try saveToDatabase(
                    searchId: searchId,
                    options: options,
                    timestamp: startTime,
                    durationMs: durationMs,
                    analyzedApps: analyzedApps,
                    summary: summary
                )
                print()
                print("Saved to database: \(searchId)")
            } catch {
                print("Warning: Failed to save to database: \(error.localizedDescription)")
            }

        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }

    private func generateWordVariants(_ word: String) -> [String] {
        var variants = [word]

        // Add 's'
        variants.append(word + "s")

        // Add 'es'
        variants.append(word + "es")

        // Replace 'y' with 'ies' if ends in consonant+y
        if word.hasSuffix("y") && word.count > 1 {
            let beforeY = word.dropLast()
            let lastChar = beforeY.last
            // Check if it's a consonant (not a vowel)
            if let char = lastChar, !"aeiou".contains(char) {
                variants.append(String(beforeY) + "ies")
            }
        }

        // Add 'ing'
        variants.append(word + "ing")

        // If ends with 'e', also try dropping 'e' and adding 'ing'
        if word.hasSuffix("e") && word.count > 1 {
            variants.append(String(word.dropLast()) + "ing")
        }

        // Add 'ed'
        variants.append(word + "ed")

        // If ends with 'e', also try dropping 'e' and adding 'ed'
        if word.hasSuffix("e") && word.count > 1 {
            variants.append(String(word.dropLast()) + "ed")
        }

        return variants
    }

    private func removeFilterWords(_ text: String) -> String {
        let words = text.lowercased().split(separator: " ").map(String.init)
        let filtered = words.filter { !Self.filterWords.contains($0) }
        return filtered.joined(separator: " ")
    }

    private func analyzeApp(_ app: App, searchTerm: String, searchWords: [String], wordVariants: [[String]]) -> AnalyzedApp {
        let title = app.trackName.lowercased()
        let description = app.description.lowercased()
        let searchTermLower = searchTerm.lowercased()

        // Check for exact match in title (original and filtered)
        let titleFiltered = removeFilterWords(title)
        let isExactMatchInTitle = title.contains(searchTermLower) || titleFiltered.contains(searchTermLower)

        let titleMatchScore: Int
        let descriptionMatchScore: Int

        if isExactMatchInTitle {
            titleMatchScore = 5
        } else {
            // Count individual word matches in title
            titleMatchScore = countWordMatches(in: title, wordVariants: wordVariants)
        }

        // Count individual word matches in description
        descriptionMatchScore = countWordMatches(in: description, wordVariants: wordVariants)

        // Calculate dates and ages
        let originalReleaseDate = parseDate(app.releaseDate ?? "")
        let latestReleaseDate = parseDate(app.currentVersionReleaseDate ?? "")

        let now = Date()
        let ageDays = originalReleaseDate.map { Int(now.timeIntervalSince($0) / 86400) } ?? 0
        let freshnessDays = latestReleaseDate.map { Int(now.timeIntervalSince($0) / 86400) } ?? 0

        // Calculate ratings per day
        let ratingCount = app.userRatingCount ?? 0
        let ratingsPerDay = ageDays > 0 ? Double(ratingCount) / Double(ageDays) : 0

        return AnalyzedApp(
            app: app,
            titleMatchScore: titleMatchScore,
            descriptionMatchScore: descriptionMatchScore,
            originalReleaseDate: originalReleaseDate,
            latestReleaseDate: latestReleaseDate,
            ageDays: ageDays,
            freshnessDays: freshnessDays,
            ratingsPerDay: ratingsPerDay,
            genreName: app.primaryGenreName
        )
    }

    private func countWordMatches(in text: String, wordVariants: [[String]]) -> Int {
        var count = 0
        for variants in wordVariants {
            // Check if any variant appears in the text as a whole word
            for variant in variants {
                // Use word boundary matching - check if variant appears as a whole word
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: variant))\\b"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(text.startIndex..., in: text)
                    if regex.firstMatch(in: text, range: range) != nil {
                        count += 1
                        break // Count each word only once
                    }
                }
            }
        }
        return count
    }

    private func parseDate(_ dateString: String) -> Date? {
        // Try ISO8601 format first (from API)
        let iso8601Formatter = ISO8601DateFormatter()
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }

        // Try common date formats
        let formatters = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd",
        ]

        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func outputCSV(analyzedApps: [AnalyzedApp], summary: SearchSummary, durationMs: Int) {
        // Header row
        print("App ID,Rating,Rating Count,Original Release,Latest Release,Age Days,Freshness Days,Title Match Score,Description Match Score,Ratings Per Day,Title")

        // Data rows
        for analyzed in analyzedApps {
            let app = analyzed.app
            let appId = app.trackId
            let rating = app.averageUserRating.map { String(format: "%.1f", $0) } ?? ""
            let ratingCount = app.userRatingCount ?? 0
            let originalRelease = formatDate(analyzed.originalReleaseDate)
            let latestRelease = formatDate(analyzed.latestReleaseDate)
            let ageDays = analyzed.ageDays
            let freshnessDays = analyzed.freshnessDays
            let titleScore = analyzed.titleMatchScore
            let descScore = analyzed.descriptionMatchScore
            let ratingsPerDay = String(format: "%.2f", analyzed.ratingsPerDay)
            let title = escapedCSV(app.trackName)

            print("\(appId),\(rating),\(ratingCount),\(originalRelease),\(latestRelease),\(ageDays),\(freshnessDays),\(titleScore),\(descScore),\(ratingsPerDay),\(title)")
        }

        // Blank line
        print()

        // Summary statistics - Section 1: Overall
        let totalApps = analyzedApps.count
        print("Overall Summary (All \(totalApps) Apps):")
        print("  Average App Age: \(summary.avgAgeDays) days")
        print("  Average App Freshness: \(summary.avgFreshnessDays) days")
        print("  Average Star Rating: \(String(format: "%.2f", summary.avgRating))")
        print("  Average Rating Count: \(summary.avgRatingCount)")
        print("  Total Title Match Score: \(summary.totalTitleScore)")
        print("  Total Description Match Score: \(summary.totalDescScore)")
        print("  Average Title Match Score: \(String(format: "%.2f", summary.avgTitleMatchScore))")
        print("  Average Description Match Score: \(String(format: "%.2f", summary.avgDescriptionMatchScore))")
        print("  Total Ratings Per Day: \(String(format: "%.2f", summary.totalRatingsPerDay))")
        print("  Average Ratings Per Day: \(String(format: "%.2f", summary.avgRatingsPerDay))")
        print("  Competitiveness Score (v1): \(String(format: "%.1f", summary.competitivenessV1))")
        print()

        // Summary statistics - Section 2: Newest 30% vs Established
        print("Newest 30% (\(summary.newCount) Apps) vs Established (\(summary.establishedCount) Apps):")
        print("  Newest Apps:")
        print("    Percentage of Total Ratings: \(String(format: "%.1f", summary.newestPercentOfRatings))%")
        print("    Average Ratings Per Day (Velocity): \(String(format: "%.2f", summary.newestVelocity))")
        print("  Established Apps:")
        print("    Percentage of Total Ratings: \(String(format: "%.1f", summary.establishedPercentOfRatings))%")
        print("    Average Ratings Per Day (Velocity): \(String(format: "%.2f", summary.establishedVelocity))")
        print("  Velocity Ratio (Newest/Established): \(String(format: "%.2f", summary.velocityRatio))")
    }

    private func calculateSummary(analyzedApps: [AnalyzedApp]) -> SearchSummary {
        let totalApps = analyzedApps.count
        guard totalApps > 0 else {
            return SearchSummary(
                avgAgeDays: 0, avgFreshnessDays: 0, avgRating: 0, avgRatingCount: 0,
                avgTitleMatchScore: 0, avgDescriptionMatchScore: 0, avgRatingsPerDay: 0,
                newestVelocity: 0, establishedVelocity: 0, velocityRatio: 0, competitivenessV1: 0,
                totalTitleScore: 0, totalDescScore: 0, totalRatingsPerDay: 0,
                newestPercentOfRatings: 0, establishedPercentOfRatings: 0,
                newCount: 0, establishedCount: 0
            )
        }

        // Basic averages
        let avgAge = analyzedApps.map { $0.ageDays }.reduce(0, +) / totalApps
        let avgFreshness = analyzedApps.map { $0.freshnessDays }.reduce(0, +) / totalApps
        let avgRating = analyzedApps.compactMap { $0.app.averageUserRating }.reduce(0, +) / Double(totalApps)
        let avgRatingCount = analyzedApps.map { $0.app.userRatingCount ?? 0 }.reduce(0, +) / totalApps
        let totalTitleScore = analyzedApps.map { $0.titleMatchScore }.reduce(0, +)
        let totalDescScore = analyzedApps.map { $0.descriptionMatchScore }.reduce(0, +)
        let avgTitleScore = Double(totalTitleScore) / Double(totalApps)
        let avgDescScore = Double(totalDescScore) / Double(totalApps)
        let totalRatingsPerDay = analyzedApps.map { $0.ratingsPerDay }.reduce(0, +)
        let avgRatingsPerDay = totalRatingsPerDay / Double(totalApps)

        // Newest 30% vs Established
        let sortedByAge = analyzedApps.sorted { $0.ageDays < $1.ageDays }
        let newCount = Int(ceil(Double(totalApps) * 0.3))
        let newestApps = Array(sortedByAge.prefix(newCount))
        let establishedApps = Array(sortedByAge.dropFirst(newCount))

        let totalRatings = analyzedApps.map { $0.app.userRatingCount ?? 0 }.reduce(0, +)
        let newestRatings = newestApps.map { $0.app.userRatingCount ?? 0 }.reduce(0, +)
        let establishedRatings = establishedApps.map { $0.app.userRatingCount ?? 0 }.reduce(0, +)

        let newestPercentOfRatings = totalRatings > 0 ? (Double(newestRatings) / Double(totalRatings)) * 100 : 0
        let establishedPercentOfRatings = totalRatings > 0 ? (Double(establishedRatings) / Double(totalRatings)) * 100 : 0

        let newestAvgRatingsPerDay = newestApps.count > 0 ? newestApps.map { $0.ratingsPerDay }.reduce(0, +) / Double(newestApps.count) : 0
        let establishedAvgRatingsPerDay = establishedApps.count > 0 ? establishedApps.map { $0.ratingsPerDay }.reduce(0, +) / Double(establishedApps.count) : 0

        let velocityRatio = establishedAvgRatingsPerDay > 0 ? newestAvgRatingsPerDay / establishedAvgRatingsPerDay : 0

        // Calculate competitivenessV1
        let competitivenessV1 = calculateCompetitivenessV1(
            avgRatingsPerDay: avgRatingsPerDay,
            avgFreshness: avgFreshness,
            avgTitleMatchScore: avgTitleScore,
            velocityRatio: velocityRatio
        )

        return SearchSummary(
            avgAgeDays: avgAge,
            avgFreshnessDays: avgFreshness,
            avgRating: avgRating,
            avgRatingCount: avgRatingCount,
            avgTitleMatchScore: avgTitleScore,
            avgDescriptionMatchScore: avgDescScore,
            avgRatingsPerDay: avgRatingsPerDay,
            newestVelocity: newestAvgRatingsPerDay,
            establishedVelocity: establishedAvgRatingsPerDay,
            velocityRatio: velocityRatio,
            competitivenessV1: competitivenessV1,
            totalTitleScore: totalTitleScore,
            totalDescScore: totalDescScore,
            totalRatingsPerDay: totalRatingsPerDay,
            newestPercentOfRatings: newestPercentOfRatings,
            establishedPercentOfRatings: establishedPercentOfRatings,
            newCount: newCount,
            establishedCount: establishedApps.count
        )
    }

    private func calculateCompetitivenessV1(
        avgRatingsPerDay: Double,
        avgFreshness: Int,
        avgTitleMatchScore: Double,
        velocityRatio: Double
    ) -> Double {
        // Normalize avgRatingsPerDay (assume 0-100 range, cap at 100)
        let normalizedTraffic = min(avgRatingsPerDay, 100.0)

        // Normalize freshness (0 = just updated, 365+ = very stale)
        // Lower freshness = more competitive (actively maintained)
        let normalizedFreshness = max(0, 100 - Double(min(avgFreshness, 365)) / 365.0 * 100)

        // Normalize title match score (0-5 range to 0-100)
        let normalizedTitleMatch = avgTitleMatchScore * 20.0

        // Normalize velocity ratio (0-5 range to 0-100, inverted)
        // Lower ratio = harder for new apps (more competitive)
        let normalizedVelocity = max(0, 100 - min(velocityRatio, 5.0) * 20.0)

        // Weighted average (higher = more competitive)
        let competitiveness = (
            normalizedTraffic * 0.35 +
            normalizedFreshness * 0.25 +
            normalizedTitleMatch * 0.20 +
            normalizedVelocity * 0.20
        )

        return min(100, max(0, competitiveness))
    }

    private func saveToDatabase(
        searchId: String,
        options: AnalyzeOptions,
        timestamp: Date,
        durationMs: Int,
        analyzedApps: [AnalyzedApp],
        summary: SearchSummary
    ) throws {
        let db = AnalyzeDatabase()
        try db.open()
        defer { db.close() }

        // Save search metadata
        try db.saveSearch(
            id: searchId,
            keyword: options.term,
            storefront: options.storefront,
            language: options.language,
            timestamp: timestamp,
            durationMs: durationMs
        )

        // Save each app
        for (index, analyzed) in analyzedApps.enumerated() {
            try db.saveApp(
                searchId: searchId,
                rank: index + 1,
                appId: analyzed.app.trackId,
                title: analyzed.app.trackName,
                rating: analyzed.app.averageUserRating,
                ratingCount: analyzed.app.userRatingCount,
                originalRelease: formatDate(analyzed.originalReleaseDate),
                latestRelease: formatDate(analyzed.latestReleaseDate),
                ageDays: analyzed.ageDays,
                freshnessDays: analyzed.freshnessDays,
                titleMatchScore: analyzed.titleMatchScore,
                descriptionMatchScore: analyzed.descriptionMatchScore,
                ratingsPerDay: analyzed.ratingsPerDay,
                genreName: analyzed.genreName
            )
        }

        // Save summary
        try db.saveSummary(
            searchId: searchId,
            avgAgeDays: summary.avgAgeDays,
            avgFreshnessDays: summary.avgFreshnessDays,
            avgRating: summary.avgRating,
            avgRatingCount: summary.avgRatingCount,
            avgTitleMatchScore: summary.avgTitleMatchScore,
            avgDescriptionMatchScore: summary.avgDescriptionMatchScore,
            avgRatingsPerDay: summary.avgRatingsPerDay,
            newestVelocity: summary.newestVelocity,
            establishedVelocity: summary.establishedVelocity,
            velocityRatio: summary.velocityRatio,
            competitivenessV1: summary.competitivenessV1
        )
    }

    private func escapedCSV(_ text: String) -> String {
        // Escape quotes and wrap in quotes if contains comma or quote
        if text.contains(",") || text.contains("\"") || text.contains("\n") {
            return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return text
    }
}

struct AnalyzedApp {
    let app: App
    let titleMatchScore: Int
    let descriptionMatchScore: Int
    let originalReleaseDate: Date?
    let latestReleaseDate: Date?
    let ageDays: Int
    let freshnessDays: Int
    let ratingsPerDay: Double
    let genreName: String
}

struct SearchSummary {
    let avgAgeDays: Int
    let avgFreshnessDays: Int
    let avgRating: Double
    let avgRatingCount: Int
    let avgTitleMatchScore: Double
    let avgDescriptionMatchScore: Double
    let avgRatingsPerDay: Double
    let newestVelocity: Double
    let establishedVelocity: Double
    let velocityRatio: Double
    let competitivenessV1: Double
    let totalTitleScore: Int
    let totalDescScore: Int
    let totalRatingsPerDay: Double
    let newestPercentOfRatings: Double
    let establishedPercentOfRatings: Double
    let newCount: Int
    let establishedCount: Int
}
