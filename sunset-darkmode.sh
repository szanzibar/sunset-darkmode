#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_FILE="$SCRIPT_DIR/cache.json"
LOG_FILE="$SCRIPT_DIR/sunset-darkmode.log"

LOCATION_CHECK_INTERVAL=3600
SUNRISE_SUNSET_FETCH_INTERVAL=86400

# Offset constants (in minutes) Positive = later, Negative = earlier
SUNRISE_OFFSET_MINUTES=30
SUNSET_OFFSET_MINUTES=-30
FORCE_MODE_THRESHOLD=3600

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

get_location() {
    for i in {1..3}; do
        if location_output=$(CoreLocationCLI --format $'%latitude %longitude\n%address' 2>/dev/null); then
            echo "$location_output"
            return 0
        fi
        sleep 1
    done
    log "Location detection failed"
    return 1
}

fetch_sunrise_sunset() {
    local response=$(curl -s --max-time 10 "https://api.sunrisesunset.io/json?lat=$1&lng=$2&time_format=24")
    if echo "$response" | jq -e '.status == "OK"' >/dev/null 2>&1; then
        echo "$response"
        return 0
    fi
    log "Sunrise sunset API call failed"
    return 1
}

time_to_minutes() {
    local time_str="$1"
    if [[ "$time_str" == *" "* ]]; then
        time_str=$(echo "$time_str" | cut -d' ' -f2)
    fi
    local hour=$(echo "$time_str" | cut -d':' -f1)
    local minute=$(echo "$time_str" | cut -d':' -f2)
    echo $((10#$hour * 60 + 10#$minute))
}

apply_offset() {
    local minutes=$(time_to_minutes "$1")
    local adjusted=$((minutes + $2))
    
    if (( adjusted < 0 )); then
        adjusted=$((adjusted + 1440))
    elif (( adjusted >= 1440 )); then
        adjusted=$((adjusted - 1440))
    fi
    
    printf "%02d:%02d:00" $((adjusted / 60)) $((adjusted % 60))
}

set_appearance() {
    osascript -e "tell app \"System Events\" to tell appearance preferences to set dark mode to $1" 2>/dev/null
}

main() {
    command -v CoreLocationCLI >/dev/null || { log "CoreLocationCLI not found"; exit 1; }
    command -v jq >/dev/null || { log "jq not found"; exit 1; }
    
    log "Check started"
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    local cache_data=$(cat "$CACHE_FILE" 2>/dev/null || echo "{}")
    
    local last_location_check=$(echo "$cache_data" | jq -r '.last_location_check // ""')
    local cached_location=$(echo "$cache_data" | jq -r '.location // ""')
    local cached_address=$(echo "$cache_data" | jq -r '.address // ""')
    local last_sunrise_fetch=$(echo "$cache_data" | jq -r '.last_sunrise_sunset_fetch // ""')
    local cached_sunrise=$(echo "$cache_data" | jq -r '.sunrise // ""')
    local cached_sunset=$(echo "$cache_data" | jq -r '.sunset // ""')
    local last_check=$(echo "$cache_data" | jq -r '.last_check_time // ""')
    
    local current_timestamp=$(date -j -f "%Y-%m-%d %H:%M:%S" "$current_time" +%s)
    local location_changed=false
    
    # Check location if needed
    if [[ -z "$last_location_check" ]] || 
       (( current_timestamp - $(date -j -f "%Y-%m-%d %H:%M:%S" "$last_location_check" +%s 2>/dev/null || echo 0) > LOCATION_CHECK_INTERVAL )); then
        if location_data=$(get_location); then
            local current_location=$(echo "$location_data" | head -1)
            local current_address=$(echo "$location_data" | tail -n +2 | tr '\n' ' ')
            
            if [[ "$current_location" != "$cached_location" ]]; then
                location_changed=true
                log "Location changed to $current_location ($current_address)"
            fi
            
            cache_data=$(echo "$cache_data" | jq \
                --arg time "$current_time" \
                --arg loc "$current_location" \
                --arg addr "$current_address" \
                '.last_location_check = $time | .location = $loc | .address = $addr')
            cached_location="$current_location"
        fi
    fi
    
    # Fetch sunrise/sunset if needed
    if [[ "$location_changed" == true ]] || [[ -z "$last_sunrise_fetch" ]] ||
       (( current_timestamp - $(date -j -f "%Y-%m-%d %H:%M:%S" "$last_sunrise_fetch" +%s 2>/dev/null || echo 0) > SUNRISE_SUNSET_FETCH_INTERVAL )); then
        if [[ -n "$cached_location" ]]; then
            local lat=$(echo "$cached_location" | cut -d' ' -f1)
            local lng=$(echo "$cached_location" | cut -d' ' -f2)
            
            if sunrise_sunset_data=$(fetch_sunrise_sunset "$lat" "$lng"); then
                cached_sunrise=$(echo "$sunrise_sunset_data" | jq -r '.results.sunrise')
                cached_sunset=$(echo "$sunrise_sunset_data" | jq -r '.results.sunset')
                
                log "Updated sunrise/sunset: $cached_sunrise / $cached_sunset"
                cache_data=$(echo "$cache_data" | jq \
                    --arg time "$current_time" \
                    --arg sunrise "$cached_sunrise" \
                    --arg sunset "$cached_sunset" \
                    '.last_sunrise_sunset_fetch = $time | .sunrise = $sunrise | .sunset = $sunset')
            fi
        fi
    fi
    
    # Check if we need to switch modes
    if [[ -n "$cached_sunrise" && -n "$cached_sunset" ]]; then
        local adjusted_sunrise=$(apply_offset "$cached_sunrise" "$SUNRISE_OFFSET_MINUTES")
        local adjusted_sunset=$(apply_offset "$cached_sunset" "$SUNSET_OFFSET_MINUTES")
        local current_minutes=$(time_to_minutes "$current_time")
        local sunrise_minutes=$(time_to_minutes "$adjusted_sunrise")
        local sunset_minutes=$(time_to_minutes "$adjusted_sunset")
        
        local should_switch=false
        local reason=""
        local dark_mode=false
        
        # Force mode if last check was over an hour ago or first time
        if [[ -z "$last_check" ]] || 
           (( current_timestamp - $(date -j -f "%Y-%m-%d %H:%M:%S" "$last_check" +%s 2>/dev/null || echo 0) > FORCE_MODE_THRESHOLD )); then
            should_switch=true
            if (( current_minutes > sunset_minutes || current_minutes < sunrise_minutes )); then
                dark_mode=true
                reason="force mode - setting dark (sunset: $adjusted_sunset)"
            else
                reason="force mode - setting light (sunrise: $adjusted_sunrise)"
            fi
        else
            local last_minutes=$(time_to_minutes "$last_check")
            if (( last_minutes < sunrise_minutes && current_minutes >= sunrise_minutes )); then
                should_switch=true
                reason="crossed sunrise - switching to light"
            elif (( last_minutes < sunset_minutes && current_minutes >= sunset_minutes )); then
                should_switch=true
                dark_mode=true
                reason="crossed sunset - switching to dark"
            fi
        fi
        
        if [[ "$should_switch" == true ]]; then
            log "$reason"
            set_appearance "$dark_mode"
        fi
    fi
    
    cache_data=$(echo "$cache_data" | jq --arg check_time "$current_time" '.last_check_time = $check_time')
    echo "$cache_data" > "$CACHE_FILE"
    log "Check completed"
}

main "$@"