#!/bin/bash
# Minimal Alacrium rebase helper.
#
# Usage:
#   ./infra/rebase_to.sh 148.0.7778.215 [setup.sh flavour]
#
# This updates version.sh and upstream_version.sh, checks script syntax, runs
# Chromium checkout/sync through version.sh, applies the Alacrium overlay through
# setup.sh, writes the upstream diff report, and stops before any build.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

usage() {
  cat <<'EOF'
Usage: ./infra/rebase_to.sh <chromium-tag> [setup.sh flavour]

Example:
  ./infra/rebase_to.sh 148.0.7778.215
  ./infra/rebase_to.sh 148.0.7778.215 --avx2

The command stops after version/setup/diff checks. It does not build.
EOF
}

die() {
  echo "rebase_to.sh: $*" >&2
  exit 1
}

replace_version() {
  local file="$1"
  local var="$2"
  local tag="$3"

  [ -f "$file" ] || die "missing $file"
  grep -Eq "^${var}=\"[^\"]+\"" "$file" || die "could not find ${var} assignment in $file"

  local tmp
  tmp="$(mktemp)"
  sed -E "s/^(${var}=)\"[^\"]+\"/\1\"${tag}\"/" "$file" > "$tmp"
  chmod --reference="$file" "$tmp"
  mv "$tmp" "$file"
}

TARGET_TAG="${1:-}"
[ -n "$TARGET_TAG" ] || { usage; exit 2; }
case "$TARGET_TAG" in
  -h|--help)
    usage
    exit 0
    ;;
esac
shift

SETUP_FLAVOUR="${1:-}"
[ $# -le 1 ] || die "too many arguments"

CR_SRC_DIR="${ROOT}/chromium/src"
export CR_SRC_DIR

case "$TARGET_TAG" in
  tags/*) TARGET_TAG="${TARGET_TAG#tags/}" ;;
  refs/tags/*) TARGET_TAG="${TARGET_TAG#refs/tags/}" ;;
esac

[[ "$TARGET_TAG" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
  die "expected a Chromium version tag like 148.0.7778.215"

echo "Updating Alacrium rebase target to Chromium $TARGET_TAG"
replace_version version.sh ALACRIUM_VER "$TARGET_TAG"
replace_version upstream_version.sh CR_VER "$TARGET_TAG"

echo "Checking shell syntax"
bash -n version.sh upstream_version.sh setup.sh infra/*.sh

echo "Checking out Chromium tag and syncing dependencies"
./version.sh

echo "Applying Alacrium overlay"
if [ -n "$SETUP_FLAVOUR" ]; then
  ./setup.sh "$SETUP_FLAVOUR"
else
  ./setup.sh
fi

echo "Checking for patch rejects"
if find "$CR_SRC_DIR" -name '*.rej' -print -quit | grep -q .; then
  find "$CR_SRC_DIR" -name '*.rej' -print
  die "patch rejects found"
fi

echo "Writing upstream diff report"
./infra/diff_vs_upstream.sh "$TARGET_TAG"

echo "Rebase prep finished for $TARGET_TAG"
echo "Next step: inspect out/upstream_diff/summary.md, then run ./build_incremental.sh 6 when ready."
