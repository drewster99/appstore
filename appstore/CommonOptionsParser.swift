import Foundation

struct ParseResult {
    let options: CommonOptions
    let remainingArgs: [String]
    let error: String?

    init(options: CommonOptions, remainingArgs: [String], error: String? = nil) {
        self.options = options
        self.remainingArgs = remainingArgs
        self.error = error
    }
}

class CommonOptionsParser {
    static func parse(_ args: [String]) -> ParseResult {
        var outputFormat: OutputFormat = EnvironmentConfig.defaultOutputFormat ?? .text
        var verbosity: Verbosity = EnvironmentConfig.defaultVerbosity ?? .summary
        var outputFile: String?
        var inputFile: String?
        var fullDescription = false
        var showRequest = EnvironmentConfig.showRequest
        var storefront = EnvironmentConfig.defaultStorefront != "us" ? EnvironmentConfig.defaultStorefront : nil
        var language: String = "en_us"

        var remainingArgs = [String]()
        var i = 0

        while i < args.count {
            let arg = args[i]

            switch arg {
            case "--output-format", "--format":
                i += 1
                if i < args.count {
                    let formatString = args[i].lowercased()
                    if let format = OutputFormat.from(cliName: formatString) {
                        outputFormat = format
                    } else {
                        return ParseResult(
                            options: CommonOptions(),
                            remainingArgs: [],
                            error: "Invalid output format '\(args[i])'. Valid formats: text, json, html, html-open, markdown"
                        )
                    }
                } else {
                    return ParseResult(
                        options: CommonOptions(),
                        remainingArgs: [],
                        error: "--output-format requires a value"
                    )
                }

            case "--verbosity", "-v":
                i += 1
                if i < args.count {
                    let verbosityString = args[i].lowercased()
                    if let v = Verbosity(rawValue: verbosityString) {
                        verbosity = v
                    } else {
                        return ParseResult(
                            options: CommonOptions(),
                            remainingArgs: [],
                            error: "Invalid verbosity level '\(args[i])'. Valid levels: minimal, summary, expanded, verbose, complete"
                        )
                    }
                } else {
                    return ParseResult(
                        options: CommonOptions(),
                        remainingArgs: [],
                        error: "--verbosity requires a value"
                    )
                }

            case "--output-file", "-o":
                i += 1
                if i < args.count {
                    outputFile = args[i]
                } else {
                    return ParseResult(
                        options: CommonOptions(),
                        remainingArgs: [],
                        error: "--output-file requires a file path"
                    )
                }

            case "--input-file", "-i":
                i += 1
                if i < args.count {
                    inputFile = args[i]
                } else {
                    return ParseResult(
                        options: CommonOptions(),
                        remainingArgs: [],
                        error: "--input-file requires a file path"
                    )
                }

            case "--full-description":
                fullDescription = true

            case "--show-request":
                showRequest = true

            case "--country", "--storefront":
                i += 1
                if i < args.count {
                    // Convert to uppercase for consistency
                    storefront = args[i].uppercased()
                } else {
                    return ParseResult(
                        options: CommonOptions(),
                        remainingArgs: [],
                        error: "\(arg) requires a value"
                    )
                }

            case "--language", "--lang":
                i += 1
                if i < args.count {
                    language = args[i]
                } else {
                    return ParseResult(
                        options: CommonOptions(),
                        remainingArgs: [],
                        error: "\(arg) requires a value"
                    )
                }

            case "--output-mode":
                i += 1
                if i < args.count {
                    let modeString = args[i].lowercased()
                    if let mode = OutputMode(rawValue: modeString) {
                        let converted = OutputOptions.fromOutputMode(mode)
                        outputFormat = converted.format
                        verbosity = converted.verbosity
                    } else {
                        return ParseResult(
                            options: CommonOptions(),
                            remainingArgs: [],
                            error: "Invalid output mode '\(args[i])'. Valid modes: oneline, summary, expanded, verbose, complete, json"
                        )
                    }
                } else {
                    return ParseResult(
                        options: CommonOptions(),
                        remainingArgs: [],
                        error: "--output-mode requires a value"
                    )
                }

            default:
                remainingArgs.append(arg)
            }

            i += 1
        }

        let options = CommonOptions(
            outputFormat: outputFormat,
            verbosity: verbosity,
            outputFile: outputFile,
            inputFile: inputFile,
            fullDescription: fullDescription,
            showRequest: showRequest,
            storefront: storefront,
            language: language
        )

        return ParseResult(options: options, remainingArgs: remainingArgs)
    }
}