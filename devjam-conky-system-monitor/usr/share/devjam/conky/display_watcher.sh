#!/bin/bash
# Detects changes in screen resolution, refresh rate, and scaling factor
# (supports both X11 and Wayland) and restarts only the Conky process.

pidfile="/tmp/conky_display_watcher.pid"

if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    exit 0
fi
echo $$ > "$pidfile"
trap 'rm -f "$pidfile"' EXIT

CONKY_CONF="$HOME/.config/conky/conky.conf"

# SAFELY finds only the PIDs of actual conky binary processes (prevents killing
# terminals, text editors, or scripts that contain 'conky' in their path/name).
find_conky_pids() {
    # Use pidof to grab genuine binary executables only
    local pids
    pids=$(pidof conky 2>/dev/null)
    
    # Fallback if pids is empty (e.g. specific AppImage executables)
    if [ -z "$pids" ]; then
        for p in /proc/[0-9]*; do
            pid="${p##*/}"
            [ "$pid" = "$$" ] && continue
            exe=$(readlink -f "$p/exe" 2>/dev/null)
            if [[ "$exe" == */conky ]]; then
                pids="$pids $pid"
            fi
        done
    fi

    echo "$pids"
}

get_mode() {
    local mode=""
    local dpi=""
    
    # Query KScreen with a 2-second timeout to handle high CPU load / starvation
    local kscreen_out
    kscreen_out=$(timeout 2s kscreen-doctor -j 2>/dev/null)
    local kscreen_status=$?

    if [ $kscreen_status -eq 0 ] && [ -n "$kscreen_out" ]; then
        mode=$(echo "$kscreen_out" | jq -r '.outputs[] | select(.enabled == true) as $out | $out.modes[] | select(.id == $out.currentModeId) | "\(.size.width)x\(.size.height)_\(.refreshRate)"' 2>/dev/null | head -n1)
        dpi=$(echo "$kscreen_out" | jq -r '.outputs[] | select(.enabled == true) | select(.scale != null) | (.scale * 100 | round)' 2>/dev/null | head -n1)
    fi

    # Fallback to xrandr if KScreen query failed or returned empty
    if [ -z "$mode" ] || [ "$mode" = "null" ]; then
        mode=$(xrandr --current 2>/dev/null | awk '/\*/ {for(i=1;i<=NF;i++) if($i ~ /\*/) print $1 "_" $i}' | head -n1)
    fi

    if [ -z "$dpi" ] || [ "$dpi" = "null" ]; then
        dpi=$(xrdb -query 2>/dev/null | grep -i 'Xft.dpi' | grep -o '[0-9]*')
        [ -z "$dpi" ] && dpi=96
    fi

    # Return ERROR if display output is invalid or incomplete (e.g., during boot or CPU starvation)
    if [ -z "$mode" ] || [ "$mode" = "null" ] || ! [[ "$mode" =~ ^[0-9]+x[0-9]+ ]]; then
        echo "ERROR"
        return
    fi

    echo "${mode}_scale${dpi}"
}

LAST_MODE=$(get_mode)

# Wait during initial startup until a valid display resolution is detected
while [ "$LAST_MODE" = "ERROR" ]; do
    sleep 2
    LAST_MODE=$(get_mode)
done

while true; do
    sleep 2
    NEW_MODE=$(get_mode)

    # Only trigger restart if NEW_MODE is valid, non-empty, and different from LAST_MODE
    if [ "$NEW_MODE" != "ERROR" ] && [ -n "$NEW_MODE" ] && [ "$NEW_MODE" != "$LAST_MODE" ]; then
        for pid in $(find_conky_pids); do
            kill "$pid" 2>/dev/null
        done
        sleep 1

        # Direct robust restart using the predefined configuration path
        nohup conky -c "$CONKY_CONF" >/dev/null 2>&1 &

        LAST_MODE="$NEW_MODE"
    fi
done
