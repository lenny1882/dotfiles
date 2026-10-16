#!/bin/sh

case "${LC_ALL:-${LC_CTYPE:-$LANG}}" in
    *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) ;;
    *) export LC_CTYPE=C.UTF-8 ;;
esac

. "$(cd -P "$(dirname "$0")" && pwd)/../../../setup/colours.sh"
export TUI_COLOUR_ART=$(colour_256 tui_grey)
export TUI_COLOUR_DIM=$(colour_256 tui_dimmed)
export TUI_COLOUR_HILITE=$(colour_256 tui_white)
export TUI_COLOUR_SELECT_256=$(colour_256 col_green)
export TUI_COLOUR_SELECT_RGB=$(colour_rgb col_green)

exec "$(dirname "$0")/monitor_tui.py" "$@"
