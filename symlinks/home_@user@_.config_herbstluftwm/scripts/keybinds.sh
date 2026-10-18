#!/usr/bin/env bash

# usage: keybinds.sh [--list]
# a rofi list of the live herbstluftwm keybinds, grouped and reworded; --list prints it instead

hc() { "${herbstclient_command[@]:-herbstclient}" "$@"; }

groups=(apps system screenshot window frame tag herbstluftwm mouse)
key_width=36

# command -> "group|label"
describe() {
    case $1 in
        quit)                                   echo "herbstluftwm|quit herbstluftwm" ;;
        reload)                                 echo "herbstluftwm|reload herbstluftwm" ;;
        remove)                                 echo "frame|remove frame" ;;
        "split explode")                        echo "frame|explode frame" ;;
        split\ *)                               echo "frame|split frame" ;;
        resize\ *)                              echo "frame|resize frame" ;;
        set_layout\ *)                          echo "frame|layout: ${1#set_layout }" ;;
        *cycle_layout*)                         echo "frame|cycle layout" ;;
        cycle)                                  echo "frame|cycle windows in frame" ;;
        "use_index +1"*)                        echo "tag|next tag" ;;
        "use_index -1"*)                        echo "tag|previous tag" ;;
        use_index\ [0-9]*)                      echo "tag|go to tag" ;;
        move_index\ *)                          echo "tag|move window to tag" ;;
        close)                                  echo "window|close window" ;;
        focus\ *)                               echo "window|focus" ;;
        shift\ *)                               echo "window|move window" ;;
        "cycle_all +1")                         echo "window|next window" ;;
        "cycle_all -1")                         echo "window|previous window" ;;
        *clients.focus.floating*)               echo "window|toggle floating" ;;
        *clients.focus.minimized*)              echo "window|minimise window" ;;
        "jumpto last-minimized")                echo "window|restore last minimised" ;;
        "spawn urxvt")                          echo "apps|terminal" ;;
        *rofi-wrap.sh*"-show drun"*)            echo "apps|launcher: apps" ;;
        *rofi-wrap.sh*"-show run"*)             echo "apps|launcher: run command" ;;
        *rofi-wrap.sh*"-show window"*)          echo "apps|launcher: windows" ;;
        *rofi-wrap.sh*"-show calc"*)            echo "apps|calculator" ;;
        *nnn-wrap.sh)                           echo "apps|file manager (nnn)" ;;
        *monitor-tui-wrap.sh)                   echo "apps|monitor layout tui" ;;
        *bottom-wrap.sh)                        echo "apps|system monitor" ;;
        *keybinds.sh)                           echo "apps|keybind cheat-sheet" ;;
        spawn\ physlock*)                       echo "system|lock screen" ;;
        *volume.sh\ mute)                         echo "system|volume: mute" ;;
        *volume.sh\ dec)                          echo "system|volume: down" ;;
        *volume.sh\ inc)                          echo "system|volume: up" ;;
        *brightness.sh\ down)                     echo "system|brightness: down" ;;
        *brightness.sh\ up)                       echo "system|brightness: up" ;;
        *screenshot.sh\ select-clip)            echo "screenshot|region to clipboard" ;;
        *screenshot.sh\ select)                 echo "screenshot|region to file" ;;
        *screenshot.sh\ area-clip)              echo "screenshot|window to clipboard" ;;
        *screenshot.sh\ area)                   echo "screenshot|window to file" ;;
        *)                                      echo "other|$1" ;;
    esac
}

pretty_mods() {
    local m=${1//Mod4/Super}
    m=${m//Mod1/Alt}
    echo "${m//Control/Ctrl}"
}

pretty_key() {
    case $1 in
        period) echo . ;;
        comma)  echo , ;;
        space)  echo Space ;;
        *)      echo "$1" ;;
    esac
}

