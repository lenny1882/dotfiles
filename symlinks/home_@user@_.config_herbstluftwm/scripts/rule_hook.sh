#!/usr/bin/env bash
hook=$1
name=$2
winid=$3

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

    monitors_changed)
        "$SCRIPT_DIR/monitor_reconcile.sh"
        ;;

    monitors_applied)
        source ~/.config/herbstluftwm/variables.autostart
        "$SCRIPT_DIR/panel.sh" "$col_active" "$col_purple"
        "$SCRIPT_DIR/background.sh"
        "$SCRIPT_DIR/tag_layouts.sh"
        ;;
esac