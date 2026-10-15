#!/usr/bin/env bash
# Load each tag's assigned layout for the connected monitor set.
#   An empty tag is overwritten; a tag with windows is only overwritten when
#   its shape matches a named layout (anything else is custom and is kept).
#   A tag whose layout is `none` is left alone. --dry-run prints what would happen.
#   A tag shown on a portrait monitor (taller than wide) gets its layout transposed: every split and clients
#   direction swapped, so side by side becomes stacked. A tag that is not on a monitor is not transposed.
#   --only TAG does just that tag (rule_hook.sh runs it when a tag is shown on a monitor).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYOUTS_FILE=${HLWM_LAYOUTS:-$SCRIPT_DIR/hlwm_layouts.conf}
TAG_LAYOUTS_FILE=${HLWM_TAG_LAYOUTS:-$SCRIPT_DIR/hlwm_tag_layouts.conf}

hc() { "${herbstclient_command[@]:-herbstclient}" "$@"; }
log() { echo "tag_layouts: $*" >&2; }

while (($#)); do
    case $1 in
        --dry-run) DRY=1 ;;
        --only) shift; ONLY=$1 ;;
    esac
    shift
done

# Swap horizontal and vertical in the splits and the clients algorithms.
transpose() {
    printf '%s' "$1" | sed -E 's/(split|clients) horizontal/\1 @@/g; s/(split|clients) vertical/\1 horizontal/g; s/@@/vertical/g'
}

# portrait[TAG]=1 for each tag shown on a monitor taller than wide (from `list_monitors`).
declare -A portrait=()
while read -r w h tag; do
    ((h > w)) && portrait[$tag]=1
done < <(hc list_monitors | sed -nE 's/^[0-9]+: ([0-9]+)x([0-9]+)[+-][0-9]+[+-][0-9]+.* with tag "([^"]*)".*/\1 \2 \3/p')

shape() {
    printf '%s' "$1" | tr '\n' ' ' \
        | sed -E 's/0x[0-9a-fA-F]+//g; s/[[:space:]]+/ /g; s/ ?([()]) ?/\1/g; s/\(split ([a-z]+):[^ (]*/(split \1/g; s/\(clients ([a-z]+):[^ ()]*/(clients \1/g'
}

source "$LAYOUTS_FILE"
source "$TAG_LAYOUTS_FILE"

key=$("$SCRIPT_DIR/monitor_reconcile.sh" --key)
[[ -v TAG_LAYOUTS[$key] ]] || { log "no assignments for '$key'"; exit 0; }

named=()
while read -r var; do
    named+=("$(shape "${!var}")" "$(shape "$(transpose "${!var}")")")
done < <(grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' "$LAYOUTS_FILE" | tr -d =)

while read -r line; do
    [[ -z $line ]] && continue
    [[ $line =~ ^(.*[^[:space:]])[[:space:]]*\[[^]]*\][[:space:]]*$ ]] && line=${BASH_REMATCH[1]}
    [[ $line =~ ^(.*[^[:space:]])[[:space:]]*\{[1-9]\}[[:space:]]*$ ]] && line=${BASH_REMATCH[1]}
    var=${line##* }
    tag=${line% *}
    tag=${tag%"${tag##*[![:space:]]}"}
    [[ $var == none ]] && continue
    [[ -n $ONLY && $tag != "$ONLY" ]] && continue
    [[ -v $var ]] || { log "$tag: unknown layout '$var'"; continue; }
    hc silent get_attr "tags.by-name.$tag.index" || { log "$tag: no such tag"; continue; }

    layout=${!var} how=
    if [[ -n ${portrait[$tag]} ]]; then layout=$(transpose "$layout") how=" (portrait)"; fi
    dump=$(hc dump "$tag")
    want=$(shape "$layout")
    have=$(shape "$dump")

    if [[ $have == "$want" ]]; then
        continue
    elif [[ $dump == *0x* ]]; then
        match=
        for s in "${named[@]}"; do [[ $s == "$have" ]] && match=1; done
        [[ -z $match ]] && { log "$tag: custom, kept"; continue; }
    fi

    log "$tag: $var$how"
    [[ -n $DRY ]] || hc load "$tag" "$layout"
done <<< "${TAG_LAYOUTS[$key]}"
