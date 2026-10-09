#!/bin/sh

case "${LC_ALL:-${LC_CTYPE:-$LANG}}" in
    *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) ;;
    *) export LC_CTYPE=C.UTF-8 ;;
esac

exec "$(dirname "$0")/monitor_tui.py" "$@"
