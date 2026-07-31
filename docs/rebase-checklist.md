# M148+ Rebase Checklist

Use this short gate list before marking a Alacrium M148+ update ready for PR
review.

- For a version bump, start with:
  `./infra/rebase_to.sh <chromium-tag>`
- Confirm `$CR_SRC_DIR` is a Chromium git/gclient checkout, not a release
  tarball. `./trunk.sh` bootstraps one when missing.
- Run syntax checks:
  `./infra/rebase_check.sh`
- For Chromium patch applicability, run:
  `./infra/rebase_check.sh --with-upstream`
- If API keys changed, regenerate the sync-defaults patch:
  `./infra/generate_google_api_keys_patch.sh --input API_KEYS.txt --output other/google-api-keys-defaults.patch`
- Run setup and confirm it completes without patch rejects:
  `./setup.sh`
- Confirm no rejects were produced:
  `find "$CR_SRC_DIR" -name '*.rej' -print`
- Build the browser:
  `./build_incremental.sh 6`
- Build packages:
  `./build_incremental.sh 6 --packages`
- Smoke check `navigator.globalPrivacyControl` is `true`.
- Smoke check Chrome sync is available when Alacrium API keys are present.
- Verify installed `chrome-sandbox` permissions are standard:
  root-owned with mode `4755`.
- Confirm no scratch files, build output, packages, or Chromium checkout files
  are staged for the PR.
