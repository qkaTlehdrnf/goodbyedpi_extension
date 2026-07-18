#!/bin/sh
# Removes the native messaging host registration for Chrome on macOS / Linux.
# Usage: ./uninstall-host.sh

set -e
HOST_NAME="com.goodbyedpi.chrome"

case "$(uname -s)" in
  Darwin) TARGET_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts" ;;
  Linux)  TARGET_DIR="$HOME/.config/google-chrome/NativeMessagingHosts" ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

MANIFEST="$TARGET_DIR/$HOST_NAME.json"
if [ -f "$MANIFEST" ]; then
  rm -f "$MANIFEST"
  echo "Removed: $MANIFEST"
else
  echo "No registration found."
fi
echo "If ciadpi is still running: pkill -f ciadpi"
