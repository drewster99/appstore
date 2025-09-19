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
    let listType: ListType
    let outputMode: OutputMode
}

class ListCommand {
    func execute(options: ListOptions) {
        switch options.listType {
        case .storefronts:
            listStorefronts(outputMode: options.outputMode)
        case .genres:
            listGenres(outputMode: options.outputMode)
        case .attributes:
            listAttributes(outputMode: options.outputMode)
        case .charttypes:
            listChartTypes(outputMode: options.outputMode)
        }
    }

    private func listStorefronts(outputMode: OutputMode) {
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

        if outputMode == .json {
            var jsonData: [String: Any] = [:]
            for (code, name) in storefronts {
                jsonData[code] = name
            }

            if let data = try? JSONSerialization.data(withJSONObject: jsonData, options: [.prettyPrinted, .sortedKeys]),
               let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
            return
        }

        print("Available App Store Storefronts:")
        print(String(repeating: "-", count: 40))

        for (code, name) in storefronts {
            print("  \(code) - \(name)")
        }

        print()
        print("Use with: --storefront <code>")
        print("Example: appstore search twitter --storefront gb")
    }

    private func listGenres(outputMode: OutputMode) {
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

        if outputMode == .json {
            var jsonData: [String: Any] = [:]
            for (id, name) in genres {
                jsonData[String(id)] = name
            }

            if let data = try? JSONSerialization.data(withJSONObject: jsonData, options: [.prettyPrinted, .sortedKeys]),
               let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
            return
        }

        print("Available App Store Genre IDs:")
        print(String(repeating: "-", count: 40))

        for (id, name) in genres {
            print("  \(id) - \(name)")
        }

        print()
        print("Use with: --genre <id>")
        print("Example: appstore search game --genre 6014")
        print("Example: appstore top free --genre 6014")
    }

    private func listAttributes(outputMode: OutputMode) {
        if outputMode == .json {
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

            if let data = try? JSONSerialization.data(withJSONObject: jsonData, options: [.prettyPrinted, .sortedKeys]),
               let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
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

    private func listChartTypes(outputMode: OutputMode) {
        if outputMode == .json {
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

            if let data = try? JSONSerialization.data(withJSONObject: jsonData, options: [.prettyPrinted, .sortedKeys]),
               let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
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
}