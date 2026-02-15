import XCTest
@testable import appstore

class CommandParserTests: XCTestCase {

    func testSearchCommandBasic() {
        let parser = CommandParser(arguments: ["appstore", "search", "spotify"])
        let command = parser.parse()

        switch command {
        case .search(let options):
            XCTAssertEqual(options.query, "spotify")
            XCTAssertEqual(options.limit, SearchOptions.defaultLimit)
            XCTAssertNil(options.storefront)
            XCTAssertNil(options.attribute)
        default:
            XCTFail("Expected search command")
        }
    }

    func testSearchCommandWithLimit() {
        let parser = CommandParser(arguments: ["appstore", "search", "--limit", "5", "twitter"])
        let command = parser.parse()

        switch command {
        case .search(let options):
            XCTAssertEqual(options.query, "twitter")
            XCTAssertEqual(options.limit, 5)
        default:
            XCTFail("Expected search command")
        }
    }

    func testSearchCommandWithStorefront() {
        let parser = CommandParser(arguments: ["appstore", "search", "--storefront", "gb", "game"])
        let command = parser.parse()

        switch command {
        case .search(let options):
            XCTAssertEqual(options.query, "game")
            XCTAssertEqual(options.storefront, "gb")
        default:
            XCTFail("Expected search command")
        }
    }

    func testSearchCommandWithAttribute() {
        let parser = CommandParser(arguments: ["appstore", "search", "--attribute", "softwareDeveloper", "OpenAI"])
        let command = parser.parse()

        switch command {
        case .search(let options):
            XCTAssertEqual(options.query, "OpenAI")
            XCTAssertEqual(options.attribute, "softwareDeveloper")
        default:
            XCTFail("Expected search command")
        }
    }

    func testSearchCommandWithOutputFile() {
        let parser = CommandParser(arguments: ["appstore", "search", "--output-file", "/tmp/test.json", "app"])
        let command = parser.parse()

        switch command {
        case .search(let options):
            XCTAssertEqual(options.query, "app")
            XCTAssertEqual(options.outputFile, "/tmp/test.json")
        default:
            XCTFail("Expected search command")
        }
    }

    func testLookupCommandWithId() {
        let parser = CommandParser(arguments: ["appstore", "lookup", "--id", "284910350"])
        let command = parser.parse()

        switch command {
        case .lookup(let options):
            switch options.lookupType {
            case .id(let id):
                XCTAssertEqual(id, "284910350")
            default:
                XCTFail("Expected ID lookup type")
            }
        default:
            XCTFail("Expected lookup command")
        }
    }

    func testLookupCommandSmartDetection() {
        // Test numeric ID detection
        let parser1 = CommandParser(arguments: ["appstore", "lookup", "284910350"])
        let command1 = parser1.parse()

        switch command1 {
        case .lookup(let options):
            switch options.lookupType {
            case .id(let id):
                XCTAssertEqual(id, "284910350")
            default:
                XCTFail("Expected ID lookup type")
            }
        default:
            XCTFail("Expected lookup command")
        }

        // Test bundle ID detection
        let parser2 = CommandParser(arguments: ["appstore", "lookup", "com.spotify.client"])
        let command2 = parser2.parse()

        switch command2 {
        case .lookup(let options):
            switch options.lookupType {
            case .bundleId(let bundleId):
                XCTAssertEqual(bundleId, "com.spotify.client")
            default:
                XCTFail("Expected bundle ID lookup type")
            }
        default:
            XCTFail("Expected lookup command")
        }
    }

    func testTopCommandDefault() {
        let parser = CommandParser(arguments: ["appstore", "top"])
        let command = parser.parse()

        switch command {
        case .top(let options):
            XCTAssertEqual(options.chartType, EnvironmentConfig.defaultChartType)
            XCTAssertEqual(options.storefront, EnvironmentConfig.defaultStorefront)
        default:
            XCTFail("Expected top command")
        }
    }

    func testTopCommandWithChartType() {
        let parser = CommandParser(arguments: ["appstore", "top", "paid"])
        let command = parser.parse()

        switch command {
        case .top(let options):
            XCTAssertEqual(options.chartType, .paid)
        default:
            XCTFail("Expected top command")
        }
    }

    func testListCommand() {
        let parser = CommandParser(arguments: ["appstore", "list", "storefronts"])
        let command = parser.parse()

        switch command {
        case .list(let options):
            XCTAssertEqual(options.listType, .storefronts)
        default:
            XCTFail("Expected list command")
        }
    }

    func testHelpCommand() {
        let parser = CommandParser(arguments: ["appstore", "--help"])
        let command = parser.parse()

        switch command {
        case .help:
            // Success
            break
        default:
            XCTFail("Expected help command")
        }
    }

    func testUnknownCommand() {
        let parser = CommandParser(arguments: ["appstore", "invalid"])
        let command = parser.parse()

        switch command {
        case .unknown(let cmd):
            XCTAssertEqual(cmd, "invalid")
        default:
            XCTFail("Expected unknown command")
        }
    }
}