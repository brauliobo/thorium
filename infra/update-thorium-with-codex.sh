#!/usr/bin/env bash

set -euo pipefail

thorium_dir=/home/braulio/Projects/thorium
aur_src_dir="${thorium_dir}/aur/thorium-browser-updated"
aur_bin_dir="${thorium_dir}/aur/thorium-browser-updated-bin"
state_dir=/home/braulio/.local/state/thorium-updater
lock_file="${state_dir}/update.lock"
last_message="${state_dir}/last-message.md"
release_api="https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=Linux&num=1"

mkdir -p "$state_dir"

export PATH="/home/braulio/.local/bin:/home/braulio/bin:/usr/local/bin:/usr/bin:/bin"
export SSH_ASKPASS=/usr/bin/ksshaskpass
export SSH_ASKPASS_REQUIRE=force
export GIT_SSH_COMMAND="ssh -o AddKeysToAgent=yes"

if command -v systemctl >/dev/null 2>&1; then
  while IFS= read -r line; do
    case "$line" in
      DISPLAY=*|WAYLAND_DISPLAY=*|XDG_CURRENT_DESKTOP=*|KDE_FULL_SESSION=*|DBUS_SESSION_BUS_ADDRESS=*|XDG_RUNTIME_DIR=*)
        export "$line"
        ;;
    esac
  done < <(systemctl --user show-environment 2>/dev/null || true)
fi

exec 9>"$lock_file"
if ! flock -n 9; then
  echo "Another Thorium update run is active; exiting."
  exit 0
fi

git -C "$thorium_dir" switch main
git -C "$thorium_dir" pull --ff-only origin main

current_version="$(sed -nE 's/^THOR_VER="([^"]+)"/\1/p' "${thorium_dir}/version.sh")"
latest_version="$(
  curl -fsSL "$release_api" | python3 -c '
import json
import re
import sys

try:
    releases = json.load(sys.stdin)
except json.JSONDecodeError:
    sys.exit(1)

if not releases:
    sys.exit(1)

version = releases[0].get("version", "")
if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+", version):
    sys.exit(1)

print(version)
'
)"

if [ -z "$current_version" ]; then
  echo "Could not read current Thorium version from ${thorium_dir}/version.sh" >&2
  exit 1
fi

printf 'Current Thorium version: %s\n' "$current_version"
printf 'Latest Chromium stable Linux version: %s\n' "$latest_version"

if [ "$(printf '%s\n%s\n' "$current_version" "$latest_version" | sort -V | tail -n1)" = "$current_version" ]; then
  echo "No newer stable Chromium version found; exiting."
  exit 0
fi

codex_args=(codex exec)

if [ "${THORIUM_UPDATER_DRY_RUN:-}" = 1 ]; then
  printf 'Updater would run:'
  printf ' %q' "${codex_args[@]}"
  printf ' %q' \
    --dangerously-bypass-approvals-and-sandbox \
    --dangerously-bypass-hook-trust \
    --cd "$thorium_dir" \
    --add-dir "$aur_src_dir" \
    --add-dir "$aur_bin_dir" \
    --output-last-message "$last_message" \
    -
  printf '\n'
  exit 0
fi

{
cat <<PROMPT
Preflight:
- Current Thorium version: ${current_version}
- Latest Chromium stable Linux version: ${latest_version}
- Target update version: ${latest_version}

PROMPT
cat <<'PROMPT'
You are running as a daily unattended Thorium updater for Braulio Oliveira.

Goal:
- Check whether a newer stable Chromium exists than the version in /home/braulio/Projects/thorium/version.sh.
- The wrapper already detected a newer stable Linux release. Use the preflight
  target version above unless official/current sources show a newer stable.
- If no newer stable exists, make no repo changes and exit clearly.
- If a newer minor or major stable exists, update Thorium, build/package it with low priority and 6 jobs, install it locally, push main, update both AUR packages, and push them.

Local paths:
- Thorium repo: /home/braulio/Projects/thorium
- Source AUR repo: /home/braulio/Projects/thorium/aur/thorium-browser-updated
- Binary AUR repo: /home/braulio/Projects/thorium/aur/thorium-browser-updated-bin

Rules:
- Use official/current sources to determine the latest stable Chromium version.
- Keep all changes reproducible in git.
- Do not use destructive git commands.
- Do not change unrelated files.
- Do not push if validation fails.
- Use git author/committer: Braulio Oliveira <brauliobo@gmail.com>.
- Work only on main. Start from the already fast-forwarded main checkout; do
  not create or use an automation branch.
- Use concise commit messages.

Thorium update flow:
- Fetch origin/upstream/chromium as needed.
- Commit the validated update directly to main and push main.
- Run the existing repo tooling first:
  ./infra/rebase_to.sh <version>
  ./infra/rebase_check.sh --with-upstream
- If patches need mechanical porting, update the patch/tool inputs rather than editing Chromium output by hand.
- Preserve the incremental build strategy and build with:
  nice -n 10 ionice -c2 -n7 ./build_incremental.sh 6 --packages
- Reuse the existing Chromium checkout and out/thorium.

Local install:
- Build an Arch package from the generated RPM using the existing packaging logic or AUR bin package.
- Install locally with pacman using sudo when available. Prefer sudo -n; if sudo requires a password and cannot prompt, leave the built package path and report that install was skipped.

Release and AUR:
- Upload the new binary package to github.com/brauliobo/thorium as a release asset named for the version.
- Update /home/braulio/Projects/thorium/aur/thorium-browser-updated:
  - pkgver/pkgrel
  - pinned Thorium git commit
  - .SRCINFO
- Update /home/braulio/Projects/thorium/aur/thorium-browser-updated-bin:
  - pkgver/pkgrel
  - pinned Thorium git commit
  - release asset URL
  - sha256sum
  - .SRCINFO
- Commit and push each AUR repo to AUR.

Validation before pushing:
- ./infra/rebase_check.sh
- makepkg --printsrcinfo works in each AUR repo.
- The binary release asset URL is reachable.
- AUR git remotes are reachable using the configured SSH askpass.

Final response:
- State version checked, whether an update was done, main commit pushed, AUR package commits pushed, local install result, and any blocker.
PROMPT
} | "${codex_args[@]}" \
  --dangerously-bypass-approvals-and-sandbox \
  --dangerously-bypass-hook-trust \
  --cd "$thorium_dir" \
  --add-dir "$aur_src_dir" \
  --add-dir "$aur_bin_dir" \
  --output-last-message "$last_message" \
  -
