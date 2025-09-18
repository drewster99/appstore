import Foundation

class HelpCommand {
    static func showGeneralHelp() {
        print("""
        appstore - Command line tool for searching the App Store

        USAGE:
            appstore <command> [options]

        COMMANDS:
            search <query>    Search the App Store for apps
            --help, -h        Display this help message

        EXAMPLES:
            appstore search twitter
            appstore search "photo editor"
            appstore search --help
            appstore --help

        For more information about a specific command, use:
            appstore <command> --help
        """)
    }

    static func showSearchHelp() {
        print("""
        appstore search - Search the App Store for applications

        USAGE:
            appstore search <query>

        DESCRIPTION:
            Searches the App Store using the iTunes Search API and displays
            matching applications with their details.

        OPTIONS:
            --help, -h    Display this help message

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
            appstore search minecraft
            appstore search "adobe photoshop"
        """)
    }

    static func showUnknownCommand(_ command: String) {
        print("""
        Error: Unknown command '\(command)'

        Available commands:
            search    Search the App Store for apps
            --help    Display help information

        Use 'appstore --help' for more information.
        """)
    }

    static func showUsage() {
        print("""
        Usage: appstore <command> [options]
        Try 'appstore --help' for more information.
        """)
    }
}