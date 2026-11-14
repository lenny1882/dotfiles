#!/usr/bin/env bash
# Name the 9 tags and bind their keys for the connected monitor set.
#   Names come from the set's lines in hlwm_tag_layouts.conf, in order, padded to 9 with
#   1..9. A tag's key is its {n} on the line, else its position (1-9).
#   Existing tags are renamed in place, so their windows stay. --dry-run prints "index name key".

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tagconf.sh"

source ~/.config/herbstluftwm/variables.autostart

if [[ $1 == --dry-run ]]; then
    tagconf_tags
    exit 0
fi

names=() keys=()
while read -r i rest; do
    names[i]=${rest% *}
    keys[i]=${rest##* }
done < <(tagconf_tags)

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
