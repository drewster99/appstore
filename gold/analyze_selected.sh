#!/bin/bash

# Script to batch analyze selected keywords from the exported JSON
# Usage: ./analyze_selected.sh selected_keywords.json [output_dir]

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <selected_keywords.json> [output_dir]"
    echo ""
    echo "This script will run 'appstore analyze' for each keyword in the JSON file"
    echo "and save the results to CSV files in the output directory."
    exit 1
fi

SELECTED_FILE="$1"
OUTPUT_DIR="${2:-analysis_results}"

if [ ! -f "$SELECTED_FILE" ]; then
    echo "Error: File not found: $SELECTED_FILE"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "=========================================="
echo "Batch Keyword Analysis"
echo "=========================================="
echo "Input file: $SELECTED_FILE"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Extract keywords from JSON using Python
KEYWORDS=$(python3 -c "
import json
import sys

with open('$SELECTED_FILE') as f:
    data = json.load(f)

for item in data:
    print(item['search_term'])
")

# Count keywords
KEYWORD_COUNT=$(echo "$KEYWORDS" | wc -l | tr -d ' ')
echo "Found $KEYWORD_COUNT keywords to analyze"
echo ""

# Counter
CURRENT=0

# Analyze each keyword
while IFS= read -r keyword; do
    CURRENT=$((CURRENT + 1))

    # Create safe filename
    SAFE_NAME=$(echo "$keyword" | tr ' ' '_' | tr -cd '[:alnum:]_-')
    OUTPUT_FILE="$OUTPUT_DIR/${SAFE_NAME}.csv"

    echo "[$CURRENT/$KEYWORD_COUNT] Analyzing: \"$keyword\""

    # Run appstore analyze
    if appstore analyze "$keyword" > "$OUTPUT_FILE" 2>&1; then
        echo "  ✓ Saved to: $OUTPUT_FILE"
    else
        echo "  ✗ Error analyzing \"$keyword\""
    fi

    # Rate limiting - wait a bit between requests
    sleep 2

done <<< "$KEYWORDS"

echo ""
echo "=========================================="
echo "Analysis complete!"
echo "Results saved to: $OUTPUT_DIR/"
echo "=========================================="
