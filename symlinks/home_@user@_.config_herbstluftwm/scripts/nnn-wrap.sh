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
_block="07";		_charDevice="0b";	_directory="04";	_executable="02";
_regularFile="07";	_hardLink="06";		_symLink="61";		_missingOrFileDetails="F7";
_orphanedSymLink="09";	_fifo="03";		_socket="0D";		_unknown="00";
export NNN_FCOLORS="$_block$_charDevice$_directory$_executable$_regularFile$_hardLink$_symLink$_missingOrFileDetails$_orphanedSymLink$_fifo$_socket$_unknown"
export NNN_COLORS="#a21f4c07"
export NNN_TRASH=2
export NNN_PLUG='f:fzopen;d:dragdrop;x:xdgdefault'

#plugins
export NNN_FINDHISTLEN=0

export EDITOR=micro
export VISUAL=micro

# Unmask ^Q (if required, see `stty -a`) to Quit nnn
stty start undef
stty stop under

# nnn -deioQRUx -F 0 $*
"$(dirname "$0")/pty_inset.py" nnn -deiHoQRUx -F 0 -s startup $*
