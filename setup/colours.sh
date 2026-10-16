#!/bin/sh

# colours: edit the values below; the helpers after them convert a colour to the format a program needs
# NAME_256=N and NAME_ansi=name next to a colour set the value for a format its hex cannot convert to exactly

col_dark=#252526
col_dark2=#2D2D30
col_light=#ECEFF4
col_grey=#3E3E42
col_grey_dark=#333333
col_grey_mid=#777777
col_grey_light=#999999

col_green=#2E7D32
col_green_256=28
col_purple=#7B1FA2
col_blue=#1565C0
col_red=#D32F2F
col_orange=#FF9800
col_chartblue=#2D77CE
col_cyan=#1F88A2
col_seagreen=#3CA341
col_lightgreen=#87D75F

ansi_black=#000000
ansi_red=$col_red
ansi_green=#0dbc79
ansi_yellow=#e5e510
ansi_blue=#2472c8
ansi_purple=$col_purple
ansi_cyan=#11a8cd
ansi_white=#e5e5e5
ansi_bright_black=#666666
ansi_bright_red=#ef5350
ansi_bright_green=#66bb6a
ansi_bright_yellow=#f5f543
ansi_bright_blue=#3b8eea
ansi_bright_purple=#d670d6
ansi_bright_cyan=#29b8db
ansi_bright_white=$col_light

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

colour_ansi() {
	_colour_value "$1" || return 1
	if ! _colour_override "$1" ansi; then
		echo "colours: ${1}_ansi is not set" >&2
		return 1
	fi
	printf '%s\n' "$_ov"
}
