import Foundation
import MCP

/// MCP server exposing App Store CLI functionality for LLM consumption via stdio transport.
final class AppStoreMCPServer {
    func run() async throws {
        let server = Server(
            name: "appstore-mcp",
            version: appVersion,
            capabilities: .init(
                prompts: .init(listChanged: false),
                resources: .init(subscribe: false, listChanged: false),
                tools: .init(listChanged: false)
            )
        )

        await registerToolHandlers(on: server)
        await registerResourceHandlers(on: server)
        await registerPromptHandlers(on: server)

        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
}
