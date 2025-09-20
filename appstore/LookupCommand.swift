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

        do {
            let result = try await api.lookupWithRawData(
                lookupType: options.lookupType,
                storefront: options.commonOptions.storefront,
                entity: options.entity,
                language: options.commonOptions.language,
                showRequest: options.commonOptions.showRequest
            )

            if result.apps.isEmpty && options.commonOptions.outputFormat != .json {
                print("No results found")
                return
            }

            // Use OutputManager to handle all output
            outputManager.outputLookupResults(result.apps)

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