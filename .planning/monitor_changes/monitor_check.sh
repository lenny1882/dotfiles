#!/usr/bin/env bash
# Safe pre-flight checks for the monitor scripts. Changes nothing: no xrandr
# changes, no herbstclient calls. Run it before restarting or reloading.
#
#   .planning/monitor_changes/monitor_check.sh
#
# 1. syntax of every script (and shellcheck, if installed)
# 2. reconcile against built-in fixtures, with --dry-run
# 3. the same read-only queries against the live display, if there is one

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../symlinks/home_@user@_.config_herbstluftwm/scripts" && pwd)"
CONF_DIR="$(dirname "$DIR")"
RECONCILE="$DIR/monitor_reconcile.sh"
TMP=$(mktemp -d) && trap 'rm -rf "$TMP"' EXIT

pass=0 fail=0 skip=0
ok()   { printf '  ok    %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
skp()  { printf '  skip  %s\n' "$1"; skip=$((skip + 1)); }
head_() { printf '\n%s\n' "$1"; }

# expect <description> <file> <pattern>: the file must match the pattern
expect() { if grep -Eq -- "$3" "$2"; then ok "$1"; else bad "$1 (no match for: $3)"; sed 's/^/        /' "$2"; fi; }
# reject <description> <file> <pattern>: the file must not match the pattern
reject() { if grep -Eq -- "$3" "$2"; then bad "$1 (found: $3)"; sed 's/^/        /' "$2"; else ok "$1"; fi; }

# ---------------------------------------------------------------- fixtures
# xrandr --query: only the lines the scripts read.
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

# the custom mode was already added on an earlier run
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
    if shellcheck -x -S warning "$DIR"/monitor_changes.sh "$DIR"/monitor_reconcile.sh "$DIR"/background.sh >"$TMP/sc.out" 2>&1; then
        ok "shellcheck"
    else
        bad "shellcheck"; sed 's/^/        /' "$TMP/sc.out"
    fi
else
    skp "shellcheck not installed"
fi

for s in monitor_reconcile.sh monitor_changes.sh background.sh; do
    [[ -x $DIR/$s ]] && ok "$s is executable" || bad "$s is not executable"
done

# ---------------------------------------------------------------- 2. fixtures
head_ "2. fixtures (--dry-run, nothing is applied)"

run key-laptop laptop "$TMP/empty.conf" "$RECONCILE" --key
[[ $(cat "$TMP/key-laptop.out") == "eDP-1" ]] && ok "--key, laptop only: eDP-1" || bad "--key, laptop only: $(cat "$TMP/key-laptop.out")"
run key-docked docked "$TMP/empty.conf" "$RECONCILE" --key
[[ $(cat "$TMP/key-docked.out") == "DP-4 eDP-1" ]] && ok "--key, docked: DP-4 eDP-1" || bad "--key, docked: $(cat "$TMP/key-docked.out")"

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

run lay-docked docked "$TMP/dock.conf" "$RECONCILE" --dry-run --force
expect "docked, panel-off layout: DP-4 is set first" "$TMP/lay-docked.out" 'DP-4 --mode 1920x1080 --primary --pos 0x0'
expect "docked, panel-off layout: panel is switched off after" "$TMP/lay-docked.out" 'eDP-1 --off'

# the guard: the external never got a mode, so the panel must stay on
run guard failed "$TMP/dock.conf" XRANDR_AFTER_FIXTURE="$TMP/failed.q" "$RECONCILE" --dry-run --force
expect "guard: failed external keeps the panel on" "$TMP/guard.out" 'keeping the panel on'
reject "guard: the panel is not switched off" "$TMP/guard.out" 'output eDP-1 --off'

# the guard: a layout that turns every output off
run alloff laptop "$TMP/alloff.conf" "$RECONCILE" --dry-run --force
expect "guard: a layout with nothing active keeps the panel on" "$TMP/alloff.out" 'keeping the panel on'
reject "guard: the panel is not switched off" "$TMP/alloff.out" 'output eDP-1 --off'

# custom modes for a monitor whose EDID was rejected
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
        n=$(pgrep -fc 'monitor_changes\.sh')
        printf '        monitor_changes.sh processes running: %s\n' "$n"
    fi
fi

# ---------------------------------------------------------------- summary
printf '\n%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
((fail == 0))
