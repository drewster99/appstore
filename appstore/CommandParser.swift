import Foundation

enum Command {
    case search(options: SearchOptions)
    case lookup(options: LookupOptions)
    case top(options: TopOptions)
    case list(options: ListOptions)
    case help
    case usage
    case searchHelp
    case lookupHelp
    case topHelp
    case listHelp
    case unknown(String)
}

class CommandParser {
    private let arguments: [String]

    init(arguments: [String] = CommandLine.arguments) {
        self.arguments = arguments
    }

    func parse() -> Command {
        guard arguments.count > 1 else {
            return .usage
        }

        let command = arguments[1].lowercased()

        switch command {
        case "--help", "-h", "help":
            return .help

        case "search":
            if arguments.count > 2 {
                if arguments[2] == "--help" || arguments[2] == "-h" {
                    return .searchHelp
                }

                var showRequest = EnvironmentConfig.showRequest
                var limit = EnvironmentConfig.defaultLimit ?? SearchOptions.defaultLimit
                var outputMode = OutputMode.default
                var storefront = EnvironmentConfig.defaultStorefront != "us" ? EnvironmentConfig.defaultStorefront : nil
                var attribute = EnvironmentConfig.defaultAttribute
                var genre = EnvironmentConfig.defaultGenre
                var searchTerms = Array(arguments.dropFirst(2))

                // Process all flags
                var i = 0
                while i < searchTerms.count {
                    switch searchTerms[i] {
                    case "--unlimited":
                        limit = 0
                        searchTerms.remove(at: i)

                    case "--show-request":
                        showRequest = true
                        searchTerms.remove(at: i)

                    case "--limit":
                        searchTerms.remove(at: i)
                        if i < searchTerms.count, let limitValue = Int(searchTerms[i]) {
                            if limitValue == 0 {
                                limit = 0  // Unlimited
                            } else {
                                limit = min(max(limitValue, 1), SearchOptions.maxLimit)
                            }
                            searchTerms.remove(at: i)
                        } else {
                            print("Error: --limit requires a numeric value")
                            return .searchHelp
                        }

                    case "--output-mode":
                        searchTerms.remove(at: i)
                        if i < searchTerms.count {
                            let modeString = searchTerms[i].lowercased()
                            if let mode = OutputMode(rawValue: modeString) {
                                outputMode = mode
                                searchTerms.remove(at: i)
                            } else {
                                print("Error: Invalid output mode '\(searchTerms[i])'")
                                print("Valid modes: \(OutputMode.allCases.map { $0.rawValue }.joined(separator: ", "))")
                                return .searchHelp
                            }
                        } else {
                            print("Available output modes:")
                            for mode in OutputMode.allCases {
                                print("  \(mode.rawValue) - \(mode.description)")
                            }
                            return .searchHelp
                        }

                    case "--country", "--storefront":
                        let flag = searchTerms[i]
                        searchTerms.remove(at: i)
                        if i < searchTerms.count {
                            storefront = searchTerms[i]
                            searchTerms.remove(at: i)
                        } else {
                            print("Error: \(flag) requires a value")
                            return .searchHelp
                        }

                    case "--attribute":
                        searchTerms.remove(at: i)
                        if i < searchTerms.count {
                            attribute = searchTerms[i]
                            searchTerms.remove(at: i)
                        } else {
                            print("Recommended attributes for app search:")
                            for attr in SearchAttribute.allCases where attr.isRecommendedForSoftware {
                                print("  \(attr.rawValue) - \(attr.description)")
                            }
                            print("\nOther available attributes (less useful for apps):")
                            for attr in SearchAttribute.allCases where !attr.isRecommendedForSoftware {
                                print("  \(attr.rawValue) - \(attr.description)")
                            }
                            return .searchHelp
                        }

                    case "--genre":
                        searchTerms.remove(at: i)
                        if i < searchTerms.count, let genreId = Int(searchTerms[i]) {
                            genre = genreId
                            searchTerms.remove(at: i)
                        } else {
                            print("Error: --genre requires a numeric genre ID")
                            print("Common genre IDs:")
                            print("  6014 - Games")
                            print("  6016 - Entertainment")
                            print("  6005 - Social Networking")
                            print("  6007 - Photo & Video")
                            print("  6022 - Music")
                            print("  6021 - Health & Fitness")
                            print("Use 'appstore top --help' for a full list of genre IDs")
                            return .searchHelp
                        }

                    default:
                        // Check if it's an unknown flag
                        if searchTerms[i].hasPrefix("--") || (searchTerms[i].hasPrefix("-") && searchTerms[i] != "-") {
                            print("Error: Unknown option '\(searchTerms[i])'")
                            print("Use 'appstore search --help' to see available options.")
                            return .searchHelp
                        }
                        i += 1
                    }
                }

                // Ensure we still have search terms after removing flags
                guard !searchTerms.isEmpty else {
                    return .searchHelp
                }

                let query = searchTerms.joined(separator: " ")
                let options = SearchOptions(
                    query: query,
                    showRequest: showRequest,
                    limit: limit,
                    outputMode: outputMode,
                    storefront: storefront,
                    attribute: attribute,
                    genre: genre
                )
                return .search(options: options)
            } else {
                return .searchHelp
            }

        case "lookup":
            return parseLookupCommand()

        case "top":
            return parseTopCommand()

        case "list":
            return parseListCommand()

        default:
            return .unknown(command)
        }
    }

