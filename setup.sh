#!/bin/bash

# Copyright (c) 2026 Alex313031.

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

copy_optional_overlay () {
	local overlay_path="$1"

	if [ -e "${overlay_path}" ]; then
		cp -r -v "${overlay_path}" ${CR_SRC_DIR}/
	else
		printf "${YEL}Skipping missing optional overlay: %s${c0}\n" "${overlay_path}"
	fi
}

apply_patch_once () {
	local patch_dir="$1"
	local patch_file="$2"
	local label="$3"

	printf "${YEL}%s...${c0}\n" "${label}"
	if git -C "${patch_dir}" apply --check "${patch_file}" >/dev/null 2>&1; then
		git -C "${patch_dir}" apply --reject "${patch_file}"
	elif git -C "${patch_dir}" apply --check --reverse "${patch_file}" >/dev/null 2>&1; then
		printf "${GRE}%s already applied; skipping.${c0}\n" "${label}"
	else
		die "${label} does not apply cleanly in ${patch_dir}"
	fi
}

# --help
displayHelp () {
	printf "\n" &&
	printf "${bold}${GRE}Script to copy Thorium source files over the Chromium source tree.${c0}\n" &&
	printf "${bold}${YEL}  Use the --mac flag for MacOS builds.${c0}\n" &&
	printf "${bold}${YEL}  Use the --raspi or --arm64 flag for Raspberry Pi builds.${c0}\n" &&
	printf "${bold}${YEL}  Use the --woa flag for Windows on ARM builds.${c0}\n" &&
	printf "${bold}${YEL}  Use the --avx512 flag for AVX-512 Builds.${c0}\n" &&
	printf "${bold}${YEL}  Use the --avx2 flag for AVX2 Builds.${c0}\n" &&
	printf "${bold}${YEL}  Use the --sse4 flag for SSE4.1 Builds.${c0}\n" &&
	printf "${bold}${YEL}  Use the --sse3 flag for SSE3 Builds.${c0}\n" &&
	printf "${bold}${YEL}  Use the --sse2 flag for 32 bit SSE2 Builds.${c0}\n" &&
	printf "${bold}${YEL}  Use the --android flag for Android Builds.${c0}\n" &&
	printf "${bold}${YEL}  Use the --cros flag for ChromiumOS Builds.${c0}\n" &&
	printf "${bold}${YEL}  --help or -h shows this help.${c0}\n" &&
	printf "${bold}${YEL}  IMPORTANT: For Polly builds, first run build_polly.sh in ./infra before building.${c0}\n" &&
	printf "${bold}${YEL}   This should be done AFTER running this setup.sh script!${c0}\n" &&
	printf "\n"
	printf "${bold}${YEL}  NOTE: The \`CR_DIR\` env variable can be used to override the location of \"chromium/src\".${c0}\n" &&
	printf "${bold}${YEL}   The default is $HOME/chromium/src${c0}\n" &&
	printf "\n"
}
case $1 in
	--help) displayHelp; exit 0;;
esac
case $1 in
	-h) displayHelp; exit 0;;
esac

# chromium/src dir env variable
THORIUM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${CR_DIR}" ]; then 
    CR_SRC_DIR="$HOME/chromium/src"
    export CR_SRC_DIR
else 
    CR_SRC_DIR="${CR_DIR}"
    export CR_SRC_DIR
fi

printf "\n" &&
printf "${YEL}Creating build output directory...${c0}\n" &&

mkdir -v -p ${CR_SRC_DIR}/out/thorium/ &&

printf "\n" &&
printf "${YEL}Copying Thorium source files over the Chromium tree...${c0}\n" &&
cd "${THORIUM_ROOT}" &&
# Note: M147+ ships JPEG XL natively (enable_jxl_decoder declared in
# third_party/blink/renderer/config.gni). The thorium-libjxl overlay is no
# longer needed and has been removed.

