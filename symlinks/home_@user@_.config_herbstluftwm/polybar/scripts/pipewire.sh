#!/usr/bin/env bash

action=$1
current=$( pactl list sinks |sed -n "/$(pactl info |grep Sink |sed 's/Default Sink: //')/,\$p" |grep '^[[:space:]]Name:' |sed 's/.*Name: //' )
volume=$( pactl list sinks |sed -n "/$(pactl info |grep Sink |sed 's/Default Sink: //')/,\$p" |grep '^[[:space:]]Volume:' |head -n $(( sink + 1 )) |tail -n 1 |sed -e 's,.* \([0-9][0-9]*\)%.*,\1,' )
sink=$( pactl list short sinks |grep $current |sed -e 's,^\([0-9][0-9]*\)[^0-9].*,\1,' |head -n 1 )

case $action in
    mute)
        pactl -- set-sink-mute $sink toggle
        ;;
    *)
        if [[ $volume -lt 1 ]]; then
            echo " mute"
        else
            printf -v padded "%03s" $volume
            echo " ${padded}%"
        fi
        ;;
esac