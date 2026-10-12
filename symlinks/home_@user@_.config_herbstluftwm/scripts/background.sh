#!/usr/bin/env bash
# Set the desktop background: the wallpaper ($wallpaper) for a known set of
# monitors, a plain solid colour for an unknown one (a projector, say).
# feh sets both, so it always owns the root pixmap. For the colour it is given
# a 1x1 image, which --bg-fill stretches over every monitor. rule_hook.sh runs this whenever the monitors change.
source ~/.config/herbstluftwm/variables.autostart

solid_ppm() {
    local hex=${1#\#}
    printf 'P6 1 1 255\n'
    printf "\\x${hex:0:2}\\x${hex:2:2}\\x${hex:4:2}"
}

# feh reads its monitors from X, which lists the virtual ones. Take them away while it runs, so the
# wallpaper spans each physical monitor, then put them back as they were.
hide_virtual_monitors() {
    virtual=()
    local line name geom out
    while read -r line; do
        read -r _ name geom out <<<"$line"
        name=${name#[+*]} name=${name#[+*]}
        [[ $name == *~* ]] && virtual+=("$name $geom ${out:-none}")
    done < <(xrandr --listmonitors | grep -E '^ *[0-9]+:')
    local v
    for v in "${virtual[@]}"; do xrandr --delmonitor "${v%% *}"; done
}

restore_virtual_monitors() {
    local v name geom out
    for v in "${virtual[@]}"; do read -r name geom out <<<"$v"; xrandr --setmonitor "$name" "$geom" "$out"; done
}

if "$(dirname "${BASH_SOURCE[0]}")/monitor_reconcile.sh" --known; then
    hide_virtual_monitors
    trap restore_virtual_monitors EXIT
    feh --no-fehbg --bg-fill "$wallpaper"
else
    img=$(mktemp --suffix=.ppm) || exit 1
    solid_ppm "$col_grey" >"$img"
    feh --no-fehbg --bg-fill "$img"
    rm -f "$img"
fi
