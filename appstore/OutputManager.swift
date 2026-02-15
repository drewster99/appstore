import Foundation

class OutputManager {
    private let options: CommonOptions
    private let formatter: OutputFormatter

    init(options: CommonOptions) {
        self.options = options

        switch options.outputFormat {
        case .text:
            self.formatter = TextFormatter()
        case .json, .rawJson:
            self.formatter = JSONFormatter()
        case .markdown:
            self.formatter = MarkdownOutputFormatter()
        case .html, .htmlOpen:
            self.formatter = TextFormatter()
        }
    }

    func outputSearchResults(_ apps: [App], command: String = "search", parameters: [String: Any] = [:], durationMs: Int) {
        if let inputFile = options.inputFile {
            return
        }

        let output: String

        if options.outputFormat == .json {
            output = createMetadataWrappedJSON(apps: apps, command: command, parameters: parameters, durationMs: durationMs)
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

    func outputLookupResults(_ apps: [App], command: String = "lookup", parameters: [String: Any] = [:], durationMs: Int) {
        let output: String

        if options.outputFormat == .json {
            output = createMetadataWrappedJSON(apps: apps, command: command, parameters: parameters, durationMs: durationMs)
        } else {
            output = formatter.formatLookupResults(apps, options: options)
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

    func outputTopResults(_ rawData: Data, entries: [[String: Any]], title: String, command: String = "top", parameters: [String: Any] = [:], durationMs: Int) {
        let output: String

        if options.outputFormat == .json {
            // Wrap with metadata
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: rawData, options: [])
                output = createMetadataWrappedJSONForTop(jsonObject as? [String: Any] ?? [:], command: command, parameters: parameters, durationMs: durationMs)
            } catch {
                output = "{\"error\": \"Failed to process JSON: \(error)\"}"
            }
        } else if options.outputFormat == .rawJson {
            // Output raw RSS JSON
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: rawData, options: [])
                let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
                output = String(data: prettyData, encoding: .utf8) ?? "{}"
            } catch {
                output = "{\"error\": \"Failed to process JSON: \(error)\"}"
            }
        } else {
            output = formatter.formatTopEntries(entries, title: title, options: options)
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

    private func createMetadataWrappedJSONForTop(_ data: [String: Any], command: String, parameters: [String: Any], durationMs: Int) -> String {
        do {
            let metadata: [String: Any] = [
                "version": 1,
                "id": UUID().uuidString,
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "command": command,
                "parameters": parameters.mapValues { "\($0)" },
                "request": [
                    "url": parameters["url"] as? String ?? "https://itunes.apple.com/rss",
                    "method": "GET"
                ],
                "response": [
                    "httpStatus": 200,
                    "timestamp": ISO8601DateFormatter().string(from: Date()),
                    "durationMs": durationMs
                ]
            ]

            let wrapped: [String: Any] = [
                "metadata": metadata,
                "data": data
            ]

            let prettyData = try JSONSerialization.data(withJSONObject: wrapped, options: [.prettyPrinted, .sortedKeys])
            return String(data: prettyData, encoding: .utf8) ?? "{}"

        } catch {
            return "{\"error\": \"Failed to create JSON output: \(error)\"}"
        }
    }

    func outputListResults(_ data: Any, command: String = "list", parameters: [String: Any] = [:], durationMs: Int) {
        let output: String

        if options.outputFormat == .json {
            // Wrap with metadata
            output = createMetadataWrappedJSONForList(data, command: command, parameters: parameters, durationMs: durationMs)
        } else if options.outputFormat == .rawJson {
            // Output raw JSON
            do {
                let prettyData = try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys])
                output = String(data: prettyData, encoding: .utf8) ?? "{}"
            } catch {
                output = "{\"error\": \"Failed to process JSON: \(error)\"}"
            }
        } else {
            // For non-JSON formats, format as text
            // This would need custom formatting based on the list type
            output = formatListData(data)
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
    }

    private func createMetadataWrappedJSONForList(_ data: Any, command: String, parameters: [String: Any], durationMs: Int) -> String {
        do {
            let metadata: [String: Any] = [
                "version": 1,
                "id": UUID().uuidString,
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "command": command,
                "parameters": parameters.mapValues { "\($0)" },
                "response": [
                    "timestamp": ISO8601DateFormatter().string(from: Date()),
                    "durationMs": durationMs
                ]
            ]

            let wrapped: [String: Any] = [
                "metadata": metadata,
                "data": data
            ]

            let prettyData = try JSONSerialization.data(withJSONObject: wrapped, options: [.prettyPrinted, .sortedKeys])
            return String(data: prettyData, encoding: .utf8) ?? "{}"

        } catch {
            return "{\"error\": \"Failed to create JSON output: \(error)\"}"
        }
    }

    private func formatListData(_ data: Any) -> String {
        // This is a placeholder - the actual formatting would depend on the list type
        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "Unable to format data"
    }

    private func openInBrowser(html: String) {
        do {
            let tempFile = NSTemporaryDirectory() + "appstore_results_\(UUID().uuidString).html"
            try html.write(toFile: tempFile, atomically: true, encoding: .utf8)

            let task = Process()
            task.launchPath = "/usr/bin/open"
            task.arguments = [tempFile]
            task.launch()

            // Temp file lives in NSTemporaryDirectory and is cleaned up by the OS.
            // We can't reliably schedule cleanup in a CLI process since the process
            // may exit before the browser finishes loading the file.
        } catch {
            print("Error opening HTML in browser: \(error)")
        }
    }
}