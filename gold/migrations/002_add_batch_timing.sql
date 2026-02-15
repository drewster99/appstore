-- Migration 002: Add timing fields to keyword_batches and backfill from existing data
-- This adds started_at, completed_at, and duration_seconds to track batch processing time.
-- For existing batches, we backfill using the MIN/MAX processed_at from batch_keywords.

-- Step 1: Add new timing columns
ALTER TABLE keyword_batches ADD COLUMN started_at DATETIME;
ALTER TABLE keyword_batches ADD COLUMN completed_at DATETIME;
ALTER TABLE keyword_batches ADD COLUMN duration_seconds INTEGER;

-- Step 2: Backfill timing for completed/failed batches using processed_at timestamps
UPDATE keyword_batches
SET
    started_at = (
        SELECT MIN(processed_at)
        FROM batch_keywords
        WHERE batch_keywords.batch_id = keyword_batches.id
    ),
    completed_at = (
        SELECT MAX(processed_at)
        FROM batch_keywords
        WHERE batch_keywords.batch_id = keyword_batches.id
    )
WHERE status IN ('completed', 'failed', 'in_progress');

-- Step 3: Calculate duration_seconds from the timestamps
UPDATE keyword_batches
SET duration_seconds = (
    CAST((julianday(completed_at) - julianday(started_at)) * 86400 AS INTEGER)
)
WHERE started_at IS NOT NULL AND completed_at IS NOT NULL;

-- Step 4: Set error_message for completed keywords that found no apps
-- This distinguishes "no results" from actual errors
UPDATE batch_keywords
SET error_message = 'No apps found in App Store for this keyword'
WHERE status = 'completed'
  AND analysis_search_id IS NULL
  AND error_message IS NULL;
