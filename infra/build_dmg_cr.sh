#!/bin/bash

# Copyright (c) 2026 Alex313031 and midzer.

YEL='\033[1;33m' # Yellow
CYA='\033[1;96m' # Cyan
RED='\033[1;31m' # Red
GRE='\033[1;32m' # Green
c0='\033[0m' # Reset Text
bold='\033[1m' # Bold Text
underline='\033[4m' # Underline Text

# Error handling
yell() { echo "$0: $*" >&2; }
die() { yell "$*"; exit 111; }
try() { "$@" || die "${RED}Failed $*"; }

# chromium/src dir env variable
ALACRIUM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CR_SRC_DIR="${ALACRIUM_ROOT}/chromium/src"

printf "\n" &&
printf "${YEL}Building .dmg of Chromium...\n" &&
printf "${CYA}\n" &&

cd ${CR_SRC_DIR} &&

# Fix file attr
xattr -csr out/alacrium/Chromium.app &&

# Sign binary
codesign --force --deep --sign - out/alacrium/Chromium.app &&

# Build dmg package
chrome/installer/mac/pkg-dmg --sourcefile --source out/alacrium/Chromium.app --target "out/alacrium/Chromium_MacOS.dmg" --volname Chromium --symlink /Applications:/Applications --format UDBZ --verbosity 2 &&

cd $HOME/alacrium &&
cat logos/apple_ascii_art.txt &&

printf "${GRE}.DMG Build Completed. ${YEL}Installer at //chromium/src/out/alacrium/Chromium*.dmg\n" &&
tput sgr0
