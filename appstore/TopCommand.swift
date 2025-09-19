import Foundation

enum TopChartType: String, CaseIterable {
    case free = "topfreeapplications"
    case paid = "toppaidapplications"
    case grossing = "topgrossingapplications"
    case newFree = "newfreeapplications"
    case newPaid = "newpaidapplications"

    var displayName: String {
        switch self {
        case .free: return "Top Free"
        case .paid: return "Top Paid"
        case .grossing: return "Top Grossing"
        case .newFree: return "New Free"
        case .newPaid: return "New Paid"
        }
    }

    var description: String {
        switch self {
        case .free: return "Most downloaded free apps"
        case .paid: return "Most purchased paid apps"
        case .grossing: return "Highest revenue generating apps"
        case .newFree: return "Latest free apps"
        case .newPaid: return "Latest paid apps"
        }
    }
}

struct TopOptions {
    let chartType: TopChartType
    let limit: Int
    let storefront: String  // Was 'country', using storefront for consistency
    let genre: Int?
    let outputMode: OutputMode
}

class TopCommand {
    private let session = URLSession.shared

    func execute(options: TopOptions) async {
        if options.outputMode != .json {
            print("Fetching \(options.chartType.displayName) apps from \(options.storefront.uppercased()) App Store...")
            print()
        }

        let urlString = "https://itunes.apple.com/\(options.storefront)/rss/\(options.chartType.rawValue)/limit=\(options.limit)"
            + (options.genre.map { "/genre=\($0)" } ?? "")
            + "/json"

        guard let url = URL(string: urlString) else {
            print("Error: Invalid URL")
            return
        }

        do {
            let (data, _) = try await session.data(from: url)

            if options.outputMode == .json {
                // Show raw JSON output
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])

                if let jsonString = String(data: prettyData, encoding: .utf8) {
                    print(jsonString)
                }
                return
            }

            // Parse the JSON for other output modes
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let feed = json["feed"] as? [String: Any] else {
                print("Error: Invalid RSS feed format")
                return
            }

            // Get the title
            let title = (feed["title"] as? [String: Any])?["label"] as? String ?? "Top Apps"

            // Get entries - handle both single entry and array of entries
            var entries: [[String: Any]] = []
            if let entryArray = feed["entry"] as? [[String: Any]] {
                entries = entryArray
            } else if let singleEntry = feed["entry"] as? [String: Any] {
                entries = [singleEntry]
            }

            if entries.isEmpty {
                print("No results found")
                return
            }

            print("\(title):")
            print(String(repeating: "-", count: 80))

            switch options.outputMode {
            case .oneline:
                printOneline(entries: entries)
            case .summary, .expanded, .verbose:
                printSummary(entries: entries)
            case .complete:
                for (index, entry) in entries.enumerated() {
                    print("\n[\(index + 1)]")
                    FormatUtils.printCompleteJSON(entry, indent: 1)
                    if index < entries.count - 1 {
                        print(String(repeating: "-", count: 80))
                    }
                }
            case .json:
                break // Already handled above
            }

            print(String(repeating: "=", count: 80))

        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }

    private func printOneline(entries: [[String: Any]]) {
        for (index, entry) in entries.enumerated() {
            let rank = String(format: "%3d", index + 1)
            let name = (entry["im:name"] as? [String: Any])?["label"] as? String ?? "Unknown"

            // Get price from attributes for actual amount
            let priceInfo = entry["im:price"] as? [String: Any]
            let priceAttributes = priceInfo?["attributes"] as? [String: Any]
            let amount = priceAttributes?["amount"] as? String ?? "0.00"
            let currency = priceAttributes?["currency"] as? String ?? "USD"

            // Format price: Free for 0.00, otherwise show currency symbol
            let price: String
            if amount == "0.00" || amount == "0.00000" {
                price = "Free"
            } else {
                price = currency == "USD" ? "$\(amount)" : "\(amount) \(currency)"
            }

            // Get IDs
            let idAttributes = (entry["id"] as? [String: Any])?["attributes"] as? [String: Any]
            let appId = idAttributes?["im:id"] as? String ?? "unknown"
            let bundleId = idAttributes?["im:bundleId"] as? String ?? "unknown"

            print("\(rank). \(appId) \(bundleId) \(price) \(name)")
        }
    }

    private func printSummary(entries: [[String: Any]]) {
        for (index, entry) in entries.enumerated() {
            let name = (entry["im:name"] as? [String: Any])?["label"] as? String ?? "Unknown"
            let artist = (entry["im:artist"] as? [String: Any])?["label"] as? String ?? "Unknown Developer"

            // Get price from attributes for actual amount
            let priceInfo = entry["im:price"] as? [String: Any]
            let priceAttributes = priceInfo?["attributes"] as? [String: Any]
            let amount = priceAttributes?["amount"] as? String ?? "0.00"
            let currency = priceAttributes?["currency"] as? String ?? "USD"

            // Format price: Free for 0.00, otherwise show currency symbol
            let price: String
            if amount == "0.00" || amount == "0.00000" {
                price = "Free"
            } else {
                price = currency == "USD" ? "$\(amount)" : "\(amount) \(currency)"
            }

            let category = ((entry["category"] as? [String: Any])?["attributes"] as? [String: Any])?["label"] as? String ?? "Unknown"

            // Get IDs
            let idAttributes = (entry["id"] as? [String: Any])?["attributes"] as? [String: Any]
            let appId = idAttributes?["im:id"] as? String ?? "Unknown"
            let bundleId = idAttributes?["im:bundleId"] as? String

            print("\(index + 1). \(name)")
            print("   App ID: \(appId)")
            print("   Developer: \(artist)")
            print("   Price: \(price)")
            print("   Category: \(category)")

            if let bundleId = bundleId {
                print("   Bundle ID: \(bundleId)")
            }

            if let summary = (entry["summary"] as? [String: Any])?["label"] as? String {
                let maxLength = 150
                let cleanSummary = summary.replacingOccurrences(of: "\n", with: " ")
                let truncated = cleanSummary.count > maxLength ? String(cleanSummary.prefix(maxLength)) + "..." : cleanSummary
                print("   Description: \(truncated)")
            }

            if index < entries.count - 1 {
                print(String(repeating: "-", count: 80))
            }
        }
    }
}