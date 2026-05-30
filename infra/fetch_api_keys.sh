#!/bin/bash

# Copyright (c) 2026 Alex313031.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Fetches a contributor-provided API_KEYS.txt and optionally generates the
# Chromium defaults patch from it. This script intentionally does not embed a
# private URL; pass one explicitly or set THORIUM_API_KEYS_URL locally.

set -euo pipefail

YEL='\033[1;33m' # Yellow
RED='\033[1;31m' # Red
GRE='\033[1;32m' # Green
c0='\033[0m' # Reset Text

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

url="${THORIUM_API_KEYS_URL:-}"
output="${repo_root}/API_KEYS.txt"
generate_patch=false

usage() {
  cat <<EOF
Usage: ${0##*/} [--url URL] [--output API_KEYS.txt] [--generate-patch]

The URL may also be provided through THORIUM_API_KEYS_URL. The generated patch
is written to other/google-api-keys-defaults.patch when --generate-patch is set.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url|-u)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      url="$2"
      shift 2
      ;;
    --output|-o)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      output="$2"
      shift 2
      ;;
    --generate-patch)
      generate_patch=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${url}" ]]; then
  printf "${RED}No API key URL configured.${c0}\n" >&2
  printf "${YEL}Pass --url URL or set THORIUM_API_KEYS_URL locally.${c0}\n" >&2
  exit 2
fi

printf "\n"
printf "${YEL}Downloading API_KEYS.txt...${c0}\n"
printf "\n"

mkdir -p "$(dirname "${output}")"
tmp="$(mktemp "${output}.XXXXXX")"

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "${url}" -o "${tmp}"
elif command -v wget >/dev/null 2>&1; then
  wget -q "${url}" -O "${tmp}"
else
  rm -f "${tmp}"
  printf "${RED}Neither curl nor wget is available.${c0}\n" >&2
  exit 1
fi

mv "${tmp}" "${output}"

if [[ "${generate_patch}" == true ]]; then
  "${script_dir}/generate_google_api_keys_patch.sh" \
    --input "${output}" \
    --output "${repo_root}/other/google-api-keys-defaults.patch"
fi

printf "${GRE}Done.${c0}\n"
printf "${YEL}- API keys file: %s${c0}\n" "${output}"
if [[ "${generate_patch}" == true ]]; then
  printf "${YEL}- Generated patch: %s${c0}\n" \
    "${repo_root}/other/google-api-keys-defaults.patch"
fi
