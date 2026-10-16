#!/usr/bin/env bash
# Set the desktop background per monitor: the wallpaper ($wallpaper) on the laptop panel and on any monitor
# listed in MONITORS, a solid blue (ansi_blue, the wrapper border colour) on one that is not (a projector, say).
# feh sets both, so it always owns the root pixmap. For the colour it is given
# a solid image, which --bg-fill stretches over the monitor. rule_hook.sh runs this whenever the monitors change.
source ~/.config/herbstluftwm/variables.autostart

# A 64x64 image, not 1x1: feh scales a single pixel up to black.
solid_ppm() {
    local hex=${1#\#} px row i
    px="$((16#${hex:0:2})) $((16#${hex:2:2})) $((16#${hex:4:2}))"
    row=$(printf "$px %.0s" {1..64})
    printf 'P3\n64 64\n255\n'
    for ((i = 0; i < 64; i++)); do echo "$row"; done
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

# A monitor is known if it is the laptop panel or its EDID id is listed in MONITORS (monitor_reconcile.sh --ids
# prints "port name id", the name being the id itself when it is not listed, and `-` when there is no EDID).
declare -A known=()
while read -r port name id; do
    if [[ $port == eDP* || $port == LVDS* || $port == DSI* ]] || [[ $id != - && $name != "$id" ]]; then
        known[$port]=1
    fi
done < <("$(dirname "${BASH_SOURCE[0]}")/monitor_reconcile.sh" --ids)

hide_virtual_monitors
trap restore_virtual_monitors EXIT

# feh gives its images to the monitors in the order xrandr lists them; one image is used for all of them.
img=$(mktemp --suffix=.ppm) || exit 1
solid_ppm "$ansi_blue" >"$img"
images=() unknown=0
while read -r line; do
    read -r _ name _ out <<<"$line"
    name=${name#[+*]} name=${name#[+*]}
    if [[ -n ${known[${out:-$name}]} ]]; then images+=("$wallpaper"); else images+=("$img"); unknown=1; fi
done < <(xrandr --listmonitors | grep -E '^ *[0-9]+:')
((unknown && ${#images[@]})) || images=("$wallpaper")
feh --no-fehbg --bg-fill "${images[@]}"
rm -f "$img"
