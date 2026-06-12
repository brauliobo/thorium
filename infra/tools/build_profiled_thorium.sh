#!/usr/bin/env bash

set -euo pipefail

JOBS="${1:-6}"
CR_SRC_DIR="${CR_DIR:-${CR_SRC_DIR:-$HOME/chromium/src}}"
THORIUM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${OUT_DIR:-out/thorium-prof}"

if [[ ! "$JOBS" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 [jobs]" >&2
  exit 2
fi

if [[ -d "$HOME/depot_tools" ]]; then
  export PATH="$HOME/depot_tools:$PATH"
fi

cd "$CR_SRC_DIR"

gn gen "$OUT_DIR" --args="$(
  sed \
    -e 's/^is_official_build = .*/is_official_build = false/' \
    -e 's/^is_debug = .*/is_debug = false/' \
    -e 's/^enable_stripping = .*/enable_stripping = false/' \
    -e 's/^symbol_level = .*/symbol_level = 2/' \
    -e 's/^v8_symbol_level = .*/v8_symbol_level = 2/' \
    -e 's/^blink_symbol_level = .*/blink_symbol_level = 1/' \
    -e 's/^enable_profiling = .*/enable_profiling = true/' \
    -e 's/^exclude_unwind_tables = .*/exclude_unwind_tables = false/' \
    -e 's/^is_cfi = .*/is_cfi = false/' \
    -e 's/^use_thin_lto = .*/use_thin_lto = false/' \
    -e 's/^thin_lto_enable_optimizations = .*/thin_lto_enable_optimizations = false/' \
    -e 's/^chrome_pgo_phase = .*/chrome_pgo_phase = 0/' \
    -e 's@^pgo_data_path = .*@pgo_data_path = ""@' \
    "$THORIUM_ROOT/args.gn"
  printf '\nuse_debug_fission = true\n'
)"

export NINJA_SUMMARIZE_BUILD=1
export NINJA_STATUS="[%r processes, %f/%t @ %o/s | %e sec. ] "

nice -n 10 ionice -c2 -n7 autoninja -C "$OUT_DIR" thorium -j"$JOBS"

cat <<EOF

Profiled Thorium built at:
  $CR_SRC_DIR/$OUT_DIR/thorium

Run it with an isolated profile:
  HOME=/tmp/thorium-prof-home XDG_CONFIG_HOME=/tmp/thorium-prof-home/.config \\
    $CR_SRC_DIR/$OUT_DIR/thorium --user-data-dir=/tmp/thorium-prof-profile \\
    --enable-logging=stderr --v=1
EOF
