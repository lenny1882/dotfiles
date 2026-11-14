#!/usr/bin/env bash
# Source this: reads the tag lines of hlwm_tag_layouts.conf for one monitor set.
#   A line is: tag  layout  [{n}]  [[instance:index ...]]   (see the header of hlwm_tag_layouts.conf)
#   Fields are split like ASSIGN_LINE in monitor_tui.py: the tag is the shortest start that leaves a valid
#   rest, so it may hold spaces; a line without a tag and a layout is skipped; at most 9 lines are read.
#   tagconf_rows [KEY]      pos<TAB>tag<TAB>layout<TAB>key<TAB>instance:index ...   (returns 1 if the set has no block)
#   tagconf_tags [KEY]      index name key for the 9 tags, padded with 1..9 (what tags.sh --dry-run prints)
#   tagconf_programs [KEY]  instance<TAB>tag<TAB>index
#   KEY defaults to $TAG_SET_KEY, else `monitor_reconcile.sh --key`.

_tagconf_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TAG_LAYOUTS_FILE=${HLWM_TAG_LAYOUTS:-$_tagconf_dir/hlwm_tag_layouts.conf}
_tagconf_re='^[[:space:]]+([^[:space:]]+)([[:space:]]+\{([1-9])\})?([[:space:]]+\[([^]]*)\])?$'

tagconf_key() { printf '%s' "${TAG_SET_KEY:-$("$_tagconf_dir/monitor_reconcile.sh" --key)}"; }

tagconf_rows() {
    local key=${1-$(tagconf_key)} line i n=0 tag layout k p
    local -a progs
    [[ $_tagconf_loaded ]] || { source "$TAG_LAYOUTS_FILE"; _tagconf_loaded=1; }
    [[ -v TAG_LAYOUTS[$key] ]] || return 1
    while read -r line; do
        for ((i = 1; i < ${#line}; i++)); do
            [[ ${line:i:1} == [[:space:]] && ${line:i-1:1} != [[:space:]] ]] || continue
            [[ ${line:i} =~ $_tagconf_re ]] || continue
            tag=${line:0:i} layout=${BASH_REMATCH[1]} k=${BASH_REMATCH[3]:-$((n + 1))}
            read -ra progs <<< "${BASH_REMATCH[5]}"
            for p in "${!progs[@]}"; do [[ ${progs[p]} == *:* ]] || progs[p]+=:; done
            printf '%s\t%s\t%s\t%s\t%s\n' "$((++n))" "$tag" "$layout" "$k" "${progs[*]}"
            break
        done
        ((n == 9)) && return 0
    done <<< "${TAG_LAYOUTS[$key]}"
    return 0
}

tagconf_tags() {
    local key=${1-$(tagconf_key)} pos tag _ k n=0
    while IFS=$'\t' read -r pos tag _ k _; do
        printf '%s %s %s\n' "$((pos - 1))" "$tag" "$k"
        n=$pos
    done < <(tagconf_rows "$key")
    for ((; n < 9; n++)); do printf '%s %s %s\n' "$n" "$((n + 1))" "$((n + 1))"; done
}

tagconf_programs() {
    local key=${1-$(tagconf_key)} tag _ p
    local -a progs
    while IFS=$'\t' read -r _ tag _ _ p; do
        read -ra progs <<< "$p"
        for p in "${progs[@]}"; do printf '%s\t%s\t%s\n' "${p%:*}" "$tag" "${p##*:}"; done
    done < <(tagconf_rows "$key")
}
