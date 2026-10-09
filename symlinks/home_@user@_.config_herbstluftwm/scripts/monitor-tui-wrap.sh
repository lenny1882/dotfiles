#!/bin/sh

# wrapper for monitor_tui.py, started from a herbstluftwm keybinding like
# nnn-wrap.sh: a keybinding does not source .bashrc, so anything the TUI needs
# from the environment is set here

# the frame and monitor drawings use box drawing characters, which need a UTF-8
# locale; fall back to C.UTF-8 if the session did not set one
case "${LC_ALL:-${LC_CTYPE:-$LANG}}" in
    *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) ;;
    *) export LC_CTYPE=C.UTF-8 ;;
esac

exec "$(dirname "$0")/monitor_tui.py" $*
