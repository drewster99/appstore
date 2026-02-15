#!/usr/bin/env python3
"""Batch management for keyword processing."""

import sys
import json
from pathlib import Path
from datetime import datetime
from typing import Optional

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from db.database import transaction, execute_one, execute_query, execute_insert


def create_batch_from_json(
    json_path: Path,
    notes: Optional[str] = None,
    verbose: bool = True
) -> int:
    """
    Create a batch from selected_keywords.json file.

    Args:
        json_path: Path to the selected keywords JSON file
        notes: Optional notes about this batch
        verbose: Print progress messages

    Returns:
        Batch ID
    """
    if not json_path.exists():
        raise FileNotFoundError(f"File not found: {json_path}")

    # Load selected keywords
    with open(json_path) as f:
        keywords = json.load(f)

    if not keywords:
        raise ValueError("No keywords found in JSON file")

    if verbose:
        print(f"Loaded {len(keywords)} keywords from {json_path.name}", file=sys.stderr)

    # Get the first keyword to determine report details
    first_kw = keywords[0]
    month = first_kw.get('month')
    country = first_kw.get('country')

    if not month or not country:
        raise ValueError("Keywords must have 'month' and 'country' fields")

    if verbose:
        print(f"  Month: {month}", file=sys.stderr)
        print(f"  Country: {country}", file=sys.stderr)

    # Find the report ID for this month/country
    report = execute_one(
        """SELECT ar.*
           FROM apple_reports ar
           JOIN apple_keywords ak ON ar.id = ak.report_id
           WHERE ar.data_month = ? AND ak.country = ? AND ar.is_active = 1
           LIMIT 1""",
        (month, country)
    )

    if not report:
        raise ValueError(
            f"No active report found for month={month}, country={country}. "
            f"Import a report first."
        )

    report_id = report['id']

    if verbose:
        print(f"  Using report ID: {report_id} ({report['report_id']})", file=sys.stderr)

    # Create batch and batch keywords in a transaction
    with transaction() as conn:
        # Create batch
        cursor = conn.execute(
            """INSERT INTO keyword_batches
               (report_id, status, total_keywords, notes)
               VALUES (?, 'pending', ?, ?)""",
            (report_id, len(keywords), notes)
        )
        batch_id = cursor.lastrowid

        # Find keyword IDs and create batch_keywords entries
        batch_keywords = []
        found_count = 0

        for kw in keywords:
            search_term = kw['search_term']
            genre = kw['genre']

            # Find the keyword ID in apple_keywords
            kw_row = execute_one(
                """SELECT id FROM apple_keywords
                   WHERE report_id = ? AND country = ?
                     AND search_term = ? AND genre = ?
                   LIMIT 1""",
                (report_id, country, search_term, genre)
            )

            if kw_row:
                found_count += 1
                batch_keywords.append((
                    batch_id,
                    kw_row['id'],
                    search_term,
                    country,
                    genre
                ))
            else:
                if verbose:
                    print(f"  Warning: Keyword not found in database: {search_term} ({genre})",
                          file=sys.stderr)

        if not batch_keywords:
            raise ValueError("None of the keywords were found in the database")

        # Insert batch keywords
        conn.executemany(
            """INSERT INTO batch_keywords
               (batch_id, keyword_id, search_term, country, genre, status)
               VALUES (?, ?, ?, ?, ?, 'pending')""",
            batch_keywords
        )

        # Update total_keywords to reflect actual count
        conn.execute(
            "UPDATE keyword_batches SET total_keywords = ? WHERE id = ?",
            (len(batch_keywords), batch_id)
        )

    if verbose:
        print(f"\n✓ Created batch #{batch_id} with {len(batch_keywords)} keywords", file=sys.stderr)
        if found_count < len(keywords):
            print(f"  Warning: {len(keywords) - found_count} keywords not found in database",
                  file=sys.stderr)

    return batch_id


def list_batches(limit: int = 20, status_filter: Optional[str] = None, verbose: bool = True):
    """
    List keyword batches.

    Args:
        limit: Maximum number of batches to show
        status_filter: Filter by status (pending/in_progress/completed/failed)
        verbose: Print formatted output
    """
    query = """
        SELECT
            kb.id,
            kb.created_at,
            kb.status,
            kb.total_keywords,
            kb.completed_keywords,
            kb.failed_keywords,
            kb.notes,
            ar.report_id,
            ar.data_month,
            ar.user_locale
        FROM keyword_batches kb
        JOIN apple_reports ar ON kb.report_id = ar.id
    """

    params = []
    if status_filter:
        query += " WHERE kb.status = ?"
        params.append(status_filter)

    query += " ORDER BY kb.created_at DESC LIMIT ?"
    params.append(limit)

    batches = execute_query(query, tuple(params))

    if not batches:
        if verbose:
            print("No batches found", file=sys.stderr)
        return

    if verbose:
        # Print header
        print(f"\n{'ID':<6} {'Created':<20} {'Status':<12} {'Keywords':<12} {'Progress':<15} {'Report':<20}",
              file=sys.stderr)
        print("-" * 100, file=sys.stderr)

        for batch in batches:
            batch_id = batch['id']
            created = batch['created_at'][:19] if batch['created_at'] else 'Unknown'
            status = batch['status']
            total = batch['total_keywords']
            completed = batch['completed_keywords']
            failed = batch['failed_keywords']
            report_info = f"{batch['data_month']} {batch['user_locale'][:5]}"

            # Format progress
            if status == 'pending':
                progress = f"0/{total}"
            elif status == 'in_progress':
                progress = f"{completed + failed}/{total}"
            elif status == 'completed':
                if failed > 0:
                    progress = f"✓ {completed} (✗ {failed})"
                else:
                    progress = f"✓ {completed}"
            else:
                progress = f"✗ {failed}/{total}"

            # Color-code status (simple text markers)
            status_display = {
                'pending': '⋯ pending',
                'in_progress': '▶ in progress',
                'completed': '✓ completed',
                'failed': '✗ failed'
            }.get(status, status)

            print(f"{batch_id:<6} {created:<20} {status_display:<12} {total:<12} {progress:<15} {report_info:<20}",
                  file=sys.stderr)

            if batch['notes']:
                print(f"       Notes: {batch['notes']}", file=sys.stderr)

        print("-" * 100, file=sys.stderr)
        print(f"Showing {len(batches)} batch(es)", file=sys.stderr)


