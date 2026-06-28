#!/usr/bin/env bash
# Builds meshpad_p2p_native for Android ABIs into jniLibs (PLAN 8.4).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT/native/meshpad_p2p_native/Cargo.toml"
JNI_OUT="$ROOT/apps/meshpad/android/app/src/main/jniLibs"

resolve_ndk() {
  if [ -n "${ANDROID_NDK_HOME:-}" ] && [ -d "$ANDROID_NDK_HOME" ]; then
    return 0
  fi
  if [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME/ndk" ]; then
    ANDROID_NDK_HOME="$(find "$ANDROID_HOME/ndk" -maxdepth 1 -mindepth 1 -type d | sort -V | tail -1)"
    export ANDROID_NDK_HOME
    return 0
  fi
  if [ -n "${NDK_HOME:-}" ] && [ -d "$NDK_HOME" ]; then
    export ANDROID_NDK_HOME="$NDK_HOME"
    return 0
  fi
  return 1
}

if ! command -v cargo-ndk >/dev/null 2>&1; then
  echo "cargo-ndk not found. Install: cargo install cargo-ndk"
  if [ "${MESHPAD_REQUIRE_ANDROID_FFI:-}" = "1" ]; then
    exit 1
  fi
  exit 0
fi

if ! resolve_ndk; then
  echo "Android NDK not found (set ANDROID_NDK_HOME or install SDK NDK)."
  if [ "${MESHPAD_REQUIRE_ANDROID_FFI:-}" = "1" ]; then
    exit 1
  fi
  exit 0
fi

echo "Using NDK: $ANDROID_NDK_HOME"
mkdir -p "$JNI_OUT"

# arm64-v8a (devices), armeabi-v7a (older devices), x86_64 (emulator)
cargo ndk \
  -t arm64-v8a \
  -t armeabi-v7a \
  -t x86_64 \
  -o "$JNI_OUT" \
  build --manifest-path "$MANIFEST" --lib --release

echo "Android jniLibs:"
find "$JNI_OUT" -name 'libmeshpad_p2p_native.so' -print
