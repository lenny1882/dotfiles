#!/usr/bin/env bash

function symlinker () {
	# vars
	local home_dir="${HOME%/}/"
	local home_folders=("Documents" "Downloads" "Music" "Pictures" "Videos")
	local user_dir="${USER_DIR:?USER_DIR is not set}"
	user_dir="${user_dir%/}/"

	# replace each home folder with a link, but only if the target exists
	for folder in "${home_folders[@]}"; do
		[[ -d $user_dir$folder ]] || { echo "skip $folder: $user_dir$folder does not exist"; continue; }
		if [[ -L $home_dir$folder ]]; then
			unlink "$home_dir$folder"
		elif [[ -d $home_dir$folder ]]; then
			rm -r "$home_dir$folder"
		fi
		ln -s "$user_dir$folder" "$home_dir"
	done
}

symlinker
exit 0
