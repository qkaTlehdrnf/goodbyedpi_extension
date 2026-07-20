#!/bin/sh
# One-line permanent installer for the GoodbyeDPI companion backend (macOS / Linux).
# Downloads the native messaging host, provides the local ciadpi proxy, and
# registers it with Chrome — so the extension's toggle starts/stops it forever.
# The registration survives reboots; you never need to re-run this.
#
# Run it with a single copy-paste (the extension popup shows this command):
#   curl -fsSL https://raw.githubusercontent.com/qkaTlehdrnf/goodbyedpi_extension/master/native-host/mac-install.sh | sh
#
# Loading the extension unpacked (chrome://extensions -> Load unpacked) gives it
# a different ID than the Web Store build. Pass that ID so the native host will
# accept it too:
#   curl -fsSL .../mac-install.sh | sh -s -- <your-unpacked-extension-id>

set -e

REPO_RAW="https://raw.githubusercontent.com/qkaTlehdrnf/goodbyedpi_extension/master"
STORE_ID="aiclkdmpdfgaeaibbpeeaaolkmfkmiog"
HOST_NAME="com.goodbyedpi.chrome"
# Optional extra extension ID (e.g. an unpacked/dev load) to also allow.
EXTRA_ID="$1"

RELEASE_DL="https://github.com/qkaTlehdrnf/goodbyedpi_extension/releases/latest/download"

case "$(uname -s)" in
  Darwin)
    APP_DIR="$HOME/Library/Application Support/GoodbyeDPIChrome"
    HOST_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
    CIADPI_ASSET="ciadpi-macos"
    ;;
  Linux)
    APP_DIR="$HOME/.local/share/GoodbyeDPIChrome"
    HOST_DIR="$HOME/.config/google-chrome/NativeMessagingHosts"
    CIADPI_ASSET="ciadpi-linux-x86_64"
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

# 2) The ciadpi proxy binary. Prefer the prebuilt release asset (no compiler
#    needed); fall back to building from source if the download is unavailable.
build_from_source() {
  missing=""
  for tool in git make cc; do
    command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
  done
  if [ -n "$missing" ]; then
    echo "Could not download a prebuilt ciadpi, and build tools are missing:$missing" >&2
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
}

# Confirms the binary actually loads and runs on this machine's architecture.
ciadpi_works() {
  [ -x "$1" ] || return 1
  "$1" --definitely-not-a-flag 2>&1 | grep -q "unrecognized option"
}

if [ -f "$APP_DIR/ciadpi" ]; then
  echo "==> ciadpi already present, keeping it."
else
  echo "==> Downloading prebuilt ciadpi..."
  if curl -fsSL "$RELEASE_DL/$CIADPI_ASSET" -o "$APP_DIR/ciadpi.tmp" 2>/dev/null; then
    chmod +x "$APP_DIR/ciadpi.tmp"
    # curl doesn't set the quarantine flag, but clear it defensively so Gatekeeper
    # never blocks the unsigned binary.
    xattr -c "$APP_DIR/ciadpi.tmp" 2>/dev/null || true
    if ciadpi_works "$APP_DIR/ciadpi.tmp"; then
      mv "$APP_DIR/ciadpi.tmp" "$APP_DIR/ciadpi"
      echo "==> Installed prebuilt ciadpi."
    else
      echo "==> Prebuilt binary did not run here; building instead."
      rm -f "$APP_DIR/ciadpi.tmp"
      build_from_source
    fi
  else
    echo "==> No prebuilt download available; building instead."
    rm -f "$APP_DIR/ciadpi.tmp"
    build_from_source
  fi
fi

# 3) Register the native messaging host with Chrome (permanent).
echo "==> Registering native messaging host..."
# Always trust the Web Store build; also trust an unpacked/dev ID when given.
# The popup passes the running extension's own id, which for Store users equals
# STORE_ID — so skip it when identical to avoid a duplicate origin.
ORIGINS="    \"chrome-extension://$STORE_ID/\""
if [ -n "$EXTRA_ID" ] && [ "$EXTRA_ID" != "$STORE_ID" ]; then
  ORIGINS="$ORIGINS,
    \"chrome-extension://$EXTRA_ID/\""
  echo "==> Also allowing unpacked extension: $EXTRA_ID"
fi
cat > "$HOST_DIR/$HOST_NAME.json" <<EOF
{
  "name": "$HOST_NAME",
  "description": "GoodbyeDPI for Chrome native host",
  "path": "$APP_DIR/dpi_host.sh",
  "type": "stdio",
  "allowed_origins": [
$ORIGINS
  ]
}
EOF

echo ""
echo "Done. Now fully quit Chrome (Cmd+Q), reopen it, and toggle the extension ON."
echo "To remove later:  rm -rf \"$APP_DIR\" \"$HOST_DIR/$HOST_NAME.json\""
