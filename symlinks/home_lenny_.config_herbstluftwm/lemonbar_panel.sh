#!/usr/bin/env bash

# --------------------------------
# Setup

hc() { 
    "${herbstclient_command[@]:-herbstclient}" "$@"
}

# --------------------------------
# variables

monitors=$(hc list_monitors | cut -d: -f1)
panel_height=20
panel_padding=5

bg_dark="#1E1E1E"
bg_light="#333333"
bg_med="#252526"
bg_transparent="#00000000"
fg_white="#FFFFFF"
# fg_active="#68217A"
fg_active="$(herbstclient attr theme.tiling.active.color)"
fg_label="#4C4C4C"


# --------------------------------
# functions

function uniq_linebuffered() {
    exec awk '$0 != l { print ; l=$0 ; fflush(); }' "$@"
}

clock() {
	# Wednesday 29 December (52) | 14:51:49
    date '+%A %d %B (%V) | %T'
}

cpuload() {
    LINE=`ps -eo pcpu | awk 'BEGIN {sum=0.0f} {sum+=$1} END {print sum}'`
    bc <<< $LINE
}

groups() {
    cur=`xprop -root _NET_CURRENT_DESKTOP | awk '{print $3}'`
    tot=`xprop -root _NET_NUMBER_OF_DESKTOPS | awk '{print $3}'`

    for w in `seq 0 $((cur - 1))`; do line="${line}="; done
    line="${line}|"
    for w in `seq $((cur + 2)) $tot`; do line="${line}="; done
    echo $line
}

memused() {
    read t f <<< `grep -E 'Mem(Total|Free)' /proc/meminfo |awk '{print $2}'`
    bc <<< "scale=2; 100 - $f / $t * 100" | cut -d. -f1
}

network() {
    ipAddr=`ip addr | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | grep 192`
    read lo int1 int2 <<< `ip link | sed -n 's/^[0-9]: \(.*\):.*$/\1/p'`
    if iwconfig $int1 >/dev/null 2>&1; then
        wifi=$int1
        eth0=$int2
    else
        wifi=$int2
        eth0=$int1
    fi
    ip link show $eth0 | grep 'state UP' >/dev/null && int=$eth0 ||int=$wifi

    #int=eth0

    ping -c 1 8.8.8.8 >/dev/null 2>&1 && 
        echo "$ipAddr | $int connected" || echo "$ipAddr : $int disconnected"
}

_output() {
    buf=""

    for monitor in ${monitors[*]}; do
        buf="${buf}%{S$monitor}%{l}%{B$bg_dark} " # additional space for padding
        buf="${buf} $(groups) "
        buf="${buf} %{B$bg_transparent}" # additional space for padding
        buf="${buf}${r}%{B$bg_dark} " # additional space for padding
        buf="${buf} %{F$fg_label} NET: %{F$fg_white}$(network) "
        buf="${buf} %{F$fg_label} CPU: %{F$fg_white}$(cpuload) "
        buf="${buf} %{F$fg_label} RAM: %{F$fg_white}$(memused) "
        buf="${buf}%{B$bg_med} %{F$fg_white}$(clock) "
        buf="${buf} " # additional space for padding
    done

    echo $buf
}


# --------------------------------
# build status bar

for monitor in ${monitors[*]}; do
    # only one lot of padding due to frame padding
    hc pad $monitor $(( panel_height + panel_padding ))
done

# Format the Panel
{
    child=""
    while true; do
        (clock)
        sleep 1 || break
    done > >(uniq_linebuffered) &
    child+=" $!"
    hc -i
    kill $child
} | {

    TAGS=( $(herbstclient tag_status $monitor) )
    date=""

    while true; do
        IFS=$'\t' read -ra cmd || break
        case "${cmd[0]}" in
            tag*)
                TAGS=( $(herbstclient tag_status $monitor) )
                ;;

            focus_changed|window_title_changed)
                windowtitle="${cmd[@]:2}"
                ;;

            date)
                date="${cmd[@]:1}"
                ;;

            quit_panel|reload)
                exit 0
                ;;

            *)
                ;;
        esac

        # buf=""
        # for i in "${TAGS[@]}"; do
        #     occupied=true
        #     focused=false
        #     here=false
        #     urgent=false
        #     visible=true
        #     case ${i:0:1} in
        #         # viewed: grey background
        #         # focused: colored
        #         '.') occupied=false ; visible=false
        #             continue # hide them from taglist
        #             ;;
        #         '#') focused=true ; here=true ;;
        #         '%') focused=true ;;
        #         '+') here=true ;;
        #         '!') urgent=true ;;
        #         # occupied tags
        #         ':') visible=false ;;
        #     esac
        #     tag=""
        #     $here     && tag+="%{B$bg_light}" || tag+="%{B-}"
        #     $visible  && tag+="%{+o}" || tag+="%{-o}"
        #     $occupied && tag+="%{F-}" || tag+="%{F#909090}"
        #     $urgent   && tag+="%{B#eeD6156C}%{-o}"
        #     $focused  && tag+="%{Fwhite}%{U$fg_active}" \
        #               || tag+="%{U#454545}"
        #     tag+="%{A1:use_${i:1}:} ${i:1} %{A}"
        #     buf="${buf}$tag"
        # done
        # buf="${buf}%{A}%{A}%{F-}%{B-}%{-o}"
        # buf="${buf}%{r}"
        # buf="${buf}%{B$bg_light}%{U$bg_light}%{+o}%{+u} "
        # buf="${buf}%{A1:switchuser:}->[]%{A}"
        # buf="${buf} %{B-}%{-o}%{-u}%{F-} "
        # buf="${buf}%{B$bg_light}%{U$bg_light}%{+o}%{+u} "
        # buf="${buf} %{B-}%{-o}%{-u}%{F-} "
        # buf="${buf}%{-o}%{U#909090}%{B$bg_light} $(clock) %{B-}"
        # buf="${buf}%{B-}%{-o}%{-u}"
        # echo $buf

        buf=""

        for monitor in ${monitors[*]}; do
            buf="${buf}%{S$monitor}%{l}%{B$bg_dark} " # additional space for padding
            buf="${buf} $(groups) "
            buf="${buf} %{B$bg_transparent}" # additional space for padding
            buf="${buf}${r}%{B$bg_dark} " # additional space for padding
            buf="${buf} %{F$fg_label} NET: %{F$fg_white}$(network) "
            buf="${buf} %{F$fg_label} CPU: %{F$fg_white}$(cpuload) "
            buf="${buf} %{F$fg_label} RAM: %{F$fg_white}$(memused) "
            buf="${buf}%{B$bg_med} %{F$fg_white}$(clock) "
            buf="${buf} " # additional space for padding
        done

        echo $buf
    done
} | lemonbar -d \
    -g 1910x$panel_height+$panel_padding+$panel_padding \
    -B $bg_transparent \
    -u 2 \
    -U $fg_active

# {
#     hc -i | while read line; do
#         case $line in
#             REFRESH_PANEL)
#                 ;;

#             quit_panel|reload)
#                 pkill lemonbar
#                 exit
#                 ;;
#         esac
#         echo -e $(_output)
#     done
# } | lemonbar -p -g 1910x$panel_height+$panel_padding+$panel_padding -u 2 -U $fg_active | sh &

# # Emit hooks to keep it updating
# while true; do
#     hc emit_hook REFRESH_PANEL
#     sleep 1
#     done
# done &