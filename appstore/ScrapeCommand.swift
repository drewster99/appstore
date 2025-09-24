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
    private let api = AppStoreAPI()
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
            print("Request URL: \(url)")
            print("Request Headers:")
            for (key, value) in request.allHTTPHeaderFields ?? [:] {
                print("  \(key): \(value)")
            }
        }

        do {
            let startTime = Date()
            let (data, response) = try await URLSession.shared.data(for: request)

            if options.showRequest, let httpResponse = response as? HTTPURLResponse {
                print("\nResponse Headers:")
                for (key, value) in httpResponse.allHeaderFields {
                    print("  \(key): \(value)")
                }
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("Error: Invalid JSON response")
                return
            }

            // For raw JSON output, just output the scrape response as-is
            if options.showRawJSON {
                let outputManager = OutputManager(options: options.commonOptions)
                outputManager.outputRawJSON(data)
                return
            }

            // Extract app IDs from bubbles
            let appIds = extractAppIds(from: json, limit: options.limit)

            if appIds.isEmpty {
                print("No results found")
                return
            }

            // Use the API to lookup full details for all app IDs
            let lookupResult = try await api.lookupWithRawData(
                lookupType: .ids(appIds),
                storefront: options.storefront,
                entity: nil,
                language: options.language,
                showRequest: options.showRequest,
                showResponseHeaders: options.commonOptions.showResponseHeaders
            )

            let endTime = Date()
            let durationMs = Int(endTime.timeIntervalSince(startTime) * 1000)

            // Use OutputManager to handle all output, respecting verbosity and format options
            let outputManager = OutputManager(options: options.commonOptions)

            // Build parameters for metadata
            let parameters: [String: Any] = [
                "term": options.term,
                "storefront": options.storefront,
                "language": options.language,
                "limit": options.limit
            ]

            outputManager.outputSearchResults(lookupResult.apps, command: "scrape", parameters: parameters, durationMs: durationMs)

        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }

    private func extractAppIds(from json: [String: Any], limit: Int) -> [String] {
        // Extract app IDs from bubbles (contains all results)
        if let bubbles = json["bubbles"] as? [[String: Any]],
           let firstBubble = bubbles.first,
           let results = firstBubble["results"] as? [[String: Any]] {
            // Extract IDs from bubbles, limiting to requested amount
            return results.prefix(limit).compactMap { $0["id"] as? String }
        }
        return []
    }
}