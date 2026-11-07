#!/bin/sh

# usage: bottom-wrap.sh [cpu|memory|network|processes] [btm args]
# renders the bottom config template for that view (the main config if none) with the current colours, then runs btm on it

case $1 in
	cpu|memory|network|processes) name=bottom-$1; shift ;;
	*) name=bottom ;;
esac

conf=$(mktemp "${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/bottom-XXXXXX") || exit 1
trap 'rm -f "$conf"' EXIT
trap 'exit 1' HUP INT TERM

"${DOTFILES_DIR:?DOTFILES_DIR is not set}/setup/colours-gen" "$name" > "$conf" || exit 1
btm -C "$conf" "$@"
