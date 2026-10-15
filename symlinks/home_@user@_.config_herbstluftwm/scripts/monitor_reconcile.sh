#!/usr/bin/env bash
# Compare the connected monitors with the last applied set. If they differ,
# pick a layout, apply it with xrandr, and tell herbstluftwm.
#
#   monitor_reconcile.sh [--dry-run] [--force]   reconcile
#   monitor_reconcile.sh --key                   print the layout key and exit
#   monitor_reconcile.sh --ids                   print "port name id" for each connected output
#   monitor_reconcile.sh --known                 exit 0 if the connected set is known
#   monitor_reconcile.sh --layout FILE           apply the layout lines in FILE (implies --force)
#
# --layout is what monitor_tui.py uses; the choice holds until the connected set changes.
#
# Test without a display: XRANDR_FIXTURE=<xrandr --query output>,
# LISTMONITORS_FIXTURE=<xrandr --listmonitors output>, with --dry-run.
# XRANDR_PROP_FIXTURE=<xrandr --prop output> supplies the EDIDs; without it every output is named by its port.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYOUTS_CONF="${LAYOUTS_CONF:-$SCRIPT_DIR/monitor_layouts.conf}"
ATTR=my_monitor_layout

declare -F hc >/dev/null || hc() { herbstclient "$@"; }

log() { printf 'monitor_reconcile: %s\n' "$*" >&2; }

query_xrandr() {
    if [[ -n $XRANDR_FIXTURE ]]; then cat "$XRANDR_FIXTURE"; else xrandr --query; fi
}

query_listmonitors() {
    if [[ -n $LISTMONITORS_FIXTURE ]]; then cat "$LISTMONITORS_FIXTURE"; else xrandr --listmonitors; fi
}

query_props() {
    if [[ -n $XRANDR_PROP_FIXTURE ]]; then cat "$XRANDR_PROP_FIXTURE"
    elif [[ -z $XRANDR_FIXTURE ]]; then xrandr --prop
    fi
}

# stdin: xrandr --prop. Prints "port id" per output, the id being the first line of its EDID.
edid_ids() {
    awk '/^[^ \t]/ { port = $1; want = 0 }
         want { gsub(/[ \t]/, ""); print port, $0; want = 0 }
         /^[ \t]+EDID:/ { want = 1 }'
}

connected_outputs() { awk '$2 == "connected" { print $1 }'; }

stale_outputs() { awk '$2 == "disconnected" && ($3 ~ /^[0-9]+x[0-9]+\+/ || $4 ~ /^[0-9]+x[0-9]+\+/) { print $1 }'; }

# stdin: xrandr --listmonitors. Prints WxH+X+Y per monitor, left to right.
geometries() {
    awk '/^ *[0-9]+:/ { g = $3; gsub(/\/[0-9]+/, "", g); split(g, a, "+"); print a[2], a[3], g }' \
        | sort -n -k1,1 -k2,2 | awk '{ print $3 }'
}

# args: the connected ports. Fills NAME_OF[port] and PORT_OF[name] from MONITORS (id -> name).
# An unlisted external is named by its id (so the key shows what to add), a panel or an output without an EDID by its port.
resolve_names() {
    local port id name
    local -A id_of=()
    declare -gA NAME_OF=() PORT_OF=() IDS=()
    while read -r port id; do id_of[$port]=$id; done < <(query_props | edid_ids)
    for port in "$@"; do
        id=${id_of[$port]:-}
        if [[ -n $id && -v MONITORS[$id] ]]; then name=${MONITORS[$id]}
        elif [[ -n $id ]] && ! is_internal "$port"; then name=$id
        else name=$port
        fi
        NAME_OF[$port]=$name
        PORT_OF[$name]=$port
        IDS[$port]=$id
    done
}

# stdin: layout lines naming monitors. Prints them naming ports; words that are not monitor names pass through.
names_to_ports() {
    local line word out
    while read -r line; do
        out=()
        for word in $line; do out+=("${PORT_OF[$word]:-$word}"); done
        echo "${out[*]}"
    done
}

# stdin: layout lines. Prints "port geometry..." for each line with `--split GEOMETRY...` (WxH+X+Y, relative to the monitor).
split_specs() {
    awk '{ for (i = 1; i <= NF; i++) if ($i == "--split") {
               out = $1
               for (j = i + 1; j <= NF && $j !~ /^--/; j++) out = out " " $j
               print out; break } }'
}

