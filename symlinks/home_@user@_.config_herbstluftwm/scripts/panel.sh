#!/usr/bin/env bash

# --------------------------------
# Setup

hc() { 
    "${herbstclient_command[@]:-herbstclient}" "$@"
}

# --------------------------------
# variables
col_active=$1
col_urgent=$2

declare -A hc_monitors
declare -A pb_monitors
panel_height=25
panel_padding=5

source "$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../setup/colours.sh"
export COLOUR_BG_DARK=$(colour_argb col_dark CC)
export COLOUR_BG_LIGHT=$(colour_argb col_grey CC)
export COLOUR_BG_TRANSPARENT=$(colour_argb col_black 00)
export COLOUR_BG_DARK_TRANSLUCENT=$(colour_argb col_grey 55)
export COLOUR_BG_YELLOW=$(colour_hex col_orange)
export COLOUR_BG_RED=$(colour_hex col_red)
export COLOUR_FG_DISABLED=$(colour_argb col_light 33)
export COLOUR_FG_ERROR=$(colour_hex col_red)
export COLOUR_FG_LABEL=$(colour_argb col_light 77)
export COLOUR_FG_MONITOR_EMPTY=$(colour_argb col_light 33)
export COLOUR_FG_TRANSPARENT=$(colour_argb col_black 00)
export COLOUR_FG_WHITE=$(colour_hex col_light)

# assoc array of hc monitor id to monitor rect, e.g. ([0]=1920x1080+0+0)
tmp_hc_mon_res=($(hc list_monitors | grep -Eo '(([0-9]{1,4}.(+|x)*){3}[0-9])'))
tmp_hc_mon_ind=($(hc list_monitors | cut -d: -f1))
for i in ${!tmp_hc_mon_ind[@]}; do
	hc_monitors[${tmp_hc_mon_ind[i]}]=${tmp_hc_mon_res[i]}
done

# assoc array of polybar monitor rect to monitor input, e.g. ([1920x1080+0+0]="DP-5")
tmp_pb_mon_res=($(polybar --list-monitors | grep -Eo '(([0-9]{1,4}.(+|x)*){3}[0-9])'))
tmp_pb_mon_ind=($(polybar --list-monitors | cut -d: -f1))
for i in ${!tmp_pb_mon_ind[@]}; do
	pb_monitors[${tmp_pb_mon_res[i]}]=${tmp_pb_mon_ind[i]}
done

# the primary output (not a virtual monitor cut from it): its name and WxH+X+Y rect
read -r primary_output primary_rect < <(xrandr --query | awk '$2 == "connected" && $3 == "primary" { print $1, $4; exit }')
if [[ -z $primary_output ]]; then
	read -r primary_output primary_rect < <(xrandr --listmonitors | awk '$2 ~ /\*/ { g = $3; gsub(/\/[0-9]+/, "", g); print $4, g; exit }')
fi

# true if the hlwm monitor rect $1 lies inside the primary rect
in_primary() {
	local r='^([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)$' w h x y pw ph px py
	[[ $1 =~ $r ]] || return 1
	w=${BASH_REMATCH[1]} h=${BASH_REMATCH[2]} x=${BASH_REMATCH[3]} y=${BASH_REMATCH[4]}
	[[ $primary_rect =~ $r ]] || return 1
	pw=${BASH_REMATCH[1]} ph=${BASH_REMATCH[2]} px=${BASH_REMATCH[3]} py=${BASH_REMATCH[4]}
	((x >= px && y >= py && x + w <= px + pw && y + h <= py + ph))
}


# --------------------------------
# exec

killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do 
	sleep 1;
done

# one bar across the whole primary output, even when it is cut into several virtual monitors
for monitor in $(hc list_monitors | cut -d: -f1); do
    if in_primary "${hc_monitors[$monitor]}"; then
        # only the primary output has a panel, so only its monitors need padding
        hc pad $monitor $(( panel_height + panel_padding ))
    else
        # clear any padding left over from a previous layout
        hc pad $monitor 0
    fi
done

MONITOR=${pb_monitors[$primary_rect]:-$primary_output} \
    COLOUR_ACTIVE=$col_active \
    COLOUR_URGENT=$col_urgent \
    polybar --reload herbstluft -c ~/.config/herbstluftwm/polybar/polybar.ini 2>$HOME/.config/herbstluftwm/polybar/logs/log &

# trigger any startup ipc scripts
if hc silent new_attr bool my_not_first_autostart_panel ; then 
    sleep 1
    /usr/bin/polybar-msg action ups hook 0
fi