def get_batch_status(batch_id: int, verbose: bool = True):
    """
    Show detailed status for a specific batch.

    Args:
        batch_id: The batch ID
        verbose: Print formatted output
    """
    # Get batch info
    batch = execute_one(
        """SELECT kb.*, ar.report_id, ar.data_month, ar.user_locale
           FROM keyword_batches kb
           JOIN apple_reports ar ON kb.report_id = ar.id
           WHERE kb.id = ?""",
        (batch_id,)
    )

    if not batch:
        print(f"Batch #{batch_id} not found", file=sys.stderr)
        return

    # Get batch keywords
    keywords = execute_query(
        """SELECT *
           FROM batch_keywords
           WHERE batch_id = ?
           ORDER BY
               CASE status
                   WHEN 'failed' THEN 1
                   WHEN 'in_progress' THEN 2
                   WHEN 'pending' THEN 3
                   WHEN 'completed' THEN 4
               END,
               id""",
        (batch_id,)
    )

    if verbose:
        print(f"\n{'='*80}", file=sys.stderr)
        print(f"Batch #{batch_id}", file=sys.stderr)
        print(f"{'='*80}", file=sys.stderr)
        print(f"Created: {batch['created_at']}", file=sys.stderr)
        print(f"Status: {batch['status']}", file=sys.stderr)
        print(f"Report: {batch['data_month']} ({batch['user_locale']})", file=sys.stderr)
        print(f"Total Keywords: {batch['total_keywords']}", file=sys.stderr)
        print(f"Completed: {batch['completed_keywords']}", file=sys.stderr)
        print(f"Failed: {batch['failed_keywords']}", file=sys.stderr)
        print(f"Pending: {batch['total_keywords'] - batch['completed_keywords'] - batch['failed_keywords']}",
              file=sys.stderr)

        if batch['notes']:
            print(f"Notes: {batch['notes']}", file=sys.stderr)

        print(f"\n{'Status':<12} {'Keyword':<40} {'Genre':<20}", file=sys.stderr)
        print("-" * 80, file=sys.stderr)

        for kw in keywords:
            status_symbol = {
                'pending': '⋯',
                'in_progress': '▶',
                'completed': '✓',
                'failed': '✗'
            }.get(kw['status'], '?')

            status_display = f"{status_symbol} {kw['status']}"
            keyword = kw['search_term'][:38]
            genre = kw['genre'][:18]

            print(f"{status_display:<12} {keyword:<40} {genre:<20}", file=sys.stderr)

            if kw['error_message']:
                print(f"             Error: {kw['error_message']}", file=sys.stderr)

        print("-" * 80, file=sys.stderr)


def main():
    """Command-line interface for batch management."""
    import argparse

    parser = argparse.ArgumentParser(description="Manage keyword processing batches")
    subparsers = parser.add_subparsers(dest='command', help='Command to execute')

    # create command
    create_parser = subparsers.add_parser('create', help='Create a new batch from selected keywords JSON')
    create_parser.add_argument('json_file', help='Path to selected_keywords.json')
    create_parser.add_argument('--notes', help='Optional notes about this batch')

    # list command
    list_parser = subparsers.add_parser('list', help='List all batches')
    list_parser.add_argument('--limit', type=int, default=20, help='Maximum batches to show (default: 20)')
    list_parser.add_argument('--status', choices=['pending', 'in_progress', 'completed', 'failed'],
                             help='Filter by status')

    # status command
    status_parser = subparsers.add_parser('status', help='Show detailed status for a batch')
    status_parser.add_argument('batch_id', type=int, help='Batch ID')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    try:
        if args.command == 'create':
            json_path = Path(args.json_file)
            batch_id = create_batch_from_json(json_path, notes=args.notes)
            print(f"\nRun: python3 commands/process_batch.py {batch_id}", file=sys.stderr)

        elif args.command == 'list':
            list_batches(limit=args.limit, status_filter=args.status)

        elif args.command == 'status':
            get_batch_status(args.batch_id)

        sys.exit(0)

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
