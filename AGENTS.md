# AGENTS.md

Essential instructions for coding agents working on this Thorium repo.

## Repo Model

This is not a full Chromium checkout. It is a Thorium overlay and patch set
applied onto Chromium at `$CR_SRC_DIR` (`$HOME/chromium/src` by default).
Chromium is expected to be a git/gclient checkout from
`https://chromium.googlesource.com/chromium/src.git`, not a release tarball.

- `src/<path>` overlays `$CR_SRC_DIR/<path>`.
- `other/*.patch` contains replayable Chromium/V8/FFmpeg patches.
- `infra/*` contains tooling, packaging helpers, and generated-input helpers.
- Chromium version is pinned by `THOR_VER` in `version.sh` and `CR_VER` in
  `upstream_version.sh`.

## Canonical Workflow

```bash
./trunk.sh
./version.sh
./setup.sh [flavour]
./build.sh <jobs>
```

Use `CR_DIR=/path/to/chromium/src` to override the Chromium checkout.

For local incremental Linux rebuilds, prefer:

```bash
./build_incremental.sh 6
./build_incremental.sh 6 --packages
```

It keeps `out/thorium`, uses `nice`/`ionice`, disables unnecessary full rebuilds,
and limits builds to 6 jobs by default.

For a version bump, use:

```bash
./infra/rebase_to.sh <chromium-tag>
```

It updates the pinned versions, syncs Chromium, applies the overlay, writes the
upstream diff report, and stops before building.

## Current Rebase Rules

- Chromium target for this PR is `148.0.7778.215`.
- Do not restore `thorium-libjxl`; Chromium M147+ has native JPEG XL build
  integration via `enable_jxl_decoder`.
- Keep Chrome/Chromium source changes reproducible through `src/`, `other/`,
  or `infra/` tooling. Do not rely on manual edits inside `$CR_SRC_DIR`.
- `setup.sh` patching must stay idempotent. Per-patch apply/check/skip logic is
  required; do not reintroduce one global sentinel file for all patches.
- Generated translation additions live under
  `src/chrome/app/resources/thorium_additions/` and are merged by
  `infra/merge_thorium_xtb.py`, replacing the old huge translate patch.
- API keys stay outside git in `API_KEYS.txt`; regenerate
  `other/google-api-keys-defaults.patch` with
  `infra/generate_google_api_keys_patch.sh --input API_KEYS.txt --output other/google-api-keys-defaults.patch`
  when keys change.
- Windows-only patches may stay disabled until Linux is green, but keep them
  named clearly as disabled/deferred.

## Editing Rules

- Do not run `git add -A`.
- Do not commit unless the user explicitly asks for a commit.
- Keep large build artifacts, packages, Chromium checkouts, and worktree output
  out of git.
- Prefer deleting obsolete overlays/patches when upstream already carries the
  behavior.
- Keep `args.gn` host-neutral where possible. If staging it locally, rewrite the
  `/home/alex/chromium/src` PGO path for the local checkout.

## Validation

Before considering a PR branch ready:

```bash
./infra/rebase_check.sh
./setup.sh
find "$CR_SRC_DIR" -name '*.rej' -print
./build_incremental.sh 6
./build_incremental.sh 6 --packages
```

Smoke checks:

- `thorium-browser --version` reports the pinned Thorium version.
- `navigator.globalPrivacyControl` is `true`.
- Chrome sync is available when Thorium API keys are present.
- Installed package permissions are standard, especially `chrome-sandbox`
  owned by root with mode `4755`.
