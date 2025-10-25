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
            list <type>       List available values for various options
            scrape <query>    Search using App Store scraper API (richer data)
            ranks <app-id>    Analyze keyword rankings for an app
            analyze <query>   Analyze top 20 search results with keyword matching

        QUICK EXAMPLES:
            appstore search spotify
            appstore search --limit 5 "photo editor"
            appstore lookup 284910350              # numeric = app ID
            appstore lookup com.spotify.client     # non-numeric = bundle ID
            appstore list storefronts              # list country codes
            appstore list attributes               # list search attributes

        OPTIONS:
            --help, -h        Show help for any command

        For detailed help on a command:
            appstore search --help
            appstore lookup --help
            appstore top --help
            appstore list --help
            appstore scrape --help
            appstore ranks --help
            appstore analyze --help
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
            --show-response-headers Display the HTTP response headers
            --limit <n>            Number of results (1-200, default: 20, 0 for unlimited)
            --unlimited            Don't limit results (same as --limit 0)
            --storefront <code>    Storefront code (e.g., US, JP, GB)
            --country <code>       Alias for --storefront (for compatibility)
            --language <code>      Language for results (e.g., en_us, ja_jp, default: en_us)
            --attribute <attr>     Search specific field:
                                     softwareDeveloper - Developer name only
                                     titleTerm - App title only
                                     descriptionTerm - Description only
                                     artistTerm - Artist/developer name
            --genre <id>           Filter by genre ID (e.g., 6014 for Games)
            --output-format <fmt>  Output format (text, json, raw-json, markdown, html)
            --verbosity <level>    Detail level:
                                     minimal  - Single line per app
                                     summary  - Key details (default)
                                     expanded - Additional info
                                     verbose  - All standard fields
                                     complete - All available fields
            --full-description     Show complete app descriptions

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
            appstore search --storefront JP nintendo
            appstore search --attribute softwareDeveloper "Facebook Inc"
            appstore search --genre 6014 puzzle                # Search in Games category
            appstore search --storefront FR --genre 6014 puzzle   # French Games
            appstore search --verbosity minimal spotify
            appstore search --verbosity verbose "adobe photoshop"
            appstore search --output-format json spotify
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
            --storefront <code>    Storefront code (e.g., US, JP, GB)
            --country <code>       Alias for --storefront (for compatibility)
            --language <code>      Language for results (e.g., en_us, ja_jp, default: en_us)
            --entity <type>        Get related content (e.g., software)
            --show-request         Display the API request details
            --show-response-headers Display the HTTP response headers
            --output-format <fmt>  Output format (text, json, raw-json, markdown, html)
            --verbosity <level>    Detail level:
                                     minimal  - Single line per app
                                     summary  - Key details (default)
                                     expanded - Additional info
                                     verbose  - All standard fields
                                     complete - All available fields
            --help, -h             Display this help message

        EXAMPLES:
            appstore lookup 284910350                    # Smart: numeric = ID
            appstore lookup com.spotify.client           # Smart: non-numeric = bundle ID
            appstore lookup --id 284910350
            appstore lookup --ids 284910350,324684580
            appstore lookup --bundle-id com.spotify.client
            appstore lookup --url "https://apps.apple.com/us/app/yelp/id284910350"
            appstore lookup 284910350 --storefront JP
            appstore lookup com.facebook.Facebook --output-format json
        """)
    }

    static func showTopHelp() {
        print("""
        appstore top - View top charts from the App Store

        USAGE:
            appstore top <chart-type> [options]

        DESCRIPTION:
            Displays top charts from the App Store including top free, paid,
            and grossing apps. Data comes from Apple's RSS feeds.

        CHART TYPES (required):
            free        Top free apps
            paid        Top paid apps
            grossing    Top grossing apps
            newfree     New free apps
            newpaid     New paid apps

        OPTIONS:
            --type <type>          Chart type (free, paid, grossing, newfree, newpaid)
            --limit <n>            Number of results (1-200, default: 25)
            --storefront <code>    Storefront code (e.g., US, JP, GB, default: US)
            --country <code>       Alias for --storefront (for compatibility)
            --language <code>      Language for results (e.g., en_us, ja_jp, default: en_us)
            --genre <id>           Genre ID for filtering (e.g., 6014 for Games)
            --output-format <fmt>  Output format (text, json, raw-json, markdown, html)
            --verbosity <level>    Detail level:
                                     minimal  - Rank, bundle ID, price, name
                                     summary  - Detailed info (default)
                                     expanded - Additional info
                                     verbose  - All standard fields
                                     complete - All available fields
            --help, -h             Display this help message

        GENRE IDS (Common):
            6000 - Business               6014 - Games
            6001 - Weather                6015 - Finance
            6002 - Utilities              6016 - Entertainment
            6003 - Travel                 6017 - Education
            6004 - Sports                 6018 - Books
            6005 - Social Networking      6020 - Medical
            6006 - Reference              6021 - Magazines & Newspapers
            6007 - Productivity           6022 - Catalogs
            6008 - Photo & Video          6023 - Food & Drink
            6009 - News                   6024 - Shopping
            6010 - Navigation             6025 - Stickers
            6011 - Music                  6026 - Developer Tools
            6012 - Lifestyle              6027 - Graphics & Design
            6013 - Health & Fitness

        EXAMPLES:
            appstore top free                      # Top free apps (US)
            appstore top paid                      # Top paid apps
            appstore top grossing --limit 10       # Top 10 grossing apps
            appstore top free --storefront JP      # Top free apps in Japan
            appstore top paid --genre 6014         # Top paid games
            appstore top free --storefront GB --limit 50   # Top 50 free apps in UK
            appstore top newfree --output-format json  # New free apps as JSON
        """)
    }

    static func showUnknownCommand(_ command: String) {
        print("""
        Error: Unknown command '\(command)'

        Available commands:
            search    Search the App Store for apps
            lookup    Look up specific apps by ID or bundle
            top       View top charts from the App Store
            list      List available values for various options
            scrape    Search using App Store scraper API
            ranks     Analyze keyword rankings for an app
            analyze   Analyze top 20 search results with keyword matching
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
          top <chart>       View top charts
          list <type>       List available values
          scrape <query>    Search using App Store scraper API
          ranks <app-id>    Analyze keyword rankings for an app
          analyze <query>   Analyze top 20 search results with keyword matching

        Examples:
          appstore search twitter
          appstore lookup --id 284910350
          appstore top paid
          appstore list genres
          appstore scrape spotify
          appstore ranks 324684580
          appstore analyze "cat toy"

        Try 'appstore --help' for more information.
        """)
    }

    static func showListHelp() {
        print("""
        appstore list - List available values for various options

        USAGE:
            appstore list <type> [--output-format <format>]

        LIST TYPES:
            storefronts    List all available App Store storefronts/country codes
            genres         List all genre IDs for App Store categories
            attributes     List all search attributes for refined searches
            charttypes     List all chart types for top lists

        OPTIONS:
            --output-format <fmt>  Output format (text, json, raw-json)

        EXAMPLES:
            appstore list storefronts
            appstore list genres
            appstore list attributes
            appstore list charttypes
            appstore list storefronts --output-format json

        ALIASES:
            You can use singular or plural forms:
                storefront/storefronts, country/countries
                genre/genres, category/categories
                attribute/attributes
                charttype/charttypes, chart/charts

        The list command helps you discover valid values to use with:
            --storefront   (for search, lookup, and top commands)
            --genre        (for search and top commands)
            --attribute    (for search command)
            Chart types    (for top command)
        """)
    }

    static func showScrapeHelp() {
        print("""
        appstore scrape - Search using the App Store scraper API

        USAGE:
            appstore scrape [options] <query>

        DESCRIPTION:
            Uses the App Store's internal search API (same as app-store-scraper npm package)
            to get richer app data including screenshots, user ratings, and more metadata
            not available through the standard iTunes Search API.

        OPTIONS:
            --help, -h              Display this help message
            --show-request         Display the API request details
            --show-response-headers Display the HTTP response headers
            --show-json             Output results in JSON format
            --show-raw-json         Output raw JSON response without processing
            --output-format <format> Choose output format: json, raw-json
            --storefront <code>      Two-letter country code (default: us)
            --language <code>        Language code (default: en-us)
            --limit <num>            Maximum results to display (default: 25)
            --verbosity <level>      Output detail level:
                                      minimal  - App name only
                                      summary  - Name, developer, price
                                      expanded - Includes ratings, size, version
                                      verbose  - Includes release notes, languages
                                      complete - All available fields

        EXAMPLES:
            appstore scrape spotify
            appstore scrape --limit 5 "photo editor"
            appstore scrape --storefront gb twitter
            appstore scrape --show-json instagram
            appstore scrape --verbosity expanded facebook

        DIFFERENCES FROM 'search':
            - Returns screenshots and icon artwork
            - Includes more detailed rating information
            - Provides subtitle and copyright information
            - Uses different internal API endpoint
            - May return slightly different result ordering
        """)
    }

    static func showRanksHelp() {
        print("""
        appstore ranks - Analyze keyword rankings for an app

        USAGE:
            appstore ranks <app-id> [options]

        DESCRIPTION:
            Analyzes an app's ranking for automatically generated keywords.
            This command:
            1. Fetches the app's details
            2. Generates relevant keywords from the app's name, subtitle, and description
            3. Searches for each keyword to find where the app ranks
            4. Reports competitive analysis for each keyword

        ARGUMENTS:
            <app-id>               The App Store ID of the app to analyze

        OPTIONS:
            --limit <num>          Number of keywords to test (default: 20, max: 50)
            --storefront <code>    Two-letter country code (default: us)
            --language <code>      Language code for keyword generation (default: en-us)
            --verbosity <level>    Output detail level (minimal, summary, expanded)
            --help, -h             Display this help message

        EXAMPLES:
            appstore ranks 324684580                    # Analyze Spotify
            appstore ranks 284910350 --limit 30         # Test 30 keywords for Yelp
            appstore ranks 544007664 --storefront gb    # UK store rankings

        OUTPUT:
            For each keyword, shows:
            - The app's rank (if found in top 200)
            - Top competitor apps for that keyword
            - Apps with most reviews and highest ratings

        NOTE:
            This command makes multiple API calls and may take some time to complete.
            Rate limiting is automatically handled with delays between searches.
        """)
    }

    static func showAnalyzeHelp() {
        print("""
        appstore analyze - Analyze top 20 search results with keyword matching

        USAGE:
            appstore analyze [options] <query>

        DESCRIPTION:
            Performs a search and analyzes the top 20 results with detailed keyword
            matching and statistics. Outputs results in CSV format with comprehensive
            metrics including:
            - Match scores for search terms in title and description
            - App age and freshness metrics
            - Ratings velocity (ratings per day)
            - Comparative statistics for newest vs established apps

        OPTIONS:
            --help, -h              Display this help message
            --show-request         Display the API request details
            --storefront <code>    Two-letter country code (default: US)
            --language <code>      Language code (default: en-us)

        KEYWORD MATCHING:
            The analyze command uses smart keyword matching:
            - Generates word variants (plurals, -ing, -ed forms)
            - Checks for exact phrase matches (counts as 5 points)
            - Removes filter words (a, an, the, and, or, for, with, etc.)
            - Counts individual word matches in title and description

        CSV OUTPUT COLUMNS:
            App ID                 - App Store track ID
            Rating                 - Average user rating (out of 5)
            Rating Count           - Total number of ratings
            Original Release       - First release date (YYYY-MM-DD)
            Latest Release         - Most recent update date (YYYY-MM-DD)
            Age Days               - Days since original release
            Freshness Days         - Days since latest update
            Title Match Score      - Keyword match score in title (5 = exact match)
            Description Match Score - Keyword match score in description
            Ratings Per Day        - Rating velocity (ratings ÷ age in days)
            Title                  - App name

        SUMMARY STATISTICS:
            After the CSV data, displays:
            - Overall metrics for all 20 apps
            - Comparison of newest 30% (6 apps) vs established apps
            - Rating velocity ratios

        EXAMPLES:
            appstore analyze "cat toy"
            appstore analyze --storefront GB "photo editor"
            appstore analyze "music player" > results.csv

        NOTE:
            - Always returns exactly 20 results (no limit configuration)
            - Shows debug output with word variants being matched
            - Uses MZStore API for accurate App Store rankings
        """)
    }
}