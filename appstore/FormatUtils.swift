import Foundation

struct FormatUtils {
    static func formatFileSize(_ bytes: String?) -> String {
        guard let bytes = bytes,
              let byteCount = Double(bytes) else {
            return "Unknown"
        }

        let units = ["bytes", "KB", "MB", "GB", "TB"]
        var size = byteCount
        var unitIndex = 0

        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(Int(size)) \(units[unitIndex])"
        } else {
            return String(format: "%.1f %@", size, units[unitIndex])
        }
    }

    static func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }

    static func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "N/A" }

        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .medium
        outputFormatter.timeStyle = .none

        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        return dateString
    }

    static func formatRatingStars(_ rating: Double?) -> String {
        guard let rating = rating else { return "No rating" }
        let stars = String(repeating: "★", count: Int(rating.rounded()))
        let emptyStars = String(repeating: "☆", count: 5 - Int(rating.rounded()))
        return "\(stars)\(emptyStars)"
    }

    static func formatLanguages(_ codes: [String]?) -> String {
        guard let codes = codes, !codes.isEmpty else { return "N/A" }

        let sorted = codes.sorted()
        if sorted.count > 10 {
            let first10 = sorted.prefix(10)
            return "\(first10.joined(separator: ", ")) (+\(sorted.count - 10) more)"
        }
        return sorted.joined(separator: ", ")
    }

    static func printCompleteJSON(_ dictionary: [String: Any], indent: Int = 0) {
        let indentString = String(repeating: "  ", count: indent)

        let sortedKeys = dictionary.keys.sorted()
        for key in sortedKeys {
            guard let value = dictionary[key] else { continue }

            if let dict = value as? [String: Any] {
                print("\(indentString)\(key):")
                printCompleteJSON(dict, indent: indent + 1)
            } else if let array = value as? [[String: Any]] {
                print("\(indentString)\(key): [\(array.count) items]")
                for (index, item) in array.enumerated() {
                    print("\(indentString)  [\(index)]:")
                    printCompleteJSON(item, indent: indent + 2)
                }
            } else if let array = value as? [Any] {
                if array.isEmpty {
                    print("\(indentString)\(key): []")
                } else {
                    print("\(indentString)\(key): \(array.map { String(describing: $0) }.joined(separator: ", "))")
                }
            } else {
                print("\(indentString)\(key): \(value)")
            }
        }
    }
}