#!/usr/bin/env bash
# Extracts a single version section from CHANGELOG.md for GitHub Release body.
# Usage: extract-changelog-section.sh <version> [changelog_file]
set -euo pipefail

VERSION="${1:?version required}"
FILE="${2:-CHANGELOG.md}"

if [[ ! -f "$FILE" ]]; then
  echo "Changelog not found: $FILE" >&2
  exit 1
fi

awk -v version="$VERSION" '
  BEGIN { found = 0 }
  /^## \[/ {
    if (found) exit
    if ($0 ~ "\\[" version "\\]") {
      found = 1
      next
    }
  }
  found { print }
' "$FILE"
