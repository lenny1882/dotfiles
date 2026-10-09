#!/usr/bin/env python3
"""Checks for monitor_tui.py that need no display: parsing, moving, the
turn-off guard, the generated layout, saving to the conf, and a dry run through
monitor_reconcile.sh --layout over stdin. Run from anywhere:

    python3 .planning/monitor_changes/monitor_tui_check.py
"""
import importlib.util
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.normpath(os.path.join(
    HERE, "..", "..", "symlinks", "home_@user@_.config_herbstluftwm", "scripts"))

spec = importlib.util.spec_from_file_location("monitor_tui", os.path.join(SCRIPTS, "monitor_tui.py"))
tui = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tui)

DOCKED = """\
eDP-1 connected primary 2560x1600+0+0 340mm x 210mm
   2560x1600    165.00*+  60.00
DP-4 connected 1920x1080+2560+0 530mm x 300mm
   1920x1080_custom     60.00*+
   1920x1080     60.00
   1280x720     60.00
HDMI-1 disconnected
"""

# DP-4 plugged in but not enabled: no geometry, no starred mode.
OFF = """\
eDP-1 connected primary 2560x1600+0+0 340mm x 210mm
   2560x1600    165.00*+
DP-4 connected 340mm x 210mm
   1920x1080     60.00 +
   1280x720     60.00
"""

passed = failed = 0


def check(desc, cond, detail=""):
    global passed, failed
    if cond:
        passed += 1
        print(f"  ok    {desc}")
    else:
        failed += 1
        print(f"  FAIL  {desc} {detail}")


def model(text):
    return tui.Model(tui.parse_xrandr(text))


print("monitor_tui.py")

m = model(DOCKED)
e, d = m.outs
check("parse: only connected outputs", [o.name for o in m.outs] == ["eDP-1", "DP-4"])
check("parse: primary flag", e.primary and not d.primary)
check("parse: geometry", (d.x, d.y, d.w, d.h) == (2560, 0, 1920, 1080))
check("parse: custom suffix stripped from the active mode", d.mode == "1920x1080")
check("parse: modes are unique", d.modes == ["1920x1080", "1280x720"], d.modes)
check("key is sorted names", m.key() == "DP-4 eDP-1")

mo = model(OFF)
check("parse: output without geometry is off", mo.outs[1].mode == "off")
check("parse: off output gets its preferred size", (mo.outs[1].w, mo.outs[1].h) == (1920, 1080))

# moving
m = model(DOCKED)
e, d = m.outs
check("snap left lands left of the other output (skipping overlapping stops)",
      m.snap(d, -1, 0) and d.x == -1920, d.x)
check("layout positions start at 0x0", m.layout_lines()[0] == "eDP-1 2560x1600 --pos 1920x0 --primary", m.layout_lines())
check("layout line for DP-4", m.layout_lines()[1] == "DP-4 1920x1080 --pos 0x0", m.layout_lines())

m = model(DOCKED)
e, d = m.outs
check("snap down aligns bottom edges first", m.snap(d, 0, 1) and d.y == 520, d.y)
check("snap down again goes below", m.snap(d, 0, 1) and d.y == 1600, d.y)
m = model(DOCKED)
check("snap that way with no free spot is refused", not m.snap(m.outs[1], 1, 0))

m = model(DOCKED)
m.nudge(m.outs[1], -1, 0)
check("nudge moves by 10 px", m.outs[1].x == 2550)
check("nudge into the neighbour is flagged as an overlap", m.has_overlap())

# on / off / primary / mode
m = model(DOCKED)
e, d = m.outs
check("turn off the primary hands primary on", m.toggle(e) == "" and not e.on and d.primary)
check("turning off the last active output is refused", m.toggle(d) != "" and d.on)
check("off outputs appear as 'off'", m.layout_lines()[0] == "eDP-1 off", m.layout_lines())
check("an output that is off cannot be primary", m.make_primary(e) != "")
check("turn it on again, placed right of the active ones",
      m.toggle(e) == "" and e.on and e.x == d.x + d.w, (e.x, d.x, d.w))

m = model(DOCKED)
m.set_mode(m.outs[1], "1280x720")
check("set mode updates the size", (m.outs[1].w, m.outs[1].h) == (1280, 720))
m.set_mode(m.outs[1], "auto")
check("auto goes back to the preferred size", (m.outs[1].w, m.outs[1].h) == (1920, 1080), (m.outs[1].w, m.outs[1].h))

m = model(DOCKED)
m.make_primary(m.outs[1])
check("make primary moves the flag", m.outs[1].primary and not m.outs[0].primary)

# saving to the conf
CONF = 'declare -gA LAYOUTS=()\n\n# example\nLAYOUTS["DP-4 eDP-1"]="\neDP-1 auto --primary --pos 0x0\nDP-4 1920x1080 --right-of eDP-1\n"\n'
with tempfile.TemporaryDirectory() as tmp:
    conf = os.path.join(tmp, "layouts.conf")
    with open(conf, "w") as f:
        f.write(CONF)
    tui.save_conf(conf, "DP-4 eDP-1", ["eDP-1 off", "DP-4 1920x1080 --pos 0x0 --primary"])
    text = open(conf).read()
    check("save: the old active entry is replaced", text.count('LAYOUTS["DP-4 eDP-1"]="') == 1 and "--right-of" not in text, text)
    check("save: the new entry is there", "eDP-1 off" in text and tui.SAVED_COMMENT in text)
    check("save: unrelated lines are kept", "# example" in text and "declare -gA" in text)
    tui.save_conf(conf, "DP-4 eDP-1", ["eDP-1 auto --pos 0x0 --primary"])
    text = open(conf).read()
    check("save again: still one entry and one comment", text.count('LAYOUTS["DP-4 eDP-1"]="') == 1 and text.count(tui.SAVED_COMMENT) == 1, text)
    tui.save_conf(conf, "HDMI-1 eDP-1", ["eDP-1 auto --pos 0x0"])
    text = open(conf).read()
    check("save: a different key is appended alongside", text.count('LAYOUTS["') == 2, text)

    # a dry run through monitor_reconcile.sh --layout over stdin
    fixture = os.path.join(tmp, "docked.q")
    with open(fixture, "w") as f:
        f.write(DOCKED)
    os.environ["XRANDR_FIXTURE"] = fixture
    m = model(DOCKED)
    m.snap(m.outs[1], -1, 0)
    rc, err = tui.run_reconcile(["--dry-run", "--layout", "/dev/stdin"], "\n".join(m.layout_lines()) + "\n")
    check("reconcile --layout over stdin succeeds", rc == 0, err)
    check("reconcile --layout plans the new positions",
          "--output eDP-1 --auto" not in err and "eDP-1 --mode 2560x1600 --pos 1920x0 --primary" in err, err)
    off = ["eDP-1 off", "DP-4 1920x1080 --pos 0x0 --primary"]
    rc, err = tui.run_reconcile(["--dry-run", "--layout", "/dev/stdin"], "\n".join(off) + "\n")
    check("reconcile --layout switches the panel off after the external is set",
          rc == 0 and "DP-4 --mode 1920x1080" in err and "eDP-1 --off" in err, err)
    rc, err = tui.run_reconcile(["--dry-run", "--layout", "/nonexistent"], "")
    check("reconcile --layout rejects an unreadable file", rc != 0, err)

print(f"\n{passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
