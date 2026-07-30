#!/usr/bin/env python3
"""Repair pathological self-refresh chains in a Chromium History database."""

from __future__ import annotations

import argparse
import datetime as dt
from pathlib import Path
import shutil
import sqlite3
import sys


CHAIN_START = 0x10000000
CLIENT_REDIRECT = 0x40000000

CANDIDATES_SQL = """
  SELECT child.url, urls.url, COUNT(*) AS links
  FROM visits AS child
  JOIN visits AS parent ON parent.id = child.from_visit
  JOIN urls ON urls.id = child.url
  WHERE {local_visit_filter}child.url = parent.url
    AND child.visit_time != parent.visit_time
    AND (child.transition & ?) != 0
    AND (child.transition & ?) = 0
  GROUP BY child.url, urls.url
  HAVING COUNT(*) >= ?
  ORDER BY links DESC
"""

UPDATE_SQL = """
  WITH pathological_urls AS (
    SELECT child.url
    FROM visits AS child
    JOIN visits AS parent ON parent.id = child.from_visit
    WHERE {local_visit_filter}child.url = parent.url
      AND child.visit_time != parent.visit_time
      AND (child.transition & ?) != 0
      AND (child.transition & ?) = 0
    GROUP BY child.url
    HAVING COUNT(*) >= ?
  )
  UPDATE visits
  SET transition = transition | ?
  WHERE id IN (
    SELECT child.id
    FROM visits AS child
    JOIN visits AS parent ON parent.id = child.from_visit
    JOIN pathological_urls ON pathological_urls.url = child.url
    WHERE {local_visit_filter}child.url = parent.url
      AND child.visit_time != parent.visit_time
      AND (child.transition & ?) != 0
      AND (child.transition & ?) = 0
  )
"""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("database", type=Path, help="path to a profile History file")
    parser.add_argument(
        "--minimum-links",
        type=int,
        default=100,
        help="minimum repeated self-refresh links per URL (default: 100)",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="apply the repair; otherwise only report candidates",
    )
    parser.add_argument(
        "--backup",
        type=Path,
        help="backup path (default: History.backup-YYYYmmdd-HHMMSS)",
    )
    return parser.parse_args()


def check_database(db: sqlite3.Connection) -> None:
    problems = [row[0] for row in db.execute("PRAGMA quick_check") if row[0] != "ok"]
    if problems:
        raise RuntimeError("database quick_check failed: " + "; ".join(problems))


def local_visit_filter(db: sqlite3.Connection) -> str:
    columns = {row[1] for row in db.execute("PRAGMA table_info(visits)")}
    if "originator_cache_guid" in columns:
        return "child.originator_cache_guid = '' AND "
    return ""


def main() -> int:
    args = parse_args()
    if args.minimum_links < 1:
        print("--minimum-links must be positive", file=sys.stderr)
        return 2
    if not args.database.is_file():
        print(f"History database not found: {args.database}", file=sys.stderr)
        return 2

    db = sqlite3.connect(args.database, timeout=0)
    try:
        db.execute("PRAGMA busy_timeout=0")
        try:
            db.execute("BEGIN EXCLUSIVE")
        except sqlite3.OperationalError as error:
            raise RuntimeError(
                "database is in use; close Thorium completely before running this tool"
            ) from error

        check_database(db)
        query_filter = local_visit_filter(db)
        candidates = list(
            db.execute(
                CANDIDATES_SQL.format(local_visit_filter=query_filter),
                (CLIENT_REDIRECT, CHAIN_START, args.minimum_links),
            )
        )
        if not candidates:
            print("No pathological self-refresh chains found.")
            db.rollback()
            return 0

        print("Pathological self-refresh chains:")
        for url_id, url, links in candidates:
            print(f"  links={links:>8} url_id={url_id:<8} {url}")

        if not args.apply:
            print("Dry run only. Re-run with --apply after reviewing the URLs.")
            db.rollback()
            return 0

        timestamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
        backup = args.backup or args.database.with_name(
            f"{args.database.name}.backup-{timestamp}"
        )
        if backup.exists():
            raise RuntimeError(f"backup already exists: {backup}")
        shutil.copy2(args.database, backup)
        print(f"Backup: {backup}")

        db.execute(
            UPDATE_SQL.format(local_visit_filter=query_filter),
            (
                CLIENT_REDIRECT,
                CHAIN_START,
                args.minimum_links,
                CHAIN_START,
                CLIENT_REDIRECT,
                CHAIN_START,
            ),
        )
        changed = db.execute("SELECT changes()").fetchone()[0]
        check_database(db)
        db.commit()
        print(f"Repaired {changed} visits.")
        return 0
    except (RuntimeError, sqlite3.DatabaseError, OSError) as error:
        db.rollback()
        print(f"error: {error}", file=sys.stderr)
        return 1
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
