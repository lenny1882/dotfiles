#!/usr/bin/env bash
# rofi menu to see and change the monitor layout without editing
# monitor_layouts.conf. Edits a working copy of the current xrandr state, then
# hands it to monitor_reconcile.sh --layout, so the panel guard and custom
# modes still apply.
#
#   monitor_popup.sh [--dry-run]
#
# A change holds until the connected set changes (the new key no longer matches);
# "Apply and save" also writes it to monitor_layouts.conf so it survives a restart.
#
# Test without a display: XRANDR_FIXTURE=<xrandr --query output>, ROFI=<a
# command that reads menu rows on stdin and prints the chosen one>.
#
# Not handled: rotation (positions assume unrotated outputs), and moving an
# output does not re-flow the others.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=monitor_reconcile.sh
source "$SCRIPT_DIR/monitor_reconcile.sh"

ROFI=${ROFI:-rofi}
RECONCILE="$SCRIPT_DIR/monitor_reconcile.sh"

# Working state, one line per connected output: name mode x y primary w h
# (mode is WxH, auto or off; primary is 0 or 1).
declare -a ST=()

menu() { # args: prompt, message. stdin: rows. Prints the chosen row.
    "$ROFI" -dmenu -i -no-custom -p "$1" -mesg "$2"
}

notify() { "$ROFI" -e "$1" 2>/dev/null || log "$1"; }

# stdin: xrandr --query. Prints the state lines for the current display.
read_state() {
    awk '
        function flush() {
            if (name == "") return
            if (!on) { mode = "off"; x = 0; y = 0; w = pw; h = ph }
            print name, mode, x, y, prim, w, h
            name = ""
        }
        $2 == "connected" || $2 == "disconnected" {
            flush()
            if ($2 == "disconnected") next
            name = $1; on = 0; mode = "off"; prim = ($3 == "primary") ? 1 : 0; pw = ph = 0
            for (i = 3; i <= NF; i++) if ($i ~ /^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/) {
                split($i, g, /[x+]/); w = g[1]; h = g[2]; x = g[3]; y = g[4]; on = 1
            }
            next
        }
        name != "" && /^[ \t]/ {
            m = $1
            if (pw == 0 && $0 ~ /\+/) { split(m, p, /[x_]/); pw = p[1]; ph = p[2] }
            for (i = 2; i <= NF; i++) if ($i ~ /\*/) { sub(/_custom$/, "", m); mode = m }
        }
        END { flush() }'
}

load_state() {
    mapfile -t ST < <(query_xrandr | read_state)
}

field() { # args: state line, field number
    local -a f; read -ra f <<<"$1"; echo "${f[$2-1]}"
}

state_index() { # args: output name. Prints the index into ST.
    local i
    for i in "${!ST[@]}"; do [[ $(field "${ST[i]}" 1) == "$1" ]] && { echo "$i"; return 0; }; done
    return 1
}

# args: name, new mode. Updates the mode and, for WxH, the size.
set_mode() {
    local i name mode x y p w h
    i=$(state_index "$1") || return 1
    read -r name mode x y p w h <<<"${ST[i]}"
    mode=$2
    [[ $mode =~ ^([0-9]+)x([0-9]+)$ ]] && { w=${BASH_REMATCH[1]}; h=${BASH_REMATCH[2]}; }
    ST[i]="$name $mode $x $y $p $w $h"
}

# args: name. Primary moves here; an output that is off cannot be primary.
set_primary() {
    local i name mode x y p w h
    for i in "${!ST[@]}"; do
        read -r name mode x y p w h <<<"${ST[i]}"
        if [[ $name == "$1" && $mode != off ]]; then p=1; else p=0; fi
        ST[i]="$name $mode $x $y $p $w $h"
    done
}

# args: name, left-of|right-of|above|below, other name.
place() {
    local i j name mode x y p w h on om ox oy op ow oh
    i=$(state_index "$1") && j=$(state_index "$3") || return 1
    read -r name mode x y p w h <<<"${ST[i]}"
    read -r on om ox oy op ow oh <<<"${ST[j]}"
    case $2 in
        right-of) x=$((ox + ow)); y=$oy ;;
        left-of)  x=$((ox - w));  y=$oy ;;
        below)    x=$ox;          y=$((oy + oh)) ;;
        above)    x=$ox;          y=$((oy - h)) ;;
    esac
    ST[i]="$name $mode $x $y $p $w $h"
}

# args: name. Turn on at the preferred mode, or off. Never leaves nothing active.
toggle_output() {
    local i name mode x y p w h active=0 l
    i=$(state_index "$1") || return 1
    read -r name mode x y p w h <<<"${ST[i]}"
    if [[ $mode == off ]]; then
        set_mode "$name" auto
    else
        for l in "${ST[@]}"; do [[ $(field "$l" 2) != off ]] && active=$((active + 1)); done
        if ((active < 2)); then notify "At least one output must stay on."; return 1; fi
        set_mode "$name" off
        if [[ $p == 1 ]]; then
            for l in "${ST[@]}"; do
                [[ $(field "$l" 2) != off ]] && { set_primary "$(field "$l" 1)"; break; }
            done
        fi
    fi
}

