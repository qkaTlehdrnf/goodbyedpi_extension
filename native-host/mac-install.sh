#!/bin/sh
# One-line permanent installer for the GoodbyeDPI companion backend (macOS / Linux).
# Downloads the native messaging host, provides the local ciadpi proxy, and
# registers it with Chrome — so the extension's toggle starts/stops it forever.
# The registration survives reboots; you never need to re-run this.
#
# Run it with a single copy-paste (the extension popup shows this command):
#   curl -fsSL https://raw.githubusercontent.com/qkaTlehdrnf/goodbyedpi_extension/master/native-host/mac-install.sh | sh

set -e

REPO_RAW="https://raw.githubusercontent.com/qkaTlehdrnf/goodbyedpi_extension/master"
STORE_ID="aiclkdmpdfgaeaibbpeeaaolkmfkmiog"
HOST_NAME="com.goodbyedpi.chrome"

case "$(uname -s)" in
  Darwin)
    APP_DIR="$HOME/Library/Application Support/GoodbyeDPIChrome"
    HOST_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
    ;;
  Linux)
    APP_DIR="$HOME/.local/share/GoodbyeDPIChrome"
    HOST_DIR="$HOME/.config/google-chrome/NativeMessagingHosts"
    ;;
  *)
    echo "Unsupported OS: $(uname -s)" >&2
    exit 1
    ;;
esac

echo "==> Installing GoodbyeDPI backend into: $APP_DIR"
mkdir -p "$APP_DIR" "$HOST_DIR"

# 1) Native messaging host (Python) + its launcher.
echo "==> Downloading native host..."
curl -fsSL "$REPO_RAW/native-host/dpi_host.py" -o "$APP_DIR/dpi_host.py"
curl -fsSL "$REPO_RAW/native-host/dpi_host.sh" -o "$APP_DIR/dpi_host.sh"
chmod +x "$APP_DIR/dpi_host.sh" "$APP_DIR/dpi_host.py"

# 2) The ciadpi proxy binary (built from source; byedpi ships no *nix binary).
if [ -f "$APP_DIR/ciadpi" ]; then
  echo "==> ciadpi already present, keeping it."
else
  missing=""
  for tool in git make cc python3; do
    command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
  done
  if [ -n "$missing" ]; then
    echo "Missing build tools:$missing" >&2
    echo "On macOS, install them once with:  xcode-select --install" >&2
    exit 1
  fi
  echo "==> Building ciadpi from source (hufrea/byedpi)..."
  WORK="$(mktemp -d)"
  trap 'rm -rf "$WORK"' EXIT
  git clone --depth 1 https://github.com/hufrea/byedpi "$WORK/byedpi" >/dev/null 2>&1
  make -C "$WORK/byedpi" >/dev/null
  [ -f "$WORK/byedpi/ciadpi" ] || { echo "Build produced no ciadpi binary." >&2; exit 1; }
  cp "$WORK/byedpi/ciadpi" "$APP_DIR/ciadpi"
  chmod +x "$APP_DIR/ciadpi"
fi

# 3) Register the native messaging host with Chrome (permanent).
echo "==> Registering native messaging host..."
cat > "$HOST_DIR/$HOST_NAME.json" <<EOF
{
  "name": "$HOST_NAME",
  "description": "GoodbyeDPI for Chrome native host",
  "path": "$APP_DIR/dpi_host.sh",
  "type": "stdio",
  "allowed_origins": [ "chrome-extension://$STORE_ID/" ]
}
EOF

echo ""
echo "Done. Now fully quit Chrome (Cmd+Q), reopen it, and toggle the extension ON."
echo "To remove later:  rm -rf \"$APP_DIR\" \"$HOST_DIR/$HOST_NAME.json\""
