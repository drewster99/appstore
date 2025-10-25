#!/bin/bash

# Script to batch analyze selected keywords from the exported JSON
# Usage: ./analyze_selected.sh selected_keywords.json [notes]
# Now uses database batch system for tracking and management

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <selected_keywords.json> [notes]"
    echo ""
    echo "This script will create a batch in the database and run 'appstore analyze'"
    echo "for each keyword, tracking progress and linking results."
    echo ""
    echo "Example:"
    echo "  $0 selected_keywords.json"
    echo "  $0 selected_keywords.json 'Testing Health & Fitness keywords'"
    exit 1
fi

SELECTED_FILE="$1"
NOTES="${2:-}"

if [ ! -f "$SELECTED_FILE" ]; then
    echo "Error: File not found: $SELECTED_FILE"
    exit 1
fi

echo "=========================================="
echo "Batch Keyword Analysis (Database Mode)"
echo "=========================================="
echo "Input file: $SELECTED_FILE"
if [ -n "$NOTES" ]; then
    echo "Notes: $NOTES"
fi
echo ""

# Step 1: Create batch
echo "Step 1/2: Creating batch in database..."
if [ -n "$NOTES" ]; then
    BATCH_ID=$(python3 -c "
import sys
sys.path.insert(0, '.')
from commands.batch import create_batch_from_json
from pathlib import Path
batch_id = create_batch_from_json(Path('$SELECTED_FILE'), notes='$NOTES', verbose=True)
print(batch_id, end='')
" 2>&1 | tail -1 | grep -oE '[0-9]+')
else
    BATCH_ID=$(python3 -c "
import sys
sys.path.insert(0, '.')
from commands.batch import create_batch_from_json
from pathlib import Path
batch_id = create_batch_from_json(Path('$SELECTED_FILE'), notes=None, verbose=True)
print(batch_id, end='')
" 2>&1 | tail -1 | grep -oE '[0-9]+')
fi

if [ -z "$BATCH_ID" ]; then
    echo "Error: Failed to create batch"
    exit 1
fi

echo ""
echo "✓ Created batch #$BATCH_ID"
echo ""

# Step 2: Process batch
echo "Step 2/2: Processing batch keywords..."
echo ""

python3 commands/process_batch.py "$BATCH_ID"

echo ""
echo "=========================================="
echo "Analysis complete!"
echo "=========================================="
echo ""
echo "View batch status:"
echo "  python3 commands/batch.py status $BATCH_ID"
echo ""
echo "List all batches:"
echo "  python3 commands/batch.py list"
echo "=========================================="
