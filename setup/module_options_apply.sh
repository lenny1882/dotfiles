#!/usr/bin/env bash

# write the "options <module> key=value ..." lines of a modprobe.d file to
# /sys/module/<module>/parameters/<key>, for parameters that can change at
# runtime; run after /media/Storage is mounted, when the file is a symlink into
# the dotfiles and was unreadable while the module loaded
#
# usage: module_options_apply.sh FILE

conf=${1:?usage: module_options_apply.sh FILE}

status=0
while read -r keyword module pairs || [[ -n $keyword ]]; do
	[[ $keyword == options ]] || continue
	for pair in $pairs; do
		param=/sys/module/$module/parameters/${pair%%=*}
		if [[ -w $param ]]; then
			echo "${pair#*=}" > "$param"
			echo "$module: ${pair%%=*}=${pair#*=}"
		else
			echo "$module: ${pair%%=*} is not writable at runtime" >&2
			status=1
		fi
	done
done < "$conf"
exit $status
