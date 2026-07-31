#!/bin/bash

set -euo pipefail

# Copyright (c) 2026 Alex313031, midzer, and gz83.

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
	printf "${bold}${GRE}Script to Rebase/Sync the Chromium repo.${c0}\n" &&
	# printf "${bold}${YEL}Use the --shallow flag to do a shallow sync, if you have downloaded${c0}\n" &&
	# printf "${bold}${YEL}the Chromium repo with the --no-history flag.${c0}\n" &&
	printf "\n"
}
case ${1:-} in
	--help) displayHelp; exit 0;;
esac

# chromium/src dir env variable
ALACRIUM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CR_SRC_DIR="${ALACRIUM_ROOT}/chromium/src"
CR_ROOT="$(dirname "${CR_SRC_DIR}")"

if [ -d "$HOME/depot_tools" ]; then
    export PATH="$HOME/depot_tools:$PATH"
fi

printf "\n"
printf "${bold}${GRE}Script to Rebase/Sync the Chromium repo.${c0}\n"
printf "\n"
printf "${YEL}Rebasing/Syncing and running hooks...\n"
tput sgr0 2>/dev/null || true

if [ ! -d "${CR_SRC_DIR}/.git" ]; then
    printf "${YEL}Creating Chromium git checkout at ${CR_SRC_DIR}...${c0}\n"
    mkdir -p "${CR_ROOT}"
    if command -v fetch >/dev/null 2>&1; then
        (cd "${CR_ROOT}" && fetch --nohooks chromium)
    else
        git clone https://chromium.googlesource.com/chromium/src.git "${CR_SRC_DIR}"
        cat > "${CR_ROOT}/.gclient" <<EOF
solutions = [
  {
    "name": "src",
    "url": "https://chromium.googlesource.com/chromium/src.git",
    "managed": False,
    "custom_deps": {},
    "custom_vars": {},
  },
]
EOF
        (cd "${CR_SRC_DIR}" && gclient sync --nohooks)
    fi
fi

for checkout in \
    "${CR_SRC_DIR}/v8" \
    "${CR_SRC_DIR}/third_party/devtools-frontend/src" \
    "${CR_SRC_DIR}/third_party/ffmpeg"; do
    if [ -d "${checkout}/.git" ]; then
        git -C "${checkout}" restore .
        git -C "${checkout}" clean -ffd
    fi
done

rm -rf "${CR_SRC_DIR}/third_party/pak" "${CR_SRC_DIR}/components/ungoogled"

git -C "${CR_SRC_DIR}" fetch origin --tags
git -C "${CR_SRC_DIR}" checkout -f origin/main
git -C "${CR_SRC_DIR}" clean -ffd

printf "${GRE}gclient sync${c0}\n"
(cd "${CR_SRC_DIR}" && gclient sync --with_branch_heads --with_tags --force --reset --nohooks --delete_unversioned_trees)

printf "${GRE}gclient runhooks${c0}\n"
(cd "${CR_SRC_DIR}" && gclient runhooks)

printf "\n"
printf "${GRE}Done! ${YEL}You can now run \'./version.sh\'\n"
tput sgr0 2>/dev/null || true

#c0='\033[0m' # Reset Text
#c1='\033[0m\033[36m\033[1m' # Light Cyan
#c2='\033[0m\033[1;31m' # Light Red
#c3='\033[0m\033[37m' # Light Grey
#c4='\033[0m\033[1;34m\033[1m' # Light Blue
#c5='\033[0m\033[1;37m' # White
#c6='\033[0m\033[1;34m' # Dark Blue
#c7='\033[1;32m' # Green

#printf "\n" &&
#printf "${c4}                .,:loool:,.              \n" &&
#printf "${c4}            .,coooooooooooooc,.          \n" &&
#printf "${c4}         .,lllllllllllllllllllll,.       \n" &&
#printf "${c4}        ;ccccccccccccccccccccccccc;      \n" &&
#printf "${c1}      ,${c4}ccccccccccccccccccccccccccccc.    \n" &&
#printf "${c1}     ,oo${c4}c::::::::ok${c5}00000${c3}OOkkkkkkkkkkk:   \n" &&
#printf "${c1}    .ooool${c4};;;;:x${c5}K0${c6}kxxxxxk${c5}0X${c3}K0000000000.  \n" &&
#printf "${c1}    :oooool${c4};,;O${c5}K${c6}ddddddddddd${c5}KX${c3}000000000d  \n" &&
#printf "${c1}    lllllool${c4};l${c5}N${c6}dllllllllllld${c5}N${c3}K000000000  \n" &&
#printf "${c1}    lllllllll${c4}o${c5}M${c6}dccccccccccco${c5}W${c3}K000000000  \n" &&
#printf "${c1}    ;cllllllllX${c5}X${c6}c:::::::::c${c5}0X${c3}000000000d  \n" &&
#printf "${c1}    .ccccllllllO${c5}Nk${c6}c;,,,;cx${c5}KK${c3}0000000000.  \n" &&
#printf "${c1}     .cccccclllllxO${c5}OOOO0${c1}kx${c3}O0000000000;   \n" &&
#printf "${c1}      .:ccccccccllllllllo${c3}O0000000OOO,    \n" &&
#printf "${c1}        ,:ccccccccclllcd${c3}0000OOOOOOl.     \n" &&
#printf "${c1}          .::ccccccccc${c3}dOOOOOOOkx:.       \n" &&
#printf "${c1}            ..,::cccc${c3}xOOOkkko;.          \n" &&
#printf "${c1}               ..::${c3}dOkkxl:.              \n" &&
#printf "\n"
#printf "${c7}            Long Live Chromium\041\n${c0}\n" &&

printf "\n" &&
cat "${ALACRIUM_ROOT}/logos/chromium_logo_ascii_art.txt" &&
printf "\n" &&
tput sgr0
