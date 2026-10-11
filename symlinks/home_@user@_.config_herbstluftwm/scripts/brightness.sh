#!/usr/bin/env bash

action=$1

for bl in /sys/class/backlight/*; do
    if [ -d "$bl" ]; then
        type=$(cat "$bl/type")
        # Check if the device can actually be modified
        max_brightness=$(cat "$bl/max_brightness")
        
        if [ "$max_brightness" -gt 0 ]; then
            device=$bl   
        fi
    fi
done

brightness=$(cat $device/brightness )
max=$( cat $device/max_brightness )
step=$(( max / 20 ))

case $action in
    up)
        if [[ $brightness -ge $(( max - step)) ]]; then
            echo $max > $device/brightness
        elif [[ $brightness -le $(( max - step )) ]]; then
            echo $(( brightness + step ))  > $device/brightness
        fi
        ;;

    down)
        if [[ $(( brightness - step )) -ge $step ]]; then
            echo $(( brightness -step )) > $device/brightness
        elif [[ $(( brightness - step )) -le $step ]]; then
            echo $step > $device/brightness
        fi
        ;;
esac
