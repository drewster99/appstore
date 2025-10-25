#!/usr/bin/env python3
"""
Keyword Analysis Pipeline
Processes keywords from JSON, runs appstore analyze on each, and generates reports.
"""

import json
import subprocess
import sys
import time
import argparse
from pathlib import Path
from datetime import datetime, timezone
from typing import Dict, List, Optional, Any
import csv
from io import StringIO


class KeywordAnalyzer:
    def __init__(self, appstore_path: str, delay: float = 2.0):
        """
        Initialize the keyword analyzer.

        Args:
            appstore_path: Path to the appstore CLI binary
            delay: Delay in seconds between API calls
        """
        self.appstore_path = appstore_path
        self.delay = delay
        self.results = []
        self.failed = []

    def run_analyze(self, keyword: str, storefront: str = "US", language: str = "en-us") -> Optional[Dict[str, Any]]:
        """
        Run appstore analyze on a single keyword.

        Args:
            keyword: Search term to analyze
            storefront: Country code (default: US)
            language: Language code (default: en-us)

        Returns:
            Dictionary with apps and summary, or None if failed
        """
        try:
            print(f"  Analyzing: {keyword}", flush=True)

            cmd = [
                self.appstore_path,
                "analyze",
                keyword,
                "--storefront", storefront
            ]

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=120
            )

            if result.returncode != 0:
                print(f"  ⚠️  Command failed with code {result.returncode}")
                print(f"  Error: {result.stderr}")
                return None

            # Parse the output
            return self.parse_analyze_output(result.stdout)

        except subprocess.TimeoutExpired:
            print(f"  ⚠️  Timeout after 120 seconds")
            return None
        except Exception as e:
            print(f"  ⚠️  Error: {e}")
            return None

    def parse_analyze_output(self, output: str) -> Dict[str, Any]:
        """
        Parse the CSV and summary output from appstore analyze.

        Args:
            output: Raw stdout from appstore analyze command

        Returns:
            Dictionary with 'apps' list and 'summary' dict
        """
        lines = output.strip().split('\n')

        # Find where CSV starts and where summary starts
        csv_start = None
        csv_end = None
        summary_start = None

        for i, line in enumerate(lines):
            if line.startswith("App ID,"):
                csv_start = i
            elif csv_start is not None and csv_end is None:
                if not line.strip() or line.startswith("Overall Summary"):
                    csv_end = i
            elif line.startswith("Overall Summary"):
                summary_start = i
                break

        # Parse CSV data
        apps = []
        if csv_start is not None and csv_end is not None:
            csv_text = '\n'.join(lines[csv_start:csv_end])
            reader = csv.DictReader(StringIO(csv_text))
            for row in reader:
                apps.append({
                    'app_id': int(row['App ID']) if row['App ID'] else None,
                    'rating': float(row['Rating']) if row['Rating'] else None,
                    'rating_count': int(row['Rating Count']) if row['Rating Count'] else 0,
                    'original_release': row['Original Release'],
                    'latest_release': row['Latest Release'],
                    'age_days': int(row['Age Days']) if row['Age Days'] else 0,
                    'freshness_days': int(row['Freshness Days']) if row['Freshness Days'] else 0,
                    'title_match_score': int(row['Title Match Score']) if row['Title Match Score'] else 0,
                    'description_match_score': int(row['Description Match Score']) if row['Description Match Score'] else 0,
                    'ratings_per_day': float(row['Ratings Per Day']) if row['Ratings Per Day'] else 0.0,
                    'title': row['Title'],
                    'genre': row['Genre'] if 'Genre' in row else '',
                    'version': row['Version'] if 'Version' in row else '',
                    'age_rating': row['Age Rating'] if 'Age Rating' in row else ''
                })

        # Parse summary statistics
        summary = {}
        if summary_start is not None:
            for line in lines[summary_start:]:
                line = line.strip()

                # Extract key metrics from summary
                if "Average App Age:" in line:
                    summary['avg_age_days'] = int(line.split(':')[1].strip().split()[0])
                elif "Average App Freshness:" in line:
                    summary['avg_freshness_days'] = int(line.split(':')[1].strip().split()[0])
                elif "Average Star Rating:" in line:
                    summary['avg_rating'] = float(line.split(':')[1].strip())
                elif "Average Rating Count:" in line:
                    summary['avg_rating_count'] = int(line.split(':')[1].strip())
                elif "Average Title Match Score:" in line:
                    summary['avg_title_match_score'] = float(line.split(':')[1].strip())
                elif "Average Description Match Score:" in line:
                    summary['avg_description_match_score'] = float(line.split(':')[1].strip())
                elif "Average Ratings Per Day:" in line:
                    summary['avg_ratings_per_day'] = float(line.split(':')[1].strip())
                elif "Competitiveness Score (v1):" in line:
                    summary['competitiveness_v1'] = float(line.split(':')[1].strip())
                elif "Velocity Ratio (Newest/Established):" in line:
                    summary['velocity_ratio'] = float(line.split(':')[1].strip())
                elif "Median App Age:" in line:
                    summary['median_age_days'] = int(line.split(':')[1].strip().split()[0])
                elif "Age Ratio (Old/New):" in line:
                    summary['age_ratio'] = float(line.split(':')[1].strip())

        return {
            'apps': apps,
            'summary': summary
        }

    def process_keywords(self, keywords: List[Dict[str, Any]], checkpoint_file: Optional[Path] = None) -> Dict[str, Any]:
        """
        Process all keywords and combine with analysis results.

        Args:
            keywords: List of keyword objects from input JSON
            checkpoint_file: Optional file to save progress

        Returns:
            Combined results dictionary
        """
        total = len(keywords)
        successful = 0
        failed = 0

        # Load checkpoint if exists
        processed_terms = set()
        if checkpoint_file and checkpoint_file.exists():
            with open(checkpoint_file, 'r') as f:
                checkpoint = json.load(f)
                self.results = checkpoint.get('results', [])
                processed_terms = {r['input']['search_term'] for r in self.results}
                print(f"Resuming from checkpoint: {len(processed_terms)} already processed")

        print(f"\nProcessing {total} keywords...")
        print("=" * 60)

        for i, keyword_data in enumerate(keywords, 1):
            search_term = keyword_data['search_term']

            # Skip if already processed
            if search_term in processed_terms:
                print(f"[{i}/{total}] Skipping (already processed): {search_term}")
                successful += 1
                continue

            print(f"\n[{i}/{total}] {search_term}")

            # Convert country name to code (simple mapping)
            country = keyword_data.get('country', 'United States')
            storefront = self.country_to_code(country)

            # Run analysis
            analysis = self.run_analyze(search_term, storefront)

            if analysis:
                self.results.append({
                    'input': keyword_data,
                    'analysis': analysis
                })
                successful += 1
                print(f"  ✓ Found {len(analysis['apps'])} apps, competitiveness: {analysis['summary'].get('competitiveness_v1', 'N/A')}")
            else:
                self.failed.append({
                    'keyword': search_term,
                    'input': keyword_data
                })
                failed += 1
                print(f"  ✗ Failed")

            # Save checkpoint
            if checkpoint_file and (i % 5 == 0 or i == total):
                self.save_checkpoint(checkpoint_file, successful, failed)

            # Rate limiting (skip delay on last item)
            if i < total:
                time.sleep(self.delay)

        print("\n" + "=" * 60)
        print(f"Completed: {successful} successful, {failed} failed")

        return {
            'metadata': {
                'generated': datetime.now(timezone.utc).isoformat(),
                'total_keywords': total,
                'successful': successful,
                'failed': failed
            },
            'results': self.results,
            'failed': self.failed
        }

    def country_to_code(self, country: str) -> str:
        """Convert country name to 2-letter code."""
        mapping = {
            'United States': 'US',
            'United Kingdom': 'GB',
            'Canada': 'CA',
            'Australia': 'AU',
            'Japan': 'JP',
            'Germany': 'DE',
            'France': 'FR',
            'Spain': 'ES',
            'Italy': 'IT',
        }
        return mapping.get(country, 'US')

    def save_checkpoint(self, checkpoint_file: Path, successful: int, failed: int):
        """Save progress to checkpoint file."""
        with open(checkpoint_file, 'w') as f:
            json.dump({
                'timestamp': datetime.now(timezone.utc).isoformat(),
                'successful': successful,
                'failed': failed,
                'results': self.results
            }, f, indent=2)
        print(f"  💾 Checkpoint saved ({successful} successful, {failed} failed)")


