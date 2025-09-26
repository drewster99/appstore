import Foundation

struct RanksOptions {
    let appId: String
    let limit: Int?  // Optional limit on number of keywords to generate and test
    let commonOptions: CommonOptions

    init(appId: String, limit: Int? = nil, commonOptions: CommonOptions) {
        self.appId = appId
        self.limit = limit
        self.commonOptions = commonOptions
    }
}