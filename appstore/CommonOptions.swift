import Foundation

struct CommonOptions {
    let outputFormat: OutputFormat
    let verbosity: Verbosity
    let outputFile: String?
    let inputFile: String?
    let fullDescription: Bool
    let showRequest: Bool
    let storefront: String?

    static var `default`: CommonOptions {
        return CommonOptions(
            outputFormat: .text,
            verbosity: .summary,
            outputFile: nil,
            inputFile: nil,
            fullDescription: false,
            showRequest: false,
            storefront: nil
        )
    }

    init(
        outputFormat: OutputFormat? = nil,
        verbosity: Verbosity? = nil,
        outputFile: String? = nil,
        inputFile: String? = nil,
        fullDescription: Bool = false,
        showRequest: Bool = false,
        storefront: String? = nil
    ) {
        self.outputFormat = outputFormat ?? .text
        self.verbosity = verbosity ?? .summary
        self.outputFile = outputFile
        self.inputFile = inputFile
        self.fullDescription = fullDescription
        self.showRequest = showRequest
        self.storefront = storefront
    }
}