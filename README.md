# App Store MCP Server

An MCP server for searching the App Store, checking keyword rankings, analyzing competition, and tracking trends — powered by a native macOS binary for fast, direct access to App Store APIs.

Also works as a standalone CLI tool with rich output formats.

## Requirements

- macOS 26+ (Apple Silicon)

## Quick Start

### Install via uvx (recommended)

```bash
uvx appstore-mcp-server
```

This downloads the native binary on first run and starts the MCP server. No persistent installation needed.

### Install via pip

```bash
pip install appstore-mcp-server
appstore-mcp-server
```

### Download binary directly

Download the latest release from [GitHub Releases](https://github.com/drewster99/appstore-mcp-server/releases), extract, and run:

```bash
tar xzf appstore-*-macos-arm64.tar.gz
./appstore --mcp
```

## MCP Client Setup

### Claude Code

```bash
claude mcp add --scope user --transport stdio -- appstore-mcp-server uvx appstore-mcp-server
```

Or with the binary directly:

```bash
claude mcp add --scope user --transport stdio -- appstore-mcp-server /path/to/appstore --mcp
```

### Claude Desktop

Add to your Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "appstore-mcp-server": {
      "command": "uvx",
      "args": ["appstore-mcp-server"]
    }
  }
}
```

### Other MCP Clients

The server communicates over stdio using the standard MCP protocol. Run with `--mcp` flag:

```
/path/to/appstore --mcp
```

## MCP Tools

| Tool | Description |
|------|-------------|
| `search_apps` | iTunes Search API with attribute/genre filtering |
| `search_ranked` | MZStore API — results match actual App Store rankings |
| `lookup_app` | Look up an app by ID, bundle ID, or App Store URL |
| `top_charts` | Current top chart rankings (free, paid, grossing) |
| `find_app_rank` | Check where an app ranks for a single keyword |
| `check_app_rankings` | Check an app's rank across auto-generated keywords (slow) |
| `analyze_keyword` | Competitive analysis with competitiveness score (0-100) |
| `app_competitors` | Find an app's top competitors via overlapping search results |
| `compare_keywords` | Compare competitiveness across multiple keywords (slow) |
| `discover_trending` | Discover trending categories from new chart entries |
| `version` | Get the server version |

Most tools support:
- **`storefront`** — Two-letter country code (default: `US`). Use for any App Store region.
- **`verbosity`** — Controls response detail and token usage:
  - `compact` (default) — Key fields only, no descriptions. Best for most queries.
  - `full` — Includes app descriptions and release notes.
  - `complete` — All fields from the API response. Verbose (~4KB/app).

### MCP Resources

| Resource | URI | Description |
|----------|-----|-------------|
| Storefronts | `appstore://storefronts` | Country codes and names for all supported App Store regions |
| Genres | `appstore://genres` | Genre IDs and names for App Store categories |
| Search Attributes | `appstore://attributes` | Available search attribute names for refined searches |
| Chart Types | `appstore://chart-types` | Available chart types for top charts queries |

### MCP Prompts

| Prompt | Description |
|--------|-------------|
| `competitive_analysis` | Guided workflow: look up an app, find competitors, analyze keyword rankings, and get actionable recommendations. Args: `keyword_or_app_id` (required), `storefront` (optional). |
| `market_research` | Guided workflow: search rankings, top charts, competitiveness analysis, trending discovery, and opportunity identification. Args: `category` (required), `storefront` (optional). |

## CLI Usage

The binary doubles as a full-featured CLI tool. Run without `--mcp` for interactive use.

### Commands

| Command | Description |
|---------|-------------|
| `search <query>` | Search the App Store (iTunes Search API) |
| `scrape <query>` | Search with **ranked** results matching the App Store app (MZStore API) |
| `lookup <id-or-bundle>` | Look up apps by ID, bundle ID, or URL |
| `ranks <app-id>` | Analyze keyword rankings for an app |
| `analyze <query>` | Competitive analysis of top 20 results with keyword matching |
| `top <chart-type>` | View top charts (free, paid, grossing, newfree, newpaid) |
| `list <type>` | List storefronts, genres, attributes, or chart types |

