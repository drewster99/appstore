# iTunes Search API Attributes for Software

## Valid Attributes (Confirmed Working)

The following 5 attributes have been tested and confirmed to work with `media=software&entity=software`:

- **`softwareDeveloper`** - Search by developer/publisher name only
- **`descriptionTerm`** - Search within app descriptions only
- **`keywordsTerm`** - Search within app keywords
- **`genreIndex`** - Search by genre index
- **`ratingIndex`** - Search by rating index

## Invalid Attributes (HTTP 400)

The following attributes return HTTP 400 when used with `media=software&entity=software`:

- `titleTerm` - Returns HTTP 400
- `artistTerm` - Returns HTTP 400
- `languageTerm` - Returns HTTP 400
- `releaseYearTerm` - Returns HTTP 400
- `ratingTerm` - Returns HTTP 400
- `allTrackTerm` - Returns HTTP 400
- All media-specific attributes (`albumTerm`, `songTerm`, `mixTerm`, `composerTerm`, `producerTerm`, `directorTerm`, `actorTerm`, `authorTerm`, `featureFilmTerm`, `movieTerm`, `movieArtistTerm`, `shortFilmTerm`, `showTerm`, `tvEpisodeTerm`, `tvSeasonTerm`, `allArtistTerm`)

## Usage Examples

```bash
# Search for apps by a specific developer only
curl "https://itunes.apple.com/search?term=Meta&media=software&entity=software&attribute=softwareDeveloper"

# Search within app descriptions only
curl "https://itunes.apple.com/search?term=editing&media=software&entity=software&attribute=descriptionTerm"

# Search within app keywords
curl "https://itunes.apple.com/search?term=photo&media=software&entity=software&attribute=keywordsTerm"
```

## Notes

1. **Default Behavior**: When no attribute is specified, the API searches across all fields.
2. **Case Sensitivity**: Attribute names are case-sensitive.
3. **Invalid Attributes**: Using an invalid attribute returns HTTP 400 (often with compressed/garbled error body).
4. **Combination**: You cannot combine multiple attributes in a single query.
5. **Parameters**: Both `media=software` and `entity=software` are required for iOS app searches.
