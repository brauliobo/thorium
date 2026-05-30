#!/bin/bash

# Copyright (c) 2026 Alex313031.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

input="${repo_root}/API_KEYS.txt"
output=""

usage() {
  cat <<EOF
Usage: ${0##*/} [--input API_KEYS.txt] [--output PATCH]

Reads local Google API credentials and writes a Chromium patch for
google_apis/default_api_keys.{h,inc.cc}. If --output is omitted, the patch is
printed to stdout.

Accepted key names include GN-style lowercase names and environment-style
uppercase names:
  google_api_key / GOOGLE_API_KEY
  google_default_client_id / GOOGLE_DEFAULT_CLIENT_ID
  google_default_client_secret / GOOGLE_DEFAULT_CLIENT_SECRET

Optional remoting/SODA values are also accepted:
  google_api_key_remoting / GOOGLE_API_KEY_REMOTING
  google_client_id_remoting / GOOGLE_CLIENT_ID_REMOTING
  google_client_secret_remoting / GOOGLE_CLIENT_SECRET_REMOTING
  google_api_key_soda / GOOGLE_API_KEY_SODA
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input|-i)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      input="$2"
      shift 2
      ;;
    --output|-o)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      output="$2"
      shift 2
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

if [[ ! -f "${input}" ]]; then
  echo "Missing API key file: ${input}" >&2
  exit 1
fi

api_key=""
client_id=""
client_secret=""
api_key_remoting=""
client_id_remoting=""
client_secret_remoting=""
api_key_soda=""

set_value() {
  local name="$1"
  local value="$2"

  case "${name}" in
    google_api_key|GOOGLE_API_KEY|google_default_api_key|GOOGLE_DEFAULT_API_KEY)
      api_key="${value}"
      ;;
    google_default_client_id|GOOGLE_DEFAULT_CLIENT_ID|google_client_id_main|GOOGLE_CLIENT_ID_MAIN)
      client_id="${value}"
      ;;
    google_default_client_secret|GOOGLE_DEFAULT_CLIENT_SECRET|google_client_secret_main|GOOGLE_CLIENT_SECRET_MAIN)
      client_secret="${value}"
      ;;
    google_api_key_remoting|GOOGLE_API_KEY_REMOTING)
      api_key_remoting="${value}"
      ;;
    google_client_id_remoting|GOOGLE_CLIENT_ID_REMOTING)
      client_id_remoting="${value}"
      ;;
    google_client_secret_remoting|GOOGLE_CLIENT_SECRET_REMOTING)
      client_secret_remoting="${value}"
      ;;
    google_api_key_soda|GOOGLE_API_KEY_SODA)
      api_key_soda="${value}"
      ;;
  esac
}

while IFS= read -r line || [[ -n "${line}" ]]; do
  [[ "${line}" =~ ^[[:space:]]*# ]] && continue
  [[ "${line}" =~ ^[[:space:]]*$ ]] && continue

  if [[ "${line}" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*\"([^\"]*)\" ]]; then
    set_value "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  elif [[ "${line}" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*([^[:space:]#]+) ]]; then
    set_value "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  fi
done < "${input}"

missing=()
[[ -n "${api_key}" ]] || missing+=(google_api_key)
[[ -n "${client_id}" ]] || missing+=(google_default_client_id)
[[ -n "${client_secret}" ]] || missing+=(google_default_client_secret)

if [[ ${#missing[@]} -gt 0 ]]; then
  printf 'Missing required API_KEYS.txt value(s): %s\n' "${missing[*]}" >&2
  exit 1
fi

c_string() {
  local value="$1"

  if [[ "${value}" == *$'\n'* || "${value}" == *$'\r'* ]]; then
    echo "API key values must be single-line strings." >&2
    exit 1
  fi

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "${value}"
}

api_key_remoting="${api_key_remoting:-${api_key}}"
client_id_remoting="${client_id_remoting:-dummytoken}"
client_secret_remoting="${client_secret_remoting:-dummytoken}"
api_key_soda="${api_key_soda:-dummytoken}"

patch="$(
  cat <<EOF
diff --git a/google_apis/default_api_keys-inc.cc b/google_apis/default_api_keys-inc.cc
--- a/google_apis/default_api_keys-inc.cc
+++ b/google_apis/default_api_keys-inc.cc
@@ -16,7 +16,7 @@
 // Please keep this file's list of dependencies minimal.
 
 #if !defined(GOOGLE_API_KEY)
-#define GOOGLE_API_KEY google_apis::DefaultApiKeys::kUnsetApiToken
+#define GOOGLE_API_KEY google_apis::DefaultApiKeys::kThorApiKey
 #endif
 
 #if !defined(GOOGLE_METRICS_SIGNING_KEY)
@@ -31,41 +31,41 @@
 #endif  // #if BUILDFLAG(SUPPORT_CDM_SERVER_CERTIFICATE)
 
 #if !defined(GOOGLE_CLIENT_ID_MAIN)
-#define GOOGLE_CLIENT_ID_MAIN google_apis::DefaultApiKeys::kUnsetApiToken
+#define GOOGLE_CLIENT_ID_MAIN google_apis::DefaultApiKeys::kThorClientId
 #endif
 
 #if !defined(GOOGLE_CLIENT_SECRET_MAIN)
-#define GOOGLE_CLIENT_SECRET_MAIN google_apis::DefaultApiKeys::kUnsetApiToken
+#define GOOGLE_CLIENT_SECRET_MAIN google_apis::DefaultApiKeys::kThorClientSecret
 #endif
 
 #if !defined(GOOGLE_CLIENT_ID_REMOTING)
-#define GOOGLE_CLIENT_ID_REMOTING google_apis::DefaultApiKeys::kUnsetApiToken
+#define GOOGLE_CLIENT_ID_REMOTING google_apis::DefaultApiKeys::kThorClientIdRemoting
 #endif
 
 #if !defined(GOOGLE_CLIENT_SECRET_REMOTING)
 #define GOOGLE_CLIENT_SECRET_REMOTING \\
-  google_apis::DefaultApiKeys::kUnsetApiToken
+  google_apis::DefaultApiKeys::kThorClientSecretRemoting
 #endif
 
 #if !defined(GOOGLE_CLIENT_ID_REMOTING_HOST)
 #define GOOGLE_CLIENT_ID_REMOTING_HOST \\
-  google_apis::DefaultApiKeys::kUnsetApiToken
+  google_apis::DefaultApiKeys::kThorClientIdRemoting
 #endif
 
 #if !defined(GOOGLE_CLIENT_SECRET_REMOTING_HOST)
 #define GOOGLE_CLIENT_SECRET_REMOTING_HOST \\
-  google_apis::DefaultApiKeys::kUnsetApiToken
+  google_apis::DefaultApiKeys::kThorClientSecretRemoting
 #endif
 
 #if BUILDFLAG(IS_ANDROID)
 #if !defined(GOOGLE_API_KEY_ANDROID_NON_STABLE)
 #define GOOGLE_API_KEY_ANDROID_NON_STABLE \\
-  google_apis::DefaultApiKeys::kUnsetApiToken
+  google_apis::DefaultApiKeys::kThorApiKey
 #endif
 #endif
 
 #if !defined(GOOGLE_API_KEY_REMOTING)
-#define GOOGLE_API_KEY_REMOTING google_apis::DefaultApiKeys::kUnsetApiToken
+#define GOOGLE_API_KEY_REMOTING google_apis::DefaultApiKeys::kThorApiKeyRemoting
 #endif
 
 // API key for the Speech On-Device API (SODA).
 #if !defined(GOOGLE_API_KEY_SODA)
-#define GOOGLE_API_KEY_SODA google_apis::DefaultApiKeys::kUnsetApiToken
+#define GOOGLE_API_KEY_SODA google_apis::DefaultApiKeys::kThorApiKeySoda
 #endif
@@ -120,10 +120,10 @@
 // IDs and secrets above that have not been set (and only those; they
 // will not override already-set values).
 #if !defined(GOOGLE_DEFAULT_CLIENT_ID)
-#define GOOGLE_DEFAULT_CLIENT_ID ""
+#define GOOGLE_DEFAULT_CLIENT_ID google_apis::DefaultApiKeys::kThorClientId
 #endif
 #if !defined(GOOGLE_DEFAULT_CLIENT_SECRET)
-#define GOOGLE_DEFAULT_CLIENT_SECRET ""
+#define GOOGLE_DEFAULT_CLIENT_SECRET google_apis::DefaultApiKeys::kThorClientSecret
 #endif
 
 constexpr ::google_apis::DefaultApiKeys GetDefaultApiKeysFromDefinedValues() {
diff --git a/google_apis/default_api_keys.h b/google_apis/default_api_keys.h
--- a/google_apis/default_api_keys.h
+++ b/google_apis/default_api_keys.h
@@ -18,6 +18,21 @@ struct DefaultApiKeys {
   // various unit tests than leaving the token empty.
   static constexpr char kUnsetApiToken[] = "dummytoken";
 
+  static constexpr char kThorApiKey[] =
+      $(c_string "${api_key}");
+  static constexpr char kThorClientId[] =
+      $(c_string "${client_id}");
+  static constexpr char kThorClientSecret[] =
+      $(c_string "${client_secret}");
+  static constexpr char kThorApiKeyRemoting[] =
+      $(c_string "${api_key_remoting}");
+  static constexpr char kThorClientIdRemoting[] =
+      $(c_string "${client_id_remoting}");
+  static constexpr char kThorClientSecretRemoting[] =
+      $(c_string "${client_secret_remoting}");
+  static constexpr char kThorApiKeySoda[] =
+      $(c_string "${api_key_soda}");
+
   bool allow_unset_values;
   bool allow_override_via_environment;
   bool is_using_google_chrome_keys;
EOF
)"

if [[ -n "${output}" ]]; then
  mkdir -p "$(dirname "${output}")"
  tmp="$(mktemp "${output}.XXXXXX")"
  printf '%s\n' "${patch}" > "${tmp}"
  mv "${tmp}" "${output}"
else
  printf '%s\n' "${patch}"
fi
