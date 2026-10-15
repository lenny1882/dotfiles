#!/usr/bin/env bash
# After the monitor set changes, move the autostart programs' windows to the tags the new set gives them.
#   A window moves only if it is still on the tag the previous set gave its program; one moved by hand stays.
#   The previous set is kept in the herbstluftwm attribute my_tag_set. Run after tags.sh and tag_layouts.sh.
#   --record only remembers the current set. --dry-run prints the moves.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source ~/.config/herbstluftwm/variables.autostart
hc() { "${herbstclient_command[@]:-herbstclient}" "$@"; }
log() { echo "tag_windows: $*" >&2; }

case $1 in
    --dry-run) DRY=1 ;;
    --record) RECORD=1 ;;
esac

new=$("$SCRIPT_DIR/monitor_reconcile.sh" --key)
old=$(hc get_attr my_tag_set 2>/dev/null)

record() {
    [[ -n $DRY ]] && return
    hc silent new_attr string my_tag_set
    hc set_attr my_tag_set "$new"
}

if [[ -n $RECORD || -z $old || $old == "$new" ]]; then
    record
    exit 0
fi

programs() {
    TAG_SET_KEY=$1 bash -c 'source "$1/tag_programs.sh"; for i in "${!PROG_TAG[@]}"; do printf "%s\t%s\t%s\n" "$i" "${PROG_TAG[$i]}" "${PROG_INDEX[$i]}"; done' _ "$SCRIPT_DIR"
}

pos() {
    local -n names=$1
    local i
    for i in "${!names[@]}"; do
        [[ ${names[$i]} == "$2" ]] && { echo "$i"; return; }
    done
    return 1
}

declare -A old_tag new_tag new_index
while IFS=$'\t' read -r inst tag _; do old_tag[$inst]=$tag; done < <(programs "$old")
while IFS=$'\t' read -r inst tag index; do new_tag[$inst]=$tag new_index[$inst]=$index; done < <(programs "$new")

old_names=() new_names=()
while read -r i rest; do old_names[i]=${rest% *}; done < <(TAG_SET_KEY=$old "$SCRIPT_DIR/tags.sh" --dry-run)
while read -r i rest; do new_names[i]=${rest% *}; done < <(TAG_SET_KEY=$new "$SCRIPT_DIR/tags.sh" --dry-run)

for inst in "${!old_tag[@]}"; do
    [[ -n ${new_tag[$inst]} ]] || continue
    from=$(pos old_names "${old_tag[$inst]}") && to=$(pos new_names "${new_tag[$inst]}") || continue
    [[ $from != "$to" ]] || continue
    for id in $(hc list_clients --tag="${new_names[from]}"); do
        [[ $(hc get_attr "clients.$id.instance") == "$inst" ]] || continue
        log "$inst $id: ${new_names[from]} -> ${new_names[to]}"
        [[ -n $DRY ]] || hc apply_tmp_rule "$id" --tag="${new_names[to]}" ${new_index[$inst]:+--index="${new_index[$inst]}"}
    done
done

record
