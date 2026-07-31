#!/bin/bash

# Copyright (c) 2026 Alex313031.

YEL='\033[1;33m' # Yellow
CYA='\033[1;96m' # Cyan
RED='\033[1;31m' # Red
GRE='\033[1;32m' # Green
c0=$'\033[0m' # Reset Text
bold=$'\033[1m' # Bold Text
underline=$'\033[4m' # Underline Text
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Error handling
yell() { echo "$0: $*" >&2; }
die() { yell "$*"; exit 111; }
try() { "$@" || die "${RED}Failed $*"; }

# --help
displayHelp () {
	printf "\n" &&
	printf "${bold}${YEL}Script to build Alacrium UI Debug Shell (views_examples_with_content).${c0}\n" &&
	printf "${underline}Usage: ${c0}build_debug_shell.sh # (where # is number of jobs)\n" &&
	printf "\n"
}
case $1 in
	--help) displayHelp; exit 0;;
esac

printf "\n" &&
printf "${YEL}Building Alacrium UI Debug Shell for Linux...\n" &&
printf "${CYA}\n" &&

# chromium/src dir env variable
ALACRIUM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CR_SRC_DIR="${ALACRIUM_ROOT}/chromium/src"

# Build Alacrium UI Debug Shell
export NINJA_SUMMARIZE_BUILD=1 &&

cd ${CR_SRC_DIR} &&
autoninja -C out/alacrium alacrium_ui_debug_shell minidump_stackwalk dump_syms -j$@ &&
cd "$SCRIPT_DIR" &&

mkdir -v -p ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell &&
mkdir -v -p ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/lib &&
mkdir -v -p ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/icons &&

cp -r -f -v ./icons/icon_16.png ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/icons &&
cp -r -f -v ./icons/icon_24.png ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/icons &&
cp -r -f -v ./icons/icon_32.png ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/icons &&
cp -r -f -v ./icons/icon_48.png ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/icons &&
cp -r -f -v ./icons/icon_64.png ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/icons &&
cp -r -f -v ./icons/icon_128.png ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/icons &&
cp -r -f -v ./icons/icon_256.png ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/icons &&
cp -r -f -v ./icons/icon_256.png ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
# cp -r -f -v ./icons/alacrium_debug_shell.ico ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell &&
cp -r -f -v DEBUG_SHELL_README.md ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/README.md &&
cp -r -f -v Alacrium_Debug_Shell.sh ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/locales ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/test_fonts ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/resources ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/ui ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
# cp -r -f -v ${CR_SRC_DIR}/out/alacrium/libffmpeg.so ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/libffmpeg.so ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/lib &&
# cp -r -f -v ${CR_SRC_DIR}/out/alacrium/libblink_test_plugin.so ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
# cp -r -f -v ${CR_SRC_DIR}/out/alacrium/libmojo_core.so ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/icudtl.dat ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/content_resources.pak ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/libEGL.so ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/libGLESv2.so ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/libvk_swiftshader.so ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/libvulkan.so.1 ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/vk_swiftshader_icd.json ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/v8_context_snapshot.bin ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/ui_resources_100_percent.pak ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/ui_test.pak ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/ui_test_200_percent.pak ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/views_examples_resources.pak ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/alacrium_ui_debug_shell ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/minidump_stackwalk ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/dump_syms ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/ClearKeyCdm ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/ &&
cp -r -f -v ${CR_SRC_DIR}/out/alacrium/ClearKeyCdm/_platform_specific/linux_x64/libclearkeycdm.so ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell/lib &&

cd ${CR_SRC_DIR}/out/alacrium/Alacrium_UI_Debug_Shell &&
zip -r ../Alacrium_UI_Debug_Shell.zip * &&

printf "\n" &&
printf "${GRE}Alacrium UI Debug Shell Build Completed!\n" &&
tput sgr0
