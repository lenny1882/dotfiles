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

check 256_override "28" "$(colour_256 col_green)"
col_t="#2E7D32"; check 256_nearest_not_grey "29" "$(colour_256 col_t)"
check 256_nearest_purple "91" "$(colour_256 col_purple)"
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

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
