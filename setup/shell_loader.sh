#!/bin/bash

function loader() {
	local endString="# END: INJECTED BASHRC FILES"
	local path="$(cd "$(dirname "${BASH_SOURCE[0]}")/../shellrc" && pwd)"
	local startString="# START: INJECTED BASHRC FILES"
	local shellrc=~/.$1rc

	echo "$(sed "/^$startString/,/^$endString/d;" $shellrc)" >| $shellrc

	echo -e "\n$startString" >> $shellrc
	for file in $path/.shellrc*; do 
	    echo "if [ -f $file ]; then . $file; fi" >> $shellrc
	done
	echo -e "$endString\n" >> $shellrc

	source $shellrc
}

loader $1
exit 0