### search

Search the App Store using the iTunes Search API.

```bash
appstore search "photo editor"
appstore search --limit 5 minecraft
appstore search --storefront JP nintendo
appstore search --attribute softwareDeveloper "Meta Platforms"
appstore search --genre 6014 puzzle             # Games category
appstore search --verbosity minimal spotify
appstore search --output-format json spotify
appstore search --unlimited "weather"
```

**Key options:**

| Option | Description |
|--------|-------------|
| `--limit <n>` | Number of results (1-200, default: 200, 0 for unlimited) |
| `--unlimited` | Same as `--limit 0` |
| `--attribute <attr>` | Search specific field: `titleTerm`, `softwareDeveloper`, `descriptionTerm` |
| `--genre <id>` | Filter by genre ID (e.g., 6014 for Games) |
| `--storefront <code>` | Country code (e.g., `US`, `JP`, `GB`) |
| `--output-format <fmt>` | `text` (default), `json`, `raw-json`, `markdown`, `html`, `html-open` |
| `--verbosity <level>` | `minimal`, `summary` (default), `expanded`, `verbose`, `complete` |
| `--full-description` | Show complete app descriptions |

### scrape

Search using the MZStore API. Results are in **actual App Store ranked order** — the same ranking users see in the App Store app. Use this instead of `search` when ranking position matters.

```bash
appstore scrape spotify
appstore scrape --limit 10 "photo editor"
appstore scrape --storefront GB twitter
appstore scrape --output-format json instagram
```

**Key options:**

| Option | Description |
|--------|-------------|
| `--limit <n>` | Maximum results (default: 200) |
| `--storefront <code>` | Country code (default: `US`) |
| `--output-format <fmt>` | `text` (default), `json`, `raw-json`, `markdown`, `html` |
| `--verbosity <level>` | `minimal`, `summary` (default), `expanded`, `verbose`, `complete` |

### lookup

Look up specific apps by ID, bundle ID, or App Store URL.

```bash
appstore lookup 284910350                                   # Numeric = app ID
appstore lookup com.spotify.client                          # Non-numeric = bundle ID
appstore lookup --ids 284910350,324684580                   # Multiple apps
appstore lookup --url "https://apps.apple.com/us/app/yelp/id284910350"
appstore lookup 284910350 --storefront JP
appstore lookup com.facebook.Facebook --output-format json
```

**Key options:**

| Option | Description |
|--------|-------------|
| `--id <id>` | Look up by app ID |
| `--ids <id1,id2,...>` | Look up multiple apps (comma-separated) |
| `--bundle-id <bundle>` | Look up by bundle identifier |
| `--url <url>` | Look up by App Store URL |
| `--storefront <code>` | Country code (default: `US`) |
| `--output-format <fmt>` | `text`, `json`, `raw-json`, `markdown`, `html` |
| `--verbosity <level>` | `minimal`, `summary` (default), `expanded`, `verbose`, `complete` |

### ranks

Analyze keyword rankings for an app. Auto-generates keywords from the app's name, subtitle, and description, then checks where the app ranks for each keyword. Uses on-device AI (Apple Intelligence) to generate additional keywords when available.

```bash
appstore ranks 324684580                        # Analyze Spotify's rankings
appstore ranks 284910350 --limit 30             # Test 30 keywords for Yelp
appstore ranks 544007664 --storefront GB        # UK store rankings
```

**Key options:**

| Option | Description |
|--------|-------------|
| `--limit <n>` | Max keywords to test (default: all generated) |
| `--storefront <code>` | Country code (default: `US`) |
| `--verbosity <level>` | `minimal`, `summary` (default), `expanded`, `verbose`, `complete` |

This command makes multiple sequential API calls and may take 30-120 seconds.

### analyze

Analyze the top 20 search results for a keyword with competitive metrics. Outputs CSV with match scores, ratings velocity, app age, and a competitiveness summary.

```bash
appstore analyze "cat toy"
appstore analyze --storefront GB "photo editor"
appstore analyze "music player" > results.csv
```

