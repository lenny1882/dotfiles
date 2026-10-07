#!/bin/bash

function loader() {
	local endString="# END: INJECTED BASHRC FILES"
	local path="$(cd "$(dirname "${BASH_SOURCE[0]}")/../shellrc" && pwd)"
	local startString="# START: INJECTED BASHRC FILES"
	local var
	local shellrc=~/.$1rc

	# the locations are passed in via the environment (exported by
	# quickstart_arch.sh) - flag any that are missing before touching the rc
	# file, since the shellrc files would silently fall back to defaults
	local -a missing=()
	for var in STORAGE_DIR USER_DIR PROGRAMS_DIR; do
		[ -z "${!var}" ] && missing+=("$var")
	done
	if [ ${#missing[@]} -gt 0 ]; then
		echo "Not set in the environment: ${missing[*]}"
		echo "The shellrc files will fall back to their default locations."
		local reply
		read -r -p "Continue without them? [y/N] " reply
		[[ $reply =~ ^[Yy]$ ]] || { echo "Aborted, $shellrc not changed."; return 1; }
	fi

	echo "$(sed "/^$startString/,/^$endString/d;" $shellrc)" >| $shellrc

	echo -e "\n$startString" >> $shellrc
	# the locations chosen in quickstart_arch.sh, so the shellrc files see
	# them in every shell (only the ones that were actually set)
	for var in STORAGE_DIR USER_DIR PROGRAMS_DIR; do
		[ -n "${!var}" ] && echo "export $var=\"${!var}\"" >> $shellrc
	done
	for file in $path/.shellrc*; do 
	    echo "if [ -f $file ]; then . $file; fi" >> $shellrc
	done
	echo -e "$endString\n" >> $shellrc

	source $shellrc
}

loader "$1" || exit 1
exit 0
