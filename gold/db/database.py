"""Database connection and utility functions."""

import sqlite3
from pathlib import Path
from contextlib import contextmanager
from typing import Optional, List, Dict, Any


def get_db_path() -> Path:
    """Get the path to the analytics database."""
    home = Path.home()
    db_dir = home / ".appstore"
    db_dir.mkdir(exist_ok=True)
    return db_dir / "analytics.db"


def get_db_connection() -> sqlite3.Connection:
    """
    Get a connection to the analytics database.

    Returns:
        sqlite3.Connection with row_factory set to sqlite3.Row
    """
    db_path = get_db_path()
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row

    # Enable foreign keys
    conn.execute("PRAGMA foreign_keys = ON")

    return conn


@contextmanager
def transaction():
    """
    Context manager for database transactions.

    Usage:
        with transaction() as conn:
            conn.execute("INSERT INTO ...")
            conn.execute("UPDATE ...")
    """
    conn = get_db_connection()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def execute_query(query: str, params: tuple = ()) -> List[sqlite3.Row]:
    """
    Execute a SELECT query and return all results.

    Args:
        query: SQL query string
        params: Query parameters

    Returns:
        List of Row objects
    """
    with get_db_connection() as conn:
        cursor = conn.execute(query, params)
        return cursor.fetchall()


def execute_one(query: str, params: tuple = ()) -> Optional[sqlite3.Row]:
    """
    Execute a SELECT query and return one result.

    Args:
        query: SQL query string
        params: Query parameters

    Returns:
        Single Row object or None
    """
    with get_db_connection() as conn:
        cursor = conn.execute(query, params)
        return cursor.fetchone()


def execute_update(query: str, params: tuple = ()) -> int:
    """
    Execute an INSERT/UPDATE/DELETE query.

    Args:
        query: SQL query string
        params: Query parameters

    Returns:
        Number of affected rows
    """
    with transaction() as conn:
        cursor = conn.execute(query, params)
        return cursor.rowcount


def execute_insert(query: str, params: tuple = ()) -> int:
    """
    Execute an INSERT query and return the new row ID.

    Args:
        query: SQL query string
        params: Query parameters

    Returns:
        ID of the inserted row
    """
    with transaction() as conn:
        cursor = conn.execute(query, params)
        return cursor.lastrowid


def execute_many(query: str, params_list: List[tuple]) -> int:
    """
    Execute many INSERT/UPDATE statements in a single transaction.

    Args:
        query: SQL query string
        params_list: List of parameter tuples

    Returns:
        Number of affected rows
    """
    with transaction() as conn:
        cursor = conn.executemany(query, params_list)
        return cursor.rowcount


def row_to_dict(row: sqlite3.Row) -> Dict[str, Any]:
    """Convert a Row object to a dictionary."""
    return dict(row) if row else {}


def rows_to_dicts(rows: List[sqlite3.Row]) -> List[Dict[str, Any]]:
    """Convert a list of Row objects to dictionaries."""
    return [dict(row) for row in rows]
