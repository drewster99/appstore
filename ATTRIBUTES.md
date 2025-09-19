# iTunes Search API Attributes for Software

## Discovered Working Attributes

The following attributes have been tested and confirmed to work with `entity=software` for the iTunes Search API:

### Software/App-Specific Attributes
- **`softwareDeveloper`** - Search by developer/publisher name only
- **`titleTerm`** - Search within app titles/names only
- **`descriptionTerm`** - Search within app descriptions only

### General Attributes (work with software)
- **`artistTerm`** - Search by artist/developer name
- **`keywordsTerm`** - Search within keywords
- **`languageTerm`** - Search by language
- **`allTrackTerm`** - Search across all track-related fields

### Rating & Date Attributes
- **`ratingTerm`** - Search by content rating
- **`ratingIndex`** - Search by rating index
- **`releaseYearTerm`** - Search by release year

### Genre Attributes
- **`genreIndex`** - Search by genre index

### Media-Related Attributes (surprisingly work with software)
These attributes are primarily for other media types but still function with software:
- **`albumTerm`** - Valid but typically no results for apps
- **`songTerm`** - Returns app results (unclear why)
- **`mixTerm`** - Returns app results
- **`composerTerm`** - Returns app results
- **`producerTerm`** - Returns app results
- **`directorTerm`** - Returns app results
- **`actorTerm`** - Returns app results
- **`authorTerm`** - Valid but typically no results
- **`featureFilmTerm`** - Returns app results
- **`movieTerm`** - Returns app results
- **`movieArtistTerm`** - Valid but typically no results
- **`shortFilmTerm`** - Returns app results
- **`showTerm`** - Valid but typically no results
- **`tvEpisodeTerm`** - Returns app results
- **`tvSeasonTerm`** - Valid but typically no results
- **`allArtistTerm`** - Valid but typically no results

## Usage Examples

```bash
# Search for apps by a specific developer only
curl "https://itunes.apple.com/search?term=Meta&entity=software&attribute=softwareDeveloper"

# Search within app titles only
curl "https://itunes.apple.com/search?term=photo&entity=software&attribute=titleTerm"

# Search within app descriptions only
curl "https://itunes.apple.com/search?term=editing&entity=software&attribute=descriptionTerm"

# Search by release year
curl "https://itunes.apple.com/search?term=2024&entity=software&attribute=releaseYearTerm"

# Search by content rating
curl "https://itunes.apple.com/search?term=4&entity=software&attribute=ratingTerm"
```

## Notes

1. **Default Behavior**: When no attribute is specified, the API searches across all fields.

2. **Media Type Attributes**: Many attributes designed for music/movies/TV still work with software but may not produce meaningful filtering. They appear to fall back to general search.

3. **Case Sensitivity**: Attribute names appear to be case-sensitive.

4. **Invalid Attributes**: Using an invalid attribute returns an error response (often compressed/garbled).

5. **Combination**: You cannot combine multiple attributes in a single query.

## Recommended Attributes for Software

For app searches, these are the most useful attributes:
- `softwareDeveloper` - Find apps by a specific developer
- `titleTerm` - Find apps with specific words in the title
- `descriptionTerm` - Find apps mentioning specific features/keywords in description
- `keywordsTerm` - Search app keywords
- `releaseYearTerm` - Find apps released in a specific year

## Total Working Attributes: 27

All 27 attributes listed above have been tested and confirmed to return valid responses when used with `entity=software`, though not all produce meaningful software-specific filtering.