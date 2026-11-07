#!/usr/bin/env bash

action=$1
maxvol=100
minvol=0
modifier=5
sink=@DEFAULT_SINK@

volume=$(pactl get-sink-volume "$sink" | sed -n 's,.* \([0-9][0-9]*\)%.*,\1,p' | head -n 1)

case $action in
    inc)
        if [[ $volume -ge $(( maxvol - modifier )) ]]; then
            pactl -- set-sink-volume "$sink" $maxvol%
        else
            pactl -- set-sink-volume "$sink" +$modifier%
        fi
        ;;

    dec)
        if [[ $volume -le $(( minvol + modifier )) ]]; then
            pactl -- set-sink-volume "$sink" $minvol%
        else
            pactl -- set-sink-volume "$sink" -$modifier%
        fi
        ;;

    mute) pactl -- set-sink-mute "$sink" toggle
        ;;
esac
