#!/bin/bash
# Prints the entries of one version's section of CHANGELOG.md, the same text Glide shows in
# What's New after updating. Fails if the section is missing or empty.
# Usage: scripts/changelog-section.sh 0.3.0 [CHANGELOG.md]
set -euo pipefail
version="$1"
file="${2:-CHANGELOG.md}"
section="$(awk -v version="$version" '
    /^## / { inside = ($2 == version || $2 == "v" version); next }
    inside { print }
' "$file" | sed -e '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')"
if [ -z "${section//[[:space:]]/}" ]; then
    echo "CHANGELOG.md has no entries for $version. Add a '## $version' section before tagging." >&2
    exit 1
fi
printf '%s\n' "$section"
