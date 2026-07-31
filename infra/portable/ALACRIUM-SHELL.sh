#!/usr/bin/env bash

# Copyright (c) 2026 Alex313031

export SHELL_WRAPPER="`readlink -f "$0"`"

HERE="`dirname "$SHELL_WRAPPER"`"

PROFILE="$HERE/.config/alacrium-shell"
CACHE="$HERE/.config/cache"
export PROFILE
export CACHE

# Launch alacrium_shell
# Note: exec -a below is a bashism.
exec -a "$0" "$HERE/alacrium_shell" "--user-data-dir=$PROFILE" "--disk-cache-dir=$CACHE" "--enable-experimental-web-platform-features" "--enable-clear-hevc-for-testing" "$@"
