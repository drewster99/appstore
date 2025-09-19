//
//  main.swift
//  appstore
//
//  Created by Andrew Benson on 9/18/25.
//

import Foundation

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
            listCommand.execute(options: options)

        case .searchHelp:
            HelpCommand.showSearchHelp()

        case .lookupHelp:
            HelpCommand.showLookupHelp()

        case .topHelp:
            HelpCommand.showTopHelp()

        case .listHelp:
            HelpCommand.showListHelp()

        case .help:
            HelpCommand.showGeneralHelp()

        case .usage:
            HelpCommand.showUsage()

        case .unknown(let cmd):
            HelpCommand.showUnknownCommand(cmd)
        }
    }
}

await AppStoreCLI.main()

