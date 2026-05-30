#!/bin/bash
# Compare Thorium's src/ overlay against an upstream Chromium checkout.
#
# Prereqs: run ./trunk.sh first so $CR_SRC_DIR holds a Chromium checkout
# (defaults to $HOME/chromium/src). Pass a different tag as $1 to compare
# the overlay against a target rebase tag instead of the current THOR_VER.
#
# Output: out/upstream_diff/
#   inventory.tsv   status per overlay file (NEW|MOD|SAME|MISSING_UPSTREAM)
#   summary.md      per-area counts
#   diffs/<path>    one unified diff per modified file
#   patch_status/   `git apply --check` result for every patch in other/

set -euo pipefail
cd "$(dirname "$0")/.."
THOR_ROOT="$PWD"

CR_SRC_DIR="${CR_DIR:-${CR_SRC_DIR:-$HOME/chromium/src}}"
TARGET_TAG="${1:-$(awk -F\" '/^THOR_VER=/{print $2}' version.sh)}"

[ -d "$CR_SRC_DIR/.git" ] || { echo "No chromium checkout at $CR_SRC_DIR — run ./trunk.sh first." >&2; exit 1; }

OUT="$THOR_ROOT/out/upstream_diff"
rm -rf "$OUT" && mkdir -p "$OUT/diffs" "$OUT/patch_status"

echo "Comparing overlay against chromium tag: $TARGET_TAG"
( cd "$CR_SRC_DIR" && git fetch --tags --depth=1 origin "refs/tags/$TARGET_TAG:refs/tags/$TARGET_TAG" 2>/dev/null || true )
( cd "$CR_SRC_DIR" && git checkout -q "tags/$TARGET_TAG" ) || { echo "tag not found locally; pre-fetch $TARGET_TAG" >&2; exit 1; }

: > "$OUT/inventory.tsv"
while IFS= read -r rel; do
  sub="${rel#src/}"
  up="$CR_SRC_DIR/$sub"
  if [ ! -e "$up" ]; then
    status=NEW
  elif cmp -s "$rel" "$up"; then
    status=SAME
  else
    status=MOD
    mkdir -p "$OUT/diffs/$(dirname "$sub")"
    diff -u "$up" "$rel" > "$OUT/diffs/$sub.diff" || true
  fi
  printf '%s\t%s\n' "$status" "$sub" >> "$OUT/inventory.tsv"
done < <(find src -type f | sort)

awk -F'\t' '{n[$1]++} END{for (k in n) print k, n[k]}' "$OUT/inventory.tsv" > "$OUT/summary.counts"

check_patch() {
  local patch_dir="$1"
  local patch_file="$2"
  local name
  name=$(basename "$patch_file")
  if ( cd "$patch_dir" && git apply --check --reject --recount "$THOR_ROOT/$patch_file" ) \
      2> "$OUT/patch_status/$name.err"; then
    echo 0 > "$OUT/patch_status/$name.rc"
  else
    local rc=$?
    echo "$rc" > "$OUT/patch_status/$name.rc"
  fi
}

is_special_patch() {
  case "$1" in
    other/add-hevc-ffmpeg-decoder-parser.patch|\
    other/change-libavcodec-header.patch|\
    other/ffmpeg_hevc_ac3.patch|\
    other/v8-simd-buildflags.patch)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Patch applicability against the target tag.
for p in other/*.patch; do
  [ -f "$p" ] || continue
  is_special_patch "$p" && continue
  check_patch "$CR_SRC_DIR" "$p"
done

# ffmpeg patches apply inside third_party/ffmpeg.
for p in other/add-hevc-ffmpeg-decoder-parser.patch other/change-libavcodec-header.patch other/ffmpeg_hevc_ac3.patch; do
  [ -f "$p" ] || continue
  check_patch "$CR_SRC_DIR/third_party/ffmpeg" "$p"
done

# V8 is a nested checkout.
[ -f other/v8-simd-buildflags.patch ] && check_patch "$CR_SRC_DIR/v8" "other/v8-simd-buildflags.patch"

{
  echo "# Upstream diff summary — $TARGET_TAG"
  echo
  echo "## Overlay file status"
  awk -F'\t' '{n[$1]++} END{for (k in n) printf "- %s: %d\n", k, n[k]}' "$OUT/inventory.tsv"
  echo
  echo "## Per-area modification counts"
  awk -F'\t' '$1=="MOD"{split($2,a,"/"); c[a[1]]++} END{for (k in c) printf "- %s: %d\n", k, c[k]}' "$OUT/inventory.tsv" | sort
  echo
  echo "## Patch applicability"
  for f in "$OUT/patch_status"/*.rc; do
    rc=$(cat "$f"); name=$(basename "$f" .rc)
    [ "$rc" = 0 ] && echo "- OK   $name" || echo "- FAIL $name"
  done
} > "$OUT/summary.md"

echo "Wrote $OUT/summary.md"