# Copy Thorium sources
cp -r -v src/BUILD.gn ${CR_SRC_DIR}/ &&
cp -r -v src/ash ${CR_SRC_DIR}/ &&
cp -r -v src/build ${CR_SRC_DIR}/ &&
cp -r -v src/chrome ${CR_SRC_DIR}/ &&
copy_optional_overlay src/chromeos &&
cp -r -v src/components ${CR_SRC_DIR}/ &&
cp -r -v src/content ${CR_SRC_DIR}/ &&
copy_optional_overlay src/extensions &&
copy_optional_overlay src/google_apis &&
cp -r -v src/media ${CR_SRC_DIR}/ &&
cp -r -v src/net ${CR_SRC_DIR}/ &&
copy_optional_overlay src/ppapi &&
cp -r -v src/sandbox ${CR_SRC_DIR}/ &&
copy_optional_overlay src/services &&
cp -r -v src/third_party ${CR_SRC_DIR}/ &&
cp -r -v src/tools ${CR_SRC_DIR}/ &&
cp -r -v src/ui ${CR_SRC_DIR}/ &&
copy_optional_overlay src/v8 &&

cp -r -v thorium_shell/. ${CR_SRC_DIR}/out/thorium/ &&
cp -r -v pak_src/binaries/pak ${CR_SRC_DIR}/out/thorium/ &&
cp -r -v pak_src/binaries/pak-win/. ${CR_SRC_DIR}/out/thorium/ &&
:

patchThor () {
	printf "\n" &&
	printf "${YEL}Patching FFMPEG for HEVC...${c0}\n" &&
	apply_patch_once "${CR_SRC_DIR}/third_party/ffmpeg" "${THORIUM_ROOT}/other/add-hevc-ffmpeg-decoder-parser.patch" "HEVC ffmpeg parser patch" &&
	apply_patch_once "${CR_SRC_DIR}/third_party/ffmpeg" "${THORIUM_ROOT}/other/change-libavcodec-header.patch" "libavcodec header patch for HEVC" &&

	printf "\n" &&
	printf "${YEL}Patching policy templates...${c0}\n" &&
	apply_patch_once "${CR_SRC_DIR}" "${THORIUM_ROOT}/other/fix-policy-templates.patch" "Policy templates patch" &&

	printf "\n" &&
	printf "${YEL}Patching FTP support...${c0}\n" &&
	apply_patch_once "${CR_SRC_DIR}" "${THORIUM_ROOT}/other/ftp-support-thorium.patch" "FTP support patch" &&

	printf "${YEL}Injecting Thorium-branded translations into Chromium .xtb bundles...${c0}\n" &&
	python3 "${THORIUM_ROOT}/infra/merge_thorium_xtb.py" "${CR_SRC_DIR}" &&

	printf "\n" &&
	printf "${YEL}Applying other Misc. patches...${c0}\n" &&
	apply_patch_once "${CR_SRC_DIR}" "${THORIUM_ROOT}/other/open_in_same_tab.patch" "Open in same tab patch" &&
	apply_patch_once "${CR_SRC_DIR}" "${THORIUM_ROOT}/other/thorium_webui.patch" "Thorium WebUI patch" &&
	apply_patch_once "${CR_SRC_DIR}" "${THORIUM_ROOT}/other/keyboard_shortcuts.patch" "Thorium Keyboard Shortcuts patch" &&
	apply_patch_once "${CR_SRC_DIR}" "${THORIUM_ROOT}/other/GPC.patch" "Global Privacy Control patch" &&
	apply_patch_once "${CR_SRC_DIR}" "${THORIUM_ROOT}/other/disable-privacy-sandbox.patch" "Disable Privacy Sandbox patch" &&
	apply_patch_once "${CR_SRC_DIR}" "${THORIUM_ROOT}/other/enable-vaapi-nvidia-default.patch" "Enable NVIDIA VA-API by default patch" &&
	apply_patch_once "${CR_SRC_DIR}" "${THORIUM_ROOT}/other/history-query-dedupe.patch" "History duplicate query patch" &&
	apply_patch_once "${CR_SRC_DIR}" "${THORIUM_ROOT}/other/history-redirect-chain-cache.patch" "History redirect chain cache patch" &&
	apply_patch_once "${CR_SRC_DIR}" "${THORIUM_ROOT}/other/history-delete-directive-startup-guard.patch" "History delete directive startup guard patch" &&
	apply_patch_once "${CR_SRC_DIR}" "${THORIUM_ROOT}/other/google-api-keys-defaults.patch" "Google API key defaults patch" &&
	# Kept because it is related to Thorium custom flags (not upstreamable).
	apply_patch_once "${CR_SRC_DIR}" "${THORIUM_ROOT}/other/fix_disable_aero_crash.patch" "Disable aero crash fix"
}
patchThor;

