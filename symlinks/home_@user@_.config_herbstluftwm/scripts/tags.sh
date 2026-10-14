#!/usr/bin/env bash
# Name the 9 tags and bind their keys for the connected monitor set.
#   Names come from the set's lines in hlwm_tag_layouts.conf, in order, padded to 9 with
#   1..9. A tag's key is its {n} on the line, else its position (1-9).
#   Existing tags are renamed in place, so their windows stay. --dry-run prints "index name key".

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAG_LAYOUTS_FILE=${HLWM_TAG_LAYOUTS:-$SCRIPT_DIR/hlwm_tag_layouts.conf}

source ~/.config/herbstluftwm/variables.autostart
hc() { "${herbstclient_command[@]:-herbstclient}" "$@"; }

[[ $1 == --dry-run ]] && DRY=1

source "$TAG_LAYOUTS_FILE"
set_key=$("$SCRIPT_DIR/monitor_reconcile.sh" --key)

names=() keys=()
if [[ -v TAG_LAYOUTS[$set_key] ]]; then
    while read -r line; do
        [[ -z $line ]] && continue
        [[ $line =~ ^(.*[^[:space:]])[[:space:]]*\[[^]]*\][[:space:]]*$ ]] && line=${BASH_REMATCH[1]}
        key=$((${#names[@]} + 1))
        [[ $line =~ ^(.*[^[:space:]])[[:space:]]*\{([1-9])\}[[:space:]]*$ ]] && { line=${BASH_REMATCH[1]}; key=${BASH_REMATCH[2]}; }
        tag=${line% *}
        tag=${tag%"${tag##*[![:space:]]}"}
        names+=("$tag")
        keys+=("$key")
    done <<< "${TAG_LAYOUTS[$set_key]}"
fi
names=("${names[@]:0:9}") keys=("${keys[@]:0:9}")
while ((${#names[@]} < 9)); do
    names+=("$((${#names[@]} + 1))")
    keys+=("${#names[@]}")
done

if [[ -n $DRY ]]; then
    for i in "${!names[@]}"; do echo "$i ${names[$i]} ${keys[$i]}"; done
    exit 0
fi

for ((i = $(hc get_attr tags.count); i < 9; i++)); do hc add ".new$i"; done

change=()
for i in "${!names[@]}"; do
    old=$(hc get_attr "tags.$i.name")
    [[ $old == "${names[$i]}" ]] && continue
    hc rename "$old" ".rename$i"
    change+=("$i")
done
for i in "${change[@]}"; do hc rename ".rename$i" "${names[$i]}"; done

for i in "${!names[@]}"; do
    hc keybind "$ModSup-${keys[$i]}" use_index "$i"
    hc keybind "$ModSup-Shift-${keys[$i]}" move_index "$i"
done
