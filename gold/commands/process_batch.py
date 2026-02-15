#!/usr/bin/env python3
"""Process keywords in a batch by running appstore analyze for each."""

import sys
import subprocess
import time
from pathlib import Path
from datetime import datetime
from typing import Optional

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from db.database import transaction, execute_one, execute_query, execute_update


def find_latest_search_id_for_keyword(keyword: str, after_timestamp: str) -> Optional[str]:
    """
    Find the most recent search_id for a keyword after a given timestamp.

    Args:
        keyword: The search keyword
        after_timestamp: ISO timestamp to search after

    Returns:
        search_id or None
    """
    row = execute_one(
        """SELECT id FROM searches
           WHERE keyword = ? AND timestamp > ?
           ORDER BY timestamp DESC
           LIMIT 1""",
        (keyword, after_timestamp)
    )
    return row['id'] if row else None


def update_batch_keyword_status(
    batch_keyword_id: int,
    status: str,
    search_id: Optional[str] = None,
    error_message: Optional[str] = None
):
    """
    Update the status of a batch keyword.

    Args:
        batch_keyword_id: The batch_keyword ID
        status: New status (in_progress/completed/failed)
        search_id: Optional search ID to link
        error_message: Optional error message
    """
    with transaction() as conn:
        if search_id:
            conn.execute(
                """UPDATE batch_keywords
                   SET status = ?, analysis_search_id = ?, processed_at = CURRENT_TIMESTAMP,
                       error_message = ?
                   WHERE id = ?""",
                (status, search_id, error_message, batch_keyword_id)
            )
        else:
            conn.execute(
                """UPDATE batch_keywords
                   SET status = ?, processed_at = CURRENT_TIMESTAMP, error_message = ?
                   WHERE id = ?""",
                (status, error_message, batch_keyword_id)
            )


def update_batch_counters(batch_id: int):
    """
    Update completed_keywords and failed_keywords counts for a batch.

    Args:
        batch_id: The batch ID
    """
    with transaction() as conn:
        # Count completed and failed
        counts = execute_one(
            """SELECT
                   COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed,
                   COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed
               FROM batch_keywords
               WHERE batch_id = ?""",
            (batch_id,)
        )

        completed = counts['completed'] if counts else 0
        failed = counts['failed'] if counts else 0

        # Update batch
        conn.execute(
            """UPDATE keyword_batches
               SET completed_keywords = ?, failed_keywords = ?
               WHERE id = ?""",
            (completed, failed, batch_id)
        )


def update_batch_status(batch_id: int, status: str):
    """
    Update the overall batch status.

    Args:
        batch_id: The batch ID
        status: New status
    """
    execute_update(
        "UPDATE keyword_batches SET status = ? WHERE id = ?",
        (status, batch_id)
    )


