#!/usr/bin/env python3
"""Generate HTML dashboard from batch analysis results stored in database."""

import sys
import json
from pathlib import Path
from datetime import datetime, timezone
from typing import Dict, Any, List

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from db.database import execute_one, execute_query


def format_duration(seconds: int) -> str:
    """Format duration in seconds to human-readable string."""
    if seconds is None:
        return "N/A"

    hours = seconds // 3600
    minutes = (seconds % 3600) // 60
    secs = seconds % 60

    if hours > 0:
        return f"{hours}h {minutes}m {secs}s"
    elif minutes > 0:
        return f"{minutes}m {secs}s"
    else:
        return f"{secs}s"


def load_batch_results(batch_id: int) -> Dict[str, Any]:
    """
    Load batch results from database and format for HTML dashboard.

    Args:
        batch_id: The batch ID to load

    Returns:
        Dictionary in the same format as analyze_keywords.py expects
    """
    # Get batch info
    batch = execute_one(
        """SELECT kb.*, ar.data_month
           FROM keyword_batches kb
           JOIN apple_reports ar ON kb.report_id = ar.id
           WHERE kb.id = ?""",
        (batch_id,)
    )

    if not batch:
        raise ValueError(f"Batch #{batch_id} not found")

    print(f"Loading batch #{batch_id}...", file=sys.stderr)
    print(f"  Status: {batch['status']}", file=sys.stderr)
    print(f"  Total keywords: {batch['total_keywords']}", file=sys.stderr)
    print(f"  Completed: {batch['completed_keywords']}", file=sys.stderr)
    print(f"  Failed: {batch['failed_keywords']}", file=sys.stderr)

    # Get all batch keywords
    batch_keywords = execute_query(
        """SELECT * FROM batch_keywords WHERE batch_id = ? ORDER BY id""",
        (batch_id,)
    )

    results = []
    failed = []

    for bk in batch_keywords:
        keyword_id = bk['keyword_id']
        search_id = bk['analysis_search_id']

        # Get the keyword input data from apple_keywords
        keyword_data = execute_one(
            """SELECT * FROM apple_keywords WHERE id = ?""",
            (keyword_id,)
        )

        if not keyword_data:
            continue

        # Format input data
        input_data = {
            'search_term': keyword_data['search_term'],
            'genre': keyword_data['genre'],
            'country': keyword_data['country'],
            'month': batch['data_month'],
            'rank_in_genre': keyword_data['rank_in_genre'],
            'popularity_genre': keyword_data['popularity_genre'],
            'popularity_overall': keyword_data['popularity_overall'],
            'score_rank': keyword_data['score_rank'],
            'score_genre': keyword_data['score_genre'],
            'score_overall': keyword_data['score_overall'],
            'total_score': keyword_data['total_score']
        }

        if bk['status'] == 'completed' and search_id:
            # Get apps for this search
            apps = execute_query(
                """SELECT * FROM apps WHERE search_id = ? ORDER BY rank""",
                (search_id,)
            )

            # Get summary for this search
            summary_row = execute_one(
                """SELECT * FROM search_summaries WHERE search_id = ?""",
                (search_id,)
            )

            # Format apps
            apps_list = []
            for app in apps:
                apps_list.append({
                    'app_id': app['app_id'],
                    'title': app['title'],
                    'rating': app['rating'],
                    'rating_count': app['rating_count'],
                    'original_release': app['original_release'] or '',
                    'latest_release': app['latest_release'] or '',
                    'age_days': app['age_days'] or 0,
                    'freshness_days': app['freshness_days'] or 0,
                    'title_match_score': app['title_match_score'] or 0,
                    'description_match_score': app['description_match_score'] or 0,
                    'ratings_per_day': app['ratings_per_day'] or 0.0,
                    'genre': app['genre_name'] or '',
                    'version': app['version'] or '',
                    'age_rating': app['age_rating'] or '',
                    'minimum_os_version': app['minimum_os_version'] or ''
                })

            # Format summary
            summary = {}
            if summary_row:
                summary = {
                    'avg_age_days': summary_row['avg_age_days'] or 0,
                    'median_age_days': summary_row['median_age_days'] or 0,
                    'age_ratio': summary_row['age_ratio'] or 0.0,
                    'avg_freshness_days': summary_row['avg_freshness_days'] or 0,
                    'avg_rating': summary_row['avg_rating'] or 0.0,
                    'avg_rating_count': summary_row['avg_rating_count'] or 0,
                    'avg_title_match_score': summary_row['avg_title_match_score'] or 0.0,
                    'avg_description_match_score': summary_row['avg_description_match_score'] or 0.0,
                    'avg_ratings_per_day': summary_row['avg_ratings_per_day'] or 0.0,
                    'newest_velocity': summary_row['newest_velocity'] or 0.0,
                    'established_velocity': summary_row['established_velocity'] or 0.0,
                    'velocity_ratio': summary_row['velocity_ratio'] or 0.0,
                    'competitiveness_v1': summary_row['competitivenessV1'] or 0.0
                }

            results.append({
                'input': input_data,
                'analysis': {
                    'apps': apps_list,
                    'summary': summary
                }
            })
        else:
            # Keyword failed or not processed
            failed.append({
                'keyword': bk['search_term'],
                'input': input_data,
                'error': bk['error_message']
            })

    print(f"  Loaded {len(results)} successful results", file=sys.stderr)
    print(f"  {len(failed)} failed/pending", file=sys.stderr)

    # Format timing information
    metadata = {
        'generated': datetime.now(timezone.utc).isoformat(),
        'batch_id': batch_id,
        'total_keywords': batch['total_keywords'],
        'successful': len(results),
        'failed': len(failed)
    }

    # Add batch notes if available
    if batch['notes']:
        metadata['notes'] = batch['notes']

    # Add timing information if available
    if batch['started_at']:
        metadata['started_at'] = batch['started_at']
    if batch['completed_at']:
        metadata['completed_at'] = batch['completed_at']
    if batch['duration_seconds']:
        metadata['duration_seconds'] = batch['duration_seconds']
        metadata['duration_formatted'] = format_duration(batch['duration_seconds'])
        # Calculate rate (keywords per hour)
        if batch['duration_seconds'] > 0:
            rate = (batch['total_keywords'] / batch['duration_seconds']) * 3600
            metadata['processing_rate'] = f"{rate:.1f} keywords/hour"

    return {
        'metadata': metadata,
        'results': results,
        'failed': failed
    }


