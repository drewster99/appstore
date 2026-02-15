#!/usr/bin/env python3
"""
Generate an interactive HTML report comparing App Store search term ranks across multiple months.
"""

import pandas as pd
import numpy as np
from pathlib import Path
import json
from datetime import datetime
import sys

def load_monthly_data(file_path):
    """Load a monthly rank file and return a cleaned DataFrame."""
    print(f"Loading {file_path}...")

    # Read the file, skipping header rows
    df = pd.read_excel(file_path, skiprows=5)

    # The first row contains the actual column names
    df.columns = df.iloc[0]
    df = df.iloc[1:].reset_index(drop=True)

    # Rename columns for easier access
    df.columns = ['Month', 'Country', 'Category', 'Keyword', 'CategoryRank',
                  'CategoryPopularity', 'OverallPopularity', 'PopularityScore']

    # Convert numeric columns
    numeric_cols = ['CategoryRank', 'CategoryPopularity', 'OverallPopularity', 'PopularityScore']
    for col in numeric_cols:
        df[col] = pd.to_numeric(df[col], errors='coerce')

    # Clean up
    df = df.dropna(subset=['Keyword', 'Country', 'Category'])

    return df

def combine_monthly_data(file_paths):
    """Combine multiple monthly files into a single DataFrame."""
    dfs = []
    for fp in sorted(file_paths):
        df = load_monthly_data(fp)
        dfs.append(df)

    combined = pd.concat(dfs, ignore_index=True)
    return combined

def calculate_trends(df, country, category):
    """Calculate trends for keywords in a specific country and category."""
    # Filter data
    filtered = df[(df['Country'] == country) & (df['Category'] == category)].copy()

    if filtered.empty:
        return pd.DataFrame()

    # Get unique months sorted
    months = sorted(filtered['Month'].unique())

    if len(months) < 2:
        return pd.DataFrame()

    # Pivot to get one row per keyword with columns for each month
    trends = []

    for keyword in filtered['Keyword'].unique():
        keyword_data = filtered[filtered['Keyword'] == keyword].sort_values('Month')

        row = {'Keyword': keyword}

        # Add data for each month
        for i, month in enumerate(months, 1):
            month_data = keyword_data[keyword_data['Month'] == month]
            if not month_data.empty:
                row[f'Month{i}'] = month
                row[f'CategoryRank{i}'] = month_data['CategoryRank'].iloc[0]
                row[f'CategoryPop{i}'] = month_data['CategoryPopularity'].iloc[0]
                row[f'OverallPop{i}'] = month_data['OverallPopularity'].iloc[0]
            else:
                row[f'Month{i}'] = month
                row[f'CategoryRank{i}'] = None
                row[f'CategoryPop{i}'] = None
                row[f'OverallPop{i}'] = None

        # Calculate changes
        if len(months) >= 2:
            # Rank changes (negative = improvement in rank)
            if row.get(f'CategoryRank{len(months)}') and row.get(f'CategoryRank1'):
                row['CategoryRankChange'] = row[f'CategoryRank1'] - row[f'CategoryRank{len(months)}']

            # Popularity changes (positive = improvement)
            if row.get(f'CategoryPop{len(months)}') and row.get(f'CategoryPop1'):
                row['CategoryPopChange'] = row[f'CategoryPop{len(months)}'] - row[f'CategoryPop1']

            if row.get(f'OverallPop{len(months)}') and row.get(f'OverallPop1'):
                row['OverallPopChange'] = row[f'OverallPop{len(months)}'] - row[f'OverallPop1']

        # Determine if new or disappeared
        non_null_months = sum(1 for i in range(1, len(months) + 1) if row.get(f'CategoryRank{i}') is not None)
        row['IsNew'] = non_null_months == 1 and row.get(f'CategoryRank{len(months)}') is not None
        row['IsGone'] = non_null_months == 1 and row.get(f'CategoryRank{len(months)}') is None

        trends.append(row)

    return pd.DataFrame(trends)

