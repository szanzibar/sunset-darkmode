#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/sunset-darkmode.sh"
PLIST_DEST="$HOME/Library/LaunchAgents/com.user.sunset-darkmode.plist"

chmod +x "$SCRIPT_PATH"

command -v CoreLocationCLI >/dev/null || brew install corelocationcli
command -v jq >/dev/null || brew install jq

sed "s|SCRIPT_DIR_PLACEHOLDER|$SCRIPT_DIR|g" com.user.sunset-darkmode.plist > "$PLIST_DEST"

launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load "$PLIST_DEST"

echo "Setup complete."