# stdin: layout lines. Prints them without `--split GEOMETRY...`.
strip_splits() {
    awk '{ out = ""; skip = 0
           for (i = 1; i <= NF; i++) {
               if ($i == "--split") { skip = 1; continue }
               if (skip && $i !~ /^--/) continue
               skip = 0; out = out (out == "" ? "" : " ") $i }
           print out }'
}

# Names of the virtual monitors made earlier (PORT~N), one per line.
virtual_monitors() {
    query_listmonitors | awk '/^ *[0-9]+:/ { n = $2; sub(/^[+*]+/, "", n); if (n ~ /~/) print n }'
}

# stdin: split_specs lines. args: xrandr --query output (after applying). Defines one virtual monitor per geometry.
apply_splits() {
    local state=$1 port line W H X Y MW MH g n gw gh gx gy
    local -a geoms
    while read -r port geoms_line; do
        [[ -z $port ]] && continue
        read -ra geoms <<<"$geoms_line"
        line=$(grep -m1 "^$port connected" <<<"$state")
        if [[ ! $line =~ ([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+) ]]; then
            log "$port is not active, not splitting it"; continue
        fi
        W=${BASH_REMATCH[1]} H=${BASH_REMATCH[2]} X=${BASH_REMATCH[3]} Y=${BASH_REMATCH[4]}
        MW=0 MH=0
        [[ $line =~ ([0-9]+)mm\ x\ ([0-9]+)mm ]] && { MW=${BASH_REMATCH[1]}; MH=${BASH_REMATCH[2]}; }
        local ok=1
        for g in "${geoms[@]}"; do
            if [[ ! $g =~ ^([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)$ ]] \
                || ((BASH_REMATCH[3] + BASH_REMATCH[1] > W || BASH_REMATCH[4] + BASH_REMATCH[2] > H)); then
                log "split '$g' is not a WxH+X+Y inside $port (${W}x$H), not splitting it"; ok=0; break
            fi
        done
        ((ok)) || continue
        n=0
        for g in "${geoms[@]}"; do
            [[ $g =~ ^([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)$ ]]
            gw=${BASH_REMATCH[1]} gh=${BASH_REMATCH[2]} gx=${BASH_REMATCH[3]} gy=${BASH_REMATCH[4]}
            n=$((n + 1))
            run xrandr --setmonitor "$port~$n" "$gw/$((gw * MW / W))x$gh/$((gh * MH / H))+$((X + gx))+$((Y + gy))" "$([[ $n == 1 ]] && echo "$port" || echo none)"
        done
    done
}

is_internal() { [[ $1 == eDP* || $1 == LVDS* || $1 == DSI* ]]; }

# Panel stays on and primary at 0x0; the externals go to its right, one after the other.
fallback_layout() {
    local internal="" prev="" o
    local -a externals=()
    for o in "$@"; do
        if is_internal "$o" && [[ -z $internal ]]; then internal=$o; else externals+=("$o"); fi
    done
    if [[ -n $internal ]]; then
        echo "$internal auto --primary --pos 0x0"
        prev=$internal
    fi
    for o in "${externals[@]}"; do
        if [[ -z $prev ]]; then echo "$o auto --primary --pos 0x0"; else echo "$o auto --right-of $prev"; fi
        prev=$o
    done
    return 0
}

# Known: the set has a layout in the config, or is only the internal panel(s).
is_known_set() {
    local key=$1 o; shift
    [[ -v LAYOUTS[$key] ]] && return 0
    for o in "$@"; do is_internal "$o" || return 1; done
}

# args: key, then the outputs. Prints layout lines.
layout_for_key() {
    local key=$1; shift
    if [[ -v LAYOUTS[$key] ]]; then
        printf '%s\n' "${LAYOUTS[$key]}" | sed '/^[[:space:]]*$/d'
    else
        log "no layout for '$key', using fallback"
        fallback_layout "$@"
    fi
}

output_modes() {
    awk -v o="$2" '$1 == o { f = 1; next } f && /^[^ \t]/ { f = 0 } f { print $1 }' <<<"$1"
}

# xrandr --newmode arguments for a mode the monitor lacks: HDMI timing for 1920x1080, CVT otherwise. args: WxH.
mode_timing() {
    case $1 in
        1920x1080) echo "148.50 1920 2008 2052 2200 1080 1084 1089 1125 +hsync +vsync" ;;
        *) cvt "${1%x*}" "${1#*x}" 60 2>/dev/null | awk '/^Modeline/ { sub(/^Modeline +"[^"]*" +/, ""); print }' ;;
    esac
}

# Like run, but hides xrandr's complaint when the mode already exists.
quiet() {
    if [[ -n $DRY_RUN ]]; then run "$@"; else "$@" 2>/dev/null; fi
}

FALLBACK_MODE=1920x1080     # for an external that lists nothing but the 640x480 fallback

# stdin: layout lines. args: xrandr --query output. Replaces each WxH the output lacks with a created WxH_custom, or `auto`.
#   An external on `auto` that lists no usable mode gets FALLBACK_MODE.
resolve_modes() {
    local state=$1 name mode rest modes timing
    while read -r name mode rest; do
        [[ -z $name ]] && continue
        if [[ $mode == auto ]] && ! is_internal "$name" \
            && [[ -z $(output_modes "$state" "$name" | grep -vE '^(640x480(_custom)?)?$') ]]; then
            log "$name lists no usable mode (EDID missing or rejected), assuming $FALLBACK_MODE"
            mode=$FALLBACK_MODE
        fi
        if [[ $mode =~ ^[0-9]+x[0-9]+$ ]]; then
            modes=$(output_modes "$state" "$name")
            if grep -qx -- "$mode" <<<"$modes"; then
                :
            elif grep -qx -- "${mode}_custom" <<<"$modes"; then
                mode=${mode}_custom
            else
                timing=$(mode_timing "$mode")
                log "$name does not list $mode, adding it"
                # shellcheck disable=SC2086  # word splitting of $timing is intended
                if [[ -n $timing ]] \
                    && { quiet xrandr --newmode "${mode}_custom" $timing || true; } \
                    && run xrandr --addmode "$name" "${mode}_custom"; then
                    mode=${mode}_custom
                else
                    log "could not add $mode to $name, using auto"
                    mode=auto
                fi
            fi
        fi
        echo "$name $mode $rest"
    done
}

xrandr_args() {
    local name mode rest s
    printf '%s\n' xrandr
    while read -r name mode rest; do
        [[ -z $name ]] && continue
        printf '%s\n' --output "$name"
        case $mode in
            off)  printf '%s\n' --off ;;
            auto) printf '%s\n' --auto ;;
            *)    printf '%s\n' --mode "$mode" ;;
        esac
        # shellcheck disable=SC2086  # word splitting of $rest is intended
        [[ -n $rest ]] && printf '%s\n' $rest
    done
    for s in "$@"; do printf '%s\n' --output "$s" --off; done
}

