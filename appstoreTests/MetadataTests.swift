import XCTest
import Foundation
@testable import appstore

class MetadataTests: XCTestCase {

    func testMetadataCreation() {
        let metadata = AppStoreResponseMetadata(
            version: 1,
            id: "test-id",
            timestamp: Date(),
            command: "search",
            parameters: ["query": "test", "limit": "5"],
            request: AppStoreResponseMetadata.RequestInfo(
                url: "https://itunes.apple.com/search",
                queryString: "term=test&limit=5",
                method: "GET"
            ),
            response: AppStoreResponseMetadata.ResponseInfo(
                httpStatus: 200,
                timestamp: Date(),
                durationMs: 123
            )
        )

        XCTAssertEqual(metadata.version, 1)
        XCTAssertEqual(metadata.id, "test-id")
        XCTAssertEqual(metadata.command, "search")
        XCTAssertEqual(metadata.parameters["query"] ?? "", "test")
        XCTAssertEqual(metadata.request.method, "GET")
        XCTAssertEqual(metadata.response.httpStatus, 200)
        XCTAssertEqual(metadata.response.durationMs, 123)
    }

    func testMetadataEncoding() throws {
        let metadata = AppStoreResponseMetadata(
            version: 1,
            id: UUID().uuidString,
            timestamp: Date(),
            command: "search",
            parameters: ["query": "spotify"],
            request: AppStoreResponseMetadata.RequestInfo(
                url: "https://itunes.apple.com/search",
                queryString: "term=spotify",
                method: "GET"
            ),
            response: AppStoreResponseMetadata.ResponseInfo(
                httpStatus: 200,
                timestamp: Date(),
                durationMs: 150
            )
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(metadata)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppStoreResponseMetadata.self, from: data)

        XCTAssertEqual(decoded.version, metadata.version)
        XCTAssertEqual(decoded.command, metadata.command)
        XCTAssertEqual(decoded.request.url, metadata.request.url)
        XCTAssertEqual(decoded.response.httpStatus, metadata.response.httpStatus)
    }

    func testAppStoreResponse() throws {
        let testData = "{\"test\": \"data\"}".data(using: .utf8)!

        let response = AppStoreResponse(
            metadata: AppStoreResponseMetadata(
                version: 1,
                id: "test",
                timestamp: Date(),
                command: "search",
                parameters: [:],
                request: AppStoreResponseMetadata.RequestInfo(
                    url: "test",
                    queryString: "",
                    method: "GET"
                ),
                response: AppStoreResponseMetadata.ResponseInfo(
                    httpStatus: 200,
                    timestamp: Date(),
                    durationMs: nil
                )
            ),
            data: testData
        )

        XCTAssertEqual(response.data, testData)
        XCTAssertEqual(response.metadata.command, "search")
    }
}

class FormatUtilsTests: XCTestCase {

    func testRatingStars() {
        XCTAssertEqual(FormatUtils.formatRatingStars(5.0), "★★★★★")
        XCTAssertEqual(FormatUtils.formatRatingStars(4.5), "★★★★★")
        XCTAssertEqual(FormatUtils.formatRatingStars(4.0), "★★★★☆")
        XCTAssertEqual(FormatUtils.formatRatingStars(3.5), "★★★★☆")
        XCTAssertEqual(FormatUtils.formatRatingStars(3.0), "★★★☆☆")
        XCTAssertEqual(FormatUtils.formatRatingStars(2.5), "★★★☆☆")
        XCTAssertEqual(FormatUtils.formatRatingStars(2.0), "★★☆☆☆")
        XCTAssertEqual(FormatUtils.formatRatingStars(1.5), "★★☆☆☆")
        XCTAssertEqual(FormatUtils.formatRatingStars(1.0), "★☆☆☆☆")
        XCTAssertEqual(FormatUtils.formatRatingStars(0.5), "★☆☆☆☆")
        XCTAssertEqual(FormatUtils.formatRatingStars(0.0), "☆☆☆☆☆")
    }

    func testNumberFormatting() {
        XCTAssertEqual(FormatUtils.formatNumber(1000), "1,000")
        XCTAssertEqual(FormatUtils.formatNumber(1000000), "1,000,000")
        XCTAssertEqual(FormatUtils.formatNumber(999), "999")
        XCTAssertEqual(FormatUtils.formatNumber(0), "0")
    }

    func testFileSizeFormatting() {
        XCTAssertEqual(FormatUtils.formatFileSize("1024"), "1.0 KB")
        XCTAssertEqual(FormatUtils.formatFileSize("1048576"), "1.0 MB")
        XCTAssertEqual(FormatUtils.formatFileSize("1073741824"), "1.0 GB")
        XCTAssertEqual(FormatUtils.formatFileSize("500"), "500 bytes")
        XCTAssertEqual(FormatUtils.formatFileSize(nil), "Unknown")
        XCTAssertEqual(FormatUtils.formatFileSize("invalid"), "Unknown")
    }

    func testDateFormatting() {
        let isoString = "2024-01-15T10:30:00Z"
        let formatted = FormatUtils.formatDate(isoString)

        // The exact format depends on locale, but should not be empty or the original string
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertNotEqual(formatted, isoString)
        XCTAssertFalse(formatted.contains("T"))  // Should not contain ISO8601 'T' separator
    }

    func testLanguageFormatting() {
        let languages1 = ["EN", "FR", "ES"]
        XCTAssertEqual(FormatUtils.formatLanguages(languages1), "EN, FR, ES + 0 more")

        let languages2 = ["EN", "FR", "ES", "DE", "IT", "PT", "RU", "ZH", "JA", "KO", "AR"]
        XCTAssertTrue(FormatUtils.formatLanguages(languages2).contains("+ 6 more"))

        let empty: [String]? = nil
        XCTAssertEqual(FormatUtils.formatLanguages(empty), "Unknown")
    }
}