**CSV columns:** App ID, Rating, Rating Count, Original Release, Latest Release, Age Days, Freshness Days, Title Match Score, Description Match Score, Ratings Per Day, Title, Genre, Version, Min iOS, Age Rating.

**Key options:**

| Option | Description |
|--------|-------------|
| `--storefront <code>` | Country code (default: `US`) |

### top

View App Store top charts.

```bash
appstore top free                               # Top free apps (US)
appstore top paid --limit 10                    # Top 10 paid apps
appstore top grossing --storefront JP           # Top grossing in Japan
appstore top paid --genre 6014                  # Top paid games
appstore top newfree --output-format json       # New free apps as JSON
```

**Chart types:** `free`, `paid`, `grossing`, `newfree`, `newpaid`

**Key options:**

| Option | Description |
|--------|-------------|
| `--limit <n>` | Number of results (1-200, default: 25) |
| `--genre <id>` | Filter by genre ID |
| `--storefront <code>` | Country code (default: `US`) |
| `--output-format <fmt>` | `text`, `json`, `raw-json`, `markdown`, `html` |
| `--verbosity <level>` | `minimal`, `summary` (default), `expanded`, `verbose`, `complete` |

### list

List available values for storefronts, genres, attributes, or chart types.

```bash
appstore list storefronts                       # All country codes
appstore list genres                            # All genre IDs
appstore list attributes                        # Search attributes
appstore list charttypes                        # Chart types
appstore list storefronts --output-format json
```

Aliases: `storefront`/`storefronts`/`country`/`countries`, `genre`/`genres`/`category`/`categories`, `attribute`/`attributes`, `charttype`/`charttypes`/`chart`/`charts`.

### Common Options

These options are available across most commands:

| Option | Description |
|--------|-------------|
| `--storefront <code>` | App Store country (`US`, `JP`, `GB`, `FR`, etc.) |
| `--country <code>` | Alias for `--storefront` |
| `--language <code>` | Language for results (default: `en_us`) |
| `--output-format <fmt>` | Output format (see below) |
| `--verbosity <level>` | Detail level (see below) |
| `--show-request` | Display the HTTP request details |
| `--show-response-headers` | Display HTTP response headers |
| `-o, --output-file <path>` | Write output to file |
| `-i, --input-file <path>` | Read cached JSON from file |
| `--help, -h` | Show help for any command |

**Output formats:** `text` (default), `json`, `raw-json`, `markdown`, `html`, `html-open` (opens in browser).

**Verbosity levels:**

| Level | Description |
|-------|-------------|
| `minimal` | Single line per app |
| `summary` | Key details (default) |
| `expanded` | Adds ratings, size, version |
| `verbose` | Adds URLs, languages, features |
| `complete` | All available fields |

## Building from Source

```bash
git clone https://github.com/drewster99/appstore-mcp-server.git
cd appstore-mcp-server
```

Open `appstore.xcodeproj` in Xcode and build (Product > Build), or:

```bash
xcodebuild build \
    -project appstore.xcodeproj \
    -scheme appstore \
    -configuration Release \
    -destination 'platform=macOS,arch=arm64'
```

The binary will be in the DerivedData build products directory. Run as MCP server with `./appstore --mcp` or as CLI with `./appstore <command>`.

## Architecture

The server uses two different Apple APIs:

- **MZStore API** — Returns apps in actual App Store ranked order. Used by `search_ranked`, `find_app_rank`, `check_app_rankings`, `analyze_keyword`, `app_competitors`, `compare_keywords` (and CLI `scrape`, `ranks`, `analyze`).
- **iTunes Search/Lookup API & RSS** — Returns full app metadata and chart data. Used by `search_apps`, `lookup_app`, `top_charts`, `discover_trending` (and CLI `search`, `lookup`, `top`).

For ranking-sensitive operations, the MZStore API fetches ranked app IDs first, then the iTunes Lookup API enriches them with full details. See [CLAUDE.md](CLAUDE.md) for implementation details.

## License

MIT