patchAC3 () {
	#cp -v other/ffmpeg_hevc_ac3.patch ${CR_SRC_DIR}/third_party/ffmpeg/ &&

	#printf "\n" &&
	#printf "${YEL}Patching FFMPEG for AC3 & E-AC3...${c0}\n" &&
	#cd ${CR_SRC_DIR}/third_party/ffmpeg &&
	#git apply --reject ./ffmpeg_hevc_ac3.patch &&
	cd "${THORIUM_ROOT}"
}

patchSSE2 () {
	cp -v other/SSE2/angle-lockfree.patch ${CR_SRC_DIR}/third_party/angle/src/ &&

	printf "\n" &&
	printf "${YEL}Patching ANGLE for SSE2...${c0}\n" &&
	cd ${CR_SRC_DIR}/third_party/angle/src &&
	git apply --reject ./angle-lockfree.patch &&
	cd "${THORIUM_ROOT}"
}

cd "${THORIUM_ROOT}" &&

printf "\n" &&
echo "Copying other files to \`out/thorium\`" &&

# Add default_apps dir for Google Docs Offline extension.
mkdir -v -p ${CR_SRC_DIR}/out/thorium/default_apps &&
cp -r -v infra/default_apps/. ${CR_SRC_DIR}/out/thorium/default_apps/ &&

# Add initial preferences file to open Thorium welcome page on first run.
cp -v infra/initial_preferences ${CR_SRC_DIR}/out/thorium/ &&
cp -v infra/thor_ver ${CR_SRC_DIR}/out/thorium/ &&

