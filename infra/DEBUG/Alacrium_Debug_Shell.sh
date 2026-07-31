#!/bin/bash

# Copyright (c) 2026 Alex313031.

# Export libs
LD_LIBRARY_PATH="$(pwd)/lib"
export LD_LIBRARY_PATH

./alacrium_ui_debug_shell --debug "$@"
