#!/bin/bash
# Emits one monitors_changed hook per burst of plug / unplug events; rule_hook.sh handles it.

function monitor_xevents {
    xev -root -event randr -1 | stdbuf --output=L gawk --sandbox \
        --source 'BEGIN {
            pat=@/output (.[^,]*),.*connection RR_(\w+),/
        }
        !/crtc None/ && match ($0, pat, s) {
            switch (s[2]) {
                case "Connected":
                case "Disconnected":
                    print s[1], s[2]
                    break
            }
        }'
}

# lines look like: UDEV  [1234.56] change   /devices/pci0000:00/.../drm/card1 (drm)
function monitor_udev_events {
    udevadm monitor --udev --subsystem-match=drm | stdbuf --output=L gawk \
        '$3 == "change" { print $4, $3; fflush() }'
}

HOOK=monitors_changed

DEBOUNCE=0.5

USE_XEV=0
[[ $1 == --xev ]] && USE_XEV=1
command -v udevadm >/dev/null || USE_XEV=1

function monitor_events {
    if ((USE_XEV)); then monitor_xevents; else monitor_udev_events; fi
}

function emit_changes {
    local source device action
    ((USE_XEV)) && source=xev || source=udevadm
    printf 'monitor events from %s\n' "$source" >&2
    while read -r device action; do
        while read -r -t "$DEBOUNCE" _ _; do :; done
        printf '%s: %s\n' "$device" "$action" >&2
        herbstclient emit_hook "$HOOK"
    done < <(monitor_events)
}

trap 'trap - INT TERM EXIT; kill 0' INT TERM EXIT
emit_changes