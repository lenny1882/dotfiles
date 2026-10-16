#!/bin/sh

# usage: xrdb-wrap.sh [xrdb args] FILE
# runs xrdb on FILE with every colour in colours.sh defined as a -D macro, so the file can use the colour names

. "$(cd -P "$(dirname "$0")" && pwd)/../../../setup/colours.sh"

for name in $(set | sed -n -e 's/^\(col_[a-z0-9_]*\)=.*/\1/p'); do
	case $name in *_256) continue ;; esac
	set -- "-D$name=$(colour_hex "$name")" "$@"
done

exec xrdb "$@"
