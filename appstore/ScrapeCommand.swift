import Foundation

struct ScrapeOptions {
    let term: String
    let storefront: String
    let limit: Int
    let showJSON: Bool
    let showRawJSON: Bool
    let verbosity: Verbosity
    let outputFormat: OutputFormat
    let language: String
    let showRequest: Bool
    let commonOptions: CommonOptions

    init(term: String, limit: Int = 10, showJSON: Bool = false, showRawJSON: Bool = false, commonOptions: CommonOptions) {
        self.term = term
        self.storefront = commonOptions.storefront ?? "US"
        self.limit = limit
        self.showJSON = showJSON
        self.showRawJSON = showRawJSON
        self.verbosity = commonOptions.verbosity
        self.outputFormat = commonOptions.outputFormat
        self.language = commonOptions.language
        self.showRequest = commonOptions.showRequest
        self.commonOptions = commonOptions
    }
}

struct ScrapeCommand {
    private let storeIds: [String: String] = [
        "DZ": "143563", "AO": "143564", "AI": "143538", "AR": "143505",
        "AM": "143524", "AU": "143460", "AT": "143445", "AZ": "143568",
        "BH": "143559", "BB": "143541", "BY": "143565", "BE": "143446",
        "BZ": "143555", "BM": "143542", "BO": "143556", "BW": "143525",
        "BR": "143503", "VG": "143543", "BN": "143560", "BG": "143526",
        "CA": "143455", "KY": "143544", "CL": "143483", "CN": "143465",
        "CO": "143501", "CR": "143495", "HR": "143494", "CY": "143557",
        "CZ": "143489", "DK": "143458", "DM": "143545", "EC": "143509",
        "EG": "143516", "SV": "143506", "EE": "143518", "FI": "143447",
        "FR": "143442", "DE": "143443", "GB": "143444", "GH": "143573",
        "GR": "143448", "GD": "143546", "GT": "143504", "GY": "143553",
        "HN": "143510", "HK": "143463", "HU": "143482", "IS": "143558",
        "IN": "143467", "ID": "143476", "IE": "143449", "IL": "143491",
        "IT": "143450", "JM": "143511", "JP": "143462", "JO": "143528",
        "KE": "143529", "KR": "143466", "KW": "143493", "LV": "143519",
        "LB": "143497", "LT": "143520", "LU": "143451", "MO": "143515",
        "MK": "143530", "MG": "143531", "MY": "143473", "ML": "143532",
        "MT": "143521", "MU": "143533", "MX": "143468", "MS": "143547",
        "NP": "143484", "NL": "143452", "NZ": "143461", "NI": "143512",
        "NE": "143534", "NG": "143561", "NO": "143457", "OM": "143562",
        "PK": "143477", "PA": "143485", "PY": "143513", "PE": "143507",
        "PH": "143474", "PL": "143478", "PT": "143453", "QA": "143498",
        "RO": "143487", "RU": "143469", "SA": "143479", "SN": "143535",
        "SG": "143464", "SK": "143496", "SI": "143499", "ZA": "143472",
        "ES": "143454", "LK": "143486", "SR": "143554", "SE": "143456",
        "CH": "143459", "TW": "143470", "TZ": "143572", "TH": "143475",
        "TN": "143536", "TR": "143480", "UG": "143537", "UA": "143492",
        "AE": "143481", "US": "143441", "UY": "143514", "UZ": "143566",
        "VE": "143502", "VN": "143471", "YE": "143571"
    ]

