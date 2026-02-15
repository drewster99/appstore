import Foundation

enum ListType: String, CaseIterable {
    case storefronts
    case genres
    case attributes
    case charttypes

    var description: String {
        switch self {
        case .storefronts:
            return "Available App Store storefronts (country codes)"
        case .genres:
            return "Available genre IDs for App Store categories"
        case .attributes:
            return "Available search attributes for refined searches"
        case .charttypes:
            return "Available chart types for top lists"
        }
    }
}

struct ListOptions {
    let commonOptions: CommonOptions
    let listType: ListType

    var outputFormat: OutputFormat { commonOptions.outputFormat }
    var verbosity: Verbosity { commonOptions.verbosity }
}

class ListCommand {
    private let session = URLSession.shared

    /// Static storefront data for MCP resources.
    static let storefronts: [(code: String, name: String)] = [
        ("US", "United States"), ("GB", "United Kingdom"), ("CA", "Canada"),
        ("AU", "Australia"), ("DE", "Germany"), ("FR", "France"),
        ("IT", "Italy"), ("ES", "Spain"), ("NL", "Netherlands"),
        ("SE", "Sweden"), ("NO", "Norway"), ("DK", "Denmark"),
        ("FI", "Finland"), ("RU", "Russia"), ("JP", "Japan"),
        ("CN", "China"), ("KR", "South Korea"), ("TW", "Taiwan"),
        ("HK", "Hong Kong"), ("SG", "Singapore"), ("MY", "Malaysia"),
        ("TH", "Thailand"), ("ID", "Indonesia"), ("PH", "Philippines"),
        ("IN", "India"), ("BR", "Brazil"), ("MX", "Mexico"),
        ("AR", "Argentina"), ("CL", "Chile"), ("CO", "Colombia"),
        ("AE", "United Arab Emirates"), ("SA", "Saudi Arabia"), ("TR", "Turkey"),
        ("ZA", "South Africa"), ("EG", "Egypt"), ("IL", "Israel"),
        ("PL", "Poland"), ("HU", "Hungary"), ("CZ", "Czech Republic"),
        ("SK", "Slovakia"), ("RO", "Romania"), ("BG", "Bulgaria"),
        ("HR", "Croatia"), ("SI", "Slovenia"), ("GR", "Greece"),
        ("PT", "Portugal"), ("BE", "Belgium"), ("CH", "Switzerland"),
        ("AT", "Austria"), ("IE", "Ireland"), ("NZ", "New Zealand"),
        ("VN", "Vietnam"), ("PK", "Pakistan"), ("NG", "Nigeria"),
        ("KE", "Kenya")
    ]

    /// Static genre data for MCP resources.
    static let genres: [(id: Int, name: String)] = [
        (6000, "Business"), (6001, "Weather"), (6002, "Utilities"),
        (6003, "Travel"), (6004, "Sports"), (6005, "Social Networking"),
        (6006, "Reference"), (6007, "Productivity"), (6008, "Photo & Video"),
        (6009, "News"), (6010, "Navigation"), (6011, "Music"),
        (6012, "Lifestyle"), (6013, "Health & Fitness"), (6014, "Games"),
        (6015, "Finance"), (6016, "Entertainment"), (6017, "Education"),
        (6018, "Books"), (6020, "Medical"), (6021, "Magazines & Newspapers"),
        (6022, "Catalogs"), (6023, "Food & Drink"), (6024, "Shopping"),
        (6025, "Stickers"), (6026, "Developer Tools"), (6027, "Graphics & Design")
    ]

    /// Static search attributes for MCP resources.
    static var attributes: [(name: String, description: String, recommended: Bool)] {
        SearchAttribute.allCases.map { attr in
            (name: attr.rawValue, description: attr.description, recommended: attr.isRecommendedForSoftware)
        }
    }

    /// Static chart type data for MCP resources.
    static var chartTypes: [(name: String, displayName: String, description: String)] {
        TopChartType.allCases.map { type in
            (name: type.rawValue, displayName: type.displayName, description: type.description)
        }
    }

    func execute(options: ListOptions) async {
        let startTime = Date()
        let outputManager = OutputManager(options: options.commonOptions)

        switch options.listType {
        case .storefronts:
            await listStorefronts(outputManager: outputManager, options: options, startTime: startTime)
        case .genres:
            await listGenres(outputManager: outputManager, options: options, startTime: startTime)
        case .attributes:
            listAttributes(outputManager: outputManager, options: options, startTime: startTime)
        case .charttypes:
            listChartTypes(outputManager: outputManager, options: options, startTime: startTime)
        }
    }

