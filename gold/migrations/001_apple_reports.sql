-- Migration 001: Add Apple Search Ads reports and keywords tables
-- This extends the existing analytics.db with new tables for tracking
-- Apple Search Ads monthly keyword reports and batch processing.

-- Track each Apple Search Ads report import
CREATE TABLE IF NOT EXISTS apple_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    report_id TEXT NOT NULL,                    -- e.g., "93070_144880"
    generated_at DATETIME NOT NULL,              -- from Excel: "10/13/2025 17:50"
    data_month TEXT NOT NULL,                    -- e.g., "2025-09" (the month being reported on)
    user_locale TEXT NOT NULL,                   -- e.g., "en_US"
    month_locale_key TEXT NOT NULL,              -- computed: "2025-09_en_US"
    imported_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,                 -- marks newest report for this month+locale
    source_filename TEXT,                        -- original .xlsx filename
    total_keywords INTEGER,                      -- count of keywords in this report
    UNIQUE(report_id, generated_at)
);

CREATE INDEX IF NOT EXISTS idx_reports_month_locale
    ON apple_reports(month_locale_key, is_active);
CREATE INDEX IF NOT EXISTS idx_reports_data_month
    ON apple_reports(data_month);
CREATE INDEX IF NOT EXISTS idx_reports_is_active
    ON apple_reports(is_active);

-- Raw keyword data from each report
CREATE TABLE IF NOT EXISTS apple_keywords (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    report_id INTEGER NOT NULL,
    country TEXT NOT NULL,
    genre TEXT NOT NULL,
    search_term TEXT NOT NULL,
    rank_in_genre INTEGER NOT NULL,
    popularity_genre INTEGER,                    -- Search Popularity in Genre (1-100)
    popularity_overall INTEGER,                  -- Search Popularity (1-100)
    popularity_scale INTEGER,                    -- Search Popularity (1-5)
    score_rank INTEGER,                          -- our calculated scores
    score_genre INTEGER,
    score_overall INTEGER,
    total_score INTEGER,
    FOREIGN KEY (report_id) REFERENCES apple_reports(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_keywords_search_term
    ON apple_keywords(search_term, country);
CREATE INDEX IF NOT EXISTS idx_keywords_genre
    ON apple_keywords(genre, report_id);
CREATE INDEX IF NOT EXISTS idx_keywords_report
    ON apple_keywords(report_id);
CREATE INDEX IF NOT EXISTS idx_keywords_total_score
    ON apple_keywords(total_score DESC);
CREATE INDEX IF NOT EXISTS idx_keywords_country_report
    ON apple_keywords(country, report_id);

-- Track groups of keywords selected for processing
CREATE TABLE IF NOT EXISTS keyword_batches (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    report_id INTEGER NOT NULL,                  -- source report
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    status TEXT DEFAULT 'pending',               -- pending/in_progress/completed/failed
    total_keywords INTEGER DEFAULT 0,
    completed_keywords INTEGER DEFAULT 0,
    failed_keywords INTEGER DEFAULT 0,
    notes TEXT,                                  -- optional user notes
    FOREIGN KEY (report_id) REFERENCES apple_reports(id)
);

CREATE INDEX IF NOT EXISTS idx_batches_status
    ON keyword_batches(status);
CREATE INDEX IF NOT EXISTS idx_batches_created
    ON keyword_batches(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_batches_report
    ON keyword_batches(report_id);

-- Individual keywords within each batch
CREATE TABLE IF NOT EXISTS batch_keywords (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_id INTEGER NOT NULL,
    keyword_id INTEGER NOT NULL,                 -- links back to apple_keywords
    search_term TEXT NOT NULL,                   -- denormalized for convenience
    country TEXT NOT NULL,
    genre TEXT NOT NULL,
    status TEXT DEFAULT 'pending',               -- pending/in_progress/completed/failed
    analysis_search_id TEXT,                     -- FOREIGN KEY to searches.id (existing table)
    processed_at DATETIME,
    error_message TEXT,
    FOREIGN KEY (batch_id) REFERENCES keyword_batches(id) ON DELETE CASCADE,
    FOREIGN KEY (keyword_id) REFERENCES apple_keywords(id),
    FOREIGN KEY (analysis_search_id) REFERENCES searches(id)
);

CREATE INDEX IF NOT EXISTS idx_batch_keywords_batch
    ON batch_keywords(batch_id);
CREATE INDEX IF NOT EXISTS idx_batch_keywords_status
    ON batch_keywords(batch_id, status);
CREATE INDEX IF NOT EXISTS idx_batch_keywords_keyword
    ON batch_keywords(keyword_id);
CREATE INDEX IF NOT EXISTS idx_batch_keywords_search
    ON batch_keywords(analysis_search_id);
