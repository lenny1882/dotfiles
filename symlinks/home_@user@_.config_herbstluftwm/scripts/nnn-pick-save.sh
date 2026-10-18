#!/usr/bin/env bash
# run by nnn as a plugin in picker mode (see nnn-wrap.sh --pick save): asks for a file name in the
# folder shown, writes the path to the picker output file and tells nnn it is done

name=$NNN_SAVE_NAME
read -r -e -i "$name" -p "Save as: " name || exit
[ -n "$name" ] || exit
path=$PWD/$name
if [ -e "$path" ]; then
    read -r -p "$name exists. Overwrite? [y/N] " answer
    [[ $answer == [yY] ]] || exit
fi
printf '%s' "$path" > "$NNN_PICK_OUT" && printf 0p > "$NNN_PIPE"
