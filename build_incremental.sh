#!/bin/bash

# Incremental Thorium Linux build wrapper.
# Keep using the same Chromium checkout and out/thorium directory to avoid
# invalidating the object graph between version update attempts.

set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: $0 [jobs] [--packages]"
  echo "Runs an incremental low-priority build in the existing out/thorium directory."
  exit 0
fi

JOBS=6
BUILD_PACKAGES=0

for arg in "$@"; do
  case "$arg" in
    --packages)
      BUILD_PACKAGES=1
      ;;
    ''|*[!0-9]*)
      echo "Unknown argument: $arg" >&2
      echo "Usage: $0 [jobs] [--packages]" >&2
      exit 2
      ;;
    *)
      JOBS="$arg"
      ;;
  esac
done

CR_SRC_DIR="${CR_DIR:-${CR_SRC_DIR:-$HOME/chromium/src}}"

if [[ ! -f "$CR_SRC_DIR/out/thorium/build.ninja" ]]; then
  echo "Missing $CR_SRC_DIR/out/thorium/build.ninja; run gn gen once before incremental builds." >&2
  exit 2
fi

if [[ -d "$HOME/depot_tools" ]]; then
  export PATH="$HOME/depot_tools:$PATH"
fi

export NINJA_SUMMARIZE_BUILD=1
export NINJA_STATUS="[%r processes, %f/%t @ %o/s | %e sec. ] "

cd "$CR_SRC_DIR"

run_ninja() {
  nice -n 10 ionice -c2 -n7 autoninja -C out/thorium "$@" -j"$JOBS"
}

if [[ "$BUILD_PACKAGES" == 1 ]]; then
  run_ninja \
    chrome/installer/linux:strip_chrome_binary \
    chrome/installer/linux:strip_chrome_sandbox \
    chrome/installer/linux:strip_chrome_management_service

  ln -f out/thorium/chrome.stripped out/thorium/thorium.stripped
  ln -f out/thorium/chrome_sandbox.stripped out/thorium/thorium_sandbox.stripped
  patchelf --remove-rpath out/thorium/thorium.stripped 2>/dev/null || true
  patchelf --remove-rpath out/thorium/chrome_management_service.stripped 2>/dev/null || true

  if [[ -f /etc/arch-release ]]; then
    run_ninja chrome/installer/linux:stable_rpm
  else
    run_ninja chrome/installer/linux:stable_deb chrome/installer/linux:stable_rpm
  fi
else
  run_ninja thorium
fi
