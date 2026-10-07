#!/usr/bin/env bash

# symlink every top-level entry in ../symlinks to the real location its name
# encodes: each "_" is a path separator, so
#   etc_pacman.d_hooks_abc.hook  ->  /etc/pacman.d/hooks/abc.hook
# and @user@ stands for the user running the install, so
#   home_@user@_.config_abc  ->  /home/<user>/.config/abc
# entries are linked as-is (a folder is linked as a folder, never drilled into)
#
# usage: config_links.sh [-n|--dry-run] [-f|--force]
#   -n  print what would be linked without changing anything
#   -f  replace targets that already exist (default: skip them with a warning)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$SCRIPT_DIR/../symlinks" && pwd)"

link_user=${SUDO_USER:-$(id -un)}
dry_run=false
force=false
for arg in "$@"; do
	case $arg in
		-n|--dry-run) dry_run=true ;;
		-f|--force)   force=true ;;
		*) echo "unknown option: $arg" >&2; exit 1 ;;
	esac
done

# run a command, via sudo only when the nearest existing ancestor of $1 isn't
# writable by us (eg. anything under /etc or /usr)
asNeeded() {
	local target=$1 probe
	shift
	probe=$(dirname "$target")
	while [[ ! -d $probe ]]; do probe=$(dirname "$probe"); done
	if [[ -w $probe ]]; then "$@"; else sudo "$@"; fi
}

linker() {
	local src name target
	shopt -s nullglob dotglob
	for src in "$SOURCE_DIR"/*; do
		name=${src##*/}
		if [[ $name == *.bak* ]]; then
			echo "skip   $name (backup file)"
			continue
		fi
		if [[ $name != *_* ]]; then
			echo "skip   $name (no _ in name, can't derive a target)"
			continue
		fi
		target="/${name//_//}"
		target="${target//@user@/$link_user}"

		if [[ -L $target && $(readlink "$target") == "$src" ]]; then
			echo "ok     $target"
			continue
		fi
		if [[ -e $target || -L $target ]]; then
			if ! $force; then
				echo "skip   $target (exists, use --force to replace)"
				continue
			fi
		fi

		if $dry_run; then
			echo "link   $target -> $src"
			continue
		fi
		asNeeded "$target" mkdir -p "$(dirname "$target")"
		asNeeded "$target" ln -sfn "$src" "$target"
		echo "link   $target -> $src"
	done
}

linker
exit 0
