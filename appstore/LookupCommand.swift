import Foundation

class LookupCommand {
    private let api = AppStoreAPI()

    func execute(options: LookupOptions) async {
        let outputManager = OutputManager(options: options.commonOptions)

        if options.commonOptions.outputFormat != .json && !options.commonOptions.showRequest {
            let description = describeLookup(options)
            print("Looking up \(description)...")
            print()
        }

        let startTime = Date()

        do {
            let result = try await api.lookupWithRawData(
                lookupType: options.lookupType,
                storefront: options.commonOptions.storefront,
                entity: options.entity,
                language: options.commonOptions.language,
                showRequest: options.commonOptions.showRequest,
                showResponseHeaders: options.commonOptions.showResponseHeaders
            )

            let endTime = Date()
            let durationMs = Int(endTime.timeIntervalSince(startTime) * 1000)

            if result.apps.isEmpty && options.commonOptions.outputFormat != .json {
                print("No results found")
                return
            }

            // Build parameters for metadata
            var parameters: [String: Any] = [:]
            switch options.lookupType {
            case .id(let id):
                parameters["id"] = id
            case .ids(let ids):
                parameters["ids"] = ids.joined(separator: ",")
            case .bundleId(let bundleId):
                parameters["bundleId"] = bundleId
            case .url(let url):
                parameters["url"] = url
            }
            parameters["storefront"] = options.commonOptions.storefront ?? "US"
            parameters["language"] = options.commonOptions.language
            if let entity = options.entity {
                parameters["entity"] = entity
            }

            // Use OutputManager to handle all output
            outputManager.outputLookupResults(result.apps, command: "lookup", parameters: parameters, durationMs: durationMs)

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