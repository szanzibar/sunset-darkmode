# Sunset Dark Mode

Automatically switches macOS between light and dark mode based on sunrise/sunset times.

## Installation

```bash
./install.sh
```

Installs dependencies and sets up automation to run every 5 minutes.

## How It Works

- Gets your location and fetches sunrise/sunset times
- Switches to dark mode after sunset, light mode after sunrise
- Forces dark/light mode after long script pause (For example on first boot or after sleeping)
- Configurable offsets (default: sunrise +30min, sunset -30min)
- Runs every 5 minutes, checks location hourly, fetches sunrise/sunset when location changes or daily.
- All intervals are configurable in the script

## Note

CoreLocationCLI can fail frequently. Make sure WiFi is enabled to avoid `kCLErrorDomain error 0`. See troubleshooting notes at https://github.com/fulldecent/corelocationcli

## Uninstall

```bash
./uninstall.sh
```