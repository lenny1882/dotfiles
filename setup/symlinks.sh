#!/usr/bin/env bash

function symlinker () {
	# vars
	local home_dir="/home/lenny/"
	local home_folders=("Documents" "Downloads" "Music" "Pictures" "Videos")
	local user_dir="/media/Storage/User/"

	# remove existing and symlink in new
	for folder in "${home_folders[@]}"; do
		if [[ -d $home_dir$folder ]]; then
			if [[ -L $home_dir$folder ]]; then
				unlink $home_dir$folder
			else
				rm -r $home_dir$folder
			fi
		fi
		[ -d $user_dir$folder ] && ln -s $user_dir$folder $home_dir
	done
}

symlinker
exit 0
