import Foundation

// Environment variable configuration
struct EnvironmentConfig {
    // Core defaults
    static let defaultStorefront = ProcessInfo.processInfo.environment["APPSTORE_DEFAULT_STOREFRONT"] ?? "us"

    static var defaultLimit: Int? {
        guard let value = ProcessInfo.processInfo.environment["APPSTORE_DEFAULT_LIMIT"] else { return nil }
        if value.lowercased() == "unlimited" {
            return 0
        }
        return Int(value)
    }

    static var defaultVerbosity: Verbosity? {
        guard let value = ProcessInfo.processInfo.environment["APPSTORE_DEFAULT_VERBOSITY"],
              let verbosity = Verbosity(rawValue: value.lowercased()) else {
            return nil
        }
        return verbosity
    }

    static var defaultOutputFormat: OutputFormat? {
        guard let value = ProcessInfo.processInfo.environment["APPSTORE_DEFAULT_FORMAT"],
              let format = OutputFormat.from(cliName: value.lowercased()) else {
            return nil
        }
        return format
    }

    // Feature defaults
    static var defaultGenre: Int? {
        guard let value = ProcessInfo.processInfo.environment["APPSTORE_DEFAULT_GENRE"] else { return nil }
        return Int(value)
    }

    static let defaultAttribute = ProcessInfo.processInfo.environment["APPSTORE_DEFAULT_ATTRIBUTE"]

    static var defaultChartType: TopChartType? {
        guard let value = ProcessInfo.processInfo.environment["APPSTORE_DEFAULT_CHART_TYPE"] else {
            return nil
        }

        // Map common names to chart types
        switch value.lowercased() {
        case "free", "topfree", "topfreeapplications":
            return .free
        case "paid", "toppaid", "toppaidapplications":
            return .paid
        case "grossing", "topgrossing", "topgrossingapplications":
            return .grossing
        case "newfree", "new-free", "newfreeapplications":
            return .newFree
        case "newpaid", "new-paid", "newpaidapplications":
            return .newPaid
        default:
            return nil
        }
    }

    // Behavior
    static var showRequest: Bool {
        return ProcessInfo.processInfo.environment["APPSTORE_SHOW_REQUEST"]?.lowercased() == "true"
    }

    static var noColor: Bool {
        return ProcessInfo.processInfo.environment["APPSTORE_NO_COLOR"]?.lowercased() == "true"
    }

    static var cacheTTL: Int {
        guard let value = ProcessInfo.processInfo.environment["APPSTORE_CACHE_TTL"],
              let ttl = Int(value) else {
            return 300 // 5 minutes default
        }
        return ttl
    }
}