def generate_html_report(df, output_file='keyword_report.html'):
    """Generate an interactive HTML report."""

    # Get unique countries and categories
    countries = sorted(df['Country'].unique())
    categories = sorted(df['Category'].unique())

    # Get months for display
    months = sorted(df['Month'].unique())
    month_labels = [str(m) for m in months]

    # Pre-calculate trends for all country/category combinations
    all_trends = {}
    for country in countries:
        for category in categories:
            trends = calculate_trends(df, country, category)
            if not trends.empty:
                key = f"{country}|{category}"
                all_trends[key] = trends.to_dict('records')

    # Convert to JSON for embedding in HTML
    trends_json = json.dumps(all_trends)
    countries_json = json.dumps(countries)
    categories_json = json.dumps(categories)
    months_json = json.dumps(month_labels)

    # Generate HTML
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>App Store Keyword Rank Analysis</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <style>
        * {{
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }}

        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: #f5f5f7;
            padding: 20px;
            color: #1d1d1f;
        }}

        .container {{
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            padding: 30px;
        }}

        h1 {{
            font-size: 32px;
            font-weight: 600;
            margin-bottom: 10px;
            color: #1d1d1f;
        }}

        .subtitle {{
            color: #6e6e73;
            margin-bottom: 30px;
            font-size: 16px;
        }}

        .controls {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
            margin-bottom: 30px;
            padding: 20px;
            background: #f5f5f7;
            border-radius: 8px;
        }}

        .control-group {{
            display: flex;
            flex-direction: column;
        }}

        label {{
            font-size: 13px;
            font-weight: 600;
            color: #6e6e73;
            margin-bottom: 6px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}

        select, input {{
            padding: 10px 12px;
            border: 1px solid #d2d2d7;
            border-radius: 6px;
            font-size: 14px;
            background: white;
            transition: all 0.2s;
        }}

        select:focus, input:focus {{
            outline: none;
            border-color: #0071e3;
            box-shadow: 0 0 0 4px rgba(0,113,227,0.1);
        }}

        .tabs {{
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
            border-bottom: 1px solid #d2d2d7;
            overflow-x: auto;
        }}

        .tab {{
            padding: 12px 20px;
            background: none;
            border: none;
            border-bottom: 2px solid transparent;
            cursor: pointer;
            font-size: 14px;
            font-weight: 500;
            color: #6e6e73;
            transition: all 0.2s;
            white-space: nowrap;
        }}

        .tab:hover {{
            color: #1d1d1f;
        }}

        .tab.active {{
            color: #0071e3;
            border-bottom-color: #0071e3;
        }}

        .tab-content {{
            display: none;
        }}

        .tab-content.active {{
            display: block;
        }}

        .stats-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 30px;
        }}

        .stat-card {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }}

        .stat-card.green {{
            background: linear-gradient(135deg, #00b894 0%, #00cec9 100%);
        }}

        .stat-card.red {{
            background: linear-gradient(135deg, #ff7675 0%, #fd79a8 100%);
        }}

        .stat-card.blue {{
            background: linear-gradient(135deg, #0984e3 0%, #6c5ce7 100%);
        }}

        .stat-label {{
            font-size: 12px;
            opacity: 0.9;
            margin-bottom: 5px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}

        .stat-value {{
            font-size: 28px;
            font-weight: 700;
        }}

        table {{
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
            font-size: 14px;
        }}

        thead {{
            background: #f5f5f7;
            position: sticky;
            top: 0;
            z-index: 10;
        }}

        th {{
            padding: 12px 10px;
            text-align: left;
            font-weight: 600;
            color: #1d1d1f;
            border-bottom: 2px solid #d2d2d7;
            cursor: pointer;
            user-select: none;
        }}

        th:hover {{
            background: #e8e8ed;
        }}

        th.sortable::after {{
            content: ' ⇅';
            color: #d2d2d7;
        }}

        th.sort-asc::after {{
            content: ' ↑';
            color: #0071e3;
        }}

        th.sort-desc::after {{
            content: ' ↓';
            color: #0071e3;
        }}

        td {{
            padding: 10px;
            border-bottom: 1px solid #f5f5f7;
        }}

        tr:hover {{
            background: #fafafa;
        }}

        .rank-change {{
            display: inline-flex;
            align-items: center;
            padding: 2px 8px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
        }}

        .rank-up {{
            background: #d4edda;
            color: #155724;
        }}

        .rank-down {{
            background: #f8d7da;
            color: #721c24;
        }}

        .rank-same {{
            background: #e8e8ed;
            color: #6e6e73;
        }}

        .badge {{
            display: inline-block;
            padding: 3px 8px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}

        .badge-new {{
            background: #4CAF50;
            color: white;
        }}

        .badge-gone {{
            background: #f44336;
            color: white;
        }}

        .chart-container {{
            margin: 30px 0;
            padding: 20px;
            background: #fafafa;
            border-radius: 8px;
        }}

        .no-data {{
            text-align: center;
            padding: 60px 20px;
            color: #6e6e73;
            font-size: 16px;
        }}

        .loading {{
            text-align: center;
            padding: 40px;
            color: #6e6e73;
        }}

        .keyword-cell {{
            font-weight: 600;
            color: #1d1d1f;
        }}

        .rank-cell {{
            font-variant-numeric: tabular-nums;
        }}

        .empty-rank {{
            color: #d2d2d7;
        }}

        @media (max-width: 768px) {{
            .container {{
                padding: 15px;
            }}

            .controls {{
                grid-template-columns: 1fr;
            }}

            table {{
                font-size: 12px;
            }}

            th, td {{
                padding: 8px 5px;
            }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>App Store Keyword Rank Analysis</h1>
        <p class="subtitle">Compare keyword rankings and popularity across multiple months</p>

        <div class="controls">
            <div class="control-group">
                <label for="country">Country</label>
                <select id="country">
                    <option value="">Select a country...</option>
                </select>
            </div>

            <div class="control-group">
                <label for="category">Category</label>
                <select id="category">
                    <option value="">Select a category...</option>
                </select>
            </div>

            <div class="control-group">
                <label for="search">Search Keywords</label>
                <input type="text" id="search" placeholder="Filter keywords...">
            </div>

            <div class="control-group">
                <label for="limit">Show Top</label>
                <select id="limit">
                    <option value="50">50 keywords</option>
                    <option value="100">100 keywords</option>
                    <option value="200">200 keywords</option>
                    <option value="500">500 keywords</option>
                    <option value="999999">All keywords</option>
                </select>
            </div>
        </div>

        <div class="stats-grid" id="statsGrid" style="display: none;">
            <div class="stat-card">
                <div class="stat-label">Total Keywords</div>
                <div class="stat-value" id="statTotal">-</div>
            </div>
            <div class="stat-card green">
                <div class="stat-label">Rank Gainers</div>
                <div class="stat-value" id="statGainers">-</div>
            </div>
            <div class="stat-card red">
                <div class="stat-label">Rank Losers</div>
                <div class="stat-value" id="statLosers">-</div>
            </div>
            <div class="stat-card blue">
                <div class="stat-label">New Keywords</div>
                <div class="stat-value" id="statNew">-</div>
            </div>
        </div>

        <div class="tabs">
            <button class="tab active" data-tab="overview">Overview</button>
            <button class="tab" data-tab="gainers">Biggest Gainers</button>
            <button class="tab" data-tab="losers">Biggest Losers</button>
            <button class="tab" data-tab="new">New Keywords</button>
            <button class="tab" data-tab="popularity">Popularity Trends</button>
            <button class="tab" data-tab="charts">Charts</button>
        </div>

        <div id="overview" class="tab-content active">
            <div id="overviewContent"></div>
        </div>

        <div id="gainers" class="tab-content">
            <div id="gainersContent"></div>
        </div>

        <div id="losers" class="tab-content">
            <div id="losersContent"></div>
        </div>

        <div id="new" class="tab-content">
            <div id="newContent"></div>
        </div>

        <div id="popularity" class="tab-content">
            <div id="popularityContent"></div>
        </div>

        <div id="charts" class="tab-content">
            <div class="chart-container">
                <canvas id="rankTrendChart"></canvas>
            </div>
            <div class="chart-container">
                <canvas id="popularityDistChart"></canvas>
            </div>
        </div>
    </div>

    <script>
        // Embedded data
        const allTrends = {trends_json};
        const countries = {countries_json};
        const categories = {categories_json};
        const months = {months_json};

        let currentData = [];
        let currentSort = {{ column: null, direction: 'asc' }};

        // Initialize
        document.addEventListener('DOMContentLoaded', () => {{
            populateCountries();
            setupEventListeners();
        }});

        function populateCountries() {{
            const select = document.getElementById('country');
            countries.forEach(country => {{
                const option = document.createElement('option');
                option.value = country;
                option.textContent = country;
                select.appendChild(option);
            }});
        }}

        function populateCategories(country) {{
            const select = document.getElementById('category');
            select.innerHTML = '<option value="">Select a category...</option>';

            const availableCategories = new Set();
            Object.keys(allTrends).forEach(key => {{
                const [c, cat] = key.split('|');
                if (c === country) {{
                    availableCategories.add(cat);
                }}
            }});

            Array.from(availableCategories).sort().forEach(cat => {{
                const option = document.createElement('option');
                option.value = cat;
                option.textContent = cat;
                select.appendChild(option);
            }});
        }}

        function setupEventListeners() {{
            document.getElementById('country').addEventListener('change', (e) => {{
                populateCategories(e.target.value);
                updateReport();
            }});

            document.getElementById('category').addEventListener('change', updateReport);
            document.getElementById('search').addEventListener('input', updateReport);
            document.getElementById('limit').addEventListener('change', updateReport);

            // Tab switching
            document.querySelectorAll('.tab').forEach(tab => {{
                tab.addEventListener('click', (e) => {{
                    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
                    document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));

                    e.target.classList.add('active');
                    document.getElementById(e.target.dataset.tab).classList.add('active');

                    updateReport();
                }});
            }});
        }}

        function updateReport() {{
            const country = document.getElementById('country').value;
            const category = document.getElementById('category').value;
            const searchTerm = document.getElementById('search').value.toLowerCase();
            const limit = parseInt(document.getElementById('limit').value);

            if (!country || !category) {{
                showNoData();
                return;
            }}

            const key = `${{country}}|${{category}}`;
            const data = allTrends[key];

            if (!data || data.length === 0) {{
                showNoData();
                return;
            }}

            // Filter by search term
            let filtered = data;
            if (searchTerm) {{
                filtered = data.filter(row =>
                    row.Keyword && row.Keyword.toLowerCase().includes(searchTerm)
                );
            }}

            currentData = filtered;

            // Update stats
            updateStats(filtered);

            // Update active tab
            const activeTab = document.querySelector('.tab.active').dataset.tab;

            switch(activeTab) {{
                case 'overview':
                    renderOverview(filtered, limit);
                    break;
                case 'gainers':
                    renderGainers(filtered, limit);
                    break;
                case 'losers':
                    renderLosers(filtered, limit);
                    break;
                case 'new':
                    renderNew(filtered, limit);
                    break;
                case 'popularity':
                    renderPopularity(filtered, limit);
                    break;
                case 'charts':
                    renderCharts(filtered);
                    break;
            }}
        }}

        function updateStats(data) {{
            document.getElementById('statsGrid').style.display = 'grid';

            const total = data.length;
            const gainers = data.filter(d => (d.CategoryRankChange || 0) > 0).length;
            const losers = data.filter(d => (d.CategoryRankChange || 0) < 0).length;
            const newKeywords = data.filter(d => d.IsNew).length;

            document.getElementById('statTotal').textContent = total;
            document.getElementById('statGainers').textContent = gainers;
            document.getElementById('statLosers').textContent = losers;
            document.getElementById('statNew').textContent = newKeywords;
        }}

        function showNoData() {{
            document.getElementById('statsGrid').style.display = 'none';
            const content = '<div class="no-data">Please select a country and category to view the report.</div>';
            const contentIds = ['overviewContent', 'gainersContent', 'losersContent', 'newContent', 'popularityContent'];
            contentIds.forEach(id => {{
                const el = document.getElementById(id);
                if (el) el.innerHTML = content;
            }});
        }}

        function renderOverview(data, limit) {{
            const monthCount = months.length;
            let html = '<table><thead><tr>';
            html += '<th class="sortable" data-column="Keyword">Keyword</th>';

            for (let i = monthCount; i >= 1; i--) {{
                html += `<th class="sortable" data-column="CategoryRank${{i}}">${{months[i-1]}} Cat Rank</th>`;
            }}

            html += '<th class="sortable" data-column="CategoryRankChange">Change</th>';

            for (let i = monthCount; i >= 1; i--) {{
                html += `<th class="sortable" data-column="CategoryPop${{i}}">${{months[i-1]}} Pop</th>`;
            }}

            html += '</tr></thead><tbody>';

            const sorted = [...data].sort((a, b) => {{
                const aRank = a[`CategoryRank${{monthCount}}`] || 999999;
                const bRank = b[`CategoryRank${{monthCount}}`] || 999999;
                return aRank - bRank;
            }}).slice(0, limit);

            sorted.forEach(row => {{
                html += '<tr>';
                html += `<td class="keyword-cell">${{escapeHtml(row.Keyword || '')}}`;
                if (row.IsNew) html += ' <span class="badge badge-new">New</span>';
                html += '</td>';

                for (let i = monthCount; i >= 1; i--) {{
                    const rank = row[`CategoryRank${{i}}`];
                    html += `<td class="rank-cell">${{rank != null ? rank : '<span class="empty-rank">-</span>'}}</td>`;
                }}

                const change = row.CategoryRankChange;
                if (change != null) {{
                    if (change > 0) {{
                        html += `<td><span class="rank-change rank-up">+${{change}}</span></td>`;
                    }} else if (change < 0) {{
                        html += `<td><span class="rank-change rank-down">${{change}}</span></td>`;
                    }} else {{
                        html += `<td><span class="rank-change rank-same">-</span></td>`;
                    }}
                }} else {{
                    html += '<td>-</td>';
                }}

                for (let i = monthCount; i >= 1; i--) {{
                    const pop = row[`CategoryPop${{i}}`];
                    html += `<td>${{pop != null ? pop : '-'}}</td>`;
                }}

                html += '</tr>';
            }});

            html += '</tbody></table>';
            document.getElementById('overviewContent').innerHTML = html;

            addSortHandlers('overviewContent');
        }}

        function renderGainers(data, limit) {{
            const gainers = data
                .filter(d => (d.CategoryRankChange || 0) > 0)
                .sort((a, b) => (b.CategoryRankChange || 0) - (a.CategoryRankChange || 0))
                .slice(0, limit);

            if (gainers.length === 0) {{
                document.getElementById('gainersContent').innerHTML = '<div class="no-data">No rank improvements found.</div>';
                return;
            }}

            const monthCount = months.length;
            let html = '<table><thead><tr>';
            html += '<th>Rank</th><th>Keyword</th>';
            html += `<th>${{months[0]}} Rank</th>`;
            html += `<th>${{months[monthCount-1]}} Rank</th>`;
            html += '<th>Improvement</th>';
            html += `<th>${{months[monthCount-1]}} Pop</th>`;
            html += '</tr></thead><tbody>';

            gainers.forEach((row, idx) => {{
                html += '<tr>';
                html += `<td>${{idx + 1}}</td>`;
                html += `<td class="keyword-cell">${{escapeHtml(row.Keyword || '')}}</td>`;
                html += `<td>${{row.CategoryRank1 || '-'}}</td>`;
                html += `<td>${{row[`CategoryRank${{monthCount}}`] || '-'}}</td>`;
                html += `<td><span class="rank-change rank-up">+${{row.CategoryRankChange}}</span></td>`;
                html += `<td>${{row[`CategoryPop${{monthCount}}`] || '-'}}</td>`;
                html += '</tr>';
            }});

            html += '</tbody></table>';
            document.getElementById('gainersContent').innerHTML = html;
        }}

        function renderLosers(data, limit) {{
            const losers = data
                .filter(d => (d.CategoryRankChange || 0) < 0)
                .sort((a, b) => (a.CategoryRankChange || 0) - (b.CategoryRankChange || 0))
                .slice(0, limit);

            if (losers.length === 0) {{
                document.getElementById('losersContent').innerHTML = '<div class="no-data">No rank declines found.</div>';
                return;
            }}

            const monthCount = months.length;
            let html = '<table><thead><tr>';
            html += '<th>Rank</th><th>Keyword</th>';
            html += `<th>${{months[0]}} Rank</th>`;
            html += `<th>${{months[monthCount-1]}} Rank</th>`;
            html += '<th>Decline</th>';
            html += `<th>${{months[monthCount-1]}} Pop</th>`;
            html += '</tr></thead><tbody>';

            losers.forEach((row, idx) => {{
                html += '<tr>';
                html += `<td>${{idx + 1}}</td>`;
                html += `<td class="keyword-cell">${{escapeHtml(row.Keyword || '')}}</td>`;
                html += `<td>${{row.CategoryRank1 || '-'}}</td>`;
                html += `<td>${{row[`CategoryRank${{monthCount}}`] || '-'}}</td>`;
                html += `<td><span class="rank-change rank-down">${{row.CategoryRankChange}}</span></td>`;
                html += `<td>${{row[`CategoryPop${{monthCount}}`] || '-'}}</td>`;
                html += '</tr>';
            }});

            html += '</tbody></table>';
            document.getElementById('losersContent').innerHTML = html;
        }}

        function renderNew(data, limit) {{
            const newKeywords = data.filter(d => d.IsNew).slice(0, limit);

            if (newKeywords.length === 0) {{
                document.getElementById('newContent').innerHTML = '<div class="no-data">No new keywords found.</div>';
                return;
            }}

            const monthCount = months.length;
            let html = '<table><thead><tr>';
            html += '<th>Keyword</th>';
            html += '<th>Current Rank</th>';
            html += '<th>Popularity</th>';
            html += '</tr></thead><tbody>';

            newKeywords.forEach(row => {{
                html += '<tr>';
                html += `<td class="keyword-cell">${{escapeHtml(row.Keyword || '')}} <span class="badge badge-new">New</span></td>`;
                html += `<td>${{row[`CategoryRank${{monthCount}}`] || '-'}}</td>`;
                html += `<td>${{row[`CategoryPop${{monthCount}}`] || '-'}}</td>`;
                html += '</tr>';
            }});

            html += '</tbody></table>';
            document.getElementById('newContent').innerHTML = html;
        }}

        function renderPopularity(data, limit) {{
            const withPopChange = data
                .filter(d => d.CategoryPopChange != null)
                .sort((a, b) => Math.abs(b.CategoryPopChange || 0) - Math.abs(a.CategoryPopChange || 0))
                .slice(0, limit);

            if (withPopChange.length === 0) {{
                document.getElementById('popularityContent').innerHTML = '<div class="no-data">No popularity data available.</div>';
                return;
            }}

            const monthCount = months.length;
            let html = '<table><thead><tr>';
            html += '<th>Keyword</th>';
            html += `<th>${{months[0]}} Pop</th>`;
            html += `<th>${{months[monthCount-1]}} Pop</th>`;
            html += '<th>Change</th>';
            html += '<th>Current Rank</th>';
            html += '</tr></thead><tbody>';

            withPopChange.forEach(row => {{
                html += '<tr>';
                html += `<td class="keyword-cell">${{escapeHtml(row.Keyword || '')}}</td>`;
                html += `<td>${{row.CategoryPop1 || '-'}}</td>`;
                html += `<td>${{row[`CategoryPop${{monthCount}}`] || '-'}}</td>`;

                const change = row.CategoryPopChange;
                if (change > 0) {{
                    html += `<td><span class="rank-change rank-up">+${{change}}</span></td>`;
                }} else if (change < 0) {{
                    html += `<td><span class="rank-change rank-down">${{change}}</span></td>`;
                }} else {{
                    html += `<td><span class="rank-change rank-same">-</span></td>`;
                }}

                html += `<td>${{row[`CategoryRank${{monthCount}}`] || '-'}}</td>`;
                html += '</tr>';
            }});

            html += '</tbody></table>';
            document.getElementById('popularityContent').innerHTML = html;
        }}

        function renderCharts(data) {{
            // Top 10 keywords rank trend
            const monthCount = months.length;
            const top10 = [...data]
                .filter(d => d[`CategoryRank${{monthCount}}`] != null)
                .sort((a, b) => (a[`CategoryRank${{monthCount}}`] || 999999) - (b[`CategoryRank${{monthCount}}`] || 999999))
                .slice(0, 10);

            const ctx1 = document.getElementById('rankTrendChart');
            if (window.rankChart) window.rankChart.destroy();

            const datasets = top10.map((row, idx) => {{
                const data = [];
                for (let i = 1; i <= monthCount; i++) {{
                    data.push(row[`CategoryRank${{i}}`] || null);
                }}

                const colors = [
                    '#0071e3', '#00b894', '#ff7675', '#6c5ce7', '#fdcb6e',
                    '#e17055', '#74b9ff', '#a29bfe', '#fd79a8', '#55efc4'
                ];

                return {{
                    label: row.Keyword,
                    data: data,
                    borderColor: colors[idx % colors.length],
                    backgroundColor: colors[idx % colors.length] + '20',
                    tension: 0.3
                }};
            }});

            window.rankChart = new Chart(ctx1, {{
                type: 'line',
                data: {{
                    labels: months,
                    datasets: datasets
                }},
                options: {{
                    responsive: true,
                    plugins: {{
                        title: {{
                            display: true,
                            text: 'Top 10 Keywords - Rank Trend',
                            font: {{ size: 16, weight: '600' }}
                        }},
                        legend: {{
                            position: 'bottom'
                        }}
                    }},
                    scales: {{
                        y: {{
                            reverse: true,
                            title: {{
                                display: true,
                                text: 'Rank (lower is better)'
                            }}
                        }}
                    }}
                }}
            }});

            // Popularity distribution
            const ctx2 = document.getElementById('popularityDistChart');
            if (window.popChart) window.popChart.destroy();

            const currentPops = data
                .filter(d => d[`CategoryPop${{monthCount}}`] != null)
                .map(d => d[`CategoryPop${{monthCount}}`]);

            const bins = [0, 20, 40, 60, 80, 100];
            const binCounts = bins.slice(0, -1).map((bin, i) => {{
                return currentPops.filter(p => p > bin && p <= bins[i + 1]).length;
            }});

            window.popChart = new Chart(ctx2, {{
                type: 'bar',
                data: {{
                    labels: ['0-20', '21-40', '41-60', '61-80', '81-100'],
                    datasets: [{{
                        label: 'Number of Keywords',
                        data: binCounts,
                        backgroundColor: '#0071e3'
                    }}]
                }},
                options: {{
                    responsive: true,
                    plugins: {{
                        title: {{
                            display: true,
                            text: 'Popularity Distribution (Current Month)',
                            font: {{ size: 16, weight: '600' }}
                        }},
                        legend: {{
                            display: false
                        }}
                    }},
                    scales: {{
                        y: {{
                            title: {{
                                display: true,
                                text: 'Number of Keywords'
                            }},
                            beginAtZero: true
                        }},
                        x: {{
                            title: {{
                                display: true,
                                text: 'Popularity Score Range'
                            }}
                        }}
                    }}
                }}
            }});
        }}

        function addSortHandlers(contentId) {{
            const container = document.getElementById(contentId);
            container.querySelectorAll('th.sortable').forEach(th => {{
                th.addEventListener('click', () => {{
                    const column = th.dataset.column;
                    sortTable(column, contentId);
                }});
            }});
        }}

        function sortTable(column, contentId) {{
            const container = document.getElementById(contentId);
            const tbody = container.querySelector('tbody');
            const rows = Array.from(tbody.querySelectorAll('tr'));

            // Toggle direction
            if (currentSort.column === column) {{
                currentSort.direction = currentSort.direction === 'asc' ? 'desc' : 'asc';
            }} else {{
                currentSort.column = column;
                currentSort.direction = 'asc';
            }}

            // Update header indicators
            container.querySelectorAll('th').forEach(th => {{
                th.classList.remove('sort-asc', 'sort-desc');
                if (th.dataset.column === column) {{
                    th.classList.add(`sort-${{currentSort.direction}}`);
                }}
            }});

            // Sort rows
            rows.sort((a, b) => {{
                const aValue = a.querySelector(`td:nth-child(${{getColumnIndex(column, container)}})`).textContent.trim();
                const bValue = b.querySelector(`td:nth-child(${{getColumnIndex(column, container)}})`).textContent.trim();

                const aNum = parseFloat(aValue.replace(/[^0-9.-]/g, ''));
                const bNum = parseFloat(bValue.replace(/[^0-9.-]/g, ''));

                let result = 0;
                if (!isNaN(aNum) && !isNaN(bNum)) {{
                    result = aNum - bNum;
                }} else {{
                    result = aValue.localeCompare(bValue);
                }}

                return currentSort.direction === 'asc' ? result : -result;
            }});

            // Re-append sorted rows
            rows.forEach(row => tbody.appendChild(row));
        }}

        function getColumnIndex(column, container) {{
            const headers = Array.from(container.querySelectorAll('th'));
            return headers.findIndex(th => th.dataset.column === column) + 1;
        }}

        function escapeHtml(text) {{
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }}
    </script>
</body>
</html>"""

    # Write HTML file
    print(f"\nGenerating HTML report: {output_file}")
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(html)

    print(f"✓ Report generated successfully!")
    print(f"  - {len(all_trends)} country/category combinations")
    print(f"  - {len(countries)} countries")
    print(f"  - {len(categories)} categories")
    print(f"  - {len(months)} months")

def main():
    # Find all monthly files
    files = sorted(Path('.').glob('monthly_search_term_rank_*.xlsx'))

    if len(files) < 2:
        print("Error: Need at least 2 monthly rank files to compare.")
        print(f"Found {len(files)} file(s): {[f.name for f in files]}")
        sys.exit(1)

    print(f"Found {len(files)} monthly rank files:")
    for f in files:
        print(f"  - {f.name}")

    # Load and combine data
    print("\nLoading data...")
    combined_df = combine_monthly_data(files)

    print(f"Loaded {len(combined_df)} total records")
    print(f"  - Months: {sorted(combined_df['Month'].unique())}")
    print(f"  - Countries: {len(combined_df['Country'].unique())}")
    print(f"  - Categories: {len(combined_df['Category'].unique())}")
    print(f"  - Keywords: {len(combined_df['Keyword'].unique())}")

    # Generate report
    generate_html_report(combined_df)

    print("\n✓ Done! Open 'keyword_report.html' in your browser.")

if __name__ == '__main__':
    main()