def process_batch(
    batch_id: int,
    rate_limit_seconds: float = 2.0,
    verbose: bool = True
) -> tuple:
    """
    Process all keywords in a batch.

    Args:
        batch_id: The batch ID to process
        rate_limit_seconds: Seconds to wait between analyze calls
        verbose: Print progress messages

    Returns:
        (succeeded_count, failed_count)
    """
    # Get batch info
    batch = execute_one(
        """SELECT * FROM keyword_batches WHERE id = ?""",
        (batch_id,)
    )

    if not batch:
        raise ValueError(f"Batch #{batch_id} not found")

    if verbose:
        print(f"Processing batch #{batch_id}", file=sys.stderr)
        print(f"Total keywords: {batch['total_keywords']}", file=sys.stderr)
        print(f"Status: {batch['status']}", file=sys.stderr)
        if batch['notes']:
            print(f"Notes: {batch['notes']}", file=sys.stderr)
        print("", file=sys.stderr)

    # Get pending keywords
    keywords = execute_query(
        """SELECT * FROM batch_keywords
           WHERE batch_id = ? AND status = 'pending'
           ORDER BY id""",
        (batch_id,)
    )

    if not keywords:
        if verbose:
            print("No pending keywords to process", file=sys.stderr)
        return (0, 0)

    # Update batch status to in_progress and record start time
    with transaction() as conn:
        conn.execute(
            """UPDATE keyword_batches
               SET status = ?, started_at = CURRENT_TIMESTAMP
               WHERE id = ?""",
            ('in_progress', batch_id)
        )

    succeeded = 0
    failed = 0
    total = len(keywords)

    for idx, kw in enumerate(keywords, 1):
        keyword_id = kw['id']
        search_term = kw['search_term']
        country = kw['country']

        if verbose:
            print(f"[{idx}/{total}] Analyzing '{search_term}'...", end=" ", file=sys.stderr, flush=True)

        # Mark as in_progress
        update_batch_keyword_status(keyword_id, 'in_progress')

        # Record timestamp before running analyze
        before_timestamp = datetime.now().isoformat()

        # Run appstore analyze
        try:
            # Run the appstore analyze command
            result = subprocess.run(
                ['appstore', 'analyze', search_term],
                capture_output=True,
                text=True,
                timeout=60
            )

            # Give database a moment to update
            time.sleep(0.5)

            # Try to find the search_id that was just created
            search_id = find_latest_search_id_for_keyword(search_term, before_timestamp)

            if result.returncode == 0:
                if search_id:
                    if verbose:
                        print(f"✓ (search_id: {search_id})", file=sys.stderr)
                    update_batch_keyword_status(keyword_id, 'completed', search_id=search_id)
                    succeeded += 1
                else:
                    if verbose:
                        print("✓ (no search_id found)", file=sys.stderr)
                    update_batch_keyword_status(
                        keyword_id,
                        'completed',
                        error_message='No apps found in App Store for this keyword'
                    )
                    succeeded += 1
            else:
                error_msg = result.stderr[:200] if result.stderr else "Unknown error"
                if verbose:
                    print(f"✗ {error_msg}", file=sys.stderr)
                update_batch_keyword_status(keyword_id, 'failed', error_message=error_msg)
                failed += 1

        except subprocess.TimeoutExpired:
            if verbose:
                print("✗ Timeout", file=sys.stderr)
            update_batch_keyword_status(keyword_id, 'failed', error_message="Timeout after 60 seconds")
            failed += 1

        except Exception as e:
            if verbose:
                print(f"✗ {str(e)}", file=sys.stderr)
            update_batch_keyword_status(keyword_id, 'failed', error_message=str(e))
            failed += 1

        # Update batch counters
        update_batch_counters(batch_id)

        # Rate limiting between requests
        if idx < total and rate_limit_seconds > 0:
            time.sleep(rate_limit_seconds)

    # Update final batch status with completion time and duration
    final_status = 'completed' if failed == 0 else ('failed' if succeeded == 0 else 'completed')
    with transaction() as conn:
        conn.execute(
            """UPDATE keyword_batches
               SET status = ?,
                   completed_at = CURRENT_TIMESTAMP,
                   duration_seconds = CAST((julianday(CURRENT_TIMESTAMP) - julianday(started_at)) * 86400 AS INTEGER)
               WHERE id = ?""",
            (final_status, batch_id)
        )

    if verbose:
        print("", file=sys.stderr)
        print("="*80, file=sys.stderr)
        print(f"Batch #{batch_id} complete!", file=sys.stderr)
        print(f"  ✓ Succeeded: {succeeded}", file=sys.stderr)
        print(f"  ✗ Failed: {failed}", file=sys.stderr)
        print("="*80, file=sys.stderr)

    return (succeeded, failed)


def main():
    """Command-line interface for batch processing."""
    import argparse

    parser = argparse.ArgumentParser(description="Process keywords in a batch")
    parser.add_argument('batch_id', type=int, help='Batch ID to process')
    parser.add_argument(
        '--rate-limit',
        type=float,
        default=2.0,
        help='Seconds to wait between analyze calls (default: 2.0)'
    )
    parser.add_argument(
        '-q', '--quiet',
        action='store_true',
        help='Suppress progress output'
    )

    args = parser.parse_args()

    try:
        succeeded, failed = process_batch(
            args.batch_id,
            rate_limit_seconds=args.rate_limit,
            verbose=not args.quiet
        )

        # Exit code: 0 if all succeeded, 1 if any failed
        sys.exit(0 if failed == 0 else 1)

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
