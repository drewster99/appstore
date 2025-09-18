import Foundation

class LookupCommand {
    private let api = AppStoreAPI()

    func execute(options: LookupOptions) async {
        if options.outputMode != .json && !options.showRequest {
            let description = describeLookup(options)
            print("Looking up \(description)...")
            print()
        }

        do {
            let result = try await api.lookupWithRawData(
                lookupType: options.lookupType,
                country: options.country,
                entity: options.entity,
                showRequest: options.showRequest
            )

            if result.apps.isEmpty {
                print("No results found")
                return
            }

            let searchCommand = SearchCommand()

            switch options.outputMode {
            case .json:
                // Show JSON output
                let jsonObject = try JSONSerialization.jsonObject(with: result.rawData, options: [])
                let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])

                if let jsonString = String(data: prettyData, encoding: .utf8) {
                    print(jsonString)
                }
            case .oneline:
                print("Found \(result.apps.count) result(s):")
                searchCommand.printOneline(apps: result.apps)
            case .summary:
                print("Found \(result.apps.count) result(s):")
                searchCommand.printSummary(apps: result.apps)
            case .expanded:
                print("Found \(result.apps.count) result(s):")
                searchCommand.printExpanded(apps: result.apps)
            case .verbose:
                print("Found \(result.apps.count) result(s):")
                searchCommand.printVerbose(apps: result.apps)
            case .complete:
                print("Found \(result.apps.count) result(s):")
                searchCommand.printComplete(apps: result.apps, rawData: result.rawData)
            }

        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }

    private func describeLookup(_ options: LookupOptions) -> String {
        switch options.lookupType {
        case .id(let id):
            return "app with ID \(id)"
        case .ids(let ids):
            return "\(ids.count) apps"
        case .bundleId(let bundleId):
            return "app with bundle ID \(bundleId)"
        case .url(let url):
            return "app from URL"
        }
    }
}