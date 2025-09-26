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
    let commonOptions: CommonOptions
    let chartType: TopChartType
    let limit: Int
    let genre: Int?

    // Compatibility accessors for migration
    var showRequest: Bool { commonOptions.showRequest }
    var storefront: String { commonOptions.storefront ?? "US" }
    var outputFile: String? { commonOptions.outputFile }
    var inputFile: String? { commonOptions.inputFile }
    var outputFormat: OutputFormat? { commonOptions.outputFormat }
    var verbosity: Verbosity? { commonOptions.verbosity }
    var fullDescription: Bool { commonOptions.fullDescription }
}

class TopCommand {
    private let session = URLSession.shared

    func execute(options: TopOptions) async {
        let outputManager = OutputManager(options: options.commonOptions)

        if options.commonOptions.outputFormat != .json {
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

        let startTime = Date()

        do {
            // Rate limit before API call
            await waitForRateLimit()

            let (data, _) = try await session.data(from: url)

            let endTime = Date()
            let durationMs = Int(endTime.timeIntervalSince(startTime) * 1000)

            // Parse the JSON
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

            if entries.isEmpty && options.commonOptions.outputFormat != .json {
                print("No results found")
                return
            }

            // Build parameters for metadata
            let parameters: [String: Any] = [
                "chartType": options.chartType.rawValue,
                "storefront": options.storefront,
                "limit": options.limit,
                "genre": options.genre ?? 0,
                "url": urlString
            ]

            // Use OutputManager to handle all output
            outputManager.outputTopResults(data, entries: entries, title: title, command: "top", parameters: parameters, durationMs: durationMs)

        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
}
