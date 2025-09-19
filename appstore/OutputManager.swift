import Foundation

class OutputManager {
    private let options: CommonOptions
    private let formatter: OutputFormatter

    init(options: CommonOptions) {
        self.options = options

        switch options.outputFormat {
        case .text:
            self.formatter = TextFormatter()
        case .json:
            self.formatter = JSONFormatter()
        case .markdown:
            self.formatter = MarkdownOutputFormatter()
        case .html, .htmlOpen:
            self.formatter = TextFormatter()
        }
    }

    func outputSearchResults(_ apps: [App], command: String = "search", parameters: [String: Any] = [:], durationMs: Int? = nil) {
        if let inputFile = options.inputFile {
            return
        }

        let output: String

        if options.outputFormat == .json && durationMs != nil {
            output = createMetadataWrappedJSON(apps: apps, command: command, parameters: parameters, durationMs: durationMs!)
        } else {
            output = formatter.formatApps(apps, options: options)
        }

        if let outputFile = options.outputFile {
            do {
                try output.write(toFile: outputFile, atomically: true, encoding: .utf8)
                if options.outputFormat != .json {
                    print("Results saved to: \(outputFile)")
                }
            } catch {
                print("Error saving to file: \(error)")
            }
        } else {
            print(output)
        }

        if options.outputFormat == .htmlOpen {
            openInBrowser(html: output)
        }
    }

    func outputLookupResults(_ apps: [App]) {
        let output = formatter.formatLookupResults(apps, options: options)

        if let outputFile = options.outputFile {
            do {
                try output.write(toFile: outputFile, atomically: true, encoding: .utf8)
                if options.outputFormat != .json {
                    print("Results saved to: \(outputFile)")
                }
            } catch {
                print("Error saving to file: \(error)")
            }
        } else {
            print(output)
        }

        if options.outputFormat == .htmlOpen {
            openInBrowser(html: output)
        }
    }

    func outputTopResults(_ entries: [[String: Any]], title: String) {
        let output = formatter.formatTopEntries(entries, title: title, options: options)

        if let outputFile = options.outputFile {
            do {
                try output.write(toFile: outputFile, atomically: true, encoding: .utf8)
                if options.outputFormat != .json {
                    print("Results saved to: \(outputFile)")
                }
            } catch {
                print("Error saving to file: \(error)")
            }
        } else {
            print(output)
        }

        if options.outputFormat == .htmlOpen {
            openInBrowser(html: output)
        }
    }

    func outputRawJSON(_ data: Data) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])

            if let jsonString = String(data: prettyData, encoding: .utf8) {
                if let outputFile = options.outputFile {
                    try jsonString.write(toFile: outputFile, atomically: true, encoding: .utf8)
                } else {
                    print(jsonString)
                }
            }
        } catch {
            print("Error processing JSON: \(error)")
        }
    }

    private func createMetadataWrappedJSON(apps: [App], command: String, parameters: [String: Any], durationMs: Int) -> String {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let metadata: [String: Any] = [
                "version": 1,
                "id": UUID().uuidString,
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "command": command,
                "parameters": parameters.mapValues { "\($0)" },
                "request": [
                    "url": "https://itunes.apple.com/\(command)",
                    "method": "GET"
                ],
                "response": [
                    "httpStatus": 200,
                    "timestamp": ISO8601DateFormatter().string(from: Date()),
                    "durationMs": durationMs,
                    "resultCount": apps.count
                ]
            ]

            let results = ["results": apps]
            let resultsData = try encoder.encode(results)
            let resultsObject = try JSONSerialization.jsonObject(with: resultsData)

            let wrapped: [String: Any] = [
                "metadata": metadata,
                "data": resultsObject
            ]

            let prettyData = try JSONSerialization.data(withJSONObject: wrapped, options: [.prettyPrinted, .sortedKeys])
            return String(data: prettyData, encoding: .utf8) ?? "{}"

        } catch {
            return "{\"error\": \"Failed to create JSON output: \(error)\"}"
        }
    }

    private func openInBrowser(html: String) {
        do {
            let tempFile = NSTemporaryDirectory() + "appstore_results_\(UUID().uuidString).html"
            try html.write(toFile: tempFile, atomically: true, encoding: .utf8)

            let task = Process()
            task.launchPath = "/usr/bin/open"
            task.arguments = [tempFile]
            task.launch()
        } catch {
            print("Error opening HTML in browser: \(error)")
        }
    }
}