# MacOS ARMv8.3-A optimizations
copyMacOS () {
	printf "\n" &&
	printf "${YEL}Copying files for MacOS...${c0}\n" &&
	cp -v arm/mac_arm.gni ${CR_SRC_DIR}/build/config/arm.gni &&
	cp -v other/Mac/thorium_version.txt ${CR_SRC_DIR}/ui/webui/resources/text/ &&
	cp -r -v arm/third_party/* ${CR_SRC_DIR}/third_party/ &&
	cd ${CR_SRC_DIR} &&
	python3 tools/update_pgo_profiles.py --target=mac update --gs-url-base=chromium-optimization-profiles/pgo_profiles &&
	python3 tools/update_pgo_profiles.py --target=mac-arm update --gs-url-base=chromium-optimization-profiles/pgo_profiles &&
	cd "${THORIUM_ROOT}" &&
	[ -f ${CR_SRC_DIR}/third_party/ffmpeg/ffmpeg_hevc_ac3.patch ] || patchAC3;
	printf "\n"
}
case $1 in
	--mac) copyMacOS;
esac
case $1 in
	--macos) copyMacOS;
esac

# Raspberry Pi Source Files
copyRaspi () {
	printf "\n" &&
	printf "${YEL}Copying Raspberry Pi build files...${c0}\n" &&
	cp -r -v arm/build/* ${CR_SRC_DIR}/build/ &&
	cp -r -v arm/third_party/* ${CR_SRC_DIR}/third_party/ &&
	cp -r -v arm/raspi/* ${CR_SRC_DIR}/ &&
	cp -v arm/thorium_version.txt ${CR_SRC_DIR}/ui/webui/resources/text/ &&
	cp -v other/thor_ver_linux/wrapper-raspi ${CR_SRC_DIR}/chrome/installer/linux/common/wrapper &&
	cp -v pak_src/binaries/pak_arm64 ${CR_SRC_DIR}/out/thorium/pak &&
	#./infra/fix_libaom.sh &&
	printf "\n" &&
	cp -r -v arm/raspi/build/config/* ${CR_SRC_DIR}/build/config/ &&
	printf "\n" &&
	# Display raspi ascii art
	cat logos/raspi_ascii_art.txt
}
case $1 in
	--raspi) copyRaspi;
esac
case $1 in
	--arm64) copyRaspi;
esac

# Windows on ARM64 files
copyWOA () {
	printf "\n" &&
	printf "${YEL}Copying Windows on ARM build files...${c0}\n" &&
	cp -r -v arm/build/* ${CR_SRC_DIR}/build/ &&
	cp -v arm/thorium_version.txt ${CR_SRC_DIR}/ui/webui/resources/text/ &&
	cp -r -v arm/third_party/* ${CR_SRC_DIR}/third_party/ &&
	cd ${CR_SRC_DIR} &&
	python3 tools/update_pgo_profiles.py --target=win-arm64 update --gs-url-base=chromium-optimization-profiles/pgo_profiles &&
	cd "${THORIUM_ROOT}" &&
	# Use regular arm.gni from src, pending further testing
	# cp -v arm/woa_arm.gni ${CR_SRC_DIR}/build/config/arm.gni &&
	printf "\n"
}
case $1 in
	--woa) copyWOA;
esac

# Copy AVX512 files
copyAVX512 () {
	printf "\n" &&
	printf "${YEL}Copying AVX-512 build files...${c0}\n" &&
	cp -r -v other/AVX2/third_party/* ${CR_SRC_DIR}/third_party/ &&
	cp -v other/AVX512/thor_ver ${CR_SRC_DIR}/out/thorium/ &&
	cp -v other/AVX512/thorium_version.txt ${CR_SRC_DIR}/ui/webui/resources/text/ &&
	cp -v other/thor_ver_linux/wrapper-avx512 ${CR_SRC_DIR}/chrome/installer/linux/common/wrapper &&
	[ -f ${CR_SRC_DIR}/third_party/ffmpeg/ffmpeg_hevc_ac3.patch ] || patchAC3;
	printf "\n"
}
case $1 in
	--avx512) copyAVX512;
esac

# Copy AVX2 files
copyAVX2 () {
	printf "\n" &&
	printf "${YEL}Copying AVX2 build files...${c0}\n" &&
	cp -r -v other/AVX2/third_party/* ${CR_SRC_DIR}/third_party/ &&
	cp -v other/AVX2/thor_ver ${CR_SRC_DIR}/out/thorium/ &&
	cp -v other/AVX2/thorium_version.txt ${CR_SRC_DIR}/ui/webui/resources/text/ &&
	cp -v other/thor_ver_linux/wrapper-avx2 ${CR_SRC_DIR}/chrome/installer/linux/common/wrapper &&
	[ -f ${CR_SRC_DIR}/third_party/ffmpeg/ffmpeg_hevc_ac3.patch ] || patchAC3;
	printf "\n"
}
case $1 in
	--avx2) copyAVX2;
esac

# Copy SSE4.1 files
copySSE4 () {
	printf "\n" &&
	printf "${YEL}Copying SSE4.1 build files...${c0}\n" &&
	cp -v other/SSE4.1/thor_ver ${CR_SRC_DIR}/out/thorium/ &&
	cp -v other/SSE4.1/thorium_version.txt ${CR_SRC_DIR}/ui/webui/resources/text/ &&
	cp -v other/thor_ver_linux/wrapper-sse4 ${CR_SRC_DIR}/chrome/installer/linux/common/wrapper &&
	[ -f ${CR_SRC_DIR}/third_party/ffmpeg/ffmpeg_hevc_ac3.patch ] || patchAC3;
	printf "\n"
}
case $1 in
	--sse4) copySSE4;
esac

# Copy SSE3 files
copySSE3 () {
	printf "\n" &&
	printf "${YEL}Copying SSE3 build files...${c0}\n" &&
	cp -v other/SSE3/thor_ver ${CR_SRC_DIR}/out/thorium/ &&
	cp -v other/SSE3/thorium_version.txt ${CR_SRC_DIR}/ui/webui/resources/text/ &&
	cp -v other/thor_ver_linux/wrapper-sse3 ${CR_SRC_DIR}/chrome/installer/linux/common/wrapper &&
	cd ${CR_SRC_DIR} &&
	python3 tools/update_pgo_profiles.py --target=win32 update --gs-url-base=chromium-optimization-profiles/pgo_profiles &&
	cd "${THORIUM_ROOT}" &&
	[ -f ${CR_SRC_DIR}/third_party/ffmpeg/ffmpeg_hevc_ac3.patch ] || patchAC3;
	printf "\n"
}
case $1 in
	--sse3) copySSE3;
esac

# Copy SSE2 files
copySSE2 () {
	printf "\n" &&
	printf "${YEL}Copying SSE2 (32-bit) build files...${c0}\n" &&
	cp -v other/SSE2/thor_ver ${CR_SRC_DIR}/out/thorium/ &&
	cp -v other/SSE2/thorium_version.txt ${CR_SRC_DIR}/ui/webui/resources/text/ &&
	cp -v other/thor_ver_linux/wrapper-sse2 ${CR_SRC_DIR}/chrome/installer/linux/common/wrapper &&
	cd ${CR_SRC_DIR} &&
	python3 tools/update_pgo_profiles.py --target=win32 update --gs-url-base=chromium-optimization-profiles/pgo_profiles &&
	cd "${THORIUM_ROOT}" &&
	[ -f ${CR_SRC_DIR}/third_party/ffmpeg/ffmpeg_hevc_ac3.patch ] || patchAC3;
	[ -f ${CR_SRC_DIR}/third_party/angle/src/angle-lockfree.patch ] || patchSSE2;
	printf "\n"
}
case $1 in
	--sse2) copySSE2;
esac

# Copy Android files
copyAndroid () {
	printf "\n" &&
	printf "${YEL}Copying Android (ARM64 and ARM32) build files...${c0}\n" &&
	cp -r -v arm/build/* ${CR_SRC_DIR}/build/ &&
	cp -r -v arm/third_party/* ${CR_SRC_DIR}/third_party/ &&
	printf "\n" &&
	cp -r -v arm/android/* ${CR_SRC_DIR}/ &&
	printf "\n" &&
	#cp -r -v arm/android/third_party/* ${CR_SRC_DIR}/third_party/ &&
	rm -v -f ${CR_SRC_DIR}/chrome/android/java/res_base/drawable-v26/ic_launcher.xml &&
	rm -v -f ${CR_SRC_DIR}/chrome/android/java/res_base/drawable-v26/ic_launcher_round.xml &&
	rm -v -f ${CR_SRC_DIR}/chrome/android/java/res_chromium_base/mipmap-mdpi/layered_app_icon_background.png &&
	#rm -v -f ${CR_SRC_DIR}/chrome/android/java/res_chromium_base/mipmap-mdpi/layered_app_icon.png &&
	rm -v -f ${CR_SRC_DIR}/chrome/android/java/res_chromium_base/mipmap-xhdpi/layered_app_icon_background.png &&
	#rm -v -f ${CR_SRC_DIR}/chrome/android/java/res_chromium_base/mipmap-xhdpi/layered_app_icon.png &&
	rm -v -f ${CR_SRC_DIR}/chrome/android/java/res_chromium_base/mipmap-xxxhdpi/layered_app_icon_background.png &&
	#rm -v -f ${CR_SRC_DIR}/chrome/android/java/res_chromium_base/mipmap-xxxhdpi/layered_app_icon.png &&
	rm -v -f ${CR_SRC_DIR}/chrome/android/java/res_chromium_base/mipmap-nodpi/layered_app_icon_foreground.xml &&
	rm -v -f ${CR_SRC_DIR}/chrome/android/java/res_chromium_base/mipmap-hdpi/layered_app_icon_background.png &&
	#rm -v -f ${CR_SRC_DIR}/chrome/android/java/res_chromium_base/mipmap-hdpi/layered_app_icon.png &&
	rm -v -f ${CR_SRC_DIR}/chrome/android/java/res_chromium_base/mipmap-xxhdpi/layered_app_icon_background.png &&
	#rm -v -f ${CR_SRC_DIR}/chrome/android/java/res_chromium_base/mipmap-xxhdpi/layered_app_icon.png &&
	#./infra/fix_libaom.sh &&
	printf "\n" &&
	printf "${YEL}Downloading PGO profiles...${c0}\n" &&
	cd ${CR_SRC_DIR} &&
	python3 tools/update_pgo_profiles.py --target=android-arm64 update --gs-url-base=chromium-optimization-profiles/pgo_profiles &&
	python3 tools/update_pgo_profiles.py --target=android-arm32 update --gs-url-base=chromium-optimization-profiles/pgo_profiles &&
	cd "${THORIUM_ROOT}" &&
	printf "\n"
}
case $1 in
	--android) copyAndroid;
esac

# Copy CrOS files
copyCros () {
	printf "\n" &&
	printf "${YEL}Copying ChromiumOS build files...${c0}\n" &&
	cp -r -v other/CrOS/* ${CR_SRC_DIR}/ &&
	cp -v other/CrOS/thorium_version.txt ${CR_SRC_DIR}/ui/webui/resources/text/ &&
	[ -f ${CR_SRC_DIR}/third_party/ffmpeg/ffmpeg_hevc_ac3.patch ] || patchAC3;
	printf "\n"
}
case $1 in
	--cros) copyCros;
esac

printf "\n" &&
printf "${GRE}Done!${c0}\n" &&

#. "${THORIUM_ROOT}/aliases.txt" &&

#printf "\n" &&
#printf "export ${CYA}NINJA_SUMMARIZE_BUILD=1${c0}\n" &&
#printf "export ${CYA}EDITOR=nano${c0}\n" &&
#printf "export ${CYA}VISUAL=nano${c0}\n" &&
#printf "\n" &&
#printf "alias ${YEL}origin${c0} = ${CYA}git checkout -f origin/main${c0}\n" &&
#printf "alias ${YEL}gfetch${c0} = ${CYA}git fetch --tags${c0}\n" &&
#printf "alias ${YEL}rebase${c0} = ${CYA}git rebase-update${c0}\n" &&
#printf "alias ${YEL}gsync${c0} = ${CYA}gclient sync --with_branch_heads --with_tags -f -R -D${c0}\n" &&
#printf "alias ${YEL}args${c0} = ${CYA}gn args out/thorium${c0}\n" &&
#printf "alias ${YEL}gnls${c0} = ${CYA}gn ls out/thorium${c0}\n" &&
#printf "alias ${YEL}show${c0} = ${CYA}git show-ref${c0}\n" &&
#printf "alias ${YEL}runhooks${c0} = ${CYA}gclient runhooks${c0}\n" &&
#printf "alias ${YEL}pgo${c0} = ${CYA}python3 tools/update_pgo_profiles.py --target=linux update --gs-url-base=chromium-optimization-profiles/pgo_profiles${c0}\n" &&
#printf "alias ${YEL}pgow${c0} = ${CYA}python3 tools/update_pgo_profiles.py --target=win64 update --gs-url-base=chromium-optimization-profiles/pgo_profiles${c0}\n" &&
#printf "alias ${YEL}pgom${c0} = ${CYA}python3 tools/update_pgo_profiles.py --target=mac update --gs-url-base=chromium-optimization-profiles/pgo_profiles${c0}\n" &&
#printf "alias ${YEL}pgomac-arm${c0} = ${CYA}python3 tools/update_pgo_profiles.py --target=mac-arm update --gs-url-base=chromium-optimization-profiles/pgo_profiles${c0}\n" &&
#printf "\n" &&

cd "${THORIUM_ROOT}" &&
cat ./logos/thorium_ascii_art.txt &&

printf "${YEL}Tip: See the ${CYA}aliases.txt${YEL} file for some handy bash aliases.${c0}\n" &&
printf "\n" &&
printf "${RED} IMPORTANT: If you ran setup.sh without any flags, you must also run ./patch_ac3.sh for AC3/E-AC3 support.\n" &&
printf "\n" &&
printf "${GRE}  Enjoy Thorium!\n" &&
printf "\n" &&
tput sgr0
