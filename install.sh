#!/usr/bin/env bash
set -euo pipefail

REPO="codecorrupt/brouter"
INSTALL_DIR="$HOME/Applications"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This installer only works on macOS." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required" >&2
  exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
  echo "unzip is required" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"

if ! LATEST_URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep browser_download_url \
  | grep -E 'Brouter-.*\.zip' \
  | cut -d '"' -f 4); then
  echo "Failed to determine download URL" >&2
  exit 1
fi

echo "Downloading Brouter.app…"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

curl -fsSL "$LATEST_URL" -o "$TMP_DIR/Brouter.zip"
unzip -q "$TMP_DIR/Brouter.zip" -d "$TMP_DIR"

echo "Installing to $INSTALL_DIR"
rm -rf "$INSTALL_DIR/Brouter.app" 
mv "$TMP_DIR/Brouter.app" "$INSTALL_DIR/"

echo "Removing quarantine attributes"
xattr -cr "$INSTALL_DIR/Brouter.app"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/brouter"
CONFIG_FILE="$CONFIG_DIR/config"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Installing example config to $CONFIG_FILE"
  mkdir -p "$CONFIG_DIR"
  curl -fsSL "https://raw.githubusercontent.com/$REPO/main/src/example-config" -o "$CONFIG_FILE"
else
  echo "Config already exists, leaving it untouched"
fi

echo "Installed Brouter."
echo "Next step: Run this command to open System Settings and set Brouter as your default browser:"
echo "    open \"x-apple.systempreferences:com.apple.Desktop-Settings.extension?DefaultWebBrowser\""
