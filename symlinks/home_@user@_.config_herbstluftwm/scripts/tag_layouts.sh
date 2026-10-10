#!/usr/bin/env bash
# Load each tag's assigned layout for the connected monitor set.
#   An empty tag is overwritten; a tag with windows is only overwritten when
#   its shape matches a named layout (anything else is custom and is kept).
#   --dry-run prints what would happen.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYOUTS_FILE=${HLWM_LAYOUTS:-$SCRIPT_DIR/hlwm_layouts.conf}
TAG_LAYOUTS_FILE=${HLWM_TAG_LAYOUTS:-$SCRIPT_DIR/hlwm_tag_layouts.conf}

hc() { "${herbstclient_command[@]:-herbstclient}" "$@"; }
log() { echo "tag_layouts: $*" >&2; }

[[ $1 == --dry-run ]] && DRY=1

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
    named+=("$(shape "${!var}")")
done < <(grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' "$LAYOUTS_FILE" | tr -d =)

while read -r line; do
    [[ -z $line ]] && continue
    var=${line##* }
    tag=${line% *}
    tag=${tag%"${tag##*[![:space:]]}"}
    [[ -v $var ]] || { log "$tag: unknown layout '$var'"; continue; }
    hc silent get_attr "tags.by-name.$tag.index" || { log "$tag: no such tag"; continue; }

    dump=$(hc dump "$tag")
    want=$(shape "${!var}")
    have=$(shape "$dump")

    if [[ $have == "$want" ]]; then
        continue
    elif [[ $dump == *0x* ]]; then
        match=
        for s in "${named[@]}"; do [[ $s == "$have" ]] && match=1; done
        [[ -z $match ]] && { log "$tag: custom, kept"; continue; }
    fi

    log "$tag: $var"
    [[ -n $DRY ]] || hc load "$tag" "${!var}"
done <<< "${TAG_LAYOUTS[$key]}"
