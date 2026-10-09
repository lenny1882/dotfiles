#!/usr/bin/env bash
# Compare the connected monitors with the last applied set. If they differ,
# pick a layout, apply it with xrandr, and tell herbstluftwm.
#
#   monitor_reconcile.sh [--dry-run] [--force]   reconcile
#   monitor_reconcile.sh --key                   print the layout key and exit
#   monitor_reconcile.sh --known                 exit 0 if the connected set is known
#   monitor_reconcile.sh --layout FILE           apply the layout lines in FILE (implies --force)
#
# --layout is what monitor_popup.sh uses. The key is stored as usual, so the choice
# holds until the connected set changes; a restart goes back to the configured layout.
#
# Test without a display: XRANDR_FIXTURE=<xrandr --query output>,
# LISTMONITORS_FIXTURE=<xrandr --listmonitors output>, with --dry-run.

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

# stdin: xrandr --query
connected_outputs() { awk '$2 == "connected" { print $1 }'; }

# Disconnected outputs that still hold a mode, and need switching off.
stale_outputs() { awk '$2 == "disconnected" && $3 ~ /^[0-9]+x[0-9]+\+/ { print $1 }'; }

# stdin: xrandr --listmonitors. Prints WxH+X+Y per monitor, left to right.
geometries() {
    awk '/^ *[0-9]+:/ { g = $3; gsub(/\/[0-9]+/, "", g); split(g, a, "+"); print a[2], a[3], g }' \
        | sort -n -k1,1 -k2,2 | awk '{ print $3 }'
}

is_internal() { [[ $1 == eDP* || $1 == LVDS* || $1 == DSI* ]]; }

# Panel stays on; first external is primary, panel to its left, the rest to the right.
fallback_layout() {
    local internal="" prev="" o
    local -a externals=()
    for o in "$@"; do
        if is_internal "$o" && [[ -z $internal ]]; then internal=$o; else externals+=("$o"); fi
    done
    if ((${#externals[@]} == 0)); then
        echo "$internal auto --primary --pos 0x0"
        return
    fi
    for o in "${externals[@]}"; do
        if [[ -z $prev ]]; then echo "$o auto --primary --pos 0x0"; else echo "$o auto --right-of $prev"; fi
        prev=$o
    done
    [[ -n $internal ]] && echo "$internal auto --left-of ${externals[0]}"
    return 0
}

# Known: the set has a layout in the config, or is only the internal panel(s).
# args: key, then the outputs.
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

# Modes an output lists. args: xrandr --query output, output name.
output_modes() {
    awk -v o="$2" '$1 == o { f = 1; next } f && /^[^ \t]/ { f = 0 } f { print $1 }' <<<"$1"
}

# Timing for a mode the monitor does not list (a missing or rejected EDID
# leaves only low fallback modes). 1920x1080 uses the standard HDMI timing,
# anything else the CVT one. args: WxH. Prints the xrandr --newmode arguments.
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

# stdin: layout lines. args: xrandr --query output. Prints the same lines, with
# each WxH the output does not list replaced by a mode created for it
# (WxH_custom). Falls back to `auto` if the mode cannot be created.
resolve_modes() {
    local state=$1 name mode rest modes timing
    while read -r name mode rest; do
        [[ -z $name ]] && continue
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

# stdin: layout lines. args: stale outputs. Prints one xrandr command, NUL-free, one arg per line.
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

# Safety guard: the internal panel is only switched off once another output
# is verified active. stdin: layout lines. Prints the layout to apply first;
# any panel-off lines follow a `--` line.
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

# args: the non-off output names from the first pass. True if all hold a mode.
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
    local state key current
    local -a outs stale cmd geoms

    state=$(query_xrandr) || { log "xrandr failed"; return 1; }
    mapfile -t outs < <(connected_outputs <<<"$state" | LC_ALL=C sort)
    mapfile -t stale < <(stale_outputs <<<"$state")
    if ((${#outs[@]} == 0)); then
        log "no connected outputs, leaving things alone"
        return 1
    fi
    key="${outs[*]}"

    if [[ -n $KEY_ONLY ]]; then echo "$key"; return 0; fi
    if [[ -n $KNOWN_ONLY ]]; then
        # shellcheck source=monitor_layouts.conf
        source "$LAYOUTS_CONF"
        is_known_set "$key" "${outs[@]}"
        return
    fi

    current=$(stored_layout)
    if [[ -z $FORCE && -z $LAYOUT_FILE && $key == "$current" ]]; then
        log "unchanged ($key)"
        return 0
    fi
    log "applying '$key'"

    # shellcheck source=monitor_layouts.conf
    source "$LAYOUTS_CONF"
    local planned first deferred="" line name mode sep
    local -a active=()
    planned=$(if [[ -n $LAYOUT_FILE ]]; then sed '/^[[:space:]]*$/d' "$LAYOUT_FILE"; else layout_for_key "$key" "${outs[@]}"; fi \
        | split_panel_off | resolve_modes "$state")
    # the panel-off lines, if any, follow a `--` line
    first="" sep=0
    while IFS= read -r line; do
        if [[ $line == --* ]]; then sep=1
        elif ((sep)); then deferred+="$line"$'\n'
        else first+="$line"$'\n'
        fi
    done <<<"$planned"
    while read -r name mode _; do
        [[ $mode != off ]] && active+=("$name")
    done <<<"$first"

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

    if [[ -n $DRY_RUN && -z $LISTMONITORS_FIXTURE ]]; then
        log "would run: hc set_monitors <geometries from xrandr --listmonitors>"
        return 0
    fi
    mapfile -t geoms < <(query_listmonitors | geometries)
    run hc set_monitors "${geoms[@]}"
    if [[ -z $DRY_RUN ]]; then
        hc set_attr "$ATTR" "$key"
        # lets the watcher rebuild the bars and padding for the new monitors
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
            --known)   KNOWN_ONLY=1 ;;
            *) log "unknown argument: $1"; return 2 ;;
        esac
        shift
    done
    reconcile
}

[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
