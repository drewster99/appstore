import Foundation

struct RanksOptions {
    let appId: String
    let limit: Int  // Number of keywords to generate and test
    let commonOptions: CommonOptions

    init(appId: String, limit: Int = 20, commonOptions: CommonOptions) {
        self.appId = appId
        self.limit = limit
        self.commonOptions = commonOptions
    }
}