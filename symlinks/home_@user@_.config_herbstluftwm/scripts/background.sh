#!/usr/bin/env bash
# Set the desktop background: the wallpaper (~/.fehbg) for a known set of
# monitors, a plain solid colour for an unknown one (a projector, say).
# feh sets both, so it always owns the root pixmap. For the colour it is given
# a 1x1 image, which --bg-fill stretches over every monitor.
source ~/.config/herbstluftwm/variables.autostart

solid_ppm() {
    local hex=${1#\#}
    printf 'P6 1 1 255\n'
    printf "\\x${hex:0:2}\\x${hex:2:2}\\x${hex:4:2}"
}

if "$(dirname "${BASH_SOURCE[0]}")/monitor_reconcile.sh" --known; then
    ~/.fehbg
else
    img=$(mktemp --suffix=.ppm) || exit 1
    solid_ppm "$col_grey" >"$img"
    feh --no-fehbg --bg-fill "$img"
    rm -f "$img"
fi
