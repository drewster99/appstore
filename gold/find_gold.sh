#!/bin/bash

# Master script to find keyword gold nuggets
# This orchestrates the entire workflow from Excel file to analysis

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

# Step 1: Process keywords and score them
echo "Step 1/3: Processing and scoring keywords..."
echo "This may take 1-2 minutes for ~300k rows..."
echo ""

if [ ! -f "keywords_scored.json" ]; then
    python3 process_keywords.py "$EXCEL_FILE" "United States" > keywords_scored.json
    echo "✓ Processed keywords saved to: keywords_scored.json"
else
    echo "✓ Using existing keywords_scored.json"
fi

echo ""

# Step 2: Generate HTML report
echo "Step 2/3: Generating interactive HTML report..."
python3 generate_html.py keywords_scored.json keyword_report.html "$EXCEL_FILE"
echo "✓ HTML report generated: keyword_report.html"
echo ""

# Step 3: Open in browser
echo "Step 3/3: Opening report in browser..."
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
echo "The analyze script will run 'appstore analyze' for each"
echo "selected keyword and save the results as CSV files."
echo "========================================"
