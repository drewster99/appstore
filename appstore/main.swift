//
//  main.swift
//  appstore
//
//  Created by Andrew Benson on 9/18/25.
//

import Foundation

/// App version — single source of truth used by CLI, MCP server info, and version tool.
let appVersion = "0.0.7"

// MCP server mode: run as stdio MCP server when --mcp flag is present
if CommandLine.arguments.contains("--mcp") {
    let server = AppStoreMCPServer()
    try await server.run()
} else {
    await AppStoreCLI.main()
}

struct AppStoreCLI {
    static func main() async {
        let parser = CommandParser()
        let command = parser.parse()

        switch command {
        case .search(let options):
            let searchCommand = SearchCommand()
            await searchCommand.execute(options: options)

        case .lookup(let options):
            let lookupCommand = LookupCommand()
            await lookupCommand.execute(options: options)

        case .top(let options):
            let topCommand = TopCommand()
            await topCommand.execute(options: options)

        case .list(let options):
            let listCommand = ListCommand()
            await listCommand.execute(options: options)

        case .scrape(let options):
            let scrapeCommand = ScrapeCommand()
            await scrapeCommand.execute(options: options)

        case .ranks(let options):
            let ranksCommand = RanksCommand()
            await ranksCommand.execute(options: options)

        case .analyze(let options):
            let analyzeCommand = AnalyzeCommand()
            await analyzeCommand.execute(options: options)

        case .searchHelp:
            HelpCommand.showSearchHelp()

        case .lookupHelp:
            HelpCommand.showLookupHelp()

        case .topHelp:
            HelpCommand.showTopHelp()

        case .listHelp:
            HelpCommand.showListHelp()

        case .scrapeHelp:
            HelpCommand.showScrapeHelp()

        case .ranksHelp:
            HelpCommand.showRanksHelp()

        case .analyzeHelp:
            HelpCommand.showAnalyzeHelp()

        case .help:
            HelpCommand.showGeneralHelp()

        case .usage:
            HelpCommand.showUsage()

        case .unknown(let cmd):
            HelpCommand.showUnknownCommand(cmd)
        }
    }
}
