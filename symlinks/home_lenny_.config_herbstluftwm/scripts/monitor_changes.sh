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
                    herbstclient emit_hook test
                    break
            }
        }'
}

while read output status; do
    printf "$output was $status\n"
done < <(monitor_xevents)

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