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


# --------------------------------
# exec

killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do 
	sleep 1;
done

for monitor in $(hc list_monitors | cut -d: -f1); do
    # only one lot of padding due to frame padding
    hc pad $monitor $(( panel_height + panel_padding ))
    hc pad $monitor $(( panel_height + panel_padding ))

    if [[ $monitor = 0 ]]; then
        # make sure this runs as my user
        # /usr/bin/sudo -u $(id -nu 1000) bash -c \
        #     "MONITOR=${pb_monitors[${hc_monitors[$monitor]}]} \
        #     COLOUR_ACTIVE=$col_active \
        #     COLOUR_URGENT=$col_urgent \
        #     polybar --reload herbstluft -c ~/.config/herbstluftwm/polybar/polybar.ini 2>/home/lenny/.config/herbstluftwm/polybar/logs/log &"
        MONITOR=${pb_monitors[${hc_monitors[$monitor]}]} \
            COLOUR_ACTIVE=$col_active \
            COLOUR_URGENT=$col_urgent \
            polybar --reload herbstluft -c ~/.config/herbstluftwm/polybar/polybar.ini 2>/home/lenny/.config/herbstluftwm/polybar/logs/log &
    fi
done

# trigger any startup ipc scripts
if hc silent new_attr bool my_not_first_autostart_panel ; then 
    sleep 1
    /usr/bin/polybar-msg action ups hook 0
fi