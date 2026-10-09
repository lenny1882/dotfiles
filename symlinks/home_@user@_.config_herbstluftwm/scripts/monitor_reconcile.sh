#!/usr/bin/env bash
# Compare the connected monitors with the last applied set. If they differ,
# pick a layout, apply it with xrandr, and tell herbstluftwm.
#
#   monitor_reconcile.sh [--dry-run] [--force]   reconcile
#   monitor_reconcile.sh --key                   print the layout key and exit
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
# is confirmed active. stdin: layout lines. Prints the layout to apply first;
# panel-off lines are written to the file named by $1.
split_panel_off() {
    local deferred=$1 name mode rest kept=0
    local -a lines=()
    : >"$deferred"
    while read -r name mode rest; do
        [[ -z $name ]] && continue
        if [[ $mode == off ]] && is_internal "$name"; then
            echo "$name $mode $rest" >>"$deferred"
        else
            lines+=("$name $mode $rest")
            [[ $mode != off ]] && kept=1
        fi
    done
    if [[ -s $deferred && $kept -eq 0 ]]; then
        log "layout leaves no other active output, keeping the panel on"
        while read -r name _; do lines+=("$name auto"); done <"$deferred"
        : >"$deferred"
    fi
    printf '%s\n' "${lines[@]}"
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

    current=$(stored_layout)
    if [[ -z $FORCE && $key == "$current" ]]; then
        log "unchanged ($key)"
        return 0
    fi
    log "applying '$key'"

    # shellcheck source=monitor_layouts.conf
    source "$LAYOUTS_CONF"
    local deferred first name mode
    local -a active=()
    deferred=$(mktemp) && trap 'rm -f "$deferred"' RETURN
    first=$(layout_for_key "$key" "${outs[@]}" | split_panel_off "$deferred")
    while read -r name mode _; do
        [[ $mode != off ]] && active+=("$name")
    done <<<"$first"

    mapfile -t cmd < <(xrandr_args "${stale[@]}" <<<"$first")
    run "${cmd[@]}" || { log "xrandr failed"; return 1; }

    if [[ -s $deferred ]]; then
        if outputs_active "${active[@]}"; then
            mapfile -t cmd < <(xrandr_args <"$deferred")
            run "${cmd[@]}" || log "turning the panel off failed, leaving it on"
        else
            log "${active[*]} not active after applying, keeping the panel on"
            while read -r name _; do run xrandr --output "$name" --auto; done <"$deferred"
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
            --key)     KEY_ONLY=1 ;;
            *) log "unknown argument: $1"; return 2 ;;
        esac
        shift
    done
    reconcile
}

[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
