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
        case .search(let query):
            let searchCommand = SearchCommand()
            await searchCommand.execute(query: query)

        case .searchHelp:
            HelpCommand.showSearchHelp()

        case .help:
            HelpCommand.showGeneralHelp()

        case .unknown(let cmd):
            HelpCommand.showUnknownCommand(cmd)
        }
    }
}

await AppStoreCLI.main()