    private func parseLookupCommand() -> Command {
        guard arguments.count > 2 else {
            return .lookupHelp
        }

        if arguments[2] == "--help" || arguments[2] == "-h" {
            return .lookupHelp
        }

        // Check for smart argument (just a value without a flag)
        let firstArg = arguments[2]
        if !firstArg.hasPrefix("--") && !firstArg.hasPrefix("-") {
            // It's a value without a flag - determine if it's an ID or bundle ID
            let lookupType: LookupType
            if firstArg.allSatisfy({ $0.isNumber }) {
                // All numeric - treat as ID
                lookupType = .id(firstArg)
            } else {
                // Contains non-numeric characters - treat as bundle ID
                lookupType = .bundleId(firstArg)
            }

            // Check if there are additional options after the value
            var showRequest = EnvironmentConfig.showRequest
            var outputMode = OutputMode.default
            var storefront = EnvironmentConfig.defaultStorefront != "us" ? EnvironmentConfig.defaultStorefront : nil
            var entity: String?
            var args = Array(arguments.dropFirst(3)) // Skip the value we already processed

            // Process remaining flags
            var i = 0
            while i < args.count {
                switch args[i] {

                case "--show-request":
                    showRequest = true
                    args.remove(at: i)

                case "--country", "--storefront":
                    let flag = args[i]
                    args.remove(at: i)
                    if i < args.count {
                        storefront = args[i]
                        args.remove(at: i)
                    } else {
                        print("Error: \(flag) requires a value")
                        return .lookupHelp
                    }

                case "--output-mode":
                    args.remove(at: i)
                    if i < args.count {
                        let modeString = args[i].lowercased()
                        if let mode = OutputMode(rawValue: modeString) {
                            outputMode = mode
                            args.remove(at: i)
                        } else {
                            print("Error: Invalid output mode '\(args[i])'")
                            print("Valid modes: \(OutputMode.allCases.map { $0.rawValue }.joined(separator: ", "))")
                            return .lookupHelp
                        }
                    } else {
                        print("Available output modes:")
                        for mode in OutputMode.allCases {
                            print("  \(mode.rawValue) - \(mode.description)")
                        }
                        return .lookupHelp
                    }

                default:
                    if args[i].hasPrefix("--") || (args[i].hasPrefix("-") && args[i] != "-") {
                        print("Error: Unknown option '\(args[i])'")
                        print("Use 'appstore lookup --help' to see available options.")
                        return .lookupHelp
                    }
                    i += 1
                }
            }

            let options = LookupOptions(
                lookupType: lookupType,
                showRequest: showRequest,
                outputMode: outputMode,
                storefront: storefront,
                entity: entity
            )
            return .lookup(options: options)
        }

        var showRequest = EnvironmentConfig.showRequest
        var outputMode = OutputMode.default
        var storefront = EnvironmentConfig.defaultStorefront != "us" ? EnvironmentConfig.defaultStorefront : nil
        var entity: String?
        var lookupType: LookupType?
        var args = Array(arguments.dropFirst(2))

        // Process all flags
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--id":
                args.remove(at: i)
                if i < args.count {
                    lookupType = .id(args[i])
                    args.remove(at: i)
                } else {
                    print("Error: --id requires a value")
                    return .lookupHelp
                }

            case "--ids":
                args.remove(at: i)
                if i < args.count {
                    let ids = args[i].split(separator: ",").map(String.init)
                    lookupType = .ids(ids)
                    args.remove(at: i)
                } else {
                    print("Error: --ids requires comma-separated values")
                    return .lookupHelp
                }

            case "--bundle-id":
                args.remove(at: i)
                if i < args.count {
                    lookupType = .bundleId(args[i])
                    args.remove(at: i)
                } else {
                    print("Error: --bundle-id requires a value")
                    return .lookupHelp
                }

            case "--url":
                args.remove(at: i)
                if i < args.count {
                    lookupType = .url(args[i])
                    args.remove(at: i)
                } else {
                    print("Error: --url requires a value")
                    return .lookupHelp
                }

            case "--country", "--storefront":
                let flag = args[i]
                args.remove(at: i)
                if i < args.count {
                    storefront = args[i]
                    args.remove(at: i)
                } else {
                    print("Error: \(flag) requires a value")
                    return .lookupHelp
                }

            case "--entity":
                args.remove(at: i)
                if i < args.count {
                    entity = args[i]
                    args.remove(at: i)
                } else {
                    print("Error: --entity requires a value")
                    return .lookupHelp
                }


            case "--show-request":
                showRequest = true
                args.remove(at: i)

            case "--output-mode":
                args.remove(at: i)
                if i < args.count {
                    let modeString = args[i].lowercased()
                    if let mode = OutputMode(rawValue: modeString) {
                        outputMode = mode
                        args.remove(at: i)
                    } else {
                        print("Error: Invalid output mode '\(args[i])'")
                        print("Valid modes: \(OutputMode.allCases.map { $0.rawValue }.joined(separator: ", "))")
                        return .lookupHelp
                    }
                } else {
                    print("Available output modes:")
                    for mode in OutputMode.allCases {
                        print("  \(mode.rawValue) - \(mode.description)")
                    }
                    return .lookupHelp
                }

            default:
                // Check if it's an unknown flag
                if args[i].hasPrefix("--") || (args[i].hasPrefix("-") && args[i] != "-") {
                    print("Error: Unknown option '\(args[i])'")
                    print("Use 'appstore lookup --help' to see available options.")
                    return .lookupHelp
                }
                // If it's not a flag and we don't have a lookup type yet, it's an error
                if lookupType == nil {
                    print("Error: Must specify lookup type (--id, --ids, --bundle-id, or --url)")
                    return .lookupHelp
                }
                i += 1
            }
        }

        // Ensure we have a lookup type
        guard let lookupType = lookupType else {
            print("Error: Must specify lookup type (--id, --ids, --bundle-id, or --url)")
            return .lookupHelp
        }

        let options = LookupOptions(
            lookupType: lookupType,
            showRequest: showRequest,
            outputMode: outputMode,
            storefront: storefront,
            entity: entity
        )
        return .lookup(options: options)
    }

    private func parseTopCommand() -> Command {
        // If just "appstore top", default to top free
        if arguments.count == 2 {
            // Use default options with environment config
            let options = TopOptions(
                chartType: EnvironmentConfig.defaultChartType,
                limit: EnvironmentConfig.defaultLimit ?? 25,
                storefront: EnvironmentConfig.defaultStorefront,
                genre: EnvironmentConfig.defaultGenre,
                outputMode: OutputMode.default
            )
            return .top(options: options)
        }

        if arguments.count > 2 && (arguments[2] == "--help" || arguments[2] == "-h") {
            return .topHelp
        }

        // Parse chart type (first non-flag argument)
        var chartType = EnvironmentConfig.defaultChartType
        var limit = EnvironmentConfig.defaultLimit ?? 25
        var storefront = EnvironmentConfig.defaultStorefront
        var genre = EnvironmentConfig.defaultGenre
        var outputMode = OutputMode.default
        var args = Array(arguments.dropFirst(2))

        // Check if first argument is a chart type
        if !args.isEmpty && !args[0].hasPrefix("--") && !args[0].hasPrefix("-") {
            let typeString = args[0].lowercased()
            // Map common names to chart types
            switch typeString {
            case "free", "topfree":
                chartType = .free
            case "paid", "toppaid":
                chartType = .paid
            case "grossing", "topgrossing":
                chartType = .grossing
            case "newfree", "new-free":
                chartType = .newFree
            case "newpaid", "new-paid":
                chartType = .newPaid
            default:
                print("Error: Unknown chart type '\(typeString)'")
                print("Valid types: free, paid, grossing, newfree, newpaid")
                return .topHelp
            }
            args.removeFirst()
        }

        // Process flags
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--type":
                args.remove(at: i)
                if i < args.count {
                    let typeString = args[i].lowercased()
                    switch typeString {
                    case "free":
                        chartType = .free
                    case "paid":
                        chartType = .paid
                    case "grossing":
                        chartType = .grossing
                    case "newfree", "new-free":
                        chartType = .newFree
                    case "newpaid", "new-paid":
                        chartType = .newPaid
                    default:
                        print("Error: Invalid chart type '\(args[i])'")
                        print("Valid types: free, paid, grossing, newfree, newpaid")
                        return .topHelp
                    }
                    args.remove(at: i)
                } else {
                    print("Available chart types:")
                    for type in TopChartType.allCases {
                        print("  \(type) - \(type.description)")
                    }
                    return .topHelp
                }

            case "--limit":
                args.remove(at: i)
                if i < args.count, let limitValue = Int(args[i]) {
                    // RSS feeds max at 200
                    limit = min(max(limitValue, 1), 200)
                    args.remove(at: i)
                } else {
                    print("Error: --limit requires a numeric value (1-200)")
                    return .topHelp
                }

            case "--country", "--storefront":
                let flag = args[i]
                args.remove(at: i)
                if i < args.count {
                    storefront = args[i].lowercased()
                    args.remove(at: i)
                } else {
                    print("Error: \(flag) requires a value")
                    return .topHelp
                }

            case "--genre":
                args.remove(at: i)
                if i < args.count, let genreId = Int(args[i]) {
                    genre = genreId
                    args.remove(at: i)
                } else {
                    print("Error: --genre requires a numeric genre ID")
                    return .topHelp
                }

            case "--output-mode":
                args.remove(at: i)
                if i < args.count {
                    let modeString = args[i].lowercased()
                    if let mode = OutputMode(rawValue: modeString) {
                        outputMode = mode
                        args.remove(at: i)
                    } else {
                        print("Error: Invalid output mode '\(args[i])'")
                        print("Valid modes: \(OutputMode.allCases.map { $0.rawValue }.joined(separator: ", "))")
                        return .topHelp
                    }
                } else {
                    print("Available output modes:")
                    for mode in OutputMode.allCases {
                        print("  \(mode.rawValue) - \(mode.description)")
                    }
                    return .topHelp
                }

            default:
                if args[i].hasPrefix("--") || (args[i].hasPrefix("-") && args[i] != "-") {
                    print("Error: Unknown option '\(args[i])'")
                    print("Use 'appstore top --help' to see available options.")
                    return .topHelp
                }
                i += 1
            }
        }

        let options = TopOptions(
            chartType: chartType,
            limit: limit,
            storefront: storefront,
            genre: genre,
            outputMode: outputMode
        )
        return .top(options: options)
    }

    private func parseListCommand() -> Command {
        // If just "appstore list", show help
        if arguments.count == 2 {
            return .listHelp
        }

        if arguments.count > 2 && (arguments[2] == "--help" || arguments[2] == "-h") {
            return .listHelp
        }

        var listType: ListType?
        var outputMode = OutputMode.default
        var args = Array(arguments.dropFirst(2))

        // Check if first argument is a list type
        if !args.isEmpty && !args[0].hasPrefix("--") && !args[0].hasPrefix("-") {
            let typeString = args[0].lowercased()
            switch typeString {
            case "storefronts", "storefront", "countries", "country":
                listType = .storefronts
            case "genres", "genre", "categories", "category":
                listType = .genres
            case "attributes", "attribute":
                listType = .attributes
            case "charttypes", "charttype", "charts", "chart":
                listType = .charttypes
            default:
                print("Error: Unknown list type '\(typeString)'")
                print("Valid types: storefronts, genres, attributes, charttypes")
                return .listHelp
            }
            args.removeFirst()
        }

        // Process flags
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--output-mode":
                args.remove(at: i)
                if i < args.count {
                    let modeString = args[i].lowercased()
                    if let mode = OutputMode(rawValue: modeString) {
                        outputMode = mode
                        args.remove(at: i)
                    } else {
                        print("Error: Invalid output mode '\(args[i])'")
                        print("Valid modes: \(OutputMode.allCases.map { $0.rawValue }.joined(separator: ", "))")
                        return .listHelp
                    }
                } else {
                    print("Available output modes:")
                    for mode in OutputMode.allCases {
                        print("  \(mode.rawValue) - \(mode.description)")
                    }
                    return .listHelp
                }

            default:
                if args[i].hasPrefix("--") || (args[i].hasPrefix("-") && args[i] != "-") {
                    print("Error: Unknown option '\(args[i])'")
                    print("Use 'appstore list --help' to see available options.")
                    return .listHelp
                }
                i += 1
            }
        }

        guard let listType = listType else {
            return .listHelp
        }

        let options = ListOptions(
            listType: listType,
            outputMode: outputMode
        )
        return .list(options: options)
    }
}