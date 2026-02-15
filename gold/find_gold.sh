#!/bin/bash

# Master script to find keyword gold nuggets
# This orchestrates the entire workflow from Excel file to analysis
# Now uses database-first approach

set -e

echo "========================================"
echo "🏆 Keyword Gold Nugget Finder"
echo "========================================"
echo ""

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    pip install openpyxl
else
    source venv/bin/activate
fi

# Find Excel file
EXCEL_FILE=$(ls *.xlsx 2>/dev/null | head -1)

if [ -z "$EXCEL_FILE" ]; then
    echo "Error: No .xlsx file found in current directory"
    echo "Please place the Apple Search Ads Monthly Rankings Excel file here"
    exit 1
fi

echo "Found Excel file: $EXCEL_FILE"
echo ""

# Get country from command line or use default
COUNTRY="${1:-United States}"

# Step 1: Check if Excel file is already imported
echo "Step 1/4: Checking database..."
# Extract just the filename without path
EXCEL_FILENAME=$(basename "$EXCEL_FILE")

# Check if this file is already in the database
ALREADY_IMPORTED=$(sqlite3 ~/.appstore/analytics.db \
    "SELECT COUNT(*) FROM apple_reports WHERE source_filename = '$EXCEL_FILENAME'" 2>/dev/null || echo "0")

if [ "$ALREADY_IMPORTED" -eq "0" ]; then
    echo "  Importing Excel file into database..."
    python3 commands/import_report.py "$EXCEL_FILE" --country "$COUNTRY"
    echo ""
else
    echo "  ✓ Excel file already imported"
    echo ""
fi

# Step 2: Generate scored keywords JSON (from database)
echo "Step 2/4: Generating scored keywords from database..."
python3 process_keywords.py --country "$COUNTRY" > keywords_scored.json
echo "  ✓ Saved to: keywords_scored.json"
echo ""

# Step 3: Generate HTML report (from database)
echo "Step 3/4: Generating interactive HTML report..."
python3 generate_html.py --country "$COUNTRY" --output keyword_report.html
echo ""

# Step 4: Open in browser
echo "Step 4/4: Opening report in browser..."
open keyword_report.html 2>/dev/null || echo "Please open keyword_report.html in your browser"

echo ""
echo "========================================"
echo "✓ Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Review the keywords in your browser"
echo "2. Select keywords you want to analyze"
echo "3. Click 'Export Selected' to download selected_keywords.json"
echo "4. Run: ./analyze_selected.sh selected_keywords.json"
echo ""
echo "The analyze script will create a batch and run 'appstore analyze'"
echo "for each selected keyword, tracking progress in the database."
echo "========================================"
