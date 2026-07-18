#!/bin/sh
# Builds ByeDPI (ciadpi) from source into this folder, for macOS / Linux.
# hufrea/byedpi ships Windows/Android binaries only, so desktop *nix builds from
# source. Requires: git, make, and a C compiler.
#   macOS: xcode-select --install
#   Linux: sudo apt install build-essential git   (or your distro's equivalent)
#
# Usage: ./get-ciadpi.sh

set -e
HERE="$(cd "$(dirname "$0")" && pwd)"

for tool in git make cc; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Missing '$tool'. See the notes at the top of this script." >&2; exit 1; }
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Cloning hufrea/byedpi..."
git clone --depth 1 https://github.com/hufrea/byedpi "$WORK/byedpi"

echo "Building..."
make -C "$WORK/byedpi"

BIN="$WORK/byedpi/ciadpi"
[ -f "$BIN" ] || { echo "Build finished but no 'ciadpi' binary was produced." >&2; exit 1; }

cp "$BIN" "$HERE/ciadpi"
chmod +x "$HERE/ciadpi"
echo "Done  ->  $HERE/ciadpi"
