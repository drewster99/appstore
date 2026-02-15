"""Database migration runner."""

import sys
from pathlib import Path
from typing import List
from .database import get_db_connection, transaction


def get_migrations_dir() -> Path:
    """Get the directory containing migration files."""
    # Migrations are in migrations/ relative to this script's parent
    script_dir = Path(__file__).parent.parent
    return script_dir / "migrations"


def create_migrations_table():
    """Create the migrations tracking table if it doesn't exist."""
    with transaction() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS schema_migrations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                migration_name TEXT NOT NULL UNIQUE,
                applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """)


def get_applied_migrations() -> List[str]:
    """Get list of already-applied migration names."""
    with get_db_connection() as conn:
        cursor = conn.execute(
            "SELECT migration_name FROM schema_migrations ORDER BY id"
        )
        return [row[0] for row in cursor.fetchall()]


def get_pending_migrations() -> List[Path]:
    """Get list of migration files that haven't been applied yet."""
    migrations_dir = get_migrations_dir()

    if not migrations_dir.exists():
        return []

    # Get all .sql files
    all_migrations = sorted(migrations_dir.glob("*.sql"))

    # Get applied migrations
    applied = set(get_applied_migrations())

    # Filter to only pending
    pending = [m for m in all_migrations if m.name not in applied]

    return pending


def apply_migration(migration_path: Path) -> bool:
    """
    Apply a single migration file.

    Args:
        migration_path: Path to the .sql migration file

    Returns:
        True if successful, False otherwise
    """
    migration_name = migration_path.name

    print(f"Applying migration: {migration_name}", file=sys.stderr)

    try:
        # Read the migration SQL
        sql = migration_path.read_text()

        # Execute in a transaction
        with transaction() as conn:
            # Execute the migration SQL
            conn.executescript(sql)

            # Record that we've applied this migration
            conn.execute(
                "INSERT INTO schema_migrations (migration_name) VALUES (?)",
                (migration_name,)
            )

        print(f"  ✓ Successfully applied {migration_name}", file=sys.stderr)
        return True

    except Exception as e:
        print(f"  ✗ Error applying {migration_name}: {e}", file=sys.stderr)
        return False


def run_migrations(verbose: bool = True) -> int:
    """
    Run all pending migrations.

    Args:
        verbose: Print status messages

    Returns:
        Number of migrations applied
    """
    # Ensure migrations table exists
    create_migrations_table()

    # Get pending migrations
    pending = get_pending_migrations()

    if not pending:
        if verbose:
            print("No pending migrations", file=sys.stderr)
        return 0

    if verbose:
        print(f"Found {len(pending)} pending migration(s)", file=sys.stderr)

    # Apply each migration
    applied_count = 0
    for migration_path in pending:
        if apply_migration(migration_path):
            applied_count += 1
        else:
            print(f"Migration failed, stopping here", file=sys.stderr)
            break

    if verbose:
        print(f"\nApplied {applied_count} migration(s)", file=sys.stderr)

    return applied_count


def list_migrations(verbose: bool = True):
    """List all migrations and their status."""
    create_migrations_table()

    migrations_dir = get_migrations_dir()
    if not migrations_dir.exists():
        print("No migrations directory found", file=sys.stderr)
        return

    all_migrations = sorted(migrations_dir.glob("*.sql"))
    applied = set(get_applied_migrations())

    if verbose:
        print("Migration Status:", file=sys.stderr)
        print("-" * 60, file=sys.stderr)

    for migration_path in all_migrations:
        name = migration_path.name
        status = "✓ Applied" if name in applied else "  Pending"
        if verbose:
            print(f"{status}  {name}", file=sys.stderr)

    if verbose:
        print("-" * 60, file=sys.stderr)
        print(f"Total: {len(all_migrations)} migrations, "
              f"{len(applied)} applied, {len(all_migrations) - len(applied)} pending",
              file=sys.stderr)


def main():
    """Command-line interface for migrations."""
    import argparse

    parser = argparse.ArgumentParser(description="Database migration runner")
    parser.add_argument(
        "command",
        choices=["run", "list"],
        help="Command to execute"
    )
    parser.add_argument(
        "-q", "--quiet",
        action="store_true",
        help="Suppress output"
    )

    args = parser.parse_args()

    verbose = not args.quiet

    if args.command == "run":
        count = run_migrations(verbose=verbose)
        sys.exit(0 if count >= 0 else 1)
    elif args.command == "list":
        list_migrations(verbose=verbose)
        sys.exit(0)


if __name__ == "__main__":
    main()
