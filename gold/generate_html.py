#!/usr/bin/env python3
"""
Generate an interactive HTML report from scored keywords JSON.
"""

import json
import sys
from pathlib import Path
from datetime import datetime


HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Keyword Gold Nuggets - Ranking Report</title>
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: #f5f5f7;
            padding: 20px;
            color: #1d1d1f;
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            padding: 30px;
        }

        h1 {
            font-size: 32px;
            font-weight: 600;
            margin-bottom: 10px;
            color: #1d1d1f;
        }

        .subtitle {
            color: #86868b;
            margin-bottom: 30px;
            font-size: 16px;
        }

        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }

        .stat-box {
            background: #f5f5f7;
            padding: 20px;
            border-radius: 8px;
        }

        .stat-label {
            font-size: 14px;
            color: #86868b;
            margin-bottom: 5px;
        }

        .stat-value {
            font-size: 28px;
            font-weight: 600;
            color: #1d1d1f;
        }

        .controls {
            background: #f5f5f7;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            display: flex;
            gap: 15px;
            align-items: center;
            flex-wrap: wrap;
        }

        .controls button {
            background: #0071e3;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 500;
            cursor: pointer;
            transition: background 0.2s;
        }

        .controls button:hover {
            background: #0077ed;
        }

        .controls button.secondary {
            background: #86868b;
        }

        .controls button.secondary:hover {
            background: #6e6e73;
        }

        .filters {
            background: #f5f5f7;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
        }

        .filter-group {
            display: flex;
            flex-direction: column;
            gap: 5px;
        }

        .filter-group label {
            font-size: 12px;
            font-weight: 600;
            color: #86868b;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .filter-group input,
        .filter-group select {
            padding: 8px 12px;
            border: 1px solid #d2d2d7;
            border-radius: 6px;
            font-size: 14px;
            background: white;
        }

        .selected-count {
            font-size: 14px;
            color: #1d1d1f;
            font-weight: 500;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }

        thead {
            background: #f5f5f7;
            position: sticky;
            top: 0;
        }

        th {
            text-align: left;
            padding: 12px;
            font-weight: 600;
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: #86868b;
            border-bottom: 1px solid #d2d2d7;
        }

        th.sortable {
            cursor: pointer;
            user-select: none;
        }

        th.sortable:hover {
            background: #e8e8ed;
        }

        th.group-header {
            background: #007aff;
            color: white;
            font-weight: 600;
            font-size: 11px;
            text-align: center;
            padding: 8px;
            border-bottom: 2px solid #0051d5;
        }

        th.group-header.apple-data {
            background: #5856d6;
        }

        th.group-header.our-scores {
            background: #ff9500;
        }

        th.group-header.selection {
            background: #34c759;
        }

        th.group-header.basic-info {
            background: #007aff;
        }

        tbody tr {
            border-bottom: 1px solid #d2d2d7;
            transition: background 0.15s;
        }

        tbody tr:hover {
            background: #f9f9f9;
        }

        tbody tr.selected {
            background: #e3f2fd;
        }

        td {
            padding: 12px;
            font-size: 14px;
        }

        .score-badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 12px;
            font-weight: 600;
            font-size: 13px;
        }

        .score-high { background: #d4edda; color: #155724; }
        .score-medium { background: #fff3cd; color: #856404; }
        .score-low { background: #f8d7da; color: #721c24; }

        .keyword {
            font-weight: 500;
            color: #0071e3;
        }

        input[type="checkbox"] {
            width: 18px;
            height: 18px;
            cursor: pointer;
        }

        .genre {
            color: #86868b;
            font-size: 13px;
        }

        .number {
            text-align: right;
            font-variant-numeric: tabular-nums;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🏆 Keyword Gold Nuggets</h1>
        <p class="subtitle">Finding high-popularity, low-competition keywords{source_info}</p>

        <div class="stats">
            <div class="stat-box">
                <div class="stat-label">Total Keywords</div>
                <div class="stat-value">{total_keywords}</div>
            </div>
            <div class="stat-box">
                <div class="stat-label">Country</div>
                <div class="stat-value">{country}</div>
            </div>
            <div class="stat-box">
                <div class="stat-label">Month</div>
                <div class="stat-value">{month}</div>
            </div>
            <div class="stat-box">
                <div class="stat-label">Generated</div>
                <div class="stat-value">{generated_time}</div>
            </div>
        </div>

        <div class="filters">
            <div class="filter-group">
                <label>Genre</label>
                <select id="filter-genre" onchange="applyFilters()">
                    <option value="">All Genres</option>
                </select>
            </div>
            <div class="filter-group">
                <label>Min Words in Keyword</label>
                <input type="number" id="filter-min-words" min="1" placeholder="Any" onchange="applyFilters()">
            </div>
            <div class="filter-group">
                <label>Max Words in Keyword</label>
                <input type="number" id="filter-max-words" min="1" placeholder="Any" onchange="applyFilters()">
            </div>
            <div class="filter-group">
                <label>Max Rank in Genre</label>
                <input type="number" id="filter-max-rank" min="1" max="500" placeholder="500" onchange="applyFilters()">
            </div>
            <div class="filter-group">
                <label>Min Pop. in Genre</label>
                <input type="number" id="filter-min-pop-genre" min="0" max="100" placeholder="0" onchange="applyFilters()">
            </div>
            <div class="filter-group">
                <label>Min Pop. Overall</label>
                <input type="number" id="filter-min-pop-overall" min="0" max="100" placeholder="0" onchange="applyFilters()">
            </div>
        </div>

        <div class="controls">
            <button onclick="selectTop(50)">Select Top 50</button>
            <button onclick="selectTop(100)">Select Top 100</button>
            <button onclick="selectVisible()">Select All Visible</button>
            <button class="secondary" onclick="clearSelection()">Clear All</button>
            <button class="secondary" onclick="exportSelected()">Export Selected</button>
            <span class="selected-count">Selected: <strong id="selected-count">0</strong> | Showing: <strong id="visible-count">0</strong> of {total_keywords}</span>
        </div>

        <table id="keywords-table">
            <thead>
                <tr>
                    <th colspan="1" class="group-header selection">Select</th>
                    <th colspan="3" class="group-header basic-info">Basic Info</th>
                    <th colspan="3" class="group-header apple-data">Apple Search Ads Data</th>
                    <th colspan="3" class="group-header our-scores">Our Calculated Scores</th>
                </tr>
                <tr>
                    <th style="width: 50px;">
                        <input type="checkbox" id="select-all" onchange="toggleAllVisible(this.checked)">
                    </th>
                    <th class="sortable" onclick="sortTable('total_score')">Total Score ▼</th>
                    <th class="sortable" onclick="sortTable('search_term')">Keyword</th>
                    <th class="sortable" onclick="sortTable('genre')">Genre</th>
                    <th class="sortable number" onclick="sortTable('rank_in_genre')">Rank in Genre</th>
                    <th class="sortable number" onclick="sortTable('popularity_genre')">Pop. in Genre</th>
                    <th class="sortable number" onclick="sortTable('popularity_overall')">Pop. Overall</th>
                    <th class="sortable number" onclick="sortTable('score_rank')">Rank Score</th>
                    <th class="sortable number" onclick="sortTable('score_genre')">Genre Score</th>
                    <th class="sortable number" onclick="sortTable('score_overall')">Overall Score</th>
                </tr>
            </thead>
            <tbody id="keywords-body">
                {table_rows}
            </tbody>
        </table>
    </div>

    <script>
        const allKeywordsData = {keywords_json};
        let filteredData = [...allKeywordsData];

        // Populate genre dropdown
        window.addEventListener('DOMContentLoaded', function() {
            const genres = [...new Set(allKeywordsData.map(k => k.genre))].sort();
            const select = document.getElementById('filter-genre');
            genres.forEach(genre => {
                const option = document.createElement('option');
                option.value = genre;
                option.textContent = genre;
                select.appendChild(option);
            });
            applyFilters();
        });

        function getScoreClass(score) {
            if (score >= 8) return 'score-high';
            if (score >= 5) return 'score-medium';
            return 'score-low';
        }

        function countWords(text) {
            return text.trim().split(/\\s+/).length;
        }

        function applyFilters() {
            const genre = document.getElementById('filter-genre').value;
            const minWords = parseInt(document.getElementById('filter-min-words').value) || 0;
            const maxWords = parseInt(document.getElementById('filter-max-words').value) || Infinity;
            const maxRank = parseInt(document.getElementById('filter-max-rank').value) || 500;
            const minPopGenre = parseInt(document.getElementById('filter-min-pop-genre').value) || 0;
            const minPopOverall = parseInt(document.getElementById('filter-min-pop-overall').value) || 0;

            filteredData = allKeywordsData.filter(kw => {
                const wordCount = countWords(kw.search_term);
                return (!genre || kw.genre === genre) &&
                       wordCount >= minWords &&
                       wordCount <= maxWords &&
                       kw.rank_in_genre <= maxRank &&
                       kw.popularity_genre >= minPopGenre &&
                       kw.popularity_overall >= minPopOverall;
            });

            // Re-sort with current sort settings
            sortTable(currentSort.column, true);
            updateVisibleCount();
        }

        function updateVisibleCount() {
            const visible = document.querySelectorAll('tbody tr').length;
            document.getElementById('visible-count').textContent = visible;
        }

        function updateSelectedCount() {
            const count = document.querySelectorAll('tbody input[type="checkbox"]:checked').length;
            document.getElementById('selected-count').textContent = count;
        }

        function toggleAllVisible(checked) {
            document.querySelectorAll('tbody input[type="checkbox"]').forEach(cb => {
                cb.checked = checked;
                if (checked) cb.closest('tr').classList.add('selected');
                else cb.closest('tr').classList.remove('selected');
            });
            updateSelectedCount();
        }

        function selectVisible() {
            document.querySelectorAll('tbody input[type="checkbox"]').forEach(cb => {
                cb.checked = true;
                cb.closest('tr').classList.add('selected');
            });
            document.getElementById('select-all').checked = true;
            updateSelectedCount();
        }

        function toggleRow(checkbox) {
            if (checkbox.checked) {
                checkbox.closest('tr').classList.add('selected');
            } else {
                checkbox.closest('tr').classList.remove('selected');
            }
            updateSelectedCount();
        }

        function selectTop(n) {
            clearSelection();
            const checkboxes = document.querySelectorAll('tbody input[type="checkbox"]');
            for (let i = 0; i < Math.min(n, checkboxes.length); i++) {
                checkboxes[i].checked = true;
                checkboxes[i].closest('tr').classList.add('selected');
            }
            updateSelectedCount();
        }

        function clearSelection() {
            document.querySelectorAll('tbody input[type="checkbox"]').forEach(cb => {
                cb.checked = false;
                cb.closest('tr').classList.remove('selected');
            });
            document.getElementById('select-all').checked = false;
            updateSelectedCount();
        }

        function exportSelected() {
            const selected = [];
            document.querySelectorAll('tbody input[type="checkbox"]:checked').forEach(cb => {
                const index = parseInt(cb.getAttribute('data-index'));
                selected.push(allKeywordsData[index]);
            });

            if (selected.length === 0) {
                alert('No keywords selected');
                return;
            }

            // Generate filename with timestamp including seconds
            const now = new Date();
            const timestamp = now.getFullYear() +
                String(now.getMonth() + 1).padStart(2, '0') +
                String(now.getDate()).padStart(2, '0') + '_' +
                String(now.getHours()).padStart(2, '0') +
                String(now.getMinutes()).padStart(2, '0') +
                String(now.getSeconds()).padStart(2, '0');
            const filename = `selected_keywords_${timestamp}.json`;

            const blob = new Blob([JSON.stringify(selected, null, 2)], { type: 'application/json' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = filename;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
        }

        let currentSort = { column: 'total_score', ascending: false };

        function sortTable(column, skipToggle) {
            if (!skipToggle) {
                if (currentSort.column === column) {
                    currentSort.ascending = !currentSort.ascending;
                } else {
                    currentSort.column = column;
                    currentSort.ascending = column === 'search_term' || column === 'genre';
                }
            }

            const sorted = [...filteredData].sort((a, b) => {
                let aVal = a[column];
                let bVal = b[column];

                if (typeof aVal === 'string') {
                    aVal = aVal.toLowerCase();
                    bVal = bVal.toLowerCase();
                }

                if (currentSort.ascending) {
                    return aVal > bVal ? 1 : -1;
                } else {
                    return aVal < bVal ? 1 : -1;
                }
            });

            renderTable(sorted);
        }

        function renderTable(data) {
            const tbody = document.getElementById('keywords-body');
            tbody.innerHTML = data.map((kw, idx) => {
                const originalIndex = allKeywordsData.indexOf(kw);
                const scoreClass = getScoreClass(kw.total_score);
                return `
                    <tr>
                        <td><input type="checkbox" data-index="${originalIndex}" onchange="toggleRow(this)"></td>
                        <td><span class="score-badge ${scoreClass}">${kw.total_score}</span></td>
                        <td class="keyword">${kw.search_term}</td>
                        <td class="genre">${kw.genre}</td>
                        <td class="number">${kw.rank_in_genre}</td>
                        <td class="number">${kw.popularity_genre}</td>
                        <td class="number">${kw.popularity_overall}</td>
                        <td class="number">${kw.score_rank}</td>
                        <td class="number">${kw.score_genre}</td>
                        <td class="number">${kw.score_overall}</td>
                    </tr>
                `;
            }).join('');
            updateVisibleCount();
            document.getElementById('select-all').checked = false;
        }
    </script>
</body>
</html>
"""


def generate_html(keywords_data, output_path, source_filename=None):
    """Generate HTML report from keywords data."""

    country = keywords_data.get("country", "Unknown")
    total_keywords = keywords_data.get("total_keywords", 0)
    keywords = keywords_data.get("keywords", [])

    # Get month from first keyword if available
    month = keywords[0].get("month", "Unknown") if keywords else "Unknown"

    # Show all keywords (filtering will happen in browser)
    keywords_display = keywords

    # Generate timestamp
    generated_time = datetime.now().strftime("%Y-%m-%d %H:%M")

    # Generate table rows (initial render, JS will handle sorting)
    table_rows = []
    for idx, kw in enumerate(keywords_display):
        score_class = "score-high" if kw["total_score"] >= 8 else "score-medium" if kw["total_score"] >= 5 else "score-low"
        table_rows.append(f"""
            <tr>
                <td><input type="checkbox" data-index="{idx}" onchange="toggleRow(this)"></td>
                <td><span class="score-badge {score_class}">{kw["total_score"]}</span></td>
                <td class="keyword">{kw["search_term"]}</td>
                <td class="genre">{kw["genre"]}</td>
                <td class="number">{kw["rank_in_genre"]}</td>
                <td class="number">{kw["popularity_genre"]}</td>
                <td class="number">{kw["popularity_overall"]}</td>
                <td class="number">{kw["score_rank"]}</td>
                <td class="number">{kw["score_genre"]}</td>
                <td class="number">{kw["score_overall"]}</td>
            </tr>
        """)

    # Build source info string
    source_info = ""
    if source_filename:
        source_info = f" | Source: {source_filename}"

    # Replace placeholders in template
    html = HTML_TEMPLATE.replace("{total_keywords}", str(total_keywords))
    html = html.replace("{country}", country)
    html = html.replace("{month}", month)
    html = html.replace("{source_info}", source_info)
    html = html.replace("{generated_time}", generated_time)
    html = html.replace("{table_rows}", "\n".join(table_rows))
    html = html.replace("{keywords_json}", json.dumps(keywords_display))

    with open(output_path, 'w') as f:
        f.write(html)

    print(f"Generated HTML report: {output_path}", file=sys.stderr)
    print(f"Displaying top {len(keywords_display)} of {total_keywords} keywords", file=sys.stderr)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 generate_html.py <keywords_json> [output_html] [source_filename]", file=sys.stderr)
        sys.exit(1)

    json_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else "keyword_report.html"
    source_filename = sys.argv[3] if len(sys.argv) > 3 else None

    if not Path(json_path).exists():
        print(f"Error: File not found: {json_path}", file=sys.stderr)
        sys.exit(1)

    with open(json_path) as f:
        keywords_data = json.load(f)

    generate_html(keywords_data, output_path, source_filename)
    print(f"\nOpen {output_path} in your browser to view the report")


if __name__ == "__main__":
    main()
