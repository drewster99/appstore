import Foundation
import MCP

/// Registers MCP resource handlers for static reference data.
func registerResourceHandlers(on server: Server) async {
    await server.withMethodHandler(ListResources.self) { _ in
        ListResources.Result(resources: [
            Resource(
                name: "App Store Storefronts",
                uri: "appstore://storefronts",
                description: "Country codes and names for all supported App Store storefronts",
                mimeType: "application/json"
            ),
            Resource(
                name: "App Store Genres",
                uri: "appstore://genres",
                description: "Genre IDs and names for App Store categories",
                mimeType: "application/json"
            ),
            Resource(
                name: "Search Attributes",
                uri: "appstore://attributes",
                description: "Available search attribute names and descriptions for refined searches",
                mimeType: "application/json"
            ),
            Resource(
                name: "Chart Types",
                uri: "appstore://chart-types",
                description: "Available chart type names and descriptions for top charts",
                mimeType: "application/json"
            )
        ])
    }

    await server.withMethodHandler(ReadResource.self) { params in
        let uri = params.uri

        switch uri {
        case "appstore://storefronts":
            return try storefrontsResource()
        case "appstore://genres":
            return try genresResource()
        case "appstore://attributes":
            return try attributesResource()
        case "appstore://chart-types":
            return try chartTypesResource()
        default:
            throw MCPError.invalidRequest("Unknown resource URI: \(uri)")
        }
    }
}

// MARK: - Resource Builders

private func storefrontsResource() throws -> ReadResource.Result {
    var dict: [String: String] = [:]
    for sf in ListCommand.storefronts {
        dict[sf.code] = sf.name
    }
    let data = try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
    let json = String(data: data, encoding: .utf8) ?? "{}"
    return ReadResource.Result(contents: [
        .text(json, uri: "appstore://storefronts", mimeType: "application/json")
    ])
}

private func genresResource() throws -> ReadResource.Result {
    var dict: [String: String] = [:]
    for genre in ListCommand.genres {
        dict[String(genre.id)] = genre.name
    }
    let data = try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
    let json = String(data: data, encoding: .utf8) ?? "{}"
    return ReadResource.Result(contents: [
        .text(json, uri: "appstore://genres", mimeType: "application/json")
    ])
}

private func attributesResource() throws -> ReadResource.Result {
    var recommended: [String: String] = [:]
    var other: [String: String] = [:]
    for attr in ListCommand.attributes {
        if attr.recommended {
            recommended[attr.name] = attr.description
        } else {
            other[attr.name] = attr.description
        }
    }
    let dict: [String: Any] = ["recommended": recommended, "other": other]
    let data = try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
    let json = String(data: data, encoding: .utf8) ?? "{}"
    return ReadResource.Result(contents: [
        .text(json, uri: "appstore://attributes", mimeType: "application/json")
    ])
}

private func chartTypesResource() throws -> ReadResource.Result {
    var dict: [String: [String: String]] = [:]
    for ct in ListCommand.chartTypes {
        dict[ct.name] = [
            "displayName": ct.displayName,
            "description": ct.description
        ]
    }
    let data = try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
    let json = String(data: data, encoding: .utf8) ?? "{}"
    return ReadResource.Result(contents: [
        .text(json, uri: "appstore://chart-types", mimeType: "application/json")
    ])
}
