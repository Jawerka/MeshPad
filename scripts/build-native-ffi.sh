#!/usr/bin/env bash
# Builds meshpad_p2p_native cdylib and copies into Flutter runner/native (PLAN 8.4).
set -euo pipefail

PROFILE="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT/native/meshpad_p2p_native/Cargo.toml"

if [[ "$PROFILE" == "release" ]]; then
  cargo build --manifest-path "$MANIFEST" --lib --release
else
  cargo build --manifest-path "$MANIFEST" --lib
fi

SRC="$ROOT/native/meshpad_p2p_native/target/$PROFILE/libmeshpad_p2p_native.so"
DST_DIR="$ROOT/apps/meshpad/linux/runner/native"

mkdir -p "$DST_DIR"
cp -f "$SRC" "$DST_DIR/libmeshpad_p2p_native.so"
echo "Copied to $DST_DIR/libmeshpad_p2p_native.so"
