#!/bin/sh

# usage: colours_gen_check.sh   (run it under sh, bash and bash --posix)

src=$(cd "$(dirname "$0")/../../setup" && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/colours-gen-check.XXXXXX") || exit 1
trap 'rm -rf "$work"' EXIT
mkdir "$work/templates"
cp "$src/colours.sh" "$src/colours-gen" "$work/"
gen="$work/colours-gen"

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

printf 'bg = "@col_dark@"\nfg = "@col_light@" # @col_light@ again\nplain = "#abcdef"\n' > "$work/templates/t.tmpl"
check substitutes 'bg = "#252526"
fg = "#ECEFF4" # #ECEFF4 again
plain = "#abcdef"' "$("$gen" t)"

printf 'no placeholders here\nuser@example.com and @ alone\n' > "$work/templates/plain.tmpl"
check no_placeholders_unchanged 'no placeholders here
user@example.com and @ alone' "$("$gen" plain)"

printf 'b = "@col_nord9@@col_light@"\n' > "$work/templates/adj.tmpl"
check adjacent 'b = "#81A1C1#ECEFF4"' "$("$gen" adj)"

printf 'ok = "@col_red@"\nbad = "@col_nope@"\n' > "$work/templates/bad.tmpl"
out=$("$gen" bad 2>"$work/err")
rc=$?
check unknown_colour_exit 1 "$rc"
check unknown_colour_no_stdout "" "$out"
check unknown_colour_message "colours: unknown colour 'col_nope'
colours-gen: bad.tmpl uses @col_nope@" "$(cat "$work/err")"

"$gen" missing >/dev/null 2>&1; check missing_template_exit 2 "$?"
"$gen" >/dev/null 2>&1; check no_argument_exit 2 "$?"
"$gen" a b >/dev/null 2>&1; check two_arguments_exit 2 "$?"

printf 'x = "@col_green_256@"\n' > "$work/templates/num.tmpl"
"$gen" num >/dev/null 2>&1; check non_hex_value_rejected 1 "$?"

for t in "$src"/templates/*.tmpl; do
	name=$(basename "$t" .tmpl)
	"$src/colours-gen" "$name" >/dev/null 2>"$work/err"; check "real_template_$name" 0 "$?"
done

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
