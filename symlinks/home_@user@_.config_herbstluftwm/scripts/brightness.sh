#!/usr/bin/env bash

action=$1

for bl in /sys/class/backlight/*; do
    [ -d "$bl" ] || continue
    max_brightness=$(cat "$bl/max_brightness")
    if [ "$max_brightness" -gt 0 ]; then
        device=$bl
    fi
done

[ -n "$device" ] || { echo "brightness.sh: no adjustable backlight" >&2; exit 1; }

brightness=$(cat "$device/brightness")
max=$(cat "$device/max_brightness")
step=$(( max / 20 ))

case $action in
    up)
        if [[ $brightness -ge $(( max - step )) ]]; then
            echo "$max" > "$device/brightness"
        else
            echo $(( brightness + step )) > "$device/brightness"
        fi
        ;;

    down)
        if [[ $(( brightness - step )) -ge $step ]]; then
            echo $(( brightness - step )) > "$device/brightness"
        else
            echo "$step" > "$device/brightness"
        fi
        ;;
esac
