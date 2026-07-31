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

# --help
displayHelp () {
	printf "\n" &&
	printf "${bold}${GRE}Script to build Alacrium and Alacrium Shell on MacOS.${c0}\n" &&
	printf "${underline}${YEL}Usage:${c0} build.sh # (where # is number of jobs)${c0}\n" &&
	printf "${YEL}Use the --build-shell flag to also build the alacrium_shell target.${c0}\n" &&
	printf "\n"
}
case $1 in
	--help) displayHelp; exit 0;;
esac

# Build Alacrium Shell in addition to the others.
buildShell () {
	printf "\n" &&
	printf "${YEL}Building Alacrium and Alacrium Shell for MacOS...\n" &&
	printf "${CYA}\n" &&
	
	# Build Alacrium
	export NINJA_SUMMARIZE_BUILD=1 &&
	export NINJA_STATUS="[%r processes, %f/%t @ %o/s | %e sec. ] " &&
	
	cd ${CR_SRC_DIR} &&
	autoninja -C out/alacrium alacrium chromedriver alacrium_shell policy_templates -j$@ &&

	printf "\n" &&
	cat "$(dirname "$0")/logos/alacrium_ascii_art.txt" &&
	printf "\n" &&
	
	printf "${GRE}${bold}Build Completed. ${YEL}${bold}You can now run \'./create_dmg.sh\', and copy the Alacrium Shell.app out.\n" &&
	tput sgr0
}
case $1 in
	--build-shell) buildShell; exit 0;;
esac

# chromium/src dir env variable
ALACRIUM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CR_SRC_DIR="${ALACRIUM_ROOT}/chromium/src"

printf "\n" &&
printf "${YEL}Building Alacrium for MacOS...\n" &&
printf "${CYA}\n" &&

# Build Alacrium
export NINJA_SUMMARIZE_BUILD=1 &&
export NINJA_STATUS="[%r processes, %f/%t @ %o/s | %e sec. ] " &&

cd ${CR_SRC_DIR} &&
# For restoring individual build targets for customization
#autoninja -C out/alacrium alacrium chromedriver policy_templates -j$@ &&
autoninja -C out/alacrium alacrium_all -j$@ &&
printf "${GRE}\nBuilding installer...\n" &&
autoninja -C out/alacrium chrome/installer/mac minidump_stackwalk -j$@ &&

printf "\n" &&
cat "$(dirname "$0")/logos/alacrium_ascii_art.txt" &&
printf "\n" &&

printf "${GRE}${bold}Build Completed. ${YEL}${bold}You can now run \'./create_dmg.sh\'\n" &&
tput sgr0
