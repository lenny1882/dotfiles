#!/usr/bin/env bash
# Safe pre-flight checks for the monitor scripts. Changes nothing: no xrandr
# changes, no herbstclient calls. Run it before restarting or reloading.
#
#   .planning/monitor_changes/monitor_check.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../symlinks/home_@user@_.config_herbstluftwm/scripts" && pwd)"
CONF_DIR="$(dirname "$DIR")"
RECONCILE="$DIR/monitor_reconcile.sh"
TMP=$(mktemp -d) && trap 'rm -rf "$TMP"' EXIT

pass=0 fail=0 skip=0
ok()   { printf '  ok    %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
skp()  { printf '  skip  %s\n' "$1"; skip=$((skip + 1)); }
head_() { printf '\n%s\n' "$1"; }

expect() { if grep -Eq -- "$3" "$2"; then ok "$1"; else bad "$1 (no match for: $3)"; sed 's/^/        /' "$2"; fi; }
reject() { if grep -Eq -- "$3" "$2"; then bad "$1 (found: $3)"; sed 's/^/        /' "$2"; else ok "$1"; fi; }

# ---------------------------------------------------------------- fixtures
cat >"$TMP/laptop.q" <<'EOF'
eDP-1 connected primary 2560x1600+0+0 (normal left inverted right x axis y axis) 340mm x 210mm
   2560x1600    165.00*+
DP-4 disconnected (normal left inverted right x axis y axis)
EOF
cat >"$TMP/laptop.m" <<'EOF'
Monitors: 1
 0: +*eDP-1 2560/340x1600/210+0+0  eDP-1
EOF

cat >"$TMP/docked.q" <<'EOF'
eDP-1 connected primary 2560x1600+0+0 (normal left inverted right x axis y axis) 340mm x 210mm
   2560x1600    165.00*+
DP-4 connected 1920x1080+2560+0 (normal left inverted right x axis y axis) 530mm x 300mm
   1920x1080     60.00*+
EOF
cat >"$TMP/docked.m" <<'EOF'
Monitors: 2
 0: +*eDP-1 2560/340x1600/210+0+0  eDP-1
 1: +DP-4 1920/530x1080/300+2560+0  DP-4
EOF

# DP-4 connected but its EDID was rejected: only fallback modes, no 1920x1080.
cat >"$TMP/nomode.q" <<'EOF'
eDP-1 connected primary 2560x1600+0+0 (normal left inverted right x axis y axis) 340mm x 210mm
   2560x1600    165.00*+
DP-4 connected 640x480+2560+0 (normal left inverted right x axis y axis) 0mm x 0mm
   640x480       60.00*   59.94
   640x400       59.88
EOF
cat >"$TMP/nomode.m" <<'EOF'
Monitors: 2
 0: +*eDP-1 2560/340x1600/210+0+0  eDP-1
 1: +DP-4 640/0x480/0+2560+0  DP-4
EOF

cat >"$TMP/custom.q" <<'EOF'
eDP-1 connected primary 2560x1600+0+0 (normal left inverted right x axis y axis) 340mm x 210mm
   2560x1600    165.00*+
DP-4 connected 640x480+2560+0 (normal left inverted right x axis y axis) 0mm x 0mm
   640x480       60.00*   59.94
   1920x1080_custom 60.00
EOF
cp "$TMP/nomode.m" "$TMP/custom.m"

# DP-4 connected but never got a mode: the failed-apply state.
cat >"$TMP/failed.q" <<'EOF'
eDP-1 connected primary 2560x1600+0+0 (normal left inverted right x axis y axis) 340mm x 210mm
DP-4 connected (normal left inverted right x axis y axis)
EOF

# DP-4 listing only the 640x480 fallback, as with a rejected EDID.
cat >"$TMP/nomode-640.q" <<'EOF'
eDP-1 connected primary 2560x1600+0+0 (normal left inverted right x axis y axis) 340mm x 210mm
   2560x1600    165.00*+
DP-4 connected (normal left inverted right x axis y axis)
   640x480       60.00    59.94
   640x400       59.88    59.98
EOF
cp "$TMP/nomode.m" "$TMP/nomode-640.m"

# Unplugged, but the output still holds a mode.
cat >"$TMP/stale.q" <<'EOF'
eDP-1 connected primary 2560x1600+0+0 (normal left inverted right x axis y axis) 340mm x 210mm
DP-4 disconnected 1920x1080+2560+0 (normal left inverted right x axis y axis)
EOF

cat >"$TMP/empty.conf" <<'EOF'
declare -gA LAYOUTS=()
EOF
cat >"$TMP/dock.conf" <<'EOF'
declare -gA LAYOUTS=()
LAYOUTS["DP-4 eDP-1"]="
DP-4  1920x1080 --primary --pos 0x0
eDP-1 off
"
EOF
cat >"$TMP/panel-on.conf" <<'EOF'
declare -gA LAYOUTS=()
LAYOUTS["DP-4 eDP-1"]="
DP-4  1920x1080 --primary --pos 0x0
eDP-1 auto --right-of DP-4
"
EOF
cat >"$TMP/alloff.conf" <<'EOF'
declare -gA LAYOUTS=()
LAYOUTS["eDP-1"]="
eDP-1 off
"
EOF

# run <name> <fixture-stem> <conf> [extra env...] -- args   (output in $TMP/<name>.out)
run() {
    local name=$1 stem=$2 conf=$3; shift 3
    env XRANDR_FIXTURE="$TMP/$stem.q" LISTMONITORS_FIXTURE="$TMP/${stem%%-*}.m" \
        LAYOUTS_CONF="$conf" "$@" >"$TMP/$name.out" 2>&1
    echo $? >"$TMP/$name.rc"
}
rc() { cat "$TMP/$1.rc"; }

# ---------------------------------------------------------------- 1. syntax
head_ "1. syntax"
for f in "$DIR"/*.sh "$CONF_DIR"/monitors.autostart "$CONF_DIR"/startup.autostart; do
    [[ -f $f ]] || continue
    if bash -n "$f" 2>"$TMP/syntax.out"; then ok "bash -n ${f#"$CONF_DIR"/}"; else bad "bash -n ${f#"$CONF_DIR"/}"; cat "$TMP/syntax.out"; fi
done
if bash -n "$DIR/monitor_layouts.conf" 2>"$TMP/syntax.out"; then ok "bash -n scripts/monitor_layouts.conf"; else bad "bash -n scripts/monitor_layouts.conf"; cat "$TMP/syntax.out"; fi

if command -v shellcheck >/dev/null; then
    if shellcheck -x -S warning "$DIR"/monitor_changes.sh "$DIR"/monitor_reconcile.sh "$DIR"/background.sh "$DIR"/rule_hook.sh >"$TMP/sc.out" 2>&1; then
        ok "shellcheck"
    else
        bad "shellcheck"; sed 's/^/        /' "$TMP/sc.out"
    fi
else
    skp "shellcheck not installed"
fi

for s in monitor_reconcile.sh monitor_changes.sh background.sh rule_hook.sh; do
    [[ -x $DIR/$s ]] && ok "$s is executable" || bad "$s is not executable"
done

# ---------------------------------------------------------------- 2. fixtures
head_ "2. fixtures (--dry-run, nothing is applied)"

run key-laptop laptop "$TMP/empty.conf" "$RECONCILE" --key
[[ $(cat "$TMP/key-laptop.out") == "eDP-1" ]] && ok "--key, laptop only: eDP-1" || bad "--key, laptop only: $(cat "$TMP/key-laptop.out")"
run key-docked docked "$TMP/empty.conf" "$RECONCILE" --key
[[ $(cat "$TMP/key-docked.out") == "DP-4 eDP-1" ]] && ok "--key, docked: DP-4 eDP-1" || bad "--key, docked: $(cat "$TMP/key-docked.out")"

cat >"$TMP/docked.p" <<'EOF'
eDP-1 connected primary 2560x1600+0+0 (normal left inverted right x axis y axis) 340mm x 210mm
	EDID: 
		00ffffffffffff0009e5aaaaaaaaaaaa
		1c0104a5
DP-4 connected 1920x1080+2560+0 (normal left inverted right x axis y axis) 530mm x 300mm
	EDID: 
		00ffffffffffff0005e3bbbbbbbbbbbb
		1c0104a5
EOF
cat >"$TMP/ids.conf" <<'EOF'
declare -gA MONITORS=( ["00ffffffffffff0005e3bbbbbbbbbbbb"]="desk" )
declare -gA LAYOUTS=()
LAYOUTS["desk eDP-1"]="
desk  1920x1080 --primary --pos 0x0
eDP-1 off
"
EOF
run key-id docked "$TMP/ids.conf" XRANDR_PROP_FIXTURE="$TMP/docked.p" "$RECONCILE" --key
[[ $(cat "$TMP/key-id.out") == "desk eDP-1" ]] && ok "--key, EDID listed: the monitor's name replaces its port" || bad "--key, EDID listed: $(cat "$TMP/key-id.out")"
run key-unlisted docked "$TMP/empty.conf" XRANDR_PROP_FIXTURE="$TMP/docked.p" "$RECONCILE" --key
[[ $(cat "$TMP/key-unlisted.out") == "00ffffffffffff0005e3bbbbbbbbbbbb eDP-1" ]] && ok "--key, EDID unlisted: the id is the name, the panel stays eDP-1" || bad "--key, EDID unlisted: $(cat "$TMP/key-unlisted.out")"
run ids docked "$TMP/ids.conf" XRANDR_PROP_FIXTURE="$TMP/docked.p" "$RECONCILE" --ids
expect "--ids lists port, name and id" "$TMP/ids.out" '^DP-4 desk 00ffffffffffff0005e3bbbbbbbbbbbb$'
run apply-id docked "$TMP/ids.conf" XRANDR_PROP_FIXTURE="$TMP/docked.p" "$RECONCILE" --dry-run --force
expect "a layout naming a monitor by name is applied to its port" "$TMP/apply-id.out" 'xrandr --output DP-4 --mode 1920x1080 --primary --pos 0x0'
cat >"$TMP/wide.q" <<'EOF'
eDP-1 connected primary 2560x1600+0+0 (normal left inverted right x axis y axis) 340mm x 210mm
   2560x1600    165.00*+
DP-4 connected 5120x1440+0+0 (normal left inverted right x axis y axis) 1200mm x 340mm
   5120x1440     60.00*+
EOF
cat >"$TMP/wide.m" <<'EOF'
Monitors: 2
 0: +*DP-4~1 1280/300x1440/340+0+0  DP-4
 1: +DP-4~2 2560/600x1440/340+1280+0  none
EOF
cat >"$TMP/split.conf" <<'EOF'
declare -gA LAYOUTS=()
LAYOUTS["DP-4 eDP-1"]="
DP-4  5120x1440 --primary --pos 0x0 --split 1280x1440+0+0 2560x1440+1280+0 1280x1440+3840+0
eDP-1 off
"
EOF
run split wide "$TMP/split.conf" "$RECONCILE" --dry-run --force
expect "split: earlier virtual monitors are deleted first" "$TMP/split.out" 'xrandr --delmonitor DP-4~1'
reject "split: --split is not passed to xrandr --output" "$TMP/split.out" '--output DP-4.*--split'
expect "split: the first piece owns the output" "$TMP/split.out" 'xrandr --setmonitor DP-4~1 1280/300x1440/340\+0\+0 DP-4$'
expect "split: the middle piece is offset by its position" "$TMP/split.out" 'xrandr --setmonitor DP-4~2 2560/600x1440/340\+1280\+0 none$'
expect "split: the third piece is created" "$TMP/split.out" 'xrandr --setmonitor DP-4~3 1280/300x1440/340\+3840\+0 none$'
sed 's/3840+0/4000+0/' "$TMP/split.conf" >"$TMP/split-bad.conf"
run splitbad wide "$TMP/split-bad.conf" "$RECONCILE" --dry-run --force
expect "split: a piece outside the monitor is refused" "$TMP/splitbad.out" 'not splitting it'
reject "split: nothing is created for a refused split" "$TMP/splitbad.out" 'setmonitor'
sed 's/bbbb/cccc/' "$TMP/docked.p" >"$TMP/other.p"
run apply-other docked "$TMP/ids.conf" XRANDR_PROP_FIXTURE="$TMP/other.p" "$RECONCILE" --dry-run --force
expect "a different monitor on the same port gets the fallback, not the named layout" "$TMP/apply-other.out" "no layout for"
reject "a different monitor on the same port keeps the panel on" "$TMP/apply-other.out" 'eDP-1 --off'

run known-laptop laptop "$TMP/empty.conf" "$RECONCILE" --known
[[ $(rc known-laptop) == 0 ]] && ok "--known: laptop alone is known" || bad "--known: laptop alone should be known"
run known-docked docked "$TMP/empty.conf" "$RECONCILE" --known
[[ $(rc known-docked) != 0 ]] && ok "--known: docked, no layout, is unknown" || bad "--known: docked, no layout, should be unknown"
run known-layout docked "$TMP/dock.conf" "$RECONCILE" --known
[[ $(rc known-layout) == 0 ]] && ok "--known: docked, with layout, is known" || bad "--known: docked, with layout, should be known"

run fb-laptop laptop "$TMP/empty.conf" "$RECONCILE" --dry-run --force
[[ $(rc fb-laptop) == 0 ]] && ok "laptop only: dry run succeeds" || bad "laptop only: dry run failed"
expect "laptop only: panel is configured on" "$TMP/fb-laptop.out" 'xrandr --output eDP-1 --auto'
reject "laptop only: panel is never switched off" "$TMP/fb-laptop.out" 'eDP-1 --off'
expect "laptop only: set_monitors is planned" "$TMP/fb-laptop.out" 'set_monitors'

run fb-docked docked "$TMP/empty.conf" "$RECONCILE" --dry-run --force
[[ $(rc fb-docked) == 0 ]] && ok "docked, no layout: dry run succeeds" || bad "docked, no layout: dry run failed"
expect "docked, no layout: fallback is announced" "$TMP/fb-docked.out" 'using fallback'
reject "docked, no layout: panel stays on" "$TMP/fb-docked.out" 'eDP-1 --off'
expect "docked, no layout: the panel stays primary at 0x0" "$TMP/fb-docked.out" 'xrandr --output eDP-1 --auto --primary --pos 0x0'
expect "docked, no layout: the external goes to its right" "$TMP/fb-docked.out" 'DP-4 --auto --right-of eDP-1'
reject "docked, no layout: the external is not primary" "$TMP/fb-docked.out" 'DP-4.*--primary'

run lay-docked docked "$TMP/dock.conf" "$RECONCILE" --dry-run --force
expect "docked, panel-off layout: DP-4 is set first" "$TMP/lay-docked.out" 'DP-4 --mode 1920x1080 --primary --pos 0x0'
expect "docked, panel-off layout: panel is switched off after" "$TMP/lay-docked.out" 'eDP-1 --off'

run fb-nomodes failed "$TMP/empty.conf" "$RECONCILE" --dry-run --force
expect "unknown external with no modes: it is announced" "$TMP/fb-nomodes.out" 'DP-4 lists no usable mode'
expect "unknown external with no modes: 1920x1080 is created" "$TMP/fb-nomodes.out" 'xrandr --newmode 1920x1080_custom'
expect "unknown external with no modes: the mode is added" "$TMP/fb-nomodes.out" 'xrandr --addmode DP-4 1920x1080_custom'
expect "unknown external with no modes: it is turned on, right of the panel" "$TMP/fb-nomodes.out" 'DP-4 --mode 1920x1080_custom --right-of eDP-1'
run fb-640 nomode-640 "$TMP/empty.conf" "$RECONCILE" --dry-run --force
expect "unknown external listing only 640x480: treated as having no usable mode" "$TMP/fb-640.out" 'DP-4 lists no usable mode'
run fb-again custom "$TMP/empty.conf" "$RECONCILE" --dry-run --force
expect "unknown external whose big mode is one we created: still uses it, not auto" "$TMP/fb-again.out" 'DP-4 --mode 1920x1080_custom --right-of eDP-1'
reject "unknown external whose big mode is one we created: the mode is not re-created" "$TMP/fb-again.out" 'newmode'
run fb-ok docked "$TMP/empty.conf" "$RECONCILE" --dry-run --force
reject "unknown external with real modes: left on auto" "$TMP/fb-ok.out" 'no usable mode'

run guard failed "$TMP/dock.conf" XRANDR_AFTER_FIXTURE="$TMP/failed.q" "$RECONCILE" --dry-run --force
expect "guard: failed external keeps the panel on" "$TMP/guard.out" 'keeping the panel on'
reject "guard: the panel is not switched off" "$TMP/guard.out" 'output eDP-1 --off'

run alloff laptop "$TMP/alloff.conf" "$RECONCILE" --dry-run --force
expect "guard: a layout with nothing active keeps the panel on" "$TMP/alloff.out" 'keeping the panel on'
reject "guard: the panel is not switched off" "$TMP/alloff.out" 'output eDP-1 --off'

run nomode nomode "$TMP/dock.conf" "$RECONCILE" --dry-run --force
expect "no EDID: the missing 1920x1080 is announced" "$TMP/nomode.out" 'DP-4 does not list 1920x1080'
expect "no EDID: the mode is created" "$TMP/nomode.out" 'xrandr --newmode 1920x1080_custom 148.50 1920 2008 2052 2200 1080 1084 1089 1125'
expect "no EDID: the mode is added to DP-4" "$TMP/nomode.out" 'xrandr --addmode DP-4 1920x1080_custom'
expect "no EDID: the layout uses the custom mode" "$TMP/nomode.out" 'DP-4 --mode 1920x1080_custom'
reject "listed modes are not re-created" "$TMP/lay-docked.out" 'newmode'
run custom custom "$TMP/dock.conf" "$RECONCILE" --dry-run --force
reject "an existing custom mode is not re-created" "$TMP/custom.out" 'newmode'
expect "an existing custom mode is used" "$TMP/custom.out" 'DP-4 --mode 1920x1080_custom'

run stale stale "$TMP/empty.conf" "$RECONCILE" --dry-run --force
expect "stale output: unplugged DP-4 is switched off" "$TMP/stale.out" 'output DP-4 --off'

run bad-arg laptop "$TMP/empty.conf" "$RECONCILE" --nonsense
[[ $(rc bad-arg) != 0 ]] && ok "unknown argument is rejected" || bad "unknown argument should be rejected"

# ---------------------------------------------------------------- 3. live
head_ "3. live display (read-only)"
if [[ -z $DISPLAY ]] || ! xrandr --query >"$TMP/live.q" 2>/dev/null; then
    skp "no usable display here; run this from inside your session"
else
    ok "xrandr --query works on $DISPLAY"
    key=$("$RECONCILE" --key 2>/dev/null)
    printf '        layout key: %s\n' "$key"
    [[ -n $key ]] && ok "--key prints a layout key" || bad "--key printed nothing"
    "$RECONCILE" --known; r=$?
    printf '        known set: %s\n' "$([[ $r == 0 ]] && echo yes || echo no)"
    "$RECONCILE" --dry-run --force >"$TMP/live.out" 2>&1 \
        && ok "dry run on the live set succeeds" || { bad "dry run on the live set failed"; cat "$TMP/live.out"; }
    printf '        the dry run would do:\n'
    sed 's/^/          /' "$TMP/live.out"
    if grep -Eq -- '--off' "$TMP/live.out"; then
        printf '        note: the plan switches something off. Read it before you apply it.\n'
    fi
    if command -v herbstclient >/dev/null && herbstclient version >/dev/null 2>&1; then
        # one watcher forks several subshells with the same name, so count only
        # the processes whose parent is not itself a monitor_changes.sh
        n=$(ps -eo pid=,ppid=,args= | awk '
            /monitor_changes\.sh/ && !/awk/ { pid[$1] = 1; ppid[$1] = $2 }
            END { for (p in pid) if (!(ppid[p] in pid)) n++; print n + 0 }')
        printf '        monitor_changes.sh watchers running: %s (expect 1)\n' "$n"
    fi
fi

# ---------------------------------------------------------------- hooks
head_ "3b. hook dispatch (rule_hook.sh, with stubs for everything it runs)"
H="$TMP/hooks"; mkdir -p "$H/bin"
cp "$DIR/rule_hook.sh" "$H/rule_hook.sh"
for stub in monitor_reconcile.sh panel.sh background.sh tag_layouts.sh; do
    printf '#!/bin/sh\necho "%s $*" >> "$STUBLOG"\n' "$stub" >"$H/$stub"; chmod +x "$H/$stub"
done
printf '#!/bin/sh\necho "herbstclient $*" >> "$STUBLOG"\n' >"$H/bin/herbstclient"; chmod +x "$H/bin/herbstclient"
printf '#!/bin/sh\necho "polybar-msg $*" >> "$STUBLOG"\n' >"$H/bin/polybar-msg"; chmod +x "$H/bin/polybar-msg"
hook() { : >"$TMP/hooks.log"; PATH="$H/bin:$PATH" STUBLOG="$TMP/hooks.log" bash "$H/rule_hook.sh" "$@" >/dev/null 2>&1; }

hook monitors_changed
expect "monitors_changed runs monitor_reconcile.sh" "$TMP/hooks.log" '^monitor_reconcile.sh *$'
reject "monitors_changed runs nothing else" "$TMP/hooks.log" 'panel|background'
hook monitors_applied
expect "monitors_applied runs panel.sh with the active and urgent colours" "$TMP/hooks.log" '^panel.sh #[0-9A-Fa-f]{6} #[0-9A-Fa-f]{6}$'
expect "monitors_applied then resets the background" "$TMP/hooks.log" '^background.sh'
reject "monitors_applied does not reconcile again" "$TMP/hooks.log" 'monitor_reconcile'
hook rule peek_opened
expect "window rules still work" "$TMP/hooks.log" 'herbstclient set_attr clients.focus.decorated false'
reject "window hooks leave the monitor scripts alone" "$TMP/hooks.log" 'monitor_reconcile|panel|background'
hook tag_changed "my tag" 0
expect "tag_changed lays out just that tag" "$TMP/hooks.log" '^tag_layouts.sh --only my tag$'
hook focus_changed 0x1 title
reject "an unrelated hook runs nothing" "$TMP/hooks.log" '.'
reject "monitor_changes.sh no longer listens for hooks" "$DIR/monitor_changes.sh" 'handle_hooks|herbstclient --idle *[|]|while read.*hook'
expect "monitor_changes.sh exits when herbstluftwm does (--idle output discarded)" "$DIR/monitor_changes.sh" 'herbstclient --idle >/dev/null'
expect "monitor_changes.sh still emits monitors_changed" "$DIR/monitor_changes.sh" 'emit_hook "\$HOOK"'

# ---------------------------------------------------------------- tag programs
head_ "3b. tag_programs.sh"
mkdir -p "$TMP/tp"
cp "$DIR/tag_programs.sh" "$TMP/tp/"
printf '#!/usr/bin/env bash\necho "A-1 B-2"\n' >"$TMP/tp/monitor_reconcile.sh"; chmod +x "$TMP/tp/monitor_reconcile.sh"
cat >"$TMP/tp/hlwm_tag_layouts.conf" <<'CONF'
declare -gA TAG_LAYOUTS=()
TAG_LAYOUTS["A-1 B-2"]="
left|3   max  {3} [spotify:00 rambox:01]
my tag   grid {2} [vivaldi-stable:02]
other    max  []
bare     max
"
TAG_LAYOUTS["C-3"]="
left|3   max  [spotify:05]
"
CONF
got=$(bash -c 'source "$1"; for k in "${!PROG_TAG[@]}"; do echo "$k=${PROG_TAG[$k]}:${PROG_INDEX[$k]}"; done | sort' _ "$TMP/tp/tag_programs.sh")
if [[ $got == $'rambox=left|3:01\nspotify=left|3:00\nvivaldi-stable=my tag:02' ]]; then ok "tag_programs.sh reads the connected set's programs (tag names with spaces, [] and bare lines)"; else bad "tag_programs.sh reads the connected set's programs"; echo "$got" | sed 's/^/        /'; fi

# ---------------------------------------------------------------- tags
head_ "3c. tags.sh"
mkdir -p "$TMP/tg"
cp "$DIR/tags.sh" "$TMP/tg/"
printf '#!/usr/bin/env bash\necho "A-1"\n' >"$TMP/tg/monitor_reconcile.sh"; chmod +x "$TMP/tg/monitor_reconcile.sh"
cat >"$TMP/tg/hlwm_tag_layouts.conf" <<'CONF'
declare -gA TAG_LAYOUTS=()
TAG_LAYOUTS["A-1"]="
left    max  {3} [spotify:00]
foo      grid
right    max  {1}
"
CONF
got=$(HLWM_TAG_LAYOUTS="$TMP/tg/hlwm_tag_layouts.conf" "$TMP/tg/tags.sh" --dry-run | tr '\n' ';')
if [[ $got == '0 left 3;1 foo 2;2 right 1;3 4 4;4 5 5;5 6 6;6 7 7;7 8 8;8 9 9;' ]]; then ok "tags.sh names and keys the tags ({n} on the line, else position) and pads to 9"; else bad "tags.sh names and keys the tags"; echo "$got" | sed 's/^/        /'; fi

# ---------------------------------------------------------------- tag layouts: none
head_ "3d. tag_layouts.sh"
mkdir -p "$TMP/tl"
cp "$DIR/tag_layouts.sh" "$DIR/hlwm_layouts.conf" "$TMP/tl/"
printf '#!/usr/bin/env bash\necho "A-1"\n' >"$TMP/tl/monitor_reconcile.sh"
cat >"$TMP/tl/herbstclient" <<'STUB'
#!/usr/bin/env bash
case $1 in
    silent) exit 0 ;;
    dump) echo "(clients vertical:0)" ;;
    list_monitors) printf '%s\n' "$LISTMON" ;;
    load) echo "load $2 $3" >>"$LOADLOG" ;;
esac
exit 0
STUB
chmod +x "$TMP/tl/monitor_reconcile.sh" "$TMP/tl/herbstclient"
cat >"$TMP/tl/hlwm_tag_layouts.conf" <<'CONF'
declare -gA TAG_LAYOUTS=()
TAG_LAYOUTS["A-1"]="
one   max
two   none
three max  {3}  [x:0]
"
CONF
got=$(PATH="$TMP/tl:$PATH" "$TMP/tl/tag_layouts.sh" --dry-run 2>&1 | tr '\n' ';')
if [[ $got == 'tag_layouts: one: max;tag_layouts: three: max;' ]]; then ok "tag_layouts.sh leaves a tag whose layout is none alone, and ignores {n} and [...]"; else bad "tag_layouts.sh leaves a tag whose layout is none alone"; echo "$got" | sed 's/^/        /'; fi

cat >"$TMP/tl/hlwm_layouts.conf" <<'CONF'
split_h='(split horizontal:0.5:0 (clients vertical:0) (clients horizontal:0))'
CONF
cat >"$TMP/tl/hlwm_tag_layouts.conf" <<'CONF'
declare -gA TAG_LAYOUTS=()
TAG_LAYOUTS["A-1"]="
land   split_h
port   split_h
nowhere split_h
"
CONF
LM=$'0: 2560x1600+0+0 with tag "land" [FOCUS]\n1: 1080x1920+2560+0 with tag "port"'
: >"$TMP/load.log"
PATH="$TMP/tl:$PATH" LISTMON="$LM" LOADLOG="$TMP/load.log" "$TMP/tl/tag_layouts.sh" >"$TMP/portrait.out" 2>&1
expect "portrait: a tag on a landscape monitor keeps its layout" "$TMP/load.log" '^load land \(split horizontal:0.5:0 \(clients vertical:0\) \(clients horizontal:0\)\)$'
expect "portrait: a tag on a portrait monitor gets every direction swapped" "$TMP/load.log" '^load port \(split vertical:0.5:0 \(clients horizontal:0\) \(clients vertical:0\)\)$'
expect "portrait: a tag not on any monitor is not swapped" "$TMP/load.log" '^load nowhere \(split horizontal'
expect "portrait: the log says which one was transposed" "$TMP/portrait.out" 'port: split_h \(portrait\)'
reject "portrait: only the portrait one says so" "$TMP/portrait.out" 'land: split_h \(portrait\)'
: >"$TMP/load.log"
PATH="$TMP/tl:$PATH" LISTMON="$LM" LOADLOG="$TMP/load.log" "$TMP/tl/tag_layouts.sh" --only port >/dev/null 2>&1
[[ $(wc -l <"$TMP/load.log") == 1 ]] && expect "--only lays out just that tag" "$TMP/load.log" '^load port ' || bad "--only lays out just that tag"

# ---------------------------------------------------------------- tag windows
head_ "3e. tag_windows.sh"
W="$TMP/tw"; mkdir -p "$W/bin"
cp "$DIR/tag_windows.sh" "$DIR/tags.sh" "$DIR/tag_programs.sh" "$W/"
printf '#!/usr/bin/env bash\necho "$NEWSET"\n' >"$W/monitor_reconcile.sh"
cat >"$W/bin/herbstclient" <<'STUB'
#!/usr/bin/env bash
case $1 in
    get_attr)
        case $2 in
            my_tag_set) [[ -n $OLDSET ]] && echo "$OLDSET" || exit 1 ;;
            clients.w1.instance) echo spotify ;;
            clients.w2.instance) echo vivaldi-stable ;;
            clients.w3.instance) echo vivaldi-stable ;;
        esac ;;
    list_clients)
        case $2 in
            --tag=x) echo w1; echo w2 ;;
            --tag=y) echo w3 ;;
        esac ;;
    *) echo "$*" >>"$STUBLOG" ;;
esac
STUB
chmod +x "$W/monitor_reconcile.sh" "$W/bin/herbstclient"
cat >"$W/hlwm_tag_layouts.conf" <<'CONF'
declare -gA TAG_LAYOUTS=()
TAG_LAYOUTS["A"]="
left|1  max [spotify:0]
right|2 max [vivaldi-stable:1]
"
TAG_LAYOUTS["B"]="
x max [vivaldi-stable:11]
y max [spotify:10]
"
CONF
tw() { : >"$W/log"; HLWM_TAG_LAYOUTS="$W/hlwm_tag_layouts.conf" PATH="$W/bin:$PATH" STUBLOG="$W/log" OLDSET="$1" NEWSET="$2" "$W/tag_windows.sh" "${@:3}" >/dev/null 2>&1; }
tw A B
got=$(sort "$W/log" | tr '\n' ';')
if [[ $got == 'apply_tmp_rule w1 --tag=y --index=10;apply_tmp_rule w3 --tag=x --index=11;set_attr my_tag_set B;silent new_attr string my_tag_set;' ]]; then ok "tag_windows.sh moves windows still on their original tag, leaves one moved by hand, and records the set"; else bad "tag_windows.sh moves windows"; echo "$got" | sed 's/^/        /'; fi
tw B B
got=$(tr '\n' ';' <"$W/log")
[[ $got == 'silent new_attr string my_tag_set;set_attr my_tag_set B;' ]] && ok "tag_windows.sh moves nothing when the set has not changed" || { bad "tag_windows.sh, same set"; echo "$got" | sed 's/^/        /'; }
tw "" B
got=$(tr '\n' ';' <"$W/log")
[[ $got == 'silent new_attr string my_tag_set;set_attr my_tag_set B;' ]] && ok "tag_windows.sh only records when no set was remembered" || { bad "tag_windows.sh, no remembered set"; echo "$got" | sed 's/^/        /'; }
tw A B --dry-run
[[ ! -s $W/log ]] && ok "tag_windows.sh --dry-run changes nothing" || { bad "tag_windows.sh --dry-run"; sed 's/^/        /' "$W/log"; }

# ---------------------------------------------------------------- background
head_ "3f. background.sh"
B="$TMP/bg"; mkdir -p "$B/bin"
cp "$DIR/background.sh" "$B/"
printf '#!/bin/sh\ncat "$IDS_FILE"\n' >"$B/monitor_reconcile.sh"; chmod +x "$B/monitor_reconcile.sh"
printf '#!/bin/sh\ncat "$LISTMONITORS_FILE"\n' >"$B/bin/xrandr"
printf '#!/bin/sh\necho "$*" >"$FEHLOG"\nfor a in "$@"; do case $a in *.ppm) cp "$a" "$FEHLOG.ppm" ;; esac; done\n' >"$B/bin/feh"
chmod +x "$B/bin/xrandr" "$B/bin/feh"
wall=$(bash -c 'source ~/.config/herbstluftwm/variables.autostart; echo $wallpaper')
bg() {
    printf '%s\n' "$1" >"$B/ids"; printf 'Monitors: 2\n%s\n' "$2" >"$B/lm"
    PATH="$B/bin:$PATH" IDS_FILE="$B/ids" LISTMONITORS_FILE="$B/lm" FEHLOG="$B/feh.log" bash "$B/background.sh" >/dev/null 2>&1
    cat "$B/feh.log"
}
PANEL=' 0: +*eDP-1 2560/340x1600/210+0+0  eDP-1'
EXT=' 1: +DP-4 1920/530x1080/300+2560+0  DP-4'
got=$(bg $'eDP-1 eDP-1 00ffffffffffff0009e5c90b00000000\nDP-4 DP-4 -' "$PANEL"$'\n'"$EXT")
[[ $got == "--no-fehbg --bg-fill $wall "*.ppm ]] && ok "background: the panel keeps the wallpaper, an unrecognised external gets the solid colour" || { bad "background: panel wallpaper, unknown external colour"; echo "        $got"; }
bg $'eDP-1 eDP-1 -\nDP-4 DP-4 -' "$PANEL"$'\n'"$EXT" >/dev/null
read -r -d '' ppm <"$B/feh.log.ppm"
[[ $(head -3 "$B/feh.log.ppm" | tr '\n' ' ') == 'P3 64 64 255 ' && $(tail -n +4 "$B/feh.log.ppm" | tr -s ' \n' '\n\n' | sort | uniq -c | tr -s ' \n' ' ') == ' 4096 101 4096 192 4096 21 ' ]] \
    && ok "background: the solid colour is a 64x64 image of #1565C0 (a 1x1 image scales to black in feh)" || { bad "background: the solid image"; head -4 "$B/feh.log.ppm" | cut -c1-40 | sed 's/^/        /'; }
got=$(bg $'eDP-1 eDP-1 00ffffffffffff0009e5c90b00000000\nDP-4 desk 00ffffffffffff0005e3bbbbbbbbbbbb' "$PANEL"$'\n'"$EXT")
[[ $got == "--no-fehbg --bg-fill $wall" ]] && ok "background: an external listed in MONITORS keeps the wallpaper too" || { bad "background: listed external"; echo "        $got"; }
got=$(bg $'eDP-1 eDP-1 -\nDP-4 00ffffffffffff0005e3bbbbbbbbbbbb 00ffffffffffff0005e3bbbbbbbbbbbb' "$EXT"$'\n'"$PANEL")
[[ $got == "--no-fehbg --bg-fill "*".ppm $wall" ]] && ok "background: images follow xrandr's monitor order; an unlisted external with an EDID is unknown" || { bad "background: order, unlisted EDID"; echo "        $got"; }

# ---------------------------------------------------------------- tui
head_ "4. monitor_tui.py (no display needed)"
if command -v python3 >/dev/null; then
    if [[ -x $DIR/monitor_tui.py ]]; then ok "monitor_tui.py is executable"; else bad "monitor_tui.py is executable"; fi
    if python3 -I "$(dirname "${BASH_SOURCE[0]}")/monitor_tui_check.py" >"$TMP/tui.out" 2>&1; then
        ok "monitor_tui_check.py: $(tail -n 1 "$TMP/tui.out")"
    else
        bad "monitor_tui_check.py"; sed 's/^/        /' "$TMP/tui.out"
    fi
else
    skp "python3 not installed, monitor_tui.py cannot run"
fi

# ---------------------------------------------------------------- summary
printf '\n%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
((fail == 0))