# Layout lines for the working state. Positions are shifted so the top left
# of the active outputs is 0x0 (xrandr rejects negative positions).
emit_layout() {
    local l name mode x y p w h minx= miny=
    for l in "${ST[@]}"; do
        read -r name mode x y p w h <<<"$l"
        [[ $mode == off ]] && continue
        [[ -z $minx || $x -lt $minx ]] && minx=$x
        [[ -z $miny || $y -lt $miny ]] && miny=$y
    done
    for l in "${ST[@]}"; do
        read -r name mode x y p w h <<<"$l"
        if [[ $mode == off ]]; then echo "$name off"; continue; fi
        echo "$name $mode --pos $((x - minx))x$((y - miny))$([[ $p == 1 ]] && echo ' --primary')"
    done
}

# args: key, conf file. Replaces the key's active entry with the working layout, or appends one.
save_layout() {
    local key=$1 conf=$2 kept
    kept=$(awk -v start="LAYOUTS[\"$key\"]=\"" '
        skipping { if ($0 == "\"") skipping = 0; next }
        index($0, start) == 1 { skipping = 1; next }
        { print }' "$conf") || return 1
    {
        printf '%s
' "$kept"
        printf '
# Saved by monitor_popup.sh:
LAYOUTS["%s"]="
' "$key"
        emit_layout
        printf '"
'
    } >"$conf"
}

describe() { # args: state line
    local name mode x y p w h
    read -r name mode x y p w h <<<"$1"
    if [[ $mode == off ]]; then printf '%s  off\n' "$name"
    else printf '%s  %s  +%s+%s%s\n' "$name" "$mode" "$x" "$y" "$([[ $p == 1 ]] && echo '  primary')"; fi
}

current_key() { "$RECONCILE" --key 2>/dev/null; }

output_menu() { # args: name
    local name=$1 choice other i mode
    while :; do
        i=$(state_index "$name") || return
        mode=$(field "${ST[i]}" 2)
        choice=$(printf '%s\n' "$([[ $mode == off ]] && echo 'Turn on' || echo 'Turn off')" \
            'Mode' 'Place right of' 'Place left of' 'Place above' 'Place below' 'Make primary' 'Back' \
            | menu "$name" "$(describe "${ST[i]}")") || return
        case $choice in
            'Turn on'|'Turn off') toggle_output "$name" ;;
            Mode)
                choice=$({ echo auto; output_modes "$(query_xrandr)" "$name" | sed 's/_custom$//' | awk '!s[$0]++'; } \
                    | menu "$name mode" "now: $mode") && set_mode "$name" "$choice" ;;
            'Place '*)
                other=$(for i in "${!ST[@]}"; do field "${ST[i]}" 1; done | grep -vx -- "$name" \
                    | menu "$choice" "") || continue
                place "$name" "$(sed 's/^Place //; s/ /-/' <<<"${choice,,}")" "$other" ;;
            'Make primary') set_primary "$name" ;;
            *) return ;;
        esac
    done
}

# Applies the working layout; reports a failure. reconcile reads it from a pipe.
apply() {
    local err
    if [[ -n $DRY_RUN ]]; then "$RECONCILE" --dry-run --layout <(emit_layout); return; fi
    err=$("$RECONCILE" --layout <(emit_layout) 2>&1 >/dev/null) \
        || { notify "Applying failed: $(tail -n 3 <<<"$err")"; return 1; }
}

main_menu() {
    local rows choice key msg origin
    while :; do
        key=$(current_key)
        "$RECONCILE" --known 2>/dev/null && origin=configured || origin=fallback
        msg="set: $key ($origin layout)"
        rows=$(for choice in "${ST[@]}"; do describe "$choice"; done
               printf '%s\n' '--' 'Apply' 'Apply and save to monitor_layouts.conf' 'Reset to the configured layout' 'Cancel')
        choice=$(menu "Monitors" "$msg" <<<"$rows") || return 0
        case $choice in
            Apply) apply && return 0 ;;
            Apply\ and\ save*) apply && save_layout "$key" "$LAYOUTS_CONF" && return 0 ;;
            Reset*) "$RECONCILE" --force; load_state ;;
            Cancel|--|'') [[ $choice == Cancel || -z $choice ]] && return 0 ;;
            *) output_menu "${choice%% *}" ;;
        esac
    done
}

main() {
    while (($#)); do
        case $1 in
            --dry-run) DRY_RUN=1 ;;
            *) log "unknown argument: $1"; return 2 ;;
        esac
        shift
    done
    load_state
    ((${#ST[@]})) || { notify "No connected outputs."; return 1; }
    main_menu
}

[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
