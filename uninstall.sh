#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_DEST="$HOME/Library/LaunchAgents/com.user.sunset-darkmode.plist"

launchctl unload "$PLIST_DEST" 2>/dev/null
rm -f "$PLIST_DEST"
rm -f "$SCRIPT_DIR/cache.json"
rm -f "$SCRIPT_DIR/sunset-darkmode.log"

echo "Uninstalled."