def generate_html_dashboard(data: Dict[str, Any], output_path: Path):
    """Generate interactive HTML dashboard from analysis results."""

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
            max-width: 300px;
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

        .app-rating {
            text-align: center;
        }

        .app-cell {
            text-align: center;
            font-size: 12px;
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
            </div>
            <div class="metric">
                <div class="metric-label">Generated</div>
                <div class="metric-value" style="font-size: 16px;">""" + data['metadata']['generated'][:10] + """</div>
            </div>
        </div>

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
                    <th data-sort="avg_ratings_per_day">Ratings/Day<span class="info-icon" data-tooltip="Average of (each app's total ratings ÷ age in days). Shows typical daily rating activity for apps ranking for this keyword.">i</span></th>
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
        let sortDirection = 'desc';
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
                                <div>Age Rating</div>
                            </div>
                            ${item.analysis.apps.slice(0, 20).map((app, i) => `
                                <div class="app-item">
                                    <div class="app-rank">#${i + 1}</div>
                                    <div class="app-cell" style="font-family: monospace; font-size: 11px;">${app.app_id || 'N/A'}</div>
                                    <div class="app-title" title="${app.title}">${app.title}</div>
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
                                    <div class="app-cell" style="font-size: 11px;">${app.age_rating || 'N/A'}</div>
                                </div>
                            `).join('')}
                        </div>
                    </div>
                `;
            }
        }

        let filteredData = [];

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

    print(f"\n✓ HTML dashboard generated: {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description='Analyze keywords using appstore CLI and generate reports'
    )
    parser.add_argument(
        'input_file',
        type=Path,
        help='Input JSON file with keywords'
    )
    parser.add_argument(
        '--output',
        type=Path,
        default=Path('output/keyword_analysis.json'),
        help='Output JSON file (default: output/keyword_analysis.json)'
    )
    parser.add_argument(
        '--html',
        type=Path,
        default=Path('output/keyword_dashboard.html'),
        help='Output HTML file (default: output/keyword_dashboard.html)'
    )
    parser.add_argument(
        '--appstore-path',
        type=str,
        default='/Users/andrew/Library/Developer/Xcode/DerivedData/appstore-fmmbfpfjrlfolrfwhedbyltydogi/Build/Products/Debug/appstore',
        help='Path to appstore CLI binary'
    )
    parser.add_argument(
        '--delay',
        type=float,
        default=2.0,
        help='Delay in seconds between API calls (default: 2.0)'
    )
    parser.add_argument(
        '--resume',
        action='store_true',
        help='Resume from checkpoint if available'
    )

    args = parser.parse_args()

    # Validate input file
    if not args.input_file.exists():
        print(f"Error: Input file not found: {args.input_file}")
        sys.exit(1)

    # Create output directory
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.html.parent.mkdir(parents=True, exist_ok=True)

    # Load keywords
    print(f"Loading keywords from: {args.input_file}")
    with open(args.input_file, 'r') as f:
        keywords = json.load(f)

    print(f"Loaded {len(keywords)} keywords")

    # Initialize analyzer
    analyzer = KeywordAnalyzer(args.appstore_path, args.delay)

    # Process keywords
    checkpoint_file = args.output.parent / 'checkpoint.json' if args.resume else None
    results = analyzer.process_keywords(keywords, checkpoint_file)

    # Save JSON results
    print(f"\nSaving results to: {args.output}")
    with open(args.output, 'w') as f:
        json.dump(results, f, indent=2)

    print(f"✓ JSON results saved: {args.output}")

    # Generate HTML dashboard
    if results['results']:
        generate_html_dashboard(results, args.html)
        print(f"✓ Dashboard ready at: {args.html}")
    else:
        print("⚠️  No results to generate dashboard")

    # Clean up checkpoint
    if checkpoint_file and checkpoint_file.exists():
        checkpoint_file.unlink()
        print("✓ Checkpoint file removed")


if __name__ == '__main__':
    main()
