import Foundation

class HelpCommand {
    static func showGeneralHelp() {
        print("""
        appstore - Command line tool for the iTunes/App Store API

        USAGE:
            appstore <command> [options]

        COMMANDS:
            search <query>    Search for apps by name, developer, or description
            lookup            Look up specific apps by ID, bundle ID, or URL
            top [chart]       View top charts from the App Store

        QUICK EXAMPLES:
            appstore search spotify
            appstore search --limit 5 "photo editor"
            appstore lookup 284910350              # numeric = app ID
            appstore lookup com.spotify.client     # non-numeric = bundle ID

        OPTIONS:
            --help, -h        Show help for any command

        For detailed help on a command:
            appstore search --help
            appstore lookup --help
            appstore top --help
        """)
    }

    static func showSearchHelp() {
        print("""
        appstore search - Search the App Store for applications

        USAGE:
            appstore search [options] <query>

        DESCRIPTION:
            Searches the App Store using the iTunes Search API and displays
            matching applications with their details.

        OPTIONS:
            --help, -h              Display this help message
            --show-request         Display the API request details
            --limit <n>            Number of results (1-200, default: 20, 0 for unlimited)
            --unlimited            Don't limit results (same as --limit 0)
            --country <code>       Country code (e.g., us, jp, gb)
            --attribute <attr>     Search specific field:
                                     softwareDeveloper - Developer name only
                                     titleTerm - App title only
                                     descriptionTerm - Description only
                                     artistTerm - Artist/developer name
            --genre <id>           Filter by genre ID (e.g., 6014 for Games)
            --output-mode <mode>   Output format:
                                     oneline  - Single line per app
                                     summary  - Key details (default)
                                     expanded - Additional info (size, ratings, advisories)
                                     verbose  - All standard fields plus URLs
                                     complete - All JSON fields displayed
                                     json     - Raw JSON response (pretty-printed)

        SEARCH TIPS:
            • Use quotes for multi-word searches: appstore search "photo editor"
            • Search by app name: appstore search instagram
            • Search by developer: appstore search "facebook inc"
            • Search by category: appstore search "puzzle games"
            • Search by keyword: appstore search productivity

        DISPLAYED INFORMATION:
            • App name and developer
            • Price
            • Rating and review count
            • Category
            • Version and bundle ID
            • Brief description

        EXAMPLES:
            appstore search twitter
            appstore search "video editor"
            appstore search --limit 5 minecraft
            appstore search --country jp nintendo
            appstore search --attribute softwareDeveloper "Facebook Inc"
            appstore search --genre 6014 puzzle                # Search in Games category
            appstore search --country fr --genre 6014 puzzle   # French Games
            appstore search --output-mode oneline spotify
            appstore search --output-mode verbose "adobe photoshop"
            appstore search --output-mode json spotify
            appstore search --unlimited "photo editor"
            appstore search --show-request twitter
        """)
    }

    static func showLookupHelp() {
        print("""
        appstore lookup - Look up specific apps in the App Store

        USAGE:
            appstore lookup <id-or-bundle> [options]
            appstore lookup [options]

        DESCRIPTION:
            Looks up apps using specific identifiers like app ID, bundle ID,
            or App Store URL. Faster and more precise than searching.

            Smart lookup: If you provide just a value without flags:
            - Numeric values are treated as app IDs
            - Non-numeric values are treated as bundle IDs

        REQUIRED (one of):
            --id <id>              Look up app by its track ID
            --ids <id1,id2,...>    Look up multiple apps by comma-separated IDs
            --bundle-id <bundle>   Look up app by bundle identifier
            --url <url>            Look up app by App Store URL

        OPTIONS:
            --country <code>       Country code (e.g., us, jp, gb)
            --entity <type>        Get related content (e.g., software)
            --show-request         Display the API request details
            --output-mode <mode>   Output format:
                                     oneline  - Single line per app
                                     summary  - Key details (default)
                                     expanded - Additional info (size, ratings)
                                     verbose  - All standard fields plus URLs
                                     complete - All JSON fields displayed
                                     json     - Raw JSON response (pretty-printed)
            --help, -h             Display this help message

        EXAMPLES:
            appstore lookup 284910350                    # Smart: numeric = ID
            appstore lookup com.spotify.client           # Smart: non-numeric = bundle ID
            appstore lookup --id 284910350
            appstore lookup --ids 284910350,324684580
            appstore lookup --bundle-id com.spotify.client
            appstore lookup --url "https://apps.apple.com/us/app/yelp/id284910350"
            appstore lookup 284910350 --country jp
            appstore lookup com.facebook.Facebook --output-mode json
        """)
    }

    static func showTopHelp() {
        print("""
        appstore top - View top charts from the App Store

        USAGE:
            appstore top [chart-type] [options]

        DESCRIPTION:
            Displays top charts from the App Store including top free, paid,
            and grossing apps. Data comes from Apple's RSS feeds.

        CHART TYPES:
            free        Top free apps (default)
            paid        Top paid apps
            grossing    Top grossing apps
            newfree     New free apps
            newpaid     New paid apps

        OPTIONS:
            --type <type>          Chart type (free, paid, grossing, newfree, newpaid)
            --limit <n>            Number of results (1-200, default: 25)
            --country <code>       Country code (e.g., us, jp, gb, default: us)
            --genre <id>           Genre ID for filtering (e.g., 6014 for Games)
            --output-mode <mode>   Output format:
                                     oneline  - Rank, bundle ID, price, name
                                     summary  - Detailed info (default)
                                     json     - Raw JSON response
            --help, -h             Display this help message

        GENRE IDS (Common):
            6000 - Business               6014 - Games
            6001 - Weather                6015 - Entertainment
            6002 - Utilities              6016 - Finance
            6003 - Travel                 6017 - Medical
            6004 - Sports                 6018 - Navigation
            6005 - Social Networking      6020 - Reference
            6006 - Productivity           6021 - Health & Fitness
            6007 - Photo & Video          6022 - Music
            6008 - News                   6023 - Food & Drink
            6009 - Graphics & Design      6024 - Lifestyle
            6010 - Developer Tools        6025 - Magazines & Newspapers
            6011 - Reference              6026 - Shopping
            6012 - Medical                6027 - Stickers
            6013 - Music

        EXAMPLES:
            appstore top                           # Top free apps (US)
            appstore top paid                      # Top paid apps
            appstore top grossing --limit 10       # Top 10 grossing apps
            appstore top free --country jp         # Top free apps in Japan
            appstore top paid --genre 6014         # Top paid games
            appstore top --country gb --limit 50   # Top 50 free apps in UK
            appstore top newfree --output-mode json  # New free apps as JSON
        """)
    }

    static func showUnknownCommand(_ command: String) {
        print("""
        Error: Unknown command '\(command)'

        Available commands:
            search    Search the App Store for apps
            lookup    Look up specific apps by ID or bundle
            top       View top charts from the App Store
            --help    Display help information

        Use 'appstore --help' for more information.
        """)
    }

    static func showUsage() {
        print("""
        Usage: appstore <command> [options]

        Commands:
          search <query>    Search for apps
          lookup            Look up specific apps
          top [chart]       View top charts

        Examples:
          appstore search twitter
          appstore lookup --id 284910350
          appstore top paid

        Try 'appstore --help' for more information.
        """)
    }
}