import Foundation

struct CommonOptions {
    let outputFormat: OutputFormat
    let verbosity: Verbosity
    let outputFile: String?
    let inputFile: String?
    let fullDescription: Bool
    let showRequest: Bool
    let showResponseHeaders: Bool
    let storefront: String?
    let language: String

    static var `default`: CommonOptions {
        return CommonOptions(
            outputFormat: .text,
            verbosity: .summary,
            outputFile: nil,
            inputFile: nil,
            fullDescription: false,
            showRequest: false,
            showResponseHeaders: false,
            storefront: nil,
            language: "en_us"
        )
    }

    init(
        outputFormat: OutputFormat? = nil,
        verbosity: Verbosity? = nil,
        outputFile: String? = nil,
        inputFile: String? = nil,
        fullDescription: Bool = false,
        showRequest: Bool = false,
        showResponseHeaders: Bool = false,
        storefront: String? = nil,
        language: String? = nil
    ) {
        self.outputFormat = outputFormat ?? .text
        self.verbosity = verbosity ?? .summary
        self.outputFile = outputFile
        self.inputFile = inputFile
        self.fullDescription = fullDescription
        self.showRequest = showRequest
        self.showResponseHeaders = showResponseHeaders
        // Convert storefront to uppercase
        self.storefront = storefront?.uppercased()
        self.language = language ?? "en_us"
    }
}