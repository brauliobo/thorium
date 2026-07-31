#!/usr/bin/env bash

set -euo pipefail

ALACRIUM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -x "$HOME/depot_tools/fetch" ]]; then
  printf 'Missing %s/depot_tools. Clone depot_tools there before continuing.\n' "$HOME" >&2
  exit 1
fi

export PATH="$HOME/depot_tools:$PATH"

"${ALACRIUM_ROOT}/trunk.sh"

printf 'Chromium is ready at %s/chromium/src.\n' "$ALACRIUM_ROOT"
