# App Store CLI Architecture

## CRITICAL: API Usage Pattern

### Two Different APIs with Different Rankings

1. **MZStore API** (`https://search.itunes.apple.com/WebObjects/MZStore.woa/wa/search`)
   - Returns apps in RANKED ORDER (same as App Store app)
   - Used by the actual App Store app
   - Returns app IDs in "bubbles" array
   - MUST be used for ranking/position information
   - Parameters: `media=software` only (entity parameter is ignored)
   - No limit parameter (always returns all results, limit in code)
   - Access via: `ScrapeCommand.fetchRankedAppIds()`

2. **iTunes Search/Lookup API** (`https://itunes.apple.com/search` and `/lookup`)
   - Returns full app details with all metadata
   - Does NOT preserve correct ranking (different algorithm)
   - Used ONLY for enriching app data after getting rankings
   - Parameters: `media=software` AND `entity=software` (ensures iOS apps only)
   - Default limit: 200 (configurable)
   - Access via: `AppStoreAPI.lookupAppDetails()`

### The Correct Pattern (NEVER DEVIATE)

```swift
// Step 1: Get ranked app IDs from MZStore API
let rankedAppIds = try await ScrapeCommand.fetchRankedAppIds(
    term: searchTerm,
    storefront: storefront,
    language: language,
    limit: limit
)

// Step 2: The position in rankedAppIds IS the rank (1-based)
let rank = rankedAppIds.firstIndex(of: targetAppId).map { $0 + 1 }

// Step 3: Enrich with full details from iTunes Lookup API
let apps = try await AppStoreAPI.lookupAppDetails(
    appIds: rankedAppIds,
    storefront: storefront,
    language: language
)
```

### Commands Using This Pattern

- **`scrape`**: Gets ranked IDs from MZStore, enriches with lookup
- **`ranks`**: For each keyword, gets ranked IDs from MZStore, finds app position, enriches top results with lookup

### DO NOT (Common Mistakes)

- ❌ Use iTunes Search API for ranking (wrong rankings!)
- ❌ Reimplement the same API calls in multiple places
- ❌ Mix ranking from one API with data from another
- ❌ Assume iTunes Search API rankings match App Store app

### ALWAYS

- ✅ Use shared methods for API calls (`ScrapeCommand.fetchRankedAppIds`, `AppStoreAPI.lookupAppDetails`)
- ✅ Preserve the order from MZStore API as the true ranking
- ✅ Enrich with lookup API for consistent data format
- ✅ Remember: Position in MZStore results = App Store ranking

## Why This Architecture?

The iTunes Search API and MZStore API return **completely different rankings** for the same search term. For example, searching for "accurate":
- iTunes Search API: Returns 142 results, Fish Identifier app ranks #58
- MZStore API: Returns 196 results, Fish Identifier app ranks #70

The MZStore API is what powers the actual App Store app, so its rankings are what users see. Using the iTunes Search API for rankings would give incorrect results that don't match the App Store.

## Implementation Notes

1. The `scrape` command was already using MZStore API correctly
2. The `ranks` command was incorrectly using iTunes Search API
3. Both now share the same code path for consistency
4. Lookup API is used only for enriching data, never for ranking