# Database Migration Complete

The Apple Search Ads keyword analysis workflow has been successfully migrated to a database-first architecture.

## What Changed

### Database Schema
All data is now stored in `~/.appstore/analytics.db` with these new tables:

- **`apple_reports`** - Tracks each imported Apple Search Ads report
  - Stores report ID, timestamp, month, locale
  - Marks active reports for each month+locale combination

- **`apple_keywords`** - All keywords from imported reports
  - Links to parent report
  - Includes all scores and rankings
  - Indexed for fast queries

- **`keyword_batches`** - Groups of selected keywords for processing
  - Tracks batch status (pending/in_progress/completed/failed)
  - Counts of completed/failed keywords

- **`batch_keywords`** - Individual keywords within each batch
  - Links to apple_keywords
  - Links to searches table (from appstore analyze results)
  - Tracks processing status and errors

### Updated Workflow

#### 1. Import Report (New Step)
```bash
# Import Excel file into database
python3 commands/import_report.py "report.xlsx" --country "United States"

# Or use the master script which checks if already imported
./find_gold.sh
```

#### 2. Generate Keywords & HTML (Now Database-First)
```bash
# Generate scored keywords JSON from database (not Excel)
python3 process_keywords.py --country "United States" > keywords_scored.json

# Generate HTML report from database (not JSON)
python3 generate_html.py --country "United States" -o keyword_report.html

# Legacy mode still supported:
python3 process_keywords.py --from-excel report.xlsx
python3 generate_html.py --from-json keywords_scored.json
```

#### 3. Batch Processing (New System)
```bash
# Create a batch from selected keywords
python3 commands/batch.py create selected_keywords.json --notes "Testing keywords"

# List all batches
python3 commands/batch.py list

# View batch status
python3 commands/batch.py status 1

# Process a batch (runs appstore analyze for each keyword)
python3 commands/process_batch.py 1

# Or use the convenience script:
./analyze_selected.sh selected_keywords.json "My test batch"
```

## Key Benefits

### Historical Tracking
- Keep all imported reports in database
- Compare keyword rankings over time
- Track genre trends across months
- Analyze popularity changes

### Batch Management
- Create organized batches of keywords to analyze
- Track which keywords have been processed
- See success/failure status for each keyword
- Link analysis results back to original keywords

### No More Duplicate Work
- Database checks if report already imported
- Avoid re-importing same Excel file
- Batch system tracks what's been analyzed
- Link results to avoid re-running same searches

### Query Capabilities
```sql
-- View all reports
SELECT * FROM apple_reports WHERE is_active = 1;

-- Track keyword over time
SELECT ar.data_month, ak.rank_in_genre, ak.popularity_overall
FROM apple_keywords ak
JOIN apple_reports ar ON ak.report_id = ar.id
WHERE ak.search_term = 'calorie counter'
  AND ak.country = 'United States'
ORDER BY ar.data_month;

-- View batch progress
SELECT * FROM keyword_batches;
SELECT * FROM batch_keywords WHERE batch_id = 1;
```

## File Structure

### New Files Created
```
migrations/
  001_apple_reports.sql       # Database schema

db/
  __init__.py                  # Module init
  database.py                  # Database utilities
  migrations.py                # Migration runner

commands/
  __init__.py                  # Module init
  import_report.py             # Excel import command
  batch.py                     # Batch management
  process_batch.py             # Batch processing
```

### Modified Files
```
process_keywords.py            # Now reads from database by default
generate_html.py               # Now reads from database by default
find_gold.sh                   # Auto-imports, uses database
analyze_selected.sh            # Uses batch system
```

## Migration Status

✅ All database tables created
✅ Current Excel file imported (7,500 keywords)
✅ Test batch created and verified
✅ All core tools updated to use database
✅ Shell scripts updated
✅ Backward compatibility maintained

## Next Steps

### Immediate Use
1. Import any additional Excel reports you have
2. Use `find_gold.sh` as normal - it now uses the database
3. Select keywords and create batches
4. Process batches to run analyses

### Future Enhancements
You can now easily add:
- Trend analysis commands (keyword history, genre trends)
- Report comparison tools
- Automated batch scheduling
- Web dashboard for visualizations
- Multi-country comparisons

## Troubleshooting

### Check Database
```bash
# List all reports
sqlite3 ~/.appstore/analytics.db "SELECT * FROM apple_reports;"

# Count keywords
sqlite3 ~/.appstore/analytics.db "SELECT COUNT(*) FROM apple_keywords;"

# View batches
python3 commands/batch.py list
```

### Re-run Migrations
```bash
# Check migration status
python3 -m db.migrations list

# Run pending migrations
python3 -m db.migrations run
```

### Reset (If Needed)
```bash
# Drop all new tables (keeps existing searches/apps tables)
sqlite3 ~/.appstore/analytics.db <<EOF
DROP TABLE IF EXISTS batch_keywords;
DROP TABLE IF EXISTS keyword_batches;
DROP TABLE IF EXISTS apple_keywords;
DROP TABLE IF EXISTS apple_reports;
DROP TABLE IF EXISTS schema_migrations;
EOF

# Re-run migrations
python3 -m db.migrations run

# Re-import data
python3 commands/import_report.py "your_report.xlsx"
```

## Notes

- Database location: `~/.appstore/analytics.db`
- All data persists across runs
- Import is idempotent (won't duplicate reports)
- Legacy JSON/Excel mode still works with `--from-excel` and `--from-json` flags
- Batch processing requires `appstore analyze` command to be available
