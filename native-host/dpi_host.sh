#!/bin/sh
# Native messaging host launcher for macOS / Linux.
# Chrome execs this file; it hands stdio to the Python host, which speaks the
# native messaging protocol and manages the local ciadpi proxy.
DIR="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$DIR/dpi_host.py"
