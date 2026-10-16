#!/bin/sh

# colours: edit the values below; the helpers after them convert a colour to the format a program needs
# NAME_256=N next to a colour sets its 256-colour value where the hex is not exactly an xterm entry

# based on the vscode dark, mui pallettes
# https://www.color-hex.com/color-palette/98179
# https://mui.com/customization/palette/
col_dark=#252526
col_dark2=#2D2D30
col_light=#ECEFF4
col_light_256=15
col_grey=#3E3E42
col_grey_light=#9E9E9E

col_green=#2E7D32
col_green_256=28
col_purple=#7B1FA2
col_purple_256=5
col_red=#D32F2F
col_red_256=1
col_orange=#FF9800
col_almost_black=#111111

col_nord9=#81A1C1
col_nord10=#5E81AC
col_nord11=#BF616A
col_nord12=#D08770
col_nord13=#EBCB8B
col_nord14=#A3BE8C
col_nord15=#B48EAD

col_white=#FFFFFF

col_violet=#875FAF
col_magenta=#D70087
col_lime=#5FD700

col_black=#000000
col_black_256=0
col_emerald=#0DBC79
col_emerald_256=2
col_yellow=#E5E510
col_yellow_256=3
col_blue=#2472C8
col_blue_256=4
col_cyan=#11A8CD
col_cyan_256=6
col_bright_black=#666666
col_bright_black_256=8
col_bright_red=#EF5350
col_bright_red_256=9
col_bright_green=#66BB6A
col_bright_green_256=10
col_bright_yellow=#F5F543
col_bright_yellow_256=11
col_bright_blue=#3B8EEA
col_bright_blue_256=12
col_bright_purple=#D670D6
col_bright_purple_256=13
col_bright_cyan=#29B8DB
col_bright_cyan_256=14

_colour_value() {
	case $1 in
		''|[0-9]*|*[!A-Za-z0-9_]*) echo "colours: bad colour name '$1'" >&2; return 1 ;;
	esac
	eval "_cv=\${$1-}"
	if [ -z "$_cv" ]; then
		echo "colours: unknown colour '$1'" >&2
		return 1
	fi
	case $_cv in
		\#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) ;;
		*) echo "colours: '$1' is not #RRGGBB ($_cv)" >&2; return 1 ;;
	esac
}

_colour_split() {
	_colour_value "$1" || return 1
	_h=${_cv#\#}
	_r=$((0x${_h%????}))
	_g=${_h#??}
	_g=$((0x${_g%??}))
	_b=$((0x${_h#????}))
}

colour_hex() {
	_colour_value "$1" || return 1
	printf '%s\n' "$_cv"
}

_colour_override() {
	eval "_ov=\${$1_$2-}"
	[ -n "$_ov" ]
}

_colour_badoverride() {
	echo "colours: ${1}_$2 must be $3 ($_ov)" >&2
	return 1
}

colour_rgb() {
	_colour_split "$1" || return 1
	printf '%s;%s;%s\n' "$_r" "$_g" "$_b"
}

colour_alpha() {
	_colour_value "$1" || return 1
	printf '%s%s\n' "$_cv" "$2"
}

colour_argb() {
	_colour_value "$1" || return 1
	printf '#%s%s\n' "$2" "${_cv#\#}"
}

_colour_level() {
	if [ "$1" -lt 48 ]; then
		_lv=0
	elif [ "$1" -lt 115 ]; then
		_lv=1
	else
		_lv=$((($1 - 35) / 40))
	fi
}

_colour_levelval() {
	if [ "$1" -eq 0 ]; then
		_lvv=0
	else
		_lvv=$((55 + 40 * $1))
	fi
}

colour_256() {
	_colour_split "$1" || return 1
	if _colour_override "$1" 256; then
		case $_ov in
			*[!0-9]*) _colour_badoverride "$1" 256 "0-255"; return ;;
		esac
		if [ "$_ov" -gt 255 ]; then
			_colour_badoverride "$1" 256 "0-255"
			return
		fi
		printf '%s\n' "$_ov"
		return
	fi
	_colour_level "$_r"; _ri=$_lv; _colour_levelval "$_ri"; _rv=$_lvv
	_colour_level "$_g"; _gi=$_lv; _colour_levelval "$_gi"; _gv=$_lvv
	_colour_level "$_b"; _bi=$_lv; _colour_levelval "$_bi"; _bv=$_lvv
	if [ "$_r" -eq "$_rv" ] && [ "$_g" -eq "$_gv" ] && [ "$_b" -eq "$_bv" ]; then
		printf '%s\n' "$((16 + 36 * _ri + 6 * _gi + _bi))"
		return
	fi
	if [ "$_r" -eq "$_g" ] && [ "$_g" -eq "$_b" ] && [ "$_r" -ge 8 ] && [ "$_r" -le 238 ] && [ $(((_r - 8) % 10)) -eq 0 ]; then
		printf '%s\n' "$((232 + (_r - 8) / 10))"
		return
	fi
	echo "colours: $1 is not an xterm 256 colour, set ${1}_256" >&2
	return 1
}

colours_unload() {
	for _n in $(set | sed -n -e 's/^\(col_[A-Za-z0-9_]*\)=.*/\1/p'); do
		unset "$_n"
	done
	unset _n _cv _h _r _g _b _ov _lv _lvv _ri _gi _bi _rv _gv _bv _cube
	unset -f colour_hex colour_rgb colour_alpha colour_argb colour_256 _colour_value _colour_split _colour_override _colour_badoverride _colour_level _colour_levelval colours_unload
}
