#!/bin/bash

# Copyright (c) 2026 Alex313031.

YEL='\033[1;33m' # Yellow
RED='\033[1;31m' # Red
GRE='\033[1;32m' # Green
c0=$'\033[0m' # Reset Text
bold=$'\033[1m' # Bold Text
underline=$'\033[4m' # Underline Text

# Error handling
yell() { echo "$0: $*" >&2; }
die() { yell "$*"; exit 111; }
try() { "$@" || die "${RED}Failed $*"; }

# --help
displayHelp () {
	printf "\n" &&
	printf "${bold}${GRE}Script to copy Alacrium ARM BUILD.gn files over the Chromium source tree.${c0}\n" &&
	printf "\n"
}
case $1 in
	--help) displayHelp; exit 0;;
esac

ALACRIUM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CR_SRC_DIR="${ALACRIUM_ROOT}/chromium/src"

printf "\n" &&
printf "${YEL}Creating build output directory...\n" &&
tput sgr0 &&

mkdir -v -p "${CR_SRC_DIR}/out/alacrium/" &&
printf "\n" &&

printf "${YEL}Copying BUILD.gn...\n" &&
tput sgr0 &&

cp -r -v ./build/* "${CR_SRC_DIR}/build/" &&
cp -r -v ./media/* "${CR_SRC_DIR}/media/" &&
cp -r -v ./third_party/* "${CR_SRC_DIR}/third_party/" &&

printf "${GRE}Done!\n" &&
printf "\n" &&

printf "${GRE}Enjoy Alacrium on ARM!\n" &&
printf "\n" &&
tput sgr0
