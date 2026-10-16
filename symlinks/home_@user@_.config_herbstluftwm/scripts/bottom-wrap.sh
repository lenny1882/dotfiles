#!/bin/sh

# usage: bottom-wrap.sh [cpu|memory|network|processes] [btm args]
# renders the bottom config template for that view (the main config if none) with the current colours, then runs btm on it

dir=$(cd -P "$(dirname "$0")" && pwd)

case $1 in
	cpu|memory|network|processes) name=bottom-$1; shift ;;
	*) name=bottom ;;
esac

conf=$(mktemp "${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/bottom-XXXXXX") || exit 1
trap 'rm -f "$conf"' EXIT
trap 'exit 1' HUP INT TERM

"$dir/../../../setup/colours-gen" "$name" > "$conf" || exit 1
btm -C "$conf" "$@"
