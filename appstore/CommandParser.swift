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

                let args = Array(arguments.dropFirst(2))
                let parseResult = CommonOptionsParser.parse(args)

                if let error = parseResult.error {
                    print("Error: \(error)")
                    print("Use 'appstore search --help' to see available options.")
                    return .searchHelp
                }

                var limit = EnvironmentConfig.defaultLimit ?? SearchOptions.defaultLimit
                var attribute = EnvironmentConfig.defaultAttribute
                var genre = EnvironmentConfig.defaultGenre
                var searchTerms = parseResult.remainingArgs

                // Process search-specific flags
                var i = 0
                while i < searchTerms.count {
                    switch searchTerms[i] {
                    case "--unlimited":
                        limit = 0
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
                    commonOptions: parseResult.options,
                    query: query,
                    limit: limit,
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

            // Parse remaining arguments with CommonOptionsParser
            let remainingArgs = Array(arguments.dropFirst(3))
            let parseResult = CommonOptionsParser.parse(remainingArgs)

            if let error = parseResult.error {
                print("Error: \(error)")
                print("Use 'appstore lookup --help' to see available options.")
                return .lookupHelp
            }

            // Process lookup-specific flags
            var entity: String?
            var args = parseResult.remainingArgs
            var i = 0
            while i < args.count {
                switch args[i] {
                case "--entity":
                    args.remove(at: i)
                    if i < args.count {
                        entity = args[i]
                        args.remove(at: i)
                    } else {
                        print("Error: --entity requires a value")
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
                commonOptions: parseResult.options,
                lookupType: lookupType,
                entity: entity
            )
            return .lookup(options: options)
        }

        // Parse all arguments with CommonOptionsParser first
        let args = Array(arguments.dropFirst(2))
        let parseResult = CommonOptionsParser.parse(args)

        if let error = parseResult.error {
            print("Error: \(error)")
            print("Use 'appstore lookup --help' to see available options.")
            return .lookupHelp
        }

        var lookupType: LookupType?
        var entity: String?
        var remainingArgs = parseResult.remainingArgs

        // Process lookup-specific flags
        var i = 0
        while i < remainingArgs.count {
            switch remainingArgs[i] {
            case "--id":
                remainingArgs.remove(at: i)
                if i < remainingArgs.count {
                    lookupType = .id(remainingArgs[i])
                    remainingArgs.remove(at: i)
                } else {
                    print("Error: --id requires a value")
                    return .lookupHelp
                }

            case "--ids":
                remainingArgs.remove(at: i)
                if i < remainingArgs.count {
                    let ids = remainingArgs[i].split(separator: ",").map(String.init)
                    lookupType = .ids(ids)
                    remainingArgs.remove(at: i)
                } else {
                    print("Error: --ids requires comma-separated values")
                    return .lookupHelp
                }

            case "--bundle-id":
                remainingArgs.remove(at: i)
                if i < remainingArgs.count {
                    lookupType = .bundleId(remainingArgs[i])
                    remainingArgs.remove(at: i)
                } else {
                    print("Error: --bundle-id requires a value")
                    return .lookupHelp
                }

            case "--url":
                remainingArgs.remove(at: i)
                if i < remainingArgs.count {
                    lookupType = .url(remainingArgs[i])
                    remainingArgs.remove(at: i)
                } else {
                    print("Error: --url requires a value")
                    return .lookupHelp
                }

            case "--entity":
                remainingArgs.remove(at: i)
                if i < remainingArgs.count {
                    entity = remainingArgs[i]
                    remainingArgs.remove(at: i)
                } else {
                    print("Error: --entity requires a value")
                    return .lookupHelp
                }

            default:
                // Check if it's an unknown flag
                if remainingArgs[i].hasPrefix("--") || (remainingArgs[i].hasPrefix("-") && remainingArgs[i] != "-") {
                    print("Error: Unknown option '\(remainingArgs[i])'")
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
            commonOptions: parseResult.options,
            lookupType: lookupType,
            entity: entity
        )
        return .lookup(options: options)
    }

    private func parseTopCommand() -> Command {
        // If just "appstore top", show help
        if arguments.count == 2 {
            print("Error: Must specify a chart type")
            print("Valid types: free, paid, grossing, newfree, newpaid")
            print("Example: appstore top free")
            return .topHelp
        }

        if arguments.count > 2 && (arguments[2] == "--help" || arguments[2] == "-h") {
            return .topHelp
        }

        // Parse chart type (first non-flag argument)
        var chartType: TopChartType?
        var limit = EnvironmentConfig.defaultLimit ?? 25
        var genre = EnvironmentConfig.defaultGenre
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

        // Check if chart type was set from environment variable
        if chartType == nil && ProcessInfo.processInfo.environment["APPSTORE_DEFAULT_CHART_TYPE"] != nil {
            chartType = EnvironmentConfig.defaultChartType
        }

        // Parse common options with CommonOptionsParser
        let parseResult = CommonOptionsParser.parse(args)
        if let error = parseResult.error {
            print("Error: \(error)")
            print("Use 'appstore top --help' to see available options.")
            return .topHelp
        }

        var remainingArgs = parseResult.remainingArgs

        // Process top-specific flags
        var i = 0
        while i < remainingArgs.count {
            switch remainingArgs[i] {
            case "--type":
                remainingArgs.remove(at: i)
                if i < remainingArgs.count {
                    let typeString = remainingArgs[i].lowercased()
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
                        print("Error: Invalid chart type '\(remainingArgs[i])'")
                        print("Valid types: free, paid, grossing, newfree, newpaid")
                        return .topHelp
                    }
                    remainingArgs.remove(at: i)
                } else {
                    print("Available chart types:")
                    for type in TopChartType.allCases {
                        print("  \(type) - \(type.description)")
                    }
                    return .topHelp
                }

            case "--limit":
                remainingArgs.remove(at: i)
                if i < remainingArgs.count, let limitValue = Int(remainingArgs[i]) {
                    // RSS feeds max at 200
                    limit = min(max(limitValue, 1), 200)
                    remainingArgs.remove(at: i)
                } else {
                    print("Error: --limit requires a numeric value (1-200)")
                    return .topHelp
                }

            case "--genre":
                remainingArgs.remove(at: i)
                if i < remainingArgs.count, let genreId = Int(remainingArgs[i]) {
                    genre = genreId
                    remainingArgs.remove(at: i)
                } else {
                    print("Error: --genre requires a numeric genre ID")
                    return .topHelp
                }

            default:
                if remainingArgs[i].hasPrefix("--") || (remainingArgs[i].hasPrefix("-") && remainingArgs[i] != "-") {
                    print("Error: Unknown option '\(remainingArgs[i])'")
                    print("Use 'appstore top --help' to see available options.")
                    return .topHelp
                }
                i += 1
            }
        }

        // Ensure chart type is set
        guard let finalChartType = chartType else {
            print("Error: Must specify a chart type")
            print("Valid types: free, paid, grossing, newfree, newpaid")
            print("Example: appstore top free")
            return .topHelp
        }

        let options = TopOptions(
            commonOptions: parseResult.options,
            chartType: finalChartType,
            limit: limit,
            genre: genre
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

        // Parse common options with CommonOptionsParser
        let parseResult = CommonOptionsParser.parse(args)
        if let error = parseResult.error {
            print("Error: \(error)")
            print("Use 'appstore list --help' to see available options.")
            return .listHelp
        }

        // No list-specific flags currently

        guard let listType = listType else {
            return .listHelp
        }

        let options = ListOptions(
            commonOptions: parseResult.options,
            listType: listType
        )
        return .list(options: options)
    }
}
