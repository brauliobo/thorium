#!/usr/bin/env python3
"""Regression check for pathological Chromium History duplicate scans.

This test intentionally uses a local copy of a real History DB and never stores
that DB in git. Set THORIUM_HISTORY_DB_COPY to the copied History file.

The legacy Chromium query streams every visible visit then deduplicates in C++.
With auto-refresh URLs this can mean hundreds of thousands of rows for a few
thousand final results. The fixed query deduplicates in SQLite first.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import os
import sqlite3
import sys
import time


VISIBLE_SQL = """
  (visits.transition & 536870912) != 0
  AND (visits.transition & 255) NOT IN (3, 4, 10)
"""


def legacy_scan_count(db_path: str) -> tuple[int, int, float]:
    query = f"""
      SELECT visits.id, visits.url, visits.visit_time, visits.transition
      FROM visits
      LEFT OUTER JOIN context_annotations
        ON visits.id = context_annotations.visit_id
      WHERE (context_annotations.response_code IS NULL
             OR context_annotations.response_code != 404)
        AND visits.visit_time >= 0
        AND visits.visit_time < 9223372036854775807
      ORDER BY visits.visit_time DESC, visits.id DESC
    """

    started = time.monotonic()
    scanned = 0
    seen_urls: set[int] = set()
    with sqlite3.connect(f"file:{db_path}?mode=ro", uri=True) as db:
      for _, url_id, _, transition in db.execute(query):
        scanned += 1
        if not ((transition & 536870912) and ((transition & 255) not in (3, 4, 10))):
          continue
        seen_urls.add(url_id)
    return scanned, len(seen_urls), time.monotonic() - started


def optimized_count(db_path: str) -> tuple[int, float]:
    query = f"""
      SELECT COUNT(*)
      FROM (
        SELECT visits.id,
               ROW_NUMBER() OVER (
                 PARTITION BY visits.url
                 ORDER BY visits.visit_time DESC, visits.id DESC
               ) AS thorium_url_rank
        FROM visits
        LEFT OUTER JOIN context_annotations
          ON visits.id = context_annotations.visit_id
        WHERE (context_annotations.response_code IS NULL
               OR context_annotations.response_code != 404)
          AND visits.visit_time >= 0
          AND visits.visit_time < 9223372036854775807
          AND {VISIBLE_SQL}
      )
      WHERE thorium_url_rank = 1
    """

    started = time.monotonic()
    with sqlite3.connect(f"file:{db_path}?mode=ro", uri=True) as db:
      count = db.execute(query).fetchone()[0]
    return count, time.monotonic() - started


def check_db(db_path: str, args: argparse.Namespace) -> int:
    print(f"db={db_path}")
    scanned, legacy_results, legacy_elapsed = legacy_scan_count(db_path)
    optimized_results, optimized_elapsed = optimized_count(db_path)

    print(f"legacy_scanned={scanned}")
    print(f"legacy_results={legacy_results}")
    print(f"legacy_elapsed={legacy_elapsed:.3f}s")
    print(f"optimized_results={optimized_results}")
    print(f"optimized_elapsed={optimized_elapsed:.3f}s")

    if legacy_results != optimized_results:
      print("optimized result count does not match legacy dedupe", file=sys.stderr)
      return 1

    scan_ratio = scanned / max(optimized_results, 1)
    print(f"scan_ratio={scan_ratio:.2f}")

    if args.legacy and scan_ratio > args.max_scan_ratio:
      print(
          f"legacy query scans {scan_ratio:.2f}x more rows than final results",
          file=sys.stderr,
      )
      return 1

    if not args.legacy and not args.allow_non_pathological:
      if scan_ratio <= args.max_scan_ratio:
        print("fixture is not pathological enough to exercise the regression", file=sys.stderr)
        return 1

    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--db",
        default=os.environ.get("THORIUM_HISTORY_DB_COPY"),
        help="path to copied Chromium/Thorium History DB",
    )
    parser.add_argument(
        "--legacy",
        action="store_true",
        help="assert the old row-streaming behavior; expected to fail on the reproduced DB",
    )
    parser.add_argument(
        "--profile-dir",
        help="directory containing Chromium/Thorium profile subdirectories",
    )
    parser.add_argument(
        "--allow-non-pathological",
        action="store_true",
        help="allow DBs that do not exceed --max-scan-ratio",
    )
    parser.add_argument("--max-scan-ratio", type=float, default=3.0)
    args = parser.parse_args()

    db_paths: list[str] = []
    if args.profile_dir:
      db_paths.extend(str(p) for p in Path(args.profile_dir).glob("*/History"))
    if args.db:
      db_paths.append(args.db)

    if not db_paths:
      print("Set THORIUM_HISTORY_DB_COPY or pass --db", file=sys.stderr)
      return 2

    result = 0
    for db_path in db_paths:
      if not os.path.exists(db_path):
        print(f"History DB copy does not exist: {db_path}", file=sys.stderr)
        result = 2
        continue
      result = max(result, check_db(db_path, args))
    return result


if __name__ == "__main__":
    raise SystemExit(main())
