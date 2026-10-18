#!/bin/sh

# https://github.com/jarun/nnn/wiki/Advanced-use-cases#desktop-integration
# we need to use a wrapper file to open nnn with exported colours, etc.,
# as it will not source from .bashrc directly if opened using a herbstluftwm
# keybinding

# https://github.com/jarun/nnn/wiki
# https://forum.porteus.org/viewtopic.php?p=85715#p85715
# palette slots (Xresources *.colorN) except symlink, missing/details, unknown and contexts, which are 256-colour values
# block 07, char device 0B, directory 04, executable 02, regular 07, hard link 06
# symlink 61, missing/details F7, orphaned symlink 09, fifo 03, socket 0D, unknown 00
colours_dir=$(cd -P "$(dirname "$0")/../../../setup" && pwd)
. "$colours_dir/colours.sh"
_nnn() { printf '%02x' "$(colour_256 "$1")"; }
_block=$(_nnn col_light);			_charDevice=$(_nnn col_bright_yellow);	_directory=$(_nnn col_blue);	_executable=$(_nnn col_emerald);
_regularFile=$(_nnn col_light);		_hardLink=$(_nnn col_cyan);		_symLink=$(_nnn col_violet);	_missingOrFileDetails=$(_nnn col_grey_light);
_orphanedSymLink=$(_nnn col_bright_red);	_fifo=$(_nnn col_yellow);		_socket=$(_nnn col_bright_purple);	_unknown="00";
export NNN_FCOLORS="$_block$_charDevice$_directory$_executable$_regularFile$_hardLink$_symLink$_missingOrFileDetails$_orphanedSymLink$_fifo$_socket$_unknown"
export NNN_COLORS="#$(_nnn col_magenta)$(_nnn col_cyan)$(_nnn col_lime)$(_nnn col_light)"
export NNN_TRASH=2
export NNN_PLUG='f:fzopen;d:dragdrop;x:xdgdefault'

#plugins
export NNN_FINDHISTLEN=0

export EDITOR=micro
export VISUAL=micro

# Unmask ^Q (if required, see `stty -a`) to Quit nnn
stty start undef
stty stop undef

# picker mode, for nnn-portal.py: nnn-wrap.sh --pick file|dir|save OUTFILE START [NAME]
# the startup session is loaded and START opens in the first inactive context, as for a folder below;
# the chosen path goes to OUTFILE, which is gone or empty if nothing is chosen: Enter picks a file
# (or the selection), ;p picks the folder shown, ;s asks for a file name in the folder shown
if [ "$1" = "--pick" ]; then
    export NNN_PICK_OUT=$3 NNN_SAVE_NAME=$5 NNN_OPEN_DIR=${4:-$HOME}
    open='o:!printf "+c%s" "$NNN_OPEN_DIR" > "$NNN_PIPE"*'
    case $2 in
        dir)  export NNN_PLUG="$open"';p:!printf %s "$PWD" > "$NNN_PICK_OUT" && printf 0p > "$NNN_PIPE"*' ;;
        save) export NNN_PLUG="$open;s:!$(dirname "$0")/nnn-pick-save.sh*" ;;
        *)    export NNN_PLUG=$open ;;
    esac
    exec "$(dirname "$0")/pty_inset.py" nnn -deiHoQRUx -F 0 -s startup -P o -p "$3"
fi

# a folder passed in (from the desktop entry) opens in the first inactive context, beside the session's:
# a session load ignores the path argument, so a startup plugin (-P) writes it to nnn's plugin pipe
startup_plugin=
if [ -n "$1" ]; then
    export NNN_OPEN_DIR=$(realpath -- "$1")
    export NNN_PLUG="$NNN_PLUG"';o:!printf "+c%s" "$NNN_OPEN_DIR" > "$NNN_PIPE"*'
    startup_plugin="-P o"
fi

# nnn -deioQRUx -F 0 $*
"$(dirname "$0")/pty_inset.py" nnn -deiHoQRUx -F 0 -s startup $startup_plugin