    private func listStorefronts(outputManager: OutputManager, options: ListOptions, startTime: Date) async {
        // Note: Apple doesn't provide an API to list all storefronts,
        // so we maintain a hardcoded list of known storefronts
        let storefronts = [
            ("us", "United States"),
            ("gb", "United Kingdom"),
            ("ca", "Canada"),
            ("au", "Australia"),
            ("de", "Germany"),
            ("fr", "France"),
            ("it", "Italy"),
            ("es", "Spain"),
            ("nl", "Netherlands"),
            ("se", "Sweden"),
            ("no", "Norway"),
            ("dk", "Denmark"),
            ("fi", "Finland"),
            ("ru", "Russia"),
            ("jp", "Japan"),
            ("cn", "China"),
            ("kr", "South Korea"),
            ("tw", "Taiwan"),
            ("hk", "Hong Kong"),
            ("sg", "Singapore"),
            ("my", "Malaysia"),
            ("th", "Thailand"),
            ("id", "Indonesia"),
            ("ph", "Philippines"),
            ("in", "India"),
            ("br", "Brazil"),
            ("mx", "Mexico"),
            ("ar", "Argentina"),
            ("cl", "Chile"),
            ("co", "Colombia"),
            ("ae", "United Arab Emirates"),
            ("sa", "Saudi Arabia"),
            ("tr", "Turkey"),
            ("za", "South Africa"),
            ("eg", "Egypt"),
            ("il", "Israel"),
            ("pl", "Poland"),
            ("hu", "Hungary"),
            ("cz", "Czech Republic"),
            ("sk", "Slovakia"),
            ("ro", "Romania"),
            ("bg", "Bulgaria"),
            ("hr", "Croatia"),
            ("si", "Slovenia"),
            ("gr", "Greece"),
            ("pt", "Portugal"),
            ("be", "Belgium"),
            ("ch", "Switzerland"),
            ("at", "Austria"),
            ("ie", "Ireland"),
            ("nz", "New Zealand"),
            ("vn", "Vietnam"),
            ("pk", "Pakistan"),
            ("ng", "Nigeria"),
            ("ke", "Kenya")
        ]

        let endTime = Date()
        let durationMs = Int(endTime.timeIntervalSince(startTime) * 1000)

        // Build JSON data structure
        var jsonData: [String: Any] = [:]
        for (code, name) in storefronts {
            jsonData[code] = name
        }

        let parameters: [String: Any] = [
            "listType": "storefronts"
        ]

        // Use OutputManager for all output
        if options.outputFormat == .json || options.outputFormat == .rawJson {
            outputManager.outputListResults(jsonData, command: "list", parameters: parameters, durationMs: durationMs)
        } else {
            // Text output
            print("Available App Store Storefronts (static):")
            print(String(repeating: "-", count: 43))

            for (code, name) in storefronts {
                print("  \(code) - \(name)")
            }

            print()
            print("Use with: --storefront <code>")
            print("Example: appstore search twitter --storefront gb")
        }
    }

    private func listGenres(outputManager: OutputManager, options: ListOptions, startTime: Date) async {
        // Try to fetch from API first
        if let apiGenres = await fetchGenresFromAPI() {
            displayGenres(apiGenres, outputManager: outputManager, options: options, startTime: startTime, source: "API")
            return
        }

        // Fall back to hardcoded list if API fails
        let genres = [
            (6000, "Business"),
            (6001, "Weather"),
            (6002, "Utilities"),
            (6003, "Travel"),
            (6004, "Sports"),
            (6005, "Social Networking"),
            (6006, "Reference"),
            (6007, "Productivity"),
            (6008, "Photo & Video"),
            (6009, "News"),
            (6010, "Navigation"),
            (6011, "Music"),
            (6012, "Lifestyle"),
            (6013, "Health & Fitness"),
            (6014, "Games"),
            (6015, "Finance"),
            (6016, "Entertainment"),
            (6017, "Education"),
            (6018, "Books"),
            (6020, "Medical"),
            (6021, "Magazines & Newspapers"),
            (6022, "Catalogs"),
            (6023, "Food & Drink"),
            (6024, "Shopping"),
            (6025, "Stickers"),
            (6026, "Developer Tools"),
            (6027, "Graphics & Design")
        ]

        displayGenres(genres, outputManager: outputManager, options: options, startTime: startTime, source: "cached")
    }

    private func listAttributes(outputManager: OutputManager, options: ListOptions, startTime: Date) {
        let endTime = Date()
        let durationMs = Int(endTime.timeIntervalSince(startTime) * 1000)

        if options.outputFormat == .json || options.outputFormat == .rawJson {
            var jsonData: [String: Any] = [:]

            // Recommended attributes
            var recommended: [String: String] = [:]
            for attr in SearchAttribute.allCases where attr.isRecommendedForSoftware {
                recommended[attr.rawValue] = attr.description
            }

            // Other attributes
            var other: [String: String] = [:]
            for attr in SearchAttribute.allCases where !attr.isRecommendedForSoftware {
                other[attr.rawValue] = attr.description
            }

            jsonData["recommended"] = recommended
            jsonData["other"] = other

            let parameters: [String: Any] = [
                "listType": "attributes"
            ]

            outputManager.outputListResults(jsonData, command: "list", parameters: parameters, durationMs: durationMs)
            return
        }

        print("Available Search Attributes:")
        print(String(repeating: "=", count: 60))

        print("\nRecommended for App Search:")
        print(String(repeating: "-", count: 40))
        for attr in SearchAttribute.allCases where attr.isRecommendedForSoftware {
            print("  \(attr.rawValue) - \(attr.description)")
        }

        print("\nOther Attributes (less useful for apps):")
        print(String(repeating: "-", count: 40))
        for attr in SearchAttribute.allCases where !attr.isRecommendedForSoftware {
            print("  \(attr.rawValue) - \(attr.description)")
        }

        print()
        print("Use with: --attribute <name>")
        print("Example: appstore search OpenAI --attribute softwareDeveloper")
        print("Example: appstore search editor --attribute titleTerm")
    }

