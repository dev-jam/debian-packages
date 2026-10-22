#!/bin/bash
# Detects changes in screen resolution, refresh rate and scaling factor
# (X11 and Wayland) and restarts only the Conky process.
#
# Design notes:
#   * ONE backend is chosen at startup (KScreen if available, otherwise
#     xrandr). The two backends are never mixed, because they format the
#     same mode differently: a fallback during a timeout would look like
#     a display change and restart Conky.
#   * A failed or empty measurement returns "ERROR" and the tick is skipped.
#   * The Xft.dpi value is always part of the fingerprint, so a scale
#     change is detected on X11 even if KScreen keeps reporting scale 1.

POLL_INTERVAL=5          # seconds between checks (was 2); lower = faster reaction, more CPU
KSCREEN_TIMEOUT=2s       # kscreen-doctor can stall under heavy CPU load

pidfile="/tmp/conky_display_watcher.pid"

if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    exit 0
fi
echo $$ > "$pidfile"
trap 'rm -f "$pidfile"' EXIT

CONKY_CONF="$HOME/.config/conky/conky.conf"

BACKEND="xrandr"
if command -v kscreen-doctor >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    BACKEND="kscreen"
fi

find_conky_pids() {
    local pids p pid exe
    pids=$(pidof conky 2>/dev/null)

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

# Prints "<width>x<height>_<refresh>" or nothing on failure
mode_kscreen() {
    local out
    out=$(timeout "$KSCREEN_TIMEOUT" kscreen-doctor -j 2>/dev/null) || return
    [ -n "$out" ] || return
    echo "$out" | jq -r 'first(.outputs[] | select(.enabled == true) | . as $o | $o.modes[] | select(.id == $o.currentModeId) | "\(.size.width)x\(.size.height)_\(.refreshRate)") // empty' 2>/dev/null
}

mode_xrandr() {
    xrandr --current 2>/dev/null | awk '/\*/ {for (i = 2; i <= NF; i++) if ($i ~ /\*/) {gsub(/[*+]/, "", $i); print $1 "_" $i; exit}}'
}

get_mode() {
    local mode dpi

    if [ "$BACKEND" = "kscreen" ]; then
        mode=$(mode_kscreen)
    else
        mode=$(mode_xrandr)
    fi

    # Invalid or incomplete output (boot, CPU starvation): skip this tick
    if ! [[ "$mode" =~ ^[0-9]+x[0-9]+_ ]]; then
        echo "ERROR"
        return
    fi

    # Always the same source for the scale part of the fingerprint
    dpi=$(xrdb -query 2>/dev/null | grep -i 'Xft.dpi' | grep -o '[0-9]*' | head -n1)

    echo "${mode}_dpi${dpi:-none}"
}

LAST_MODE=$(get_mode)

# Wait during initial startup until a valid display mode is detected
while [ "$LAST_MODE" = "ERROR" ]; do
    sleep 2
    LAST_MODE=$(get_mode)
done

while true; do
    sleep "$POLL_INTERVAL"
    NEW_MODE=$(get_mode)

    if [ "$NEW_MODE" != "ERROR" ] && [ "$NEW_MODE" != "$LAST_MODE" ]; then
        for pid in $(find_conky_pids); do
            kill "$pid" 2>/dev/null
        done

        # Wait (max ~5 s) until the old Conky has really exited
        for _ in $(seq 1 25); do
            [ -z "$(find_conky_pids)" ] && break
            sleep 0.2
        done

        nohup conky -c "$CONKY_CONF" >/dev/null 2>&1 &

        LAST_MODE="$NEW_MODE"
    fi
done
