#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: refresh_patch_from_tree.sh --repo REPO --output PATCH -- PATH [PATH...]

Regenerates PATCH from REPO's current git diff for an explicit path list.
Untracked files inside PATH are added with intent-to-add so git diff includes
them without staging content.
EOF
}

repo=
output=

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      repo="$2"
      shift 2
      ;;
    --output)
      output="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      usage
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

if [[ -z "$repo" || -z "$output" || $# -eq 0 ]]; then
  usage
  exit 2
fi

if [[ ! -d "$repo/.git" ]]; then
  echo "Not a git checkout: $repo" >&2
  exit 1
fi

mapfile -t untracked < <(
  git -C "$repo" ls-files --others --exclude-standard -- "$@"
)

if [[ ${#untracked[@]} -gt 0 ]]; then
  git -C "$repo" add -N -- "${untracked[@]}"
fi

mkdir -p "$(dirname "$output")"
git -C "$repo" diff --binary --no-ext-diff -- "$@" > "$output"

if [[ ! -s "$output" ]]; then
  echo "No diff generated for $output" >&2
  exit 1
fi
