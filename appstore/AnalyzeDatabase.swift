import Foundation
import SQLite3

enum DatabaseError: Error, LocalizedError {
    case openFailed(String)
    case prepareFailed(String)
    case executeFailed(String)
    case noDatabase

    var errorDescription: String? {
        switch self {
        case .openFailed(let msg): return "Failed to open database: \(msg)"
        case .prepareFailed(let msg): return "Failed to prepare statement: \(msg)"
        case .executeFailed(let msg): return "Failed to execute statement: \(msg)"
        case .noDatabase: return "Database not initialized"
        }
    }
}

class AnalyzeDatabase {
    private var db: OpaquePointer?
    private let dbPath: String

    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let appstoreDir = homeDir.appendingPathComponent(".appstore")
        self.dbPath = appstoreDir.appendingPathComponent("analytics.db").path
    }

    func open() throws {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let appstoreDir = homeDir.appendingPathComponent(".appstore")

        do {
            try FileManager.default.createDirectory(at: appstoreDir, withIntermediateDirectories: true)
        } catch {
            throw DatabaseError.openFailed("Failed to create directory: \(error.localizedDescription)")
        }

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.openFailed(errorMessage)
        }

        try createTables()
    }

    func close() {
        sqlite3_close(db)
        db = nil
    }

    private func createTables() throws {
        let searchesTable = """
        CREATE TABLE IF NOT EXISTS searches (
            id TEXT PRIMARY KEY,
            keyword TEXT NOT NULL,
            storefront TEXT NOT NULL,
            language TEXT NOT NULL,
            timestamp DATETIME NOT NULL,
            duration_ms INTEGER
        );
        """

        let appsTable = """
        CREATE TABLE IF NOT EXISTS apps (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            search_id TEXT NOT NULL,
            rank INTEGER NOT NULL,
            app_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            rating REAL,
            rating_count INTEGER,
            original_release TEXT,
            latest_release TEXT,
            age_days INTEGER,
            freshness_days INTEGER,
            title_match_score INTEGER,
            description_match_score INTEGER,
            ratings_per_day REAL,
            genre_name TEXT,
            version TEXT,
            age_rating TEXT,
            FOREIGN KEY (search_id) REFERENCES searches(id)
        );
        """

        let summariesTable = """
        CREATE TABLE IF NOT EXISTS search_summaries (
            search_id TEXT PRIMARY KEY,
            avg_age_days INTEGER,
            median_age_days INTEGER,
            age_ratio REAL,
            avg_freshness_days INTEGER,
            avg_rating REAL,
            avg_rating_count INTEGER,
            avg_title_match_score REAL,
            avg_description_match_score REAL,
            avg_ratings_per_day REAL,
            newest_velocity REAL,
            established_velocity REAL,
            velocity_ratio REAL,
            competitivenessV1 REAL,
            FOREIGN KEY (search_id) REFERENCES searches(id)
        );
        """

        // Create indexes for common queries
        let indexes = """
        CREATE INDEX IF NOT EXISTS idx_searches_keyword ON searches(keyword);
        CREATE INDEX IF NOT EXISTS idx_searches_timestamp ON searches(timestamp);
        CREATE INDEX IF NOT EXISTS idx_apps_search_id ON apps(search_id);
        CREATE INDEX IF NOT EXISTS idx_apps_app_id ON apps(app_id);
        CREATE INDEX IF NOT EXISTS idx_summaries_competitiveness ON search_summaries(competitivenessV1);
        """

        for sql in [searchesTable, appsTable, summariesTable, indexes] {
            try execute(sql)
        }
    }

    private func execute(_ sql: String) throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.prepareFailed(errorMessage)
        }

        if sqlite3_step(statement) != SQLITE_DONE {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.executeFailed(errorMessage)
        }
    }

    func saveSearch(
        id: String,
        keyword: String,
        storefront: String,
        language: String,
        timestamp: Date,
        durationMs: Int
    ) throws {
        let sql = """
        INSERT INTO searches (id, keyword, storefront, language, timestamp, duration_ms)
        VALUES (?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.prepareFailed(errorMessage)
        }

        let timestampString = ISO8601DateFormatter().string(from: timestamp)

        sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (keyword as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (storefront as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 4, (language as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 5, (timestampString as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 6, Int32(durationMs))

        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.executeFailed(errorMessage)
        }
    }

    func saveApp(
        searchId: String,
        rank: Int,
        appId: Int,
        title: String,
        rating: Double?,
        ratingCount: Int?,
        originalRelease: String,
        latestRelease: String,
        ageDays: Int,
        freshnessDays: Int,
        titleMatchScore: Int,
        descriptionMatchScore: Int,
        ratingsPerDay: Double,
        genreName: String,
        version: String,
        ageRating: String
    ) throws {
        let sql = """
        INSERT INTO apps (
            search_id, rank, app_id, title, rating, rating_count,
            original_release, latest_release, age_days, freshness_days,
            title_match_score, description_match_score, ratings_per_day, genre_name,
            version, age_rating
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.prepareFailed(errorMessage)
        }

        sqlite3_bind_text(statement, 1, (searchId as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 2, Int32(rank))
        sqlite3_bind_int64(statement, 3, Int64(appId))
        sqlite3_bind_text(statement, 4, (title as NSString).utf8String, -1, nil)

        if let rating = rating {
            sqlite3_bind_double(statement, 5, rating)
        } else {
            sqlite3_bind_null(statement, 5)
        }

        if let count = ratingCount {
            sqlite3_bind_int64(statement, 6, Int64(count))
        } else {
            sqlite3_bind_null(statement, 6)
        }

        sqlite3_bind_text(statement, 7, (originalRelease as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 8, (latestRelease as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 9, Int32(ageDays))
        sqlite3_bind_int(statement, 10, Int32(freshnessDays))
        sqlite3_bind_int(statement, 11, Int32(titleMatchScore))
        sqlite3_bind_int(statement, 12, Int32(descriptionMatchScore))
        sqlite3_bind_double(statement, 13, ratingsPerDay)
        sqlite3_bind_text(statement, 14, (genreName as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 15, (version as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 16, (ageRating as NSString).utf8String, -1, nil)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.executeFailed(errorMessage)
        }
    }

    func saveSummary(
        searchId: String,
        avgAgeDays: Int,
        medianAgeDays: Int,
        ageRatio: Double,
        avgFreshnessDays: Int,
        avgRating: Double,
        avgRatingCount: Int,
        avgTitleMatchScore: Double,
        avgDescriptionMatchScore: Double,
        avgRatingsPerDay: Double,
        newestVelocity: Double,
        establishedVelocity: Double,
        velocityRatio: Double,
        competitivenessV1: Double
    ) throws {
        let sql = """
        INSERT INTO search_summaries (
            search_id, avg_age_days, median_age_days, age_ratio, avg_freshness_days, avg_rating, avg_rating_count,
            avg_title_match_score, avg_description_match_score, avg_ratings_per_day,
            newest_velocity, established_velocity, velocity_ratio, competitivenessV1
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.prepareFailed(errorMessage)
        }

        sqlite3_bind_text(statement, 1, (searchId as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 2, Int32(avgAgeDays))
        sqlite3_bind_int(statement, 3, Int32(medianAgeDays))
        sqlite3_bind_double(statement, 4, ageRatio)
        sqlite3_bind_int(statement, 5, Int32(avgFreshnessDays))
        sqlite3_bind_double(statement, 6, avgRating)
        sqlite3_bind_int(statement, 7, Int32(avgRatingCount))
        sqlite3_bind_double(statement, 8, avgTitleMatchScore)
        sqlite3_bind_double(statement, 9, avgDescriptionMatchScore)
        sqlite3_bind_double(statement, 10, avgRatingsPerDay)
        sqlite3_bind_double(statement, 11, newestVelocity)
        sqlite3_bind_double(statement, 12, establishedVelocity)
        sqlite3_bind_double(statement, 13, velocityRatio)
        sqlite3_bind_double(statement, 14, competitivenessV1)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.executeFailed(errorMessage)
        }
    }
}
