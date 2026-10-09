#!/bin/bash

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

# DRM hotplug events from udev. The kernel sends a "change" uevent on the card
# device when a connector is plugged, unplugged or its EDID changes. Output
# lines look like: UDEV  [1234.56] change   /devices/pci0000:00/.../drm/card1 (drm)
function monitor_udev_events {
    udevadm monitor --udev --subsystem-match=drm | stdbuf --output=L gawk \
        '$3 == "change" { print $4, $3; fflush() }'
}

HOOK=monitors_changed
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Seconds of quiet that end a burst of events. One dock can fire several.
DEBOUNCE=0.5

# udevadm is the default event source; xev is used when udevadm is missing,
# or when forced with --xev.
USE_XEV=0
[[ $1 == --xev ]] && USE_XEV=1
command -v udevadm >/dev/null || USE_XEV=1

function monitor_events {
    if ((USE_XEV)); then monitor_xevents; else monitor_udev_events; fi
}

# Turn each burst of events into one hook, so anything can react to monitors
# changing. After the first event, keep reading until DEBOUNCE seconds pass
# with nothing new.
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

# Reconcile whenever the hook fires. Safe to run repeatedly: it does nothing
# when the connected monitors match the stored layout.
function handle_hooks {
    herbstclient --idle "$HOOK" | while read -r _; do
        "$SCRIPT_DIR/monitor_reconcile.sh"
    done
}

trap 'trap - INT TERM EXIT; kill 0' INT TERM EXIT
emit_changes &
handle_hooks

# TODO:

# get monitors: xrandr | grep -w connected  | awk -F'[ +]' '{print $1,$3,$4}'
# on startup: hc new_attr string my_monitor_layout --> set it to the value of ^ (ish)
# ignore connect/disconnect - on _either_ trigger the monitor hook
# hc hook should get monitors, compare with stored attribute
#   if different, set new monitor set -- save string as names, use that to determine?
#       if name doesn't match, find primary, set to fullscreen, half screens on others
#       if <1080p then fullscreen stacked, etc.

# only connection? What about monitor change events?

# use xrandr to set monitor layouts - uses the connection name, "DP-4" -- can do things like:
#
#   [ HDMI1 ][ DP-4 ][ HDMI2 ]
#   xrandr --output DP-4 --mode 1920x1080 --primary && xrandr --output HDMI2 --mode 1920-1080 --right-of DP-4 && xrandr --output HDMI1 --mode 1920-1080 --left-of DP-4
#
#   turn off monitor (e.g. laptop main)
#   xrandr --output LVSD1 --off
# e.g. to automate connecting and disconnecting, showing things in certain ways, 

# xrandr --listmonitors
# the monitors that are plugged in and active

# get first line of edid
#   xrandr --listmonitors |sed -n '/EDID/{n;p;}' |awk '{$1=$1};1'
# get just "DP-4" equivalent for each displaying monitor
#   xrandr --listmonitors |awk -F'[ +]' '{printf $4}'
# get first line of edid for the monitor "DP-4"
#   xrandr --verbose |sed -ne '/DP-4/,$ p' |sed -n '/EDID/{n;p;}' |awk '{$1=$1};1'
#
# howto: get array of monitors, iterate over, put edids into array, check if current edids matches edids of known monitors
#   if any single current edid is not in an array of known edids, change the wallpaper to something inoffensive