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

            // Step 5: Output CSV with header
            outputCSV(analyzedApps: analyzedApps, durationMs: durationMs)

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
            ratingsPerDay: ratingsPerDay
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

    private func outputCSV(analyzedApps: [AnalyzedApp], durationMs: Int) {
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
        if totalApps > 0 {
            let avgAge = analyzedApps.map { $0.ageDays }.reduce(0, +) / totalApps
            let avgFreshness = analyzedApps.map { $0.freshnessDays }.reduce(0, +) / totalApps
            let avgRating = analyzedApps.compactMap { $0.app.averageUserRating }.reduce(0, +) / Double(analyzedApps.count)
            let avgRatingCount = analyzedApps.map { $0.app.userRatingCount ?? 0 }.reduce(0, +) / totalApps
            let totalTitleScore = analyzedApps.map { $0.titleMatchScore }.reduce(0, +)
            let totalDescScore = analyzedApps.map { $0.descriptionMatchScore }.reduce(0, +)
            let avgTitleScore = Double(totalTitleScore) / Double(totalApps)
            let avgDescScore = Double(totalDescScore) / Double(totalApps)
            let totalRatingsPerDay = analyzedApps.map { $0.ratingsPerDay }.reduce(0, +)
            let avgRatingsPerDay = totalRatingsPerDay / Double(totalApps)

            print("Overall Summary (All \(totalApps) Apps):")
            print("  Average App Age: \(avgAge) days")
            print("  Average App Freshness: \(avgFreshness) days")
            print("  Average Star Rating: \(String(format: "%.2f", avgRating))")
            print("  Average Rating Count: \(avgRatingCount)")
            print("  Total Title Match Score: \(totalTitleScore)")
            print("  Total Description Match Score: \(totalDescScore)")
            print("  Average Title Match Score: \(String(format: "%.2f", avgTitleScore))")
            print("  Average Description Match Score: \(String(format: "%.2f", avgDescScore))")
            print("  Total Ratings Per Day: \(String(format: "%.2f", totalRatingsPerDay))")
            print("  Average Ratings Per Day: \(String(format: "%.2f", avgRatingsPerDay))")
            print()

            // Summary statistics - Section 2: Newest 30% vs Established
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

            print("Newest 30% (\(newCount) Apps) vs Established (\(establishedApps.count) Apps):")
            print("  Newest Apps:")
            print("    Percentage of Total Ratings: \(String(format: "%.1f", newestPercentOfRatings))%")
            print("    Average Ratings Per Day (Velocity): \(String(format: "%.2f", newestAvgRatingsPerDay))")
            print("  Established Apps:")
            print("    Percentage of Total Ratings: \(String(format: "%.1f", establishedPercentOfRatings))%")
            print("    Average Ratings Per Day (Velocity): \(String(format: "%.2f", establishedAvgRatingsPerDay))")
            print("  Velocity Ratio (Newest/Established): \(String(format: "%.2f", velocityRatio))")
        }
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
}
