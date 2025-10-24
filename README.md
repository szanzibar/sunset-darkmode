# Sunset Dark Mode Automation

Automatically switches macOS between light and dark mode when crossing sunrise/sunset times.

## Installation

```bash
./install.sh
```

This installs dependencies (CoreLocationCLI, jq) and sets up a cron job.

## How It Works

- Runs every 5 minutes via cron (configurable in install.sh)
- Checks location once per hour  
- Fetches sunrise/sunset times when location changes or daily
- **Only triggers** when crossing sunrise/sunset thresholds (doesn't enforce current state)
- Retries location detection 3 times before giving up (It fails a lot)
- Logs include human-readable address for debugging

## Files

- `sunset-darkmode.sh` - Main script
- `cache.json` - Stores location, address, and timing data
- `sunset-darkmode.log` - Activity log with timestamps
- `install.sh` / `uninstall.sh` - Setup/removal

## Uninstall

```bash
./uninstall.sh
```