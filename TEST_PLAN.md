# App Store CLI Test Plan

## Testing Strategy

Since we're calling live APIs, we can't mock responses, but we can use well-known, stable apps that are unlikely to be removed from the App Store. We'll test with:

1. **Facebook** (ID: 284882215, Bundle: com.facebook.Facebook) - Meta's app, stable presence
2. **Spotify** (ID: 324684580, Bundle: com.spotify.client) - Major music app
3. **Twitter/X** (ID: 333903271, Bundle: com.atebits.Tweetie2) - Major social app
4. **Yelp** (ID: 284910350, Bundle: com.yelp.yelpiphone) - Stable business app

## Test Categories

### 1. Command Parsing Tests
- Test valid commands are parsed correctly
- Test invalid commands return appropriate errors
- Test help flags work for all commands
- Test parameter validation (limits, verbosity levels, etc.)

### 2. Search Command Tests
```swift
// Test basic search
testSearchBasic()
- Search for "spotify"
- Verify results contain at least 1 app
- Verify Spotify app is in results

// Test search with limit
testSearchWithLimit()
- Search "facebook" with --limit 5
- Verify exactly 5 results returned

// Test search with country
testSearchWithCountry()
- Search "nintendo" with --country jp
- Verify Japanese results returned

// Test search with attribute
testSearchWithAttribute()
- Search "spotify" with --attribute softwareDeveloper
- Verify only apps by Spotify developer returned

// Test all verbosity levels
testSearchVerbosityOneline()
testSearchVerbositySummary()
testSearchVerbosityExpanded()
testSearchVerbosityVerbose()
testSearchVerbosityComplete()
- Each test verifies expected fields present

// Test JSON output
testSearchJSON()
- Search with --show-json
- Verify valid JSON returned
- Verify structure matches expected format

// Test request display
testSearchShowRequest()
- Search with --show-request
- Verify URL and parameters displayed
```

### 3. Lookup Command Tests
```swift
// Test lookup by ID
testLookupById()
- Lookup --id 284882215 (Facebook)
- Verify exactly 1 result
- Verify correct app returned

// Test lookup by multiple IDs
testLookupByMultipleIds()
- Lookup --ids 284882215,324684580
- Verify 2 results returned
- Verify both apps present

// Test lookup by bundle ID
testLookupByBundleId()
- Lookup --bundle-id com.spotify.client
- Verify Spotify app returned

// Test lookup by URL
testLookupByUrl()
- Lookup --url "https://apps.apple.com/us/app/facebook/id284882215"
- Verify Facebook app returned

// Test lookup with country
testLookupWithCountry()
- Lookup --id 284882215 --country gb
- Verify UK version returned

// Test verbosity levels for lookup
testLookupVerbosityLevels()
- Same as search tests

// Test JSON output for lookup
testLookupJSON()
- Similar to search JSON test
```

### 4. Error Handling Tests
```swift
// Test invalid app ID
testInvalidAppId()
- Lookup --id 99999999999999
- Verify "No results found"

// Test invalid bundle ID
testInvalidBundleId()
- Lookup --bundle-id com.invalid.nonexistent
- Verify "No results found"

// Test malformed URL
testMalformedUrl()
- Lookup --url "not-a-url"
- Verify error message

// Test invalid country code
testInvalidCountry()
- Search with --country zz
- Verify appropriate error or empty results

// Test invalid attribute
testInvalidAttribute()
- Search with --attribute invalidAttr
- Verify error or no results

// Test limit out of range
testLimitOutOfRange()
- Search with --limit 0
- Search with --limit 201
- Verify limits enforced (1-200)
```

### 5. Integration Tests
```swift
// Test combined parameters
testCombinedParameters()
- Search "music" --limit 10 --country jp --verbosity verbose --show-json
- Verify all parameters respected

// Test special characters in search
testSpecialCharacters()
- Search for apps with spaces, quotes, special chars
- Verify proper URL encoding

// Test empty search results
testEmptyResults()
- Search for gibberish string
- Verify "No results found" message

// Test network timeout handling
testNetworkTimeout()
- Use very slow network or timeout parameter
- Verify graceful error handling
```

### 6. Output Format Tests
```swift
// Test field formatting
testNumberFormatting()
- Verify rating counts use comma separators
- Verify file sizes formatted correctly (KB, MB, GB)

testDateFormatting()
- Verify dates in human-readable format

testRatingFormatting()
- Verify star display correct

testLanguageFormatting()
- Verify language codes sorted and truncated if > 10
```

### 7. Performance Tests
```swift
testSearchPerformance()
- Measure time for standard search
- Should complete within 2-3 seconds

testLookupPerformance()
- Measure time for lookup
- Should be faster than search
```

## Implementation Approach

### Using XCTest (Recommended)
1. Create an XCode test target
2. Import the main app modules
3. Test each component directly
4. Use async/await for API calls
5. Use XCTAssert for validations

### Alternative: Shell Script Tests
```bash
#!/bin/bash
# Simple test runner

APPSTORE="/path/to/appstore"
PASS_COUNT=0
FAIL_COUNT=0

test_search_basic() {
    output=$($APPSTORE search spotify --limit 1)
    if [[ $output == *"Spotify"* ]]; then
        echo "✓ test_search_basic"
        ((PASS_COUNT++))
    else
        echo "✗ test_search_basic"
        ((FAIL_COUNT++))
    fi
}

# Run all tests
test_search_basic
# ... more tests ...

echo "Tests: $PASS_COUNT passed, $FAIL_COUNT failed"
```

## Known Apps for Testing

These apps have been stable for years and are unlikely to disappear:

| App | ID | Bundle ID | Use Case |
|-----|-----|-----------|----------|
| Facebook | 284882215 | com.facebook.Facebook | Social/Meta app |
| Instagram | 389801252 | com.burbn.instagram | Meta app |
| WhatsApp | 310633997 | net.whatsapp.WhatsApp | Meta messaging |
| Spotify | 324684580 | com.spotify.client | Music streaming |
| Netflix | 363590051 | com.netflix.Netflix | Video streaming |
| Twitter/X | 333903271 | com.atebits.Tweetie2 | Social media |
| YouTube | 544007664 | com.google.ios.youtube | Google video |
| Gmail | 422689480 | com.google.Gmail | Google email |
| Uber | 368677368 | com.ubercab.UberClient | Transportation |
| Yelp | 284910350 | com.yelp.yelpiphone | Business reviews |

## Test Execution

1. **Unit Tests**: Test individual functions (parsing, formatting)
2. **Integration Tests**: Test full command execution
3. **Regression Tests**: Run after any changes
4. **Performance Tests**: Monitor API response times

## Continuous Integration

Could set up GitHub Actions to:
1. Build the project
2. Run tests against live API
3. Report results
4. Flag any breaking changes

## Notes

- API rate limits: ~20 calls/minute, so space out tests
- Some results may vary by region/time
- App versions will change, so don't test exact version strings
- Focus on structure/format rather than exact content