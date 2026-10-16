#!/bin/sh

# usage: colours_check.sh   (run it under sh, bash and bash --posix)

dir=$(cd "$(dirname "$0")/../../setup" && pwd)
. "$dir/colours.sh"

pass=0
fail=0
check() {
	if [ "$2" = "$3" ]; then
		pass=$((pass + 1))
	else
		fail=$((fail + 1))
		echo "FAIL $1: expected '$2', got '$3'"
	fi
}

check hex_green "#2E7D32" "$(colour_hex col_green)"
check hex_reference "#D32F2F" "$(colour_hex ansi_red)"
check hex_reference_light "#ECEFF4" "$(colour_hex ansi_bright_white)"

# the r;g;b values written in shellrc/.shellrc_custom
check rgb_light "236;239;244" "$(colour_rgb col_light)"
check rgb_green "46;125;50" "$(colour_rgb col_green)"
check rgb_purple "123;31;162" "$(colour_rgb col_purple)"
check rgb_red "211;47;47" "$(colour_rgb col_red)"
check rgb_chartblue "45;119;206" "$(colour_rgb col_chartblue)"
check rgb_cyan "31;136;162" "$(colour_rgb col_cyan)"
check rgb_seagreen "60;163;65" "$(colour_rgb col_seagreen)"
check rgb_grey_dark "51;51;51" "$(colour_rgb col_grey_dark)"
check rgb_grey_light "153;153;153" "$(colour_rgb col_grey_light)"
check rgb_black "0;0;0" "$(colour_rgb ansi_black)"

check alpha "#252526CC" "$(colour_alpha col_dark CC)"
check argb "#CC252526" "$(colour_argb col_dark CC)"
check argb_zero "#00000000" "$(colour_argb ansi_black 00)"

# exact xterm 256-colour entries
col_t="#ffffff"; check 256_white "231" "$(colour_256 col_t)"
col_t="#8a8a8a"; check 256_grey245 "245" "$(colour_256 col_t)"
col_t="#a8a8a8"; check 256_grey248 "248" "$(colour_256 col_t)"
col_t="#008700"; check 256_cube28 "28" "$(colour_256 col_t)"
col_t="#000000"; check 256_black "16" "$(colour_256 col_t)"
col_t="#ff0000"; check 256_red "196" "$(colour_256 col_t)"

check 256_tui_grey "245" "$(colour_256 tui_grey)"
check 256_tui_dimmed "248" "$(colour_256 tui_dimmed)"
check 256_tui_white "231" "$(colour_256 tui_white)"
check 256_nnn_symlink "97" "$(colour_256 nnn_symlink)"
check 256_nnn_details "247" "$(colour_256 nnn_details)"
check 256_nnn_context1 "162" "$(colour_256 nnn_context1)"
check 256_nnn_context2 "31" "$(colour_256 nnn_context2)"
check 256_nnn_context3 "76" "$(colour_256 nnn_context3)"
check rgb_lime "0;255;0" "$(colour_rgb col_lime)"
check alpha_almost_black "#11111177" "$(colour_alpha col_almost_black 77)"
check alpha_nord4 "#D8DEE977" "$(colour_alpha col_nord4 77)"
i=0
for n in black red green yellow blue purple cyan white bright_black bright_red bright_green bright_yellow bright_blue bright_purple bright_cyan bright_white; do
	check "256_slot_$n" "$i" "$(colour_256 "ansi_$n")"
	i=$((i + 1))
done

check 256_override "28" "$(colour_256 col_green)"
col_t="#2E7D32"
if (colour_256 col_t) 2>/dev/null; then fail=$((fail + 1)); echo "FAIL colour_256 guessed a colour that is not an xterm entry"; else pass=$((pass + 1)); fi
if (colour_256 col_purple) 2>/dev/null; then fail=$((fail + 1)); echo "FAIL colour_256 guessed for col_purple"; else pass=$((pass + 1)); fi
col_t="#808080"; check 256_exact_grey244 "244" "$(colour_256 col_t)"
col_t="#080808"; check 256_exact_grey232 "232" "$(colour_256 col_t)"
col_t="#eeeeee"; check 256_exact_grey255 "255" "$(colour_256 col_t)"
col_t="#8a8a8b"; if (colour_256 col_t) 2>/dev/null; then fail=$((fail + 1)); echo "FAIL near-grey accepted"; else pass=$((pass + 1)); fi
col_t="#ffffff"; col_t_256=16; check 256_override_wins_over_exact "16" "$(colour_256 col_t)"
col_t_256=300
if (colour_256 col_t) 2>/dev/null; then fail=$((fail + 1)); echo "FAIL override above 255 accepted"; else pass=$((pass + 1)); fi
col_t_256=ab
if (colour_256 col_t) 2>/dev/null; then fail=$((fail + 1)); echo "FAIL non-numeric override accepted"; else pass=$((pass + 1)); fi
unset col_t_256


if (colour_hex nope) 2>/dev/null; then fail=$((fail + 1)); echo "FAIL unknown name accepted"; else pass=$((pass + 1)); fi
if (colour_hex 'a;b') 2>/dev/null; then fail=$((fail + 1)); echo "FAIL bad name accepted"; else pass=$((pass + 1)); fi
col_bad="red"
if (colour_hex col_bad) 2>/dev/null; then fail=$((fail + 1)); echo "FAIL non-hex value accepted"; else pass=$((pass + 1)); fi

leftover=$(
	colour_rgb col_green >/dev/null; colour_256 col_green >/dev/null; colour_argb col_dark CC >/dev/null
	colours_unload
	for n in $(grep -oE '^[a-z][a-z0-9_]*=' "$dir/colours.sh" | tr -d =; grep -oE '(^|[[:space:];])_[a-z]+=' "$dir/colours.sh" | tr -d '[:space:];='); do
		eval "[ -z \"\${$n+x}\" ]" || echo "variable $n"
	done
	for f in $(grep -oE '^[a-z_][a-z0-9_]*\(\)' "$dir/colours.sh" | tr -d '()'); do
		command -v "$f" >/dev/null 2>&1 && echo "function $f"
	done
)
check unload_leaves_nothing "" "$leftover"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
