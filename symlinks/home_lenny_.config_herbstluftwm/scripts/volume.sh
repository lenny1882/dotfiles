#!/usr/bin/env bash

action=$1
#current=$( pactl list sinks |grep '^[[:space:]]Volume:' |head -n $(( sink + 1 )) |tail -n 1 |sed -e 's,.* \([0-9][0-9]*\)%.*,\1,' )
#current=$( pactl list sinks |sed -n "/$(pactl info |grep Sink |sed 's/Default Sink: //')/,\$p" |grep '^[[:space:]]Volume:' |head -n $(( sink + 1 )) |tail -n 1 |sed -e 's,.* \([0-9][0-9]*\)%.*,\1,' )
current=$( pactl list sinks |sed -n "/$(pactl info |grep Sink |sed 's/Default Sink: //')/,\$p" |grep '^[[:space:]]Name:' |sed 's/.*Name: //' )
volume=$( pactl list sinks |sed -n "/$(pactl info |grep Sink |sed 's/Default Sink: //')/,\$p" |grep '^[[:space:]]Volume:' |head -n $(( sink + 1 )) |tail -n 1 |sed -e 's,.* \([0-9][0-9]*\)%.*,\1,' )
maxvol=100
minvol=0
modifier=5
#sink=$( pactl list short sinks |sed -e 's,^\([0-9][0-9]*\)[^0-9].*,\1,' |head -n 1 )
#sink=$( pactl list short sinks |grep RUNNING |grep alsa |sed -e 's,^\([0-9][0-9]*\)[^0-9].*,\1,' |head -n 1 )
sink=$( pactl list short sinks |grep $current |sed -e 's,^\([0-9][0-9]*\)[^0-9].*,\1,' |head -n 1 )

case $action in
    inc)
        if [[ $volume -ge $(( maxvol - modifier )) ]]; then
            pactl -- set-sink-volume $sink $maxvol%
        elif [[ $volume -le $(( maxvol - modifier )) ]]; then
            pactl -- set-sink-volume $sink +$modifier%
        fi
        ;;

    dec)
        if [[ $volume -eq $(( minvol + modifier )) ]]; then
            pactl -- set-sink-volume $sink $minvol%
        elif [[ $volume -ge $(( minvol + modifier )) ]]; then
            pactl -- set-sink-volume $sink -$modifier%
        fi
        ;;

    mute) pactl -- set-sink-mute $sink toggle
        ;;
esac
