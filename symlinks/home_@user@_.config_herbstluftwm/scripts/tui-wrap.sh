#!/bin/sh

# usage: tui-wrap.sh [--inset] [--title TEXT] COMMAND [ARGS...]
# --inset leaves a blank margin around the program (pty_inset.py)

usage() { echo "usage: tui-wrap.sh [--inset] [--title TEXT] COMMAND [ARGS...]" >&2; exit 2; }

inset= title=
while [ $# -gt 0 ]; do
    case $1 in
        --inset) inset=1; shift ;;
        --title) [ $# -ge 2 ] || usage; title=$2; shift 2 ;;
        *) break ;;
    esac
done
[ $# -gt 0 ] || usage

[ -n "$inset" ] && set -- "$(dirname "$0")/pty_inset.py" "$@"
if [ -n "$title" ]; then exec urxvt -name wrapper -title "$title" -e "$@"; fi
exec urxvt -name wrapper -e "$@"
