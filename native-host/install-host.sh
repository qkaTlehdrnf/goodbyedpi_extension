#!/bin/sh
# Registers the native messaging host for Chrome on macOS / Linux (current user).
# After this, the extension's toggle can start/stop ciadpi automatically and the
# registration survives reboots — no need to re-run it.
#
# Usage:
#   ./install-host.sh              # uses the published Chrome Web Store ID
#   ./install-host.sh <extension-id>   # for a locally loaded (unpacked) extension
#
# Requires python3 (macOS: install Xcode Command Line Tools -> xcode-select --install).

set -e

# The published Chrome Web Store extension ID (same for every user).
STORE_ID="aiclkdmpdfgaeaibbpeeaaolkmfkmiog"
EXT_ID="${1:-$STORE_ID}"

DIR="$(cd "$(dirname "$0")" && pwd)"
LAUNCHER="$DIR/dpi_host.sh"
HOST_NAME="com.goodbyedpi.chrome"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found. On macOS run: xcode-select --install" >&2
  exit 1
fi

# Chrome's per-user native messaging host directory differs by OS.
case "$(uname -s)" in
  Darwin) TARGET_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts" ;;
  Linux)  TARGET_DIR="$HOME/.config/google-chrome/NativeMessagingHosts" ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

chmod +x "$LAUNCHER" "$DIR/dpi_host.py"
mkdir -p "$TARGET_DIR"

cat > "$TARGET_DIR/$HOST_NAME.json" <<EOF
{
  "name": "$HOST_NAME",
  "description": "GoodbyeDPI for Chrome native host",
  "path": "$LAUNCHER",
  "type": "stdio",
  "allowed_origins": [ "chrome-extension://$EXT_ID/" ]
}
EOF

echo "Install complete."
echo "  manifest : $TARGET_DIR/$HOST_NAME.json"
echo "  launcher : $LAUNCHER"
echo "  extension: $EXT_ID"
echo
if [ ! -f "$DIR/ciadpi" ] && [ ! -f "$DIR/../backend/ciadpi" ]; then
  echo "NOTE: ciadpi binary not found yet. Build it with: backend/get-ciadpi.sh"
  echo
fi
echo "Now fully quit Chrome, reopen it, and toggle the extension ON."
