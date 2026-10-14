#!/usr/bin/env bash
# Source this: sets PROG_TAG and PROG_INDEX, keyed by rule instance, for the connected monitor set.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAG_LAYOUTS_FILE=${HLWM_TAG_LAYOUTS:-$SCRIPT_DIR/hlwm_tag_layouts.conf}

declare -gA PROG_TAG=() PROG_INDEX=()

source "$TAG_LAYOUTS_FILE"
_key=$("$SCRIPT_DIR/monitor_reconcile.sh" --key)

if [[ -v TAG_LAYOUTS[$_key] ]]; then
    while read -r _line; do
        [[ $_line =~ ^(.*[^[:space:]])[[:space:]]*\[([^]]*)\][[:space:]]*$ ]] || continue
        _rest=${BASH_REMATCH[1]} _progs=${BASH_REMATCH[2]}
        [[ $_rest =~ ^(.*[^[:space:]])[[:space:]]*\{[1-9]\}[[:space:]]*$ ]] && _rest=${BASH_REMATCH[1]}
        _tag=${_rest% *}
        _tag=${_tag%"${_tag##*[![:space:]]}"}
        for _prog in $_progs; do
            PROG_TAG[${_prog%:*}]=$_tag
            PROG_INDEX[${_prog%:*}]=${_prog##*:}
        done
    done <<< "${TAG_LAYOUTS[$_key]}"
fi
unset _key _line _rest _progs _tag _prog