# the last keys of a group of binds: arrows in a fixed order, a run of digits as "1-9"
join_keys() {
    local k all_digits=1 all_arrows=1 ordered=()
    for k in "$@"; do
        [[ $k == [0-9] ]] || all_digits=0
        [[ $k == Left || $k == Down || $k == Up || $k == Right ]] || all_arrows=0
    done
    if ((all_arrows)); then
        for k in Left Down Up Right; do
            [[ " $* " == *" $k "* ]] && ordered+=("$k")
        done
        (IFS=/; echo "${ordered[*]}")
    elif ((all_digits && $# > 2)); then
        mapfile -t ordered < <(printf '%s\n' "$@" | sort -n)
        echo "${ordered[0]}-${ordered[-1]}"
    else
        (IFS=/; echo "$*")
    fi
}

# the sheet as plain text: a header line per group, then its rows indented
build() {
    local line key cmd mods last desc sig g ks
    local -a order=()
    local -A keys=() rows=()

    while IFS= read -r line; do
        [[ -z $line ]] && continue
        key=${line%%$'\t'*}
        cmd=${line#*$'\t'}
        cmd=${cmd//$'\t'/ }
        last=${key##*+}
        [[ $key == *+* ]] && mods=$(pretty_mods "${key%+*}")+ || mods=
        desc=$(describe "$cmd")
        sig="$desc|$mods"
        [[ -v keys[$sig] ]] || order+=("$sig")
        keys[$sig]+="$(pretty_key "$last") "
    done < <(hc list_keybinds)

    for sig in "${order[@]}"; do
        IFS='|' read -r g desc mods <<<"$sig"
        read -ra ks <<<"${keys[$sig]}"
        rows[$g]+=$(printf '  %-*s %s' "$key_width" "$mods$(join_keys "${ks[@]}")" "$desc")$'\n'
    done
    rows[mouse]=$(printf '  %-*s %s\n  %-*s %s\n' \
        "$key_width" "Super+Alt+left button" "move floating window" \
        "$key_width" "Super+Alt+right button" "resize floating window")$'\n'

    for g in "${groups[@]}" other; do
        [[ -v rows[$g] ]] || continue
        printf '%s\n%s' "${g^^}" "${rows[$g]}"
    done
}

# the sheet in two columns as pango markup: whole groups, stacked down the left column and then the
# right, split where the two come out most even; one blank line between groups
# sets sheet_lines and sheet_chars (the width of both columns)
two_columns() {
    local line g k r cost best_cost=999 best=1 left_n right_n gap=8
    local -a blocks=() sizes=() left=() right=()

    sheet_chars=0
    for line; do
        (( ${#line} > sheet_chars )) && sheet_chars=${#line}
        if [[ $line != " "* ]]; then blocks+=(""); sizes+=(0); fi
        blocks[-1]+="$line"$'\n'
        ((sizes[-1]++))
    done

    for ((k = 1; k < ${#blocks[@]}; k++)); do
        left_n=0 right_n=0
        for g in "${!sizes[@]}"; do
            if ((g < k)); then left_n=$((left_n + sizes[g] + 1)); else right_n=$((right_n + sizes[g] + 1)); fi
        done
        cost=$((left_n > right_n ? left_n : right_n))
        if ((cost < best_cost)); then best_cost=$cost best=$k; fi
    done

    for g in "${!blocks[@]}"; do
        ((g && g != best)) && { if ((g < best)); then left+=(""); else right+=(""); fi; }
        while IFS= read -r line; do
            if ((g < best)); then left+=("$line"); else right+=("$line"); fi
        done <<<"${blocks[$g]%$'\n'}"
    done

    sheet_lines=()
    for ((r = 0; r < ${#left[@]} || r < ${#right[@]}; r++)); do
        sheet_lines+=("$(cell "${left[r]}")$(printf '%*s' "$gap" '')$(cell "${right[r]}")")
    done
    sheet_chars=$((sheet_chars * 2 + gap))
}

# one column's line: a header in bold green, a row with its action in grey; padded to the column
# width before the markup is added
cell() {
    local line=$1 prefix action
    if [[ -z $line ]]; then
        printf '%*s' "$sheet_chars" ''
    elif [[ $line != " "* ]]; then
        printf -v line '%-*s' "$sheet_chars" "$line"
        printf '<span foreground="%s" weight="bold">%s</span>' "$green" "$(escape "$line")"
    else
        prefix=${line:0:key_width+3}
        action=${line:key_width+3}
        printf -v action '%-*s' "$((sheet_chars - key_width - 3))" "$action"
        printf '%s<span foreground="%s">%s</span>' "$(escape "$prefix")" "$grey" "$(escape "$action")"
    fi
}

escape() {
    local t=${1//&/&amp;}
    t=${t//</&lt;}
    echo "${t//>/&gt;}"
}

if [[ $1 == --list ]]; then
    build
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    colours_dir=$(cd -P "$SCRIPT_DIR/../../../setup" && pwd)
    source "$colours_dir/colours.sh"
    green=$(colour_hex col_green)
    grey=$(colour_hex col_grey_light)
    blue=$(colour_hex col_blue)
    mapfile -t plain < <(build)
    two_columns "${plain[@]}"
    printf '%s\n' "${sheet_lines[@]}" \
        | "$SCRIPT_DIR/rofi-wrap.sh" -markup -e - -theme-str "window { width: $((sheet_chars * 9 + 72)); padding: 24px; y-offset: 0; border: 2px; border-color: $blue; }"
fi
