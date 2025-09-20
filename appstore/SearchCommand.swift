import Foundation

class SearchCommand {
    private let api = AppStoreAPI()

    func execute(options: SearchOptions) async {
        // Handle input file if specified
        if let inputFile = options.commonOptions.inputFile {
            await handleInputFile(inputFile, options: options)
            return
        }

        let outputManager = OutputManager(options: options.commonOptions)

        if options.commonOptions.outputFormat != .json && !options.commonOptions.showRequest {
            print("Searching App Store for: \"\(options.query)\"...")
            print()
        }

        let startTime = Date()

        do {
            let result = try await api.searchWithRawData(
                query: options.query,
                limit: options.limit,
                storefront: options.commonOptions.storefront,
                attribute: options.attribute,
                genre: options.genre,
                language: options.commonOptions.language,
                showRequest: options.commonOptions.showRequest,
                showResponseHeaders: options.commonOptions.showResponseHeaders
            )

            let endTime = Date()
            let durationMs = Int(endTime.timeIntervalSince(startTime) * 1000)

            if result.apps.isEmpty && options.commonOptions.outputFormat != .json {
                print("No results found for \"\(options.query)\"")
                return
            }

            // Use OutputManager to handle all output
            let parameters: [String: Any] = [
                "query": options.query,
                "limit": options.limit,
                "storefront": options.commonOptions.storefront ?? "us",
                "attribute": options.attribute ?? "",
                "genre": options.genre ?? 0
            ]

            outputManager.outputSearchResults(result.apps, command: "search", parameters: parameters, durationMs: durationMs)

        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }

    // MARK: - File I/O Support

    private func handleInputFile(_ inputFile: String, options: SearchOptions) async {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: inputFile))

            // Try to parse as our metadata wrapper format first
            if let metadata = try? JSONDecoder().decode(AppStoreResponseMetadata.self, from: data) {
                print("Loaded from file: \(inputFile)")
                print("Original command: \(metadata.command)")
                print("Original timestamp: \(metadata.timestamp)")
                print()
            }

            // Extract the actual results
            let jsonObject = try JSONSerialization.jsonObject(with: data)

            // Check if it's wrapped or raw
            var resultsData: Data
            if let wrapped = jsonObject as? [String: Any], let dataObject = wrapped["data"] {
                resultsData = try JSONSerialization.data(withJSONObject: dataObject)
            } else {
                resultsData = data
            }

            // Parse and display
            let searchResult = try JSONDecoder().decode(AppStoreSearchResult.self, from: resultsData)

            // Use OutputManager to display results
            let outputManager = OutputManager(options: options.commonOptions)

            if options.commonOptions.outputFormat != .json {
                print("Found \(searchResult.results.count) result(s) from file:")
            }

            outputManager.outputSearchResults(searchResult.results, command: "search", parameters: [:], durationMs: nil)

        } catch {
            print("Error reading input file: \(error)")
        }
    }
}