    private func listChartTypes(outputManager: OutputManager, options: ListOptions, startTime: Date) {
        let endTime = Date()
        let durationMs = Int(endTime.timeIntervalSince(startTime) * 1000)

        if options.outputFormat == .json || options.outputFormat == .rawJson {
            var jsonData: [String: Any] = [:]

            for type in TopChartType.allCases {
                var typeData: [String: String] = [:]
                typeData["name"] = type.displayName
                typeData["description"] = type.description
                typeData["feed"] = type.rawValue

                // Add alternative names
                var aliases: [String] = []
                switch type {
                case .free:
                    aliases = ["free", "topfree"]
                case .paid:
                    aliases = ["paid", "toppaid"]
                case .grossing:
                    aliases = ["grossing", "topgrossing"]
                case .newFree:
                    aliases = ["newfree", "new-free"]
                case .newPaid:
                    aliases = ["newpaid", "new-paid"]
                }
                typeData["aliases"] = aliases.joined(separator: ", ")

                jsonData[String(describing: type)] = typeData
            }

            let parameters: [String: Any] = [
                "listType": "charttypes"
            ]

            outputManager.outputListResults(jsonData, command: "list", parameters: parameters, durationMs: durationMs)
            return
        }

        print("Available Chart Types:")
        print(String(repeating: "-", count: 60))

        for type in TopChartType.allCases {
            print("\n\(type.displayName):")
            print("  Description: \(type.description)")
            print("  RSS Feed: \(type.rawValue)")

            // Show alternative names
            switch type {
            case .free:
                print("  Use: appstore top free")
            case .paid:
                print("  Use: appstore top paid")
            case .grossing:
                print("  Use: appstore top grossing")
            case .newFree:
                print("  Use: appstore top newfree")
            case .newPaid:
                print("  Use: appstore top newpaid")
            }
        }

        print()
        print("Examples:")
        print("  appstore top              # defaults to top free")
        print("  appstore top paid         # top paid apps")
        print("  appstore top grossing --limit 10 --storefront gb")
    }

    // MARK: - API Fetch Methods

    private func fetchGenresFromAPI() async -> [(Int, String)]? {
        // Apple's genre API endpoint
        guard let url = URL(string: "https://itunes.apple.com/WebObjects/MZStoreServices.woa/ws/genres?id=36") else {
            return nil
        }

        do {
            // Rate limit before API call
            await waitForRateLimit()

            let (data, _) = try await session.data(from: url)

            // Parse the JSON response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let appStoreGenres = json["36"] as? [String: Any],
                  let subgenres = appStoreGenres["subgenres"] as? [String: Any] else {
                return nil
            }

            // Convert to array format
            var genres: [(Int, String)] = []
            for (idString, genreData) in subgenres {
                if let id = Int(idString),
                   let genreDict = genreData as? [String: Any],
                   let name = genreDict["name"] as? String {
                    genres.append((id, name))
                }
            }

            // Sort by ID for consistency
            genres.sort { $0.0 < $1.0 }
            return genres

        } catch {
            // Silent fail - will use hardcoded list
            return nil
        }
    }

    // MARK: - Display Helper Methods

    private func displayGenres(_ genres: [(Int, String)], outputManager: OutputManager, options: ListOptions, startTime: Date, source: String) {
        let endTime = Date()
        let durationMs = Int(endTime.timeIntervalSince(startTime) * 1000)

        if options.outputFormat == .json || options.outputFormat == .rawJson {
            var jsonData: [String: Any] = ["_source": source]
            for (id, name) in genres {
                jsonData[String(id)] = name
            }

            let parameters: [String: Any] = [
                "listType": "genres",
                "source": source
            ]

            outputManager.outputListResults(jsonData, command: "list", parameters: parameters, durationMs: durationMs)
            return
        }

        print("Available App Store Genre IDs \(source == "API" ? "(live)" : "(cached)"):")
        print(String(repeating: "-", count: 40))

        for (id, name) in genres {
            print("  \(id) - \(name)")
        }

        print()
        print("Use with: --genre <id>")
        print("Example: appstore search game --genre 6014")
        print("Example: appstore top free --genre 6014")
    }
}