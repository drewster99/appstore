import XCTest
@testable import appstore

class OutputOptionsTests: XCTestCase {

    func testOutputModeCompatibility() {
        // Test conversion from OutputMode to OutputOptions
        let jsonOptions = OutputOptions.fromOutputMode(.json)
        XCTAssertEqual(jsonOptions.format, .json)
        XCTAssertEqual(jsonOptions.verbosity, .complete)

        let summaryOptions = OutputOptions.fromOutputMode(.summary)
        XCTAssertEqual(summaryOptions.format, .text)
        XCTAssertEqual(summaryOptions.verbosity, .summary)

        let onelineOptions = OutputOptions.fromOutputMode(.oneline)
        XCTAssertEqual(onelineOptions.format, .text)
        XCTAssertEqual(onelineOptions.verbosity, .minimal)
    }

    func testOutputModeRoundTrip() {
        // Test that we can convert back to OutputMode
        let modes: [OutputMode] = [.json, .oneline, .summary, .expanded, .verbose, .complete]

        for mode in modes {
            let options = OutputOptions.fromOutputMode(mode)
            let roundTripMode = options.asOutputMode
            XCTAssertEqual(roundTripMode, mode, "Failed round trip for \(mode)")
        }
    }

    func testVerbosityRespected() {
        let textOptions = OutputOptions(format: .text, verbosity: .summary, outputFile: nil, inputFile: nil)
        XCTAssertTrue(textOptions.shouldUseVerbosity)

        let jsonOptions = OutputOptions(format: .json, verbosity: .summary, outputFile: nil, inputFile: nil)
        XCTAssertFalse(jsonOptions.shouldUseVerbosity)

        let markdownOptions = OutputOptions(format: .markdown, verbosity: .verbose, outputFile: nil, inputFile: nil)
        XCTAssertTrue(markdownOptions.shouldUseVerbosity)
    }

    func testOutputFormatCLINames() {
        XCTAssertEqual(OutputFormat.text.cliName, "text")
        XCTAssertEqual(OutputFormat.json.cliName, "json")
        XCTAssertEqual(OutputFormat.htmlOpen.cliName, "html-open")

        XCTAssertEqual(OutputFormat.from(cliName: "html-open"), .htmlOpen)
        XCTAssertEqual(OutputFormat.from(cliName: "json"), .json)
        XCTAssertNil(OutputFormat.from(cliName: "invalid"))
    }

    func testVerbosityDefaults() {
        XCTAssertEqual(Verbosity.default, .summary)
        XCTAssertEqual(OutputFormat.default, .text)
    }
}