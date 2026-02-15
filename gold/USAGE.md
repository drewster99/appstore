# Gold Nugget Finder - Usage Guide

## Overview

This tool helps you find high-popularity, low-competition keywords (gold nuggets) from Apple Search Ads data.

## Quick Start

1. Place your Apple Search Ads Monthly Rankings Excel file in this directory
2. Run the master script:
   ```bash
   ./find_gold.sh
   ```
3. Review keywords in your browser
4. Select keywords and export them
5. Analyze selected keywords:
   ```bash
   ./analyze_selected.sh selected_keywords.json
   ```

## Detailed Workflow

### Step 1: Score Keywords

The system scores each keyword based on three criteria:

**Rank in Genre** (0-3 points):
- Rank 1-10: 3 points
- Rank 11-25: 2 points
- Rank 26-50: 1 point

**Search Popularity in Genre** (0-3 points):
- 76-100: 3 points
- 61-75: 2 points
- 50-60: 1 point

**Overall Search Popularity** (0-5 points):
- 86-100: 5 points
- 71-85: 4 points
- 61-70: 3 points
- 50-60: 2 points

**Maximum total score: 11 points**

### Step 2: Review in HTML Report

The interactive HTML report shows:
- All keywords sorted by total score (highest first)
- Individual scores for each category
- Genre and ranking information
- Sortable columns
- Selection checkboxes

**Features**:
- Click column headers to sort
- Use "Select Top 50/100" for quick selection
- Check individual keywords manually
- Export selected keywords as JSON

### Step 3: Analyze Competition

Once you've selected promising keywords:

```bash
./analyze_selected.sh selected_keywords.json
```

This will:
1. Run `appstore analyze` for each keyword
2. Save results as CSV files in `analysis_results/`
3. Show detailed competition analysis for each keyword

The analysis shows:
- Top 20 apps for that keyword
- Title match scores (how well they target the keyword)
- Rating counts and velocities
- App age and freshness
- Overall competition level

### Step 4: Find Gold

Look for keywords where:
- ✅ High total score (8-11 points)
- ✅ Low title match scores in top results
- ✅ Low rating counts (< 1000 reviews)
- ✅ Few apps with perfect title matches

These are your **gold nuggets** - high search volume, low competition!

## Files

- `find_gold.sh` - Master workflow script
- `process_keywords.py` - Scores keywords from Excel
- `generate_html.py` - Creates interactive report
- `analyze_selected.sh` - Batch analyzes keywords
- `keywords_scored.json` - All scored keywords (generated)
- `keyword_report.html` - Interactive report (generated)
- `selected_keywords.json` - Your selections (exported from browser)
- `analysis_results/` - Competition analysis results (generated)

## Requirements

- Python 3 with `openpyxl` (auto-installed by find_gold.sh)
- `appstore` CLI tool (for competition analysis)
- Apple Search Ads Monthly Rankings Excel file

## Tips

1. **Start with high scores**: Keywords scoring 8+ are most promising
2. **Check multiple genres**: Different categories have different competition levels
3. **Consider app age**: Older apps in top results = established competition
4. **Look at velocity**: High ratings per day = active competition
5. **Perfect title matches matter**: Apps with keyword in title are tough to beat
6. **Batch process wisely**: Use rate limiting (built into analyze_selected.sh)

## Example Workflow

```bash
# Initial setup
cd /Users/andrew/cursor/appstore/gold
./find_gold.sh

# Browser opens showing 500 top keywords

# Select 20 promising keywords in browser
# Click "Export Selected" → saves selected_keywords.json

# Analyze competition for selected keywords
./analyze_selected.sh selected_keywords.json

# Review results in analysis_results/ directory
# Look for low competition gems!
```

## Troubleshooting

**"No .xlsx file found"**
→ Place the Excel file in the gold directory

**"ModuleNotFoundError: openpyxl"**
→ Run: `source venv/bin/activate && pip install openpyxl`

**"appstore: command not found"**
→ Make sure the appstore CLI is built and in your PATH

**Analysis takes too long**
→ Select fewer keywords, or adjust sleep time in analyze_selected.sh
