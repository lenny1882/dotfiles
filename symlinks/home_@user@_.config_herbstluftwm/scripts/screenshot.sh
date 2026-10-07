#!/usr/bin/env bash

action=$1

case $action in
    select)
        scrot -b -F "$HOME/Pictures/screenshots/%Y-%m-%d_%H%M%S_select.png" -l style=solid,width=2,color=red --select=capture
        ;;

    select-clip)
        scrot -b -F - -l style=solid,width=2,color=red --select=capture | xclip -selection clipboard -t image/png
        ;;

    area)
        scrot -b -F "$HOME/Pictures/screenshots/%Y-%m-%d_%H%M%S_window.png" --focused
        ;;

    area-clip)
        scrot -b -F - --focused | xclip -selection clipboard -t image/png
        ;;
esac