def generate_html_dashboard(data: Dict[str, Any], output_path: Path):
    """Generate interactive HTML dashboard from analysis results."""

    # This is the exact same HTML template from analyze_keywords.py
    html = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Keyword Analysis Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            background: #f5f5f7;
            padding: 20px;
            color: #1d1d1f;
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            padding: 30px;
        }

        h1 {
            font-size: 32px;
            font-weight: 700;
            margin-bottom: 10px;
        }

        .metadata {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin: 20px 0;
            padding: 20px;
            background: #f5f5f7;
            border-radius: 8px;
        }

        .metric {
            padding: 15px;
            background: white;
            border-radius: 6px;
        }

        .metric-label {
            font-size: 12px;
            color: #86868b;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 5px;
        }

        .metric-value {
            font-size: 24px;
            font-weight: 600;
            color: #1d1d1f;
        }

        .controls {
            display: flex;
            gap: 15px;
            margin: 20px 0;
            flex-wrap: wrap;
        }

        input[type="text"], select {
            padding: 10px 15px;
            border: 1px solid #d2d2d7;
            border-radius: 6px;
            font-size: 14px;
            flex: 1;
            min-width: 200px;
        }

        .table-wrapper {
            overflow-x: auto;
            margin-top: 20px;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
        }

        th {
            background: #f5f5f7;
            padding: 10px 8px;
            text-align: left;
            font-weight: 600;
            font-size: 12px;
            color: #1d1d1f;
            cursor: pointer;
            user-select: none;
            border-bottom: 2px solid #d2d2d7;
            white-space: nowrap;
        }

        th:hover {
            background: #e8e8ed;
        }

        th.sorted-asc::after {
            content: " ▲";
            color: #0071e3;
        }

        th.sorted-desc::after {
            content: " ▼";
            color: #0071e3;
        }

        td {
            padding: 10px 8px;
            border-bottom: 1px solid #f5f5f7;
            font-size: 13px;
        }

        tr:hover td {
            background: #fafafa;
        }

        .expandable {
            cursor: pointer;
        }

        .keyword-cell {
            font-weight: 500;
            color: #0071e3;
        }

        .expanded-row {
            background: #f9f9f9 !important;
        }

        .info-icon {
            display: inline-block;
            width: 14px;
            height: 14px;
            line-height: 14px;
            text-align: center;
            background: #0071e3;
            color: white;
            border-radius: 50%;
            font-size: 10px;
            font-weight: bold;
            margin-left: 4px;
            cursor: help;
            position: relative;
        }

        .info-icon:hover::after {
            content: attr(data-tooltip);
            position: absolute;
            top: 100%;
            left: 50%;
            transform: translateX(-50%);
            margin-top: 8px;
            padding: 10px 14px;
            background: #1d1d1f;
            color: white;
            font-size: 13px;
            font-weight: normal;
            white-space: normal;
            min-width: 250px;
            max-width: 350px;
            width: max-content;
            border-radius: 6px;
            z-index: 10000;
            box-shadow: 0 4px 12px rgba(0,0,0,0.3);
            line-height: 1.4;
        }

        .info-icon:hover::before {
            content: '';
            position: absolute;
            top: 100%;
            left: 50%;
            transform: translateX(-50%);
            margin-top: 2px;
            border: 6px solid transparent;
            border-bottom-color: #1d1d1f;
            z-index: 10000;
        }

        .expanded-content {
            padding: 20px;
            background: #fafafa;
        }

        .app-list {
            display: grid;
            gap: 8px;
            margin-top: 10px;
        }

        .app-list-header {
            display: grid;
            grid-template-columns: 40px 100px 2fr 80px 90px 80px 80px 100px 120px 150px 80px 100px;
            gap: 10px;
            padding: 10px 12px;
            background: #e8e8ed;
            border-radius: 6px;
            font-weight: 600;
            font-size: 11px;
            color: #1d1d1f;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .app-list-header > div {
            text-align: center;
        }

        .app-list-header > div:nth-child(3) {
            text-align: left;
        }

        .app-item {
            display: grid;
            grid-template-columns: 40px 100px 2fr 80px 90px 80px 80px 100px 120px 150px 80px 100px;
            gap: 10px;
            padding: 12px;
            background: white;
            border-radius: 6px;
            align-items: center;
            font-size: 13px;
            border: 1px solid #f0f0f0;
        }

        .app-item:hover {
            border-color: #0071e3;
            box-shadow: 0 2px 4px rgba(0,113,227,0.1);
        }

        .app-rank {
            font-weight: 600;
            color: #86868b;
            text-align: center;
        }

        .app-title {
            font-weight: 500;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }

        .app-title a {
            color: #007aff;
            text-decoration: none;
        }

        .app-title a:hover {
            text-decoration: underline;
        }

        .app-rating {
            text-align: center;
        }

        .app-cell {
            text-align: center;
            font-size: 12px;
        }

        .app-id-cell {
            cursor: pointer;
            font-family: monospace;
            font-size: 11px;
            color: #007aff;
            user-select: all;
            text-align: center;
        }

        .app-id-cell:hover {
            background: #f0f0f0;
            text-decoration: underline;
        }

        .app-id-cell:active {
            background: #e0e0e0;
        }

        .app-match {
            text-align: center;
            font-size: 12px;
        }

        .score-badge {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
        }

        .score-high {
            background: #fee2e2;
            color: #991b1b;
        }

        .score-med {
            background: #fef3c7;
            color: #92400e;
        }

        .score-low {
            background: #d1f4e0;
            color: #047857;
        }

        .chart-container {
            margin: 30px 0;
            padding: 20px;
            background: #f9f9f9;
            border-radius: 8px;
        }

        .chart-title {
            font-size: 18px;
            font-weight: 600;
            margin-bottom: 15px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🏆 Keyword Analysis Dashboard</h1>
        <p style="color: #86868b; margin-top: 5px;">Finding high-popularity, low-competition keywords</p>

        <div class="metadata">
            <div class="metric">
                <div class="metric-label">Batch ID</div>
                <div class="metric-value" style="font-size: 20px;">#""" + str(data['metadata']['batch_id']) + """</div>
            </div>
            <div class="metric">
                <div class="metric-label">Total Keywords</div>
                <div class="metric-value">""" + str(data['metadata']['total_keywords']) + """</div>
            </div>
            <div class="metric">
                <div class="metric-label">Successful</div>
                <div class="metric-value" style="color: #34c759;">""" + str(data['metadata']['successful']) + """</div>
            </div>
            <div class="metric">
                <div class="metric-label">Failed</div>
                <div class="metric-value" style="color: #ff3b30;">""" + str(data['metadata']['failed']) + """</div>
            </div>""" + ("""
            <div class="metric">
                <div class="metric-label">Started</div>
                <div class="metric-value" style="font-size: 16px;">""" + data['metadata']['started_at'][:16].replace('T', ' ') + """</div>
            </div>
            <div class="metric">
                <div class="metric-label">Completed</div>
                <div class="metric-value" style="font-size: 16px;">""" + data['metadata']['completed_at'][:16].replace('T', ' ') + """</div>
            </div>
            <div class="metric">
                <div class="metric-label">Duration</div>
                <div class="metric-value" style="font-size: 18px;">""" + data['metadata']['duration_formatted'] + """</div>
            </div>
            <div class="metric">
                <div class="metric-label">Processing Rate</div>
                <div class="metric-value" style="font-size: 16px;">""" + data['metadata']['processing_rate'] + """</div>
            </div>""" if 'duration_formatted' in data['metadata'] else "") + """
        </div>""" + ("""

        <div style="background: #f5f5f7; padding: 15px; border-radius: 8px; margin: 20px 0;">
            <div style="font-size: 12px; color: #86868b; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 5px;">Batch Notes</div>
            <div style="font-size: 14px; color: #1d1d1f;">""" + data['metadata']['notes'] + """</div>
        </div>""" if 'notes' in data['metadata'] else "") + """

        <div class="controls">
            <input type="text" id="searchBox" placeholder="🔍 Search keywords...">
            <select id="genreFilter">
                <option value="">All Genres</option>
            </select>
        </div>

        <div class="table-wrapper">
            <table id="resultsTable">
            <thead>
                <tr>
                    <th data-sort="keyword">Keyword</th>
                    <th data-sort="genre">Genre</th>
                    <th data-sort="total_score">Total Score<span class="info-icon" data-tooltip="Combined score from input data (rank + genre + popularity)">i</span></th>
                    <th data-sort="competitiveness">Competitive<span class="info-icon" data-tooltip="How hard to compete (0-100). Lower = easier (green), Higher = harder (red). Based on traffic, freshness, title matching, and new app velocity.">i</span></th>
                    <th data-sort="avg_ratings_per_day">Ratings/Day<span class="info-icon" data-tooltip="Unweighted average of each app's ratings/day ratio. Shows typical daily rating velocity for apps in this keyword, not dominated by old mega-apps.">i</span></th>
                    <th data-sort="median_age_days">Median Age<span class="info-icon" data-tooltip="Median age of top 20 apps. Lower = market has newer apps competing successfully.">i</span></th>
                    <th data-sort="age_ratio">Age Ratio<span class="info-icon" data-tooltip="Oldest 70% avg age ÷ newest 30% avg age. Higher ratio (10+) = very new apps competing. Low ratio (1-3) = all apps similar age.">i</span></th>
                    <th data-sort="avg_freshness_days">Avg Fresh<span class="info-icon" data-tooltip="Days since last update for top 20 apps. Lower = apps are more actively maintained and competitive.">i</span></th>
                    <th data-sort="avg_rating">Avg Rating<span class="info-icon" data-tooltip="Average star rating of top 20 apps. Higher ratings = harder to compete on quality.">i</span></th>
                    <th data-sort="velocity_ratio">New/Old Velocity<span class="info-icon" data-tooltip="Rating velocity: newest 30% of apps ÷ oldest 70%. >1.0 = new apps gaining traction faster than old apps. <1.0 = established apps dominate.">i</span></th>
                    <th data-sort="rank_in_genre">Rank<span class="info-icon" data-tooltip="Rank within genre from input data">i</span></th>
                    <th data-sort="popularity_overall">Pop<span class="info-icon" data-tooltip="Overall popularity score from input data (0-100)">i</span></th>
                </tr>
            </thead>
            <tbody id="tableBody">
            </tbody>
        </table>
        </div>
    </div>

    <script>
        const rawData = """ + json.dumps(data['results']) + """;
        let sortColumn = 'competitiveness';
        let sortDirection = 'asc';
        let searchTerm = '';
        let genreFilter = '';

        // Populate genre filter
        const genres = [...new Set(rawData.map(r => r.input.genre))].sort();
        const genreSelect = document.getElementById('genreFilter');
        genres.forEach(genre => {
            const option = document.createElement('option');
            option.value = genre;
            option.textContent = genre;
            genreSelect.appendChild(option);
        });

        function getScoreClass(score) {
            if (score >= 75) return 'score-high';
            if (score >= 50) return 'score-med';
            return 'score-low';
        }

        function toggleRow(index) {
            const expandedRow = document.getElementById(`expanded-${index}`);
            if (expandedRow) {
                expandedRow.remove();
            } else {
                const item = filteredData[index];
                const tr = document.getElementById(`row-${index}`);

                // Use sectionRowIndex to get the correct position within tbody
                const tbody = tr.parentNode;
                const newRow = tbody.insertRow(tr.sectionRowIndex + 1);
                newRow.id = `expanded-${index}`;
                newRow.className = 'expanded-row';

                const td = newRow.insertCell(0);
                td.colSpan = 12;
                td.innerHTML = `
                    <div class="expanded-content">
                        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 20px;">
                            <div>
                                <strong>Summary Statistics:</strong><br>
                                Avg Age: ${item.analysis.summary.avg_age_days || 'N/A'} days<br>
                                Median Age: ${item.analysis.summary.median_age_days || 'N/A'} days<br>
                                Avg Freshness: ${item.analysis.summary.avg_freshness_days || 'N/A'} days<br>
                                Avg Rating: ${item.analysis.summary.avg_rating?.toFixed(2) || 'N/A'}<br>
                                Avg Title Match: ${item.analysis.summary.avg_title_match_score?.toFixed(2) || 'N/A'}<br>
                                Age Ratio: ${item.analysis.summary.age_ratio?.toFixed(2) || 'N/A'}
                            </div>
                            <div>
                                <strong>Input Scores:</strong><br>
                                Score Rank: ${item.input.score_rank}<br>
                                Score Genre: ${item.input.score_genre}<br>
                                Score Overall: ${item.input.score_overall}
                            </div>
                        </div>
                        <strong>Top 20 Apps for "${item.input.search_term}":</strong>
                        <div class="app-list">
                            <div class="app-list-header">
                                <div>#</div>
                                <div>App ID</div>
                                <div>App Name</div>
                                <div>Rating</div>
                                <div>Ratings/Day</div>
                                <div>Age (Days)</div>
                                <div>Fresh (Days)</div>
                                <div>Keyword Match</div>
                                <div>Total Ratings</div>
                                <div>Genre</div>
                                <div>Version</div>
                                <div>Min iOS</div>
                                <div>Age Rating</div>
                            </div>
                            ${item.analysis.apps.slice(0, 20).map((app, i) => `
                                <div class="app-item">
                                    <div class="app-rank">#${i + 1}</div>
                                    <div class="app-id-cell" onclick="copyLookupCommand('${app.app_id}')" title="Click to copy: appstore lookup ${app.app_id} --verbosity complete">${app.app_id || 'N/A'}</div>
                                    <div class="app-title" title="${app.title}"><a href="https://apps.apple.com/app/id${app.app_id}" target="_blank" rel="noopener">${app.title}</a></div>
                                    <div class="app-cell">${app.rating ? '⭐ ' + app.rating.toFixed(1) : 'N/A'}</div>
                                    <div class="app-cell">${app.ratings_per_day.toFixed(1)}</div>
                                    <div class="app-cell">${app.age_days.toLocaleString()}</div>
                                    <div class="app-cell">${app.freshness_days}</div>
                                    <div class="app-match">
                                        <div style="font-size: 11px; color: #86868b;">Title: ${app.title_match_score}</div>
                                        <div style="font-size: 11px; color: #86868b;">Desc: ${app.description_match_score}</div>
                                    </div>
                                    <div class="app-cell">${app.rating_count?.toLocaleString() || 0}</div>
                                    <div class="app-cell" style="font-size: 11px; overflow: hidden; text-overflow: ellipsis;" title="${app.genre || 'N/A'}">${app.genre || 'N/A'}</div>
                                    <div class="app-cell" style="font-family: monospace; font-size: 11px;">${app.version || 'N/A'}</div>
                                    <div class="app-cell" style="font-size: 11px;">${app.minimum_os_version || 'N/A'}</div>
                                    <div class="app-cell" style="font-size: 11px;">${app.age_rating || 'N/A'}</div>
                                </div>
                            `).join('')}
                        </div>
                    </div>
                `;
            }
        }

        let filteredData = [];

        function copyLookupCommand(appId) {
            const command = `appstore lookup ${appId} --verbosity complete`;
            navigator.clipboard.writeText(command).then(() => {
                // Show visual feedback
                const cells = document.querySelectorAll('.app-id-cell');
                cells.forEach(cell => {
                    if (cell.textContent === appId) {
                        const originalBg = cell.style.background;
                        cell.style.background = '#34c759';
                        cell.style.color = 'white';
                        setTimeout(() => {
                            cell.style.background = originalBg;
                            cell.style.color = '#007aff';
                        }, 500);
                    }
                });
            }).catch(err => {
                console.error('Failed to copy:', err);
                alert('Failed to copy command to clipboard');
            });
        }

        function renderTable() {
            // Filter data
            filteredData = rawData.filter(item => {
                const matchesSearch = !searchTerm ||
                    item.input.search_term.toLowerCase().includes(searchTerm.toLowerCase());
                const matchesGenre = !genreFilter || item.input.genre === genreFilter;
                return matchesSearch && matchesGenre;
            });

            // Sort data
            filteredData.sort((a, b) => {
                let aVal, bVal;

                switch(sortColumn) {
                    case 'keyword':
                        aVal = a.input.search_term;
                        bVal = b.input.search_term;
                        break;
                    case 'genre':
                        aVal = a.input.genre;
                        bVal = b.input.genre;
                        break;
                    case 'total_score':
                        aVal = a.input.total_score;
                        bVal = b.input.total_score;
                        break;
                    case 'rank_in_genre':
                        aVal = a.input.rank_in_genre;
                        bVal = b.input.rank_in_genre;
                        break;
                    case 'popularity_overall':
                        aVal = a.input.popularity_overall;
                        bVal = b.input.popularity_overall;
                        break;
                    case 'competitiveness':
                        aVal = a.analysis.summary.competitiveness_v1 || 0;
                        bVal = b.analysis.summary.competitiveness_v1 || 0;
                        break;
                    case 'avg_ratings_per_day':
                        aVal = a.analysis.summary.avg_ratings_per_day || 0;
                        bVal = b.analysis.summary.avg_ratings_per_day || 0;
                        break;
                    case 'velocity_ratio':
                        aVal = a.analysis.summary.velocity_ratio || 0;
                        bVal = b.analysis.summary.velocity_ratio || 0;
                        break;
                    case 'avg_age_days':
                        aVal = a.analysis.summary.avg_age_days || 0;
                        bVal = b.analysis.summary.avg_age_days || 0;
                        break;
                    case 'avg_freshness_days':
                        aVal = a.analysis.summary.avg_freshness_days || 0;
                        bVal = b.analysis.summary.avg_freshness_days || 0;
                        break;
                    case 'avg_rating':
                        aVal = a.analysis.summary.avg_rating || 0;
                        bVal = b.analysis.summary.avg_rating || 0;
                        break;
                    case 'median_age_days':
                        aVal = a.analysis.summary.median_age_days || 0;
                        bVal = b.analysis.summary.median_age_days || 0;
                        break;
                    case 'age_ratio':
                        aVal = a.analysis.summary.age_ratio || 0;
                        bVal = b.analysis.summary.age_ratio || 0;
                        break;
                    default:
                        aVal = 0;
                        bVal = 0;
                }

                if (typeof aVal === 'string') {
                    return sortDirection === 'asc' ?
                        aVal.localeCompare(bVal) : bVal.localeCompare(aVal);
                } else {
                    return sortDirection === 'asc' ? aVal - bVal : bVal - aVal;
                }
            });

            // Render rows
            const tbody = document.getElementById('tableBody');
            tbody.innerHTML = filteredData.map((item, index) => `
                <tr id="row-${index}" class="expandable" onclick="toggleRow(${index})">
                    <td class="keyword-cell">${item.input.search_term}</td>
                    <td>${item.input.genre}</td>
                    <td><span class="score-badge ${getScoreClass(item.input.total_score * 10)}">${item.input.total_score}</span></td>
                    <td><span class="score-badge ${getScoreClass(item.analysis.summary.competitiveness_v1 || 0)}">${(item.analysis.summary.competitiveness_v1 || 0).toFixed(1)}</span></td>
                    <td>${(item.analysis.summary.avg_ratings_per_day || 0).toFixed(0)}</td>
                    <td>${(item.analysis.summary.median_age_days || 0).toLocaleString()} days</td>
                    <td>${(item.analysis.summary.age_ratio || 0).toFixed(1)}x</td>
                    <td>${(item.analysis.summary.avg_freshness_days || 0)} days</td>
                    <td>${item.analysis.summary.avg_rating ? '⭐ ' + item.analysis.summary.avg_rating.toFixed(1) : 'N/A'}</td>
                    <td>${(item.analysis.summary.velocity_ratio || 0).toFixed(2)}x</td>
                    <td>${item.input.rank_in_genre}</td>
                    <td>${item.input.popularity_overall}</td>
                </tr>
            `).join('');

            // Update sort indicators
            document.querySelectorAll('th').forEach(th => {
                th.classList.remove('sorted-asc', 'sorted-desc');
                if (th.dataset.sort === sortColumn) {
                    th.classList.add(`sorted-${sortDirection}`);
                }
            });
        }

        // Event listeners
        document.querySelectorAll('th[data-sort]').forEach(th => {
            th.addEventListener('click', (e) => {
                // Don't sort if clicking on info icon
                if (e.target.classList.contains('info-icon')) {
                    return;
                }

                if (sortColumn === th.dataset.sort) {
                    sortDirection = sortDirection === 'asc' ? 'desc' : 'asc';
                } else {
                    sortColumn = th.dataset.sort;
                    sortDirection = 'desc';
                }
                renderTable();
            });
        });

        document.getElementById('searchBox').addEventListener('input', (e) => {
            searchTerm = e.target.value;
            renderTable();
        });

        document.getElementById('genreFilter').addEventListener('change', (e) => {
            genreFilter = e.target.value;
            renderTable();
        });

        // Initial render
        renderTable();
    </script>
</body>
</html>
"""

    with open(output_path, 'w') as f:
        f.write(html)

    print(f"\n✓ HTML dashboard generated: {output_path}", file=sys.stderr)


def main():
    """Command-line interface for generating batch reports."""
    import argparse

    parser = argparse.ArgumentParser(description="Generate HTML dashboard from batch results")
    parser.add_argument('batch_id', type=int, help='Batch ID to generate report for')
    parser.add_argument(
        '--output', '-o',
        type=Path,
        default=Path('output/batch_dashboard.html'),
        help='Output HTML file (default: output/batch_dashboard.html)'
    )

    args = parser.parse_args()

    try:
        # Ensure output directory exists
        args.output.parent.mkdir(parents=True, exist_ok=True)

        # Load batch results from database
        data = load_batch_results(args.batch_id)

        # Generate HTML dashboard
        generate_html_dashboard(data, args.output)

        print(f"\n✓ Dashboard ready! Open: {args.output}", file=sys.stderr)
        print(f"\nOr run: open {args.output}", file=sys.stderr)

        sys.exit(0)

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
