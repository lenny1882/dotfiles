#!/usr/bin/env bash
hook=$1
name=$2
winid=$3

hc() { 
    "${herbstclient_command[@]:-herbstclient}" "$@"
}

case $hook in
    rule)
        case $name in
            peek_opened)
                hc set_attr clients.focus.decorated false
                ;;

            splash_opened)
                hc set_attr clients.focus.decorated false
                ;;
        esac
        ;;

    ipc)
        polybar-msg action ups hook 0
        ;;

    test)
        notify-send -t 10000 a a
        ;;
esac