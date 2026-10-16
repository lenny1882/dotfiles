#!/bin/sh

# usage: rofi-wrap.sh [rofi args]
# runs rofi with the theme colours from colours.sh

. "$(cd -P "$(dirname "$0")" && pwd)/../../../setup/colours.sh"

exec rofi -theme-str "* { col-dark1: $(colour_hex col_dark); col-dark2: $(colour_hex col_dark2); col-grey: $(colour_hex col_grey); col-light: $(colour_hex col_light); col-green: $(colour_hex col_green); col-purple: $(colour_hex col_purple); }" "$@"