# stdin: layout lines. The internal panel is only switched off once another output is active; its off lines follow a `--` line.
split_panel_off() {
    local name mode rest kept=0
    local -a lines=() off=()
    while read -r name mode rest; do
        [[ -z $name ]] && continue
        if [[ $mode == off ]] && is_internal "$name"; then
            off+=("$name $mode $rest")
        else
            lines+=("$name $mode $rest")
            [[ $mode != off ]] && kept=1
        fi
    done
    if ((${#off[@]} && !kept)); then
        log "layout leaves no other active output, keeping the panel on"
        for name in "${off[@]}"; do lines+=("${name%% *} auto"); done
        off=()
    fi
    printf '%s\n' "${lines[@]}"
    ((${#off[@]})) && printf '%s\n' -- "${off[@]}"
    return 0
}

outputs_active() {
    local state o
    if [[ -n $DRY_RUN ]]; then
        [[ -z $XRANDR_AFTER_FIXTURE ]] && return 0
        state=$(cat "$XRANDR_AFTER_FIXTURE")
    else
        state=$(query_xrandr) || return 1
    fi
    for o in "$@"; do
        awk -v o="$o" '$1 == o && $2 == "connected" { for (i = 3; i <= NF; i++) if ($i ~ /^[0-9]+x[0-9]+\+/) f = 1 } END { exit !f }' <<<"$state" || return 1
    done
}

run() {
    if [[ -n $DRY_RUN ]]; then log "would run: $*"; else "$@"; fi
}

stored_layout() {
    [[ -n $DRY_RUN ]] && return 0
    hc attr "$ATTR" >/dev/null 2>&1 || hc new_attr string "$ATTR" >/dev/null 2>&1
    hc get "$ATTR" 2>/dev/null
}

reconcile() {
    local state key current port
    local -a outs stale cmd geoms

    state=$(query_xrandr) || { log "xrandr failed"; return 1; }
    mapfile -t outs < <(connected_outputs <<<"$state" | LC_ALL=C sort)
    mapfile -t stale < <(stale_outputs <<<"$state")
    if ((${#outs[@]} == 0)); then
        log "no connected outputs, leaving things alone"
        return 1
    fi

    declare -gA MONITORS=()
    # shellcheck source=monitor_layouts.conf
    source "$LAYOUTS_CONF"
    resolve_names "${outs[@]}"
    local -a names=()
    for port in "${outs[@]}"; do names+=("${NAME_OF[$port]}"); done
    mapfile -t names < <(printf '%s\n' "${names[@]}" | LC_ALL=C sort)
    key="${names[*]}"

    if [[ -n $KEY_ONLY ]]; then echo "$key"; return 0; fi
    if [[ -n $IDS_ONLY ]]; then
        for port in "${outs[@]}"; do printf '%s %s %s\n' "$port" "${NAME_OF[$port]}" "${IDS[$port]:--}"; done
        return 0
    fi
    if [[ -n $KNOWN_ONLY ]]; then is_known_set "$key" "${outs[@]}"; return; fi

    current=$(stored_layout)
    if [[ -z $FORCE && -z $LAYOUT_FILE && $key == "$current" ]]; then
        log "unchanged ($key)"
        return 0
    fi
    log "applying '$key'"

    local raw splits planned first deferred="" line name mode sep
    local -a active=()
    raw=$(if [[ -n $LAYOUT_FILE ]]; then sed '/^[[:space:]]*$/d' "$LAYOUT_FILE"; else layout_for_key "$key" "${outs[@]}" | names_to_ports; fi)
    splits=$(split_specs <<<"$raw")
    planned=$(strip_splits <<<"$raw" | split_panel_off | resolve_modes "$state")
    first="" sep=0
    while IFS= read -r line; do
        if [[ $line == --* ]]; then sep=1
        elif ((sep)); then deferred+="$line"$'\n'
        else first+="$line"$'\n'
        fi
    done <<<"$planned"
    while read -r name mode _; do
        [[ -n $name && $mode != off ]] && active+=("$name")
    done <<<"$first"

    while read -r name; do run xrandr --delmonitor "$name"; done < <(virtual_monitors)
    mapfile -t cmd < <(xrandr_args "${stale[@]}" <<<"$first")
    run "${cmd[@]}" || { log "xrandr failed"; return 1; }

    if [[ -n $deferred ]]; then
        if outputs_active "${active[@]}"; then
            mapfile -t cmd < <(xrandr_args <<<"$deferred")
            run "${cmd[@]}" || log "turning the panel off failed, leaving it on"
        else
            log "${active[*]} not active after applying, keeping the panel on"
            while read -r name _; do run xrandr --output "$name" --auto; done <<<"$deferred"
        fi
    fi

    [[ -n $splits ]] && apply_splits "$(query_xrandr)" <<<"$splits"

    if [[ -n $DRY_RUN && -z $LISTMONITORS_FIXTURE ]]; then
        log "would run: hc set_monitors <geometries from xrandr --listmonitors>"
        return 0
    fi
    mapfile -t geoms < <(query_listmonitors | geometries)
    run hc set_monitors "${geoms[@]}"
    if [[ -z $DRY_RUN ]]; then
        hc set_attr "$ATTR" "$key"
        hc emit_hook monitors_applied
    fi
    return 0
}

main() {
    while (($#)); do
        case $1 in
            --dry-run) DRY_RUN=1 ;;
            --force)   FORCE=1 ;;
            --layout)  LAYOUT_FILE=$2; shift
                       [[ -r $LAYOUT_FILE ]] || { log "cannot read layout file: $LAYOUT_FILE"; return 2; } ;;
            --key)     KEY_ONLY=1 ;;
            --ids)     IDS_ONLY=1 ;;
            --known)   KNOWN_ONLY=1 ;;
            *) log "unknown argument: $1"; return 2 ;;
        esac
        shift
    done
    reconcile
}

[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
