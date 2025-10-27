-- Migration 003: Add minimum_os_version to apps table
-- This adds the minimum iOS/OS version required to run each app.
-- The data comes from the iTunes API's minimumOsVersion field.

-- Add minimum_os_version column (backfill with NULL for existing data)
ALTER TABLE apps ADD COLUMN minimum_os_version TEXT;
