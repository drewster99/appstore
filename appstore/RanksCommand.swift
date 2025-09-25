import Foundation

struct RanksCommand {
    func execute(options: RanksOptions) async {
        print("Fetching app details for ID: \(options.appId)...")

        let api = AppStoreAPI()

        do {
            let lookupResult = try await api.lookupWithRawData(
                lookupType: .id(options.appId),
                storefront: options.commonOptions.storefront,
                language: options.commonOptions.language
            )

            guard let app = lookupResult.apps.first else {
                print("Error: No app found with ID \(options.appId)")
                return
            }

            print("Analyzing app: \(app.trackName)")
            print()

            // Generate keywords from app data
            print("Generating keywords...")
            let keywords = generateKeywords(from: app, limit: options.limit)

            print("Found \(keywords.count) keywords to test:")
            for (index, keyword) in keywords.enumerated() {
                print("  \(index + 1). \(keyword)")
            }
            print()

            print("Analysis complete!")

        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }

    private func generateKeywords(from app: App, limit: Int) -> [String] {
        var keywords: [String] = []

        // 1. Extract from app name
        let titleWords = app.trackName
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 2 }

        keywords.append(contentsOf: titleWords)

        // 2. Add genre
        keywords.append(app.primaryGenreName.lowercased())

        // Remove duplicates and return
        let unique = Array(Set(keywords))
        return Array(unique.prefix(limit))
    }
}