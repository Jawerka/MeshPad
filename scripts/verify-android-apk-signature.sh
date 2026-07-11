#!/usr/bin/env bash
set -euo pipefail

# Verify a release APK is signed with the expected MeshPad release certificate.
# Usage: scripts/verify-android-apk-signature.sh path/to/app-release.apk

APK="${1:-}"
FINGERPRINT_FILE="$(cd "$(dirname "$0")" && pwd)/android-release-cert-sha256.txt"

if [[ -z "$APK" || ! -f "$APK" ]]; then
  echo "Usage: $0 path/to/app-release.apk" >&2
  exit 1
fi

if [[ ! -f "$FINGERPRINT_FILE" ]]; then
  echo "Missing fingerprint file: $FINGERPRINT_FILE" >&2
  exit 1
fi

EXPECTED="$(tr -d '[:space:]' <"$FINGERPRINT_FILE")"
if [[ -z "$EXPECTED" ]]; then
  echo "Expected SHA-256 fingerprint is empty in $FINGERPRINT_FILE" >&2
  exit 1
fi

if [[ -z "${ANDROID_HOME:-}" && -z "${ANDROID_SDK_ROOT:-}" ]]; then
  echo "ANDROID_HOME or ANDROID_SDK_ROOT must be set" >&2
  exit 1
fi

SDK="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
APKSIGNER="$(find "$SDK/build-tools" -name apksigner -type f 2>/dev/null | sort -V | tail -1)"
if [[ -z "$APKSIGNER" || ! -x "$APKSIGNER" ]]; then
  echo "apksigner not found under $SDK/build-tools" >&2
  exit 1
fi

CERTS="$("$APKSIGNER" verify --print-certs "$APK" 2>/dev/null || true)"
if [[ -z "$CERTS" ]]; then
  echo "apksigner could not read certificates from $APK" >&2
  exit 1
fi

ACTUAL="$(echo "$CERTS" | grep -oE 'SHA-256 digest: [0-9A-F:]+' | head -1 | sed 's/SHA-256 digest: //' | tr -d ':')"
EXPECTED_NORM="$(echo "$EXPECTED" | tr '[:lower:]' '[:upper:]' | tr -d ':')"
ACTUAL_NORM="$(echo "$ACTUAL" | tr '[:lower:]' '[:upper:]' | tr -d ':')"

if [[ "$ACTUAL_NORM" != "$EXPECTED_NORM" ]]; then
  echo "APK signature mismatch." >&2
  echo "  expected SHA-256: $EXPECTED_NORM" >&2
  echo "  actual SHA-256:   $ACTUAL_NORM" >&2
  exit 1
fi

echo "APK signed with expected MeshPad release certificate."
