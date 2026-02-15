import XCTest
@testable import appstore

class SearchAttributeTests: XCTestCase {

    func testAllAttributesHaveDescriptions() {
        for attribute in SearchAttribute.allCases {
            XCTAssertFalse(attribute.description.isEmpty, "Attribute \(attribute) has empty description")
        }
    }

    func testRecommendedAttributes() {
        let recommended = SearchAttribute.allCases.filter { $0.isRecommendedForSoftware }

        XCTAssertTrue(recommended.contains(.softwareDeveloper))
        XCTAssertTrue(recommended.contains(.titleTerm))
        XCTAssertTrue(recommended.contains(.descriptionTerm))
        XCTAssertTrue(recommended.contains(.artistTerm))
        XCTAssertTrue(recommended.contains(.keywordsTerm))

        XCTAssertFalse(recommended.contains(.movieTerm))
        XCTAssertFalse(recommended.contains(.tvEpisodeTerm))
    }

    func testAttributeCount() {
        // We discovered 27 working attributes
        XCTAssertEqual(SearchAttribute.allCases.count, 27)
    }
}

class TopChartTypeTests: XCTestCase {

    func testChartTypeRawValues() {
        XCTAssertEqual(TopChartType.free.rawValue, "topfreeapplications")
        XCTAssertEqual(TopChartType.paid.rawValue, "toppaidapplications")
        XCTAssertEqual(TopChartType.grossing.rawValue, "topgrossingapplications")
        XCTAssertEqual(TopChartType.newFree.rawValue, "newfreeapplications")
        XCTAssertEqual(TopChartType.newPaid.rawValue, "newpaidapplications")
    }

    func testChartTypeDisplayNames() {
        XCTAssertEqual(TopChartType.free.displayName, "Top Free")
        XCTAssertEqual(TopChartType.paid.displayName, "Top Paid")
        XCTAssertEqual(TopChartType.grossing.displayName, "Top Grossing")
    }

    func testAllChartTypesHaveDescriptions() {
        for chartType in TopChartType.allCases {
            XCTAssertFalse(chartType.description.isEmpty)
            XCTAssertFalse(chartType.displayName.isEmpty)
        }
    }
}

class EnvironmentConfigTests: XCTestCase {

    func testDefaultStorefront() {
        // Default should be "us" unless overridden
        let storefront = EnvironmentConfig.defaultStorefront
        XCTAssertFalse(storefront.isEmpty)
    }

    func testChartTypeMapping() {
        // Test that chart type environment variable parsing works
        // Note: This test depends on environment variables not being set
        let defaultChart = EnvironmentConfig.defaultChartType
        XCTAssertEqual(defaultChart, .free)  // Default when no env var
    }

    func testDefaultLimitParsing() {
        // Test that nil is returned when no env var is set
        let limit = EnvironmentConfig.defaultLimit
        if ProcessInfo.processInfo.environment["APPSTORE_DEFAULT_LIMIT"] == nil {
            XCTAssertNil(limit)
        }
    }
}