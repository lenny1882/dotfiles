#!/bin/bash

function loader() {
	local endString="# END: INJECTED BASHRC FILES"
	local path="/media/Storage/User"
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
