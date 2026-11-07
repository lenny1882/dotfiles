#!/usr/bin/env bash

# switch the system between dark and light: point ~/.config/gtk-3.0/settings.ini
# and ~/.config/gtk-4.0/settings.ini at the matching copy in themes/, and set the
# color-scheme that Qt and the Chromium apps follow
#
# usage: theme.sh apply dark|light
#        theme.sh current    prints dark, light or mixed (the links and color-scheme disagree)
#        theme.sh scheme     prints dark, light or unset (color-scheme alone)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEMES_DIR=$SCRIPT_DIR/themes
CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
GSETTINGS=${GSETTINGS:-gsettings}
SCHEMA=org.gnome.desktop.interface
GTKS=(gtk-3.0 gtk-4.0)

scheme_mode() {
	case $("$GSETTINGS" get "$SCHEMA" color-scheme 2>/dev/null) in
		"'prefer-dark'") echo dark ;;
		"'prefer-light'") echo light ;;
		*) echo unset ;;
	esac
}

link_mode() {
	local target name
	target=$(readlink "$CONFIG_HOME/$1/settings.ini") || { echo none; return; }
	name=${target##*/}
	if [[ $target == "$THEMES_DIR/$1".*.ini ]]; then
		name=${name#"$1".}
		echo "${name%.ini}"
	else
		echo none
	fi
}

current_mode() {
	local mode=$(scheme_mode) gtk
	for gtk in "${GTKS[@]}"; do
		[[ $(link_mode "$gtk") == "$mode" ]] || { echo mixed; return; }
	done
	echo "$mode"
}

apply_mode() {
	local mode=$1 gtk dest scheme
	case $mode in
		dark|light) scheme=prefer-$mode ;;
		*) echo "theme: unknown mode '$mode' (dark or light)" >&2; return 1 ;;
	esac
	for gtk in "${GTKS[@]}"; do
		dest=$CONFIG_HOME/$gtk/settings.ini
		if [[ -e $dest && ! -L $dest ]]; then
			echo "theme: $dest is a regular file, not replacing it" >&2
			return 1
		fi
	done
	for gtk in "${GTKS[@]}"; do
		mkdir -p "$CONFIG_HOME/$gtk"
		ln -sfn "$THEMES_DIR/$gtk.$mode.ini" "$CONFIG_HOME/$gtk/settings.ini"
		echo "link   $CONFIG_HOME/$gtk/settings.ini -> $THEMES_DIR/$gtk.$mode.ini"
	done
	if "$GSETTINGS" set "$SCHEMA" color-scheme "$scheme"; then
		echo "set    color-scheme $scheme"
	else
		echo "theme: could not set color-scheme (no session bus?)" >&2
		return 1
	fi
}

case ${1:-} in
	apply) apply_mode "${2:-}" ;;
	current) current_mode ;;
	scheme) scheme_mode ;;
	*) sed -n '3,9p' "${BASH_SOURCE[0]}" >&2; exit 1 ;;
esac
