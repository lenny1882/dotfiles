#!/usr/bin/env bash
# Source this: sets PROG_TAG and PROG_INDEX, keyed by rule instance, for the connected monitor set.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tagconf.sh"

declare -gA PROG_TAG=() PROG_INDEX=()

while IFS=$'\t' read -r _inst _tag _index; do
    PROG_TAG[$_inst]=$_tag
    PROG_INDEX[$_inst]=$_index
done < <(tagconf_programs)
unset _inst _tag _index
