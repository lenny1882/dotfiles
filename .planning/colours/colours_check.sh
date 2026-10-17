#!/bin/sh

# usage: colours_check.sh   (run it under sh, bash and bash --posix)

dir=$(cd "$(dirname "$0")/../../setup" && pwd)
colours_dir=$dir
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

check hex_green "#287D2D" "$(colour_hex col_green)"
check hex_reference "#C5292C" "$(colour_hex col_red)"

# the r;g;b values written in shellrc/.shellrc_custom
check rgb_light "234;234;234" "$(colour_rgb col_light)"
check rgb_green "40;125;45" "$(colour_rgb col_green)"
check rgb_purple "122;37;159" "$(colour_rgb col_purple)"
check rgb_red "197;41;44" "$(colour_rgb col_red)"
check rgb_ansi_blue "40;110;204" "$(colour_rgb col_blue)"
check rgb_cyan "31;183;208" "$(colour_rgb col_cyan)"
check rgb_bright_green "105;194;111" "$(colour_rgb col_bright_green)"
check rgb_grey_light "158;158;158" "$(colour_rgb col_grey_light)"
check rgb_black "0;0;0" "$(colour_rgb col_black)"

check alpha "#262626CC" "$(colour_alpha col_dark CC)"
check argb "#CC262626" "$(colour_argb col_dark CC)"
check argb_zero "#00000000" "$(colour_argb col_black 00)"

# exact xterm 256-colour entries
col_t="#ffffff"; check 256_white "231" "$(colour_256 col_t)"
col_t="#8a8a8a"; check 256_grey245 "245" "$(colour_256 col_t)"
col_t="#a8a8a8"; check 256_grey248 "248" "$(colour_256 col_t)"
col_t="#008700"; check 256_cube28 "28" "$(colour_256 col_t)"
col_t="#000000"; check 256_black "16" "$(colour_256 col_t)"
col_t="#ff0000"; check 256_red "196" "$(colour_256 col_t)"

check 256_col_white "231" "$(colour_256 col_white)"
check 256_col_violet "97" "$(colour_256 col_violet)"
check 256_grey_light "247" "$(colour_256 col_grey_light)"
check 256_col_magenta "162" "$(colour_256 col_magenta)"
check 256_col_lime "76" "$(colour_256 col_lime)"
check rgb_lime "120;203;3" "$(colour_rgb col_lime)"
check alpha_almost_black "#12121277" "$(colour_alpha col_almost_black 77)"
check alpha_light "#EAEAEA77" "$(colour_alpha col_light 77)"
i=0
for n in black red emerald yellow blue purple cyan skip bright_black bright_red bright_green bright_yellow bright_blue bright_purple bright_cyan light; do
	[ "$n" = skip ] || check "256_slot_$n" "$i" "$(colour_256 "col_$n")"
	i=$((i + 1))
done

check 256_override "28" "$(colour_256 col_green)"
col_t="#2E7D32"
if (colour_256 col_t) 2>/dev/null; then fail=$((fail + 1)); echo "FAIL colour_256 guessed a colour that is not an xterm entry"; else pass=$((pass + 1)); fi
if (colour_256 col_orange) 2>/dev/null; then fail=$((fail + 1)); echo "FAIL colour_256 guessed for col_orange"; else pass=$((pass + 1)); fi
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
	for n in $(grep -ohE '^[a-z][a-z0-9_]*=' "$dir/colours.sh" "$dir/colours.g.sh" | tr -d =; grep -oE '(^|[[:space:];])_[a-z]+=' "$dir/colours.sh" | tr -d '[:space:];='); do
		eval "[ -z \"\${$n+x}\" ]" || echo "variable $n"
	done
	for f in $(grep -oE '^[a-z_][a-z0-9_]*\(\)' "$dir/colours.sh" | tr -d '()'); do
		command -v "$f" >/dev/null 2>&1 && echo "function $f"
	done
)
check unload_leaves_nothing "" "$leftover"

# the generated file, and colours-derive
"$dir/colours-derive" --check; check derive_check_passes 0 "$?"
work=$(mktemp -d "${TMPDIR:-/tmp}/colours-check.XXXXXX") || exit 1
trap 'rm -rf "$work"' EXIT
cp "$dir/colours.rules.sh" "$dir/colours-derive" "$work/"
"$work/colours-derive"; check derive_writes 0 "$?"
check derive_reproduces_committed_file "$(cat "$dir/colours.g.sh")" "$(cat "$work/colours.g.sh")"
check derive_output_read_only "" "$(find "$work/colours.g.sh" -perm /222)"
head -n 1 "$work/colours.g.sh" | grep -q 'DO NOT EDIT'; check derive_warning_header 0 "$?"
"$work/colours-derive" >/dev/null 2>&1; check derive_overwrites_read_only 0 "$?"
chmod u+w "$work/colours.g.sh"; echo 'col_red=#000000' >> "$work/colours.g.sh"
"$work/colours-derive" --check >/dev/null 2>&1; check derive_check_detects_drift 1 "$?"
rm "$work/colours.g.sh"
"$work/colours-derive" --check >/dev/null 2>&1; check derive_check_detects_missing_file 1 "$?"
"$work/colours-derive" --nope >/dev/null 2>&1; check derive_bad_argument 2 "$?"
sed 's/base_red\([[:space:]]*\)soft/base_red\1softish/' "$work/colours.rules.sh" > "$work/bad.sh" && mv "$work/bad.sh" "$work/colours.rules.sh"
"$work/colours-derive" >/dev/null 2>&1; check derive_rejects_unknown_modifier 1 "$?"
sed 's/base_red\([[:space:]]*\)softish/base_nope\1soft/' "$work/colours.rules.sh" > "$work/bad.sh" && mv "$work/bad.sh" "$work/colours.rules.sh"
"$work/colours-derive" >/dev/null 2>&1; check derive_rejects_unknown_base 1 "$?"
check black_is_a_base "#000000" "$(colour_hex col_black)"
check white_is_a_base "#FFFFFF" "$(colour_hex col_white)"
(unset colours_dir; . "$dir/colours.sh") >/dev/null 2>&1; check source_needs_colours_dir 1 "$?"
(colours_dir=$work; . "$dir/colours.sh") >/dev/null 2>&1; check source_needs_generated_file 1 "$?"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
