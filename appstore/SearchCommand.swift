import Foundation

class SearchCommand {
    private let api = AppStoreAPI()

    func execute(query: String) async {
        print("Searching App Store for: \"\(query)\"...")
        print()

        do {
            let apps = try await api.search(query: query)

            if apps.isEmpty {
                print("No results found for \"\(query)\"")
                return
            }

            print("Found \(apps.count) result(s):")
            print(String(repeating: "-", count: 80))

            for (index, app) in apps.enumerated() {
                printApp(app, index: index + 1)
                if index < apps.count - 1 {
                    print(String(repeating: "-", count: 80))
                }
            }

            print(String(repeating: "=", count: 80))

        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }

    private func printApp(_ app: App, index: Int) {
        print("\(index). \(app.trackName)")
        print("   Developer: \(app.artistName)")
        print("   Price: \(app.formattedPrice ?? "Free")")

        if let rating = app.averageUserRating,
           let ratingCount = app.userRatingCount {
            let stars = String(repeating: "★", count: Int(rating.rounded()))
            let emptyStars = String(repeating: "☆", count: 5 - Int(rating.rounded()))
            print("   Rating: \(stars)\(emptyStars) \(String(format: "%.1f", rating)) (\(formatNumber(ratingCount)) ratings)")
        }

        print("   Category: \(app.primaryGenreName)")
        print("   Version: \(app.version)")
        print("   Bundle ID: \(app.bundleId)")

        if let description = app.description.split(separator: "\n").first {
            let maxLength = 150
            let truncated = description.count > maxLength ? String(description.prefix(maxLength)) + "..." : String(description)
            print("   Description: \(truncated)")
        }
        print()
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }
}