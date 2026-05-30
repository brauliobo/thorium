#!/bin/bash
# Fast pre-PR checks for Thorium Chromium rebases.
#
# Default mode is local-only and cheap. Pass --with-upstream to also run
# infra/diff_vs_upstream.sh against the pinned/current target Chromium tag.

set -euo pipefail

cd "$(dirname "$0")/.."

WITH_UPSTREAM=0
TARGET_TAG=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --with-upstream)
      WITH_UPSTREAM=1
      ;;
    --target)
      shift
      [ "$#" -gt 0 ] || { echo "--target needs a Chromium tag" >&2; exit 2; }
      TARGET_TAG="$1"
      ;;
    --help|-h)
      echo "Usage: $0 [--with-upstream] [--target <chromium-tag>]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
  shift
done

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

echo "Checking shell syntax..."
bash -n trunk.sh version.sh upstream_version.sh setup.sh build_incremental.sh infra/*.sh

echo "Checking Python helper syntax..."
python3 -m py_compile \
  infra/extract_new_files_from_patch.py \
  infra/extract_thorium_xtb.py \
  infra/merge_thorium_xtb.py \
  infra/strip_dead_gn.py \
  infra/trim_hevc_patch.py

echo "Checking for local scratch files..."
[ ! -e .claude ] || fail ".claude/ must not be committed"
[ -z "$(find . -path '*/_incompat/*' -print -quit)" ] || fail "_incompat scratch files remain"
[ -z "$(find . -name '*.needs-port' -o -name '*.disabled' -print -quit)" ] || fail "deferred patch scratch files remain"

echo "Checking git whitespace outside patch payloads..."
git diff --check -- ':!other/*.patch'

if [ "$WITH_UPSTREAM" -eq 1 ]; then
  echo "Checking overlay and patch applicability against Chromium..."
  if [ -n "$TARGET_TAG" ]; then
    infra/diff_vs_upstream.sh "$TARGET_TAG"
  else
    infra/diff_vs_upstream.sh
  fi

  if find out/upstream_diff/patch_status -name '*.rc' -exec sh -c '
      for rc_file do
        [ "$(cat "$rc_file")" = 0 ] || exit 1
      done
    ' sh {} +; then
    :
  else
    fail "one or more patches failed; see out/upstream_diff/patch_status"
  fi
fi

echo "OK"