    func execute(options: ScrapeOptions) async {
        let storeId = storeIds[options.storefront.uppercased()] ?? "143441"
        let languageCode = options.language.isEmpty ? "en-us" : options.language.lowercased()

        let urlString = "https://search.itunes.apple.com/WebObjects/MZStore.woa/wa/search?clientApplication=Software&media=software&term=\(options.term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        guard let url = URL(string: urlString) else {
            print("Error: Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("\(storeId),24 t:native", forHTTPHeaderField: "X-Apple-Store-Front")
        request.setValue(languageCode, forHTTPHeaderField: "Accept-Language")
        request.cachePolicy = .reloadRevalidatingCacheData
        request.timeoutInterval = 30

        if options.showRequest {
            let outputManager = OutputManager(options: options.commonOptions)
            // For now, just print request info directly
            print("Request URL: \(url)")
            print("Request Headers:")
            for (key, value) in request.allHTTPHeaderFields ?? [:] {
                print("  \(key): \(value)")
            }
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if options.showRequest, let httpResponse = response as? HTTPURLResponse {
                // For now, just print response headers directly
                print("\nResponse Headers:")
                for (key, value) in httpResponse.allHeaderFields {
                    print("  \(key): \(value)")
                }
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("Error: Invalid JSON response")
                return
            }

            if options.showRawJSON {
                let outputManager = OutputManager(options: options.commonOptions)
                outputManager.outputRawJSON(data)
                return
            }

            let apps = parseScrapedResults(json, limit: options.limit)

            if options.showJSON {
                // Output as JSON
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: ["results": apps], options: [.prettyPrinted, .sortedKeys])
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        print(jsonString)
                    }
                } catch {
                    print("Error encoding JSON: \(error)")
                }
            } else {
                displayResults(apps, options: options)
            }

        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }

    private func parseScrapedResults(_ json: [String: Any], limit: Int) -> [[String: Any]] {
        guard let storePlatformData = json["storePlatformData"] as? [String: Any],
              let searchData = storePlatformData["native-search-lockup-search"] as? [String: Any],
              let results = searchData["results"] as? [String: Any] else {
            return []
        }

        let apps = results.compactMap { (key, value) -> [String: Any]? in
            guard let app = value as? [String: Any] else { return nil }

            var appInfo: [String: Any] = [
                "trackId": Int(key) ?? 0,
                "trackName": app["name"] ?? "",
                "artistName": app["artistName"] ?? "",
                "bundleId": app["bundleId"] ?? "",
                "subtitle": app["subtitle"] ?? "",
                "url": app["url"] ?? "",
                "shortUrl": app["shortUrl"] ?? "",
                "releaseDate": app["releaseDate"] ?? "",
                "minimumOsVersion": app["minimumOSVersion"] ?? "",
                "copyright": app["copyright"] ?? ""
            ]

            if let userRating = app["userRating"] as? [String: Any] {
                appInfo["averageUserRating"] = userRating["value"]
                appInfo["userRatingCount"] = userRating["ratingCount"]
            }

            if let offers = app["offers"] as? [[String: Any]], let firstOffer = offers.first {
                appInfo["formattedPrice"] = firstOffer["formattedPrice"]
                appInfo["price"] = firstOffer["price"]
            }

            if let genres = app["genreNames"] as? [String] {
                appInfo["primaryGenreName"] = genres.first ?? ""
                appInfo["genres"] = genres
            }

            if let contentRating = app["contentRating"] as? [String: Any] {
                appInfo["contentAdvisoryRating"] = contentRating["label"]
            }

            if let artwork = app["artwork"] as? [[String: Any]] {
                let artworkUrls = artwork.compactMap { art -> String? in
                    guard let url = art["url"] as? String,
                          let width = art["width"] as? Int,
                          width == 512 || width == 1024 else { return nil }
                    return url
                }
                if let largestArtwork = artworkUrls.first {
                    appInfo["artworkUrl512"] = largestArtwork
                }
            }

            if let screenshots = app["screenshotsByType"] as? [String: Any] {
                var screenshotUrls: [String] = []
                for (_, value) in screenshots {
                    if let deviceScreenshots = value as? [String: Any],
                       let urls = deviceScreenshots["urls"] as? [String] {
                        screenshotUrls.append(contentsOf: urls)
                    }
                }
                if !screenshotUrls.isEmpty {
                    appInfo["screenshotUrls"] = screenshotUrls
                }
            }

            return appInfo
        }

        return Array(apps.prefix(limit))
    }

    private func displayResults(_ apps: [[String: Any]], options: ScrapeOptions) {
        // Convert dictionary format to App objects for display
        let formatter = TextFormatter()

        // For now, just display basic info
        print("Found \(apps.count) result(s):")
        print(String(repeating: "-", count: 80))

        for (index, app) in apps.enumerated() {
            print("\n\(index + 1). \(app["trackName"] ?? "Unknown")")
            print("   App ID: \(app["trackId"] ?? 0)")
            print("   Developer: \(app["artistName"] ?? "Unknown")")
            print("   Bundle ID: \(app["bundleId"] ?? "Unknown")")
            if let price = app["formattedPrice"] as? String {
                print("   Price: \(price)")
            }
            if let rating = app["averageUserRating"] as? Double,
               let count = app["userRatingCount"] as? Int {
                print("   Rating: \(String(format: "%.1f", rating)) (\(count) ratings)")
            }
            if index < apps.count - 1 {
                print(String(repeating: "-", count: 80))
            }
        }
        print(String(repeating: "-", count: 80))
    }
}