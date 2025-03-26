#!/bin/sh

# https://github.com/jarun/nnn/wiki/Advanced-use-cases#desktop-integration
# we need to use a wrapper file to open nnn with exported colours, etc.,
# as it will not source from .bashrc directly if opened using a herbstluftwm
# keybinding

# https://github.com/jarun/nnn/wiki
# https://forum.porteus.org/viewtopic.php?p=85715#p85715
# cyan      1f88a2 (31, 136, 162)  --> nearest: 31  - 1F		?Hard link
# blue      2d77ce (45, 119, 206)  --> nearest: 32  - 20 		Directory
# green     2e7d32 (46, 125, 50)   --> nearest: 239 - 1C 		Executable
# sea green					      77
# grey      999999 (153, 153, 153) --> nearest: 247 - F7		?Missing / File Details
# purple    7b1fa2 (123, 31, 162)  --> nearest: 91  - 5B	61	Symlink
# magenta  [a21f7b (162, 31, 123)  -->             ]- C6 		?Socket
# orange    ff9800 (255, 152, 0)   --> nearest: 208 - D0		?FIFO
# red       d32f2f (211, 47, 47)   --> nearest: 160 - A0	01	Unknown
# yellow    					      E2 		?Char device
# black     252526 (37, 37, 38)    --> nearest: 235 - EB
# white     ECEFF4 (236, 239, 244) --> nearest: 255 - FF 	07	?Block, Char deivce, regular
# c1 d0 20 ef 00 5b 1f f7 c6 d6 ab a0
_block="0b";		_charDevice="0b";	_directory="20";	_executable="1C";
_regularFile="07";	_hardLink="0b";		_symLink="61";		_missingOrFileDetails="F7";
_orphanedSymLink="0b";	_fifo="D0";		_socket="C6";		_unknown="A0";
export NNN_FCOLORS="$_block$_charDevice$_directory$_executable$_regularFile$_hardLink$_symLink$_missingOrFileDetails$_orphanedSymLink$_fifo$_socker$_unknown"
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

nnn -deioQRUx -F 0 -s startup $*
