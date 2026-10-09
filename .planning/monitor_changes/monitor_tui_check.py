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

sys.dont_write_bytecode = True   # importing monitor_tui must not leave __pycache__ in the repo

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

# ------------------------------------------------------------------ overview
print("\nmonitor_tui.py overview")

# the dumps from a live session (tags 3wayR|5 and left|3 with one window, 8 empty)
D_3WAYR = "(split horizontal:0.5:1 (clients horizontal:0) (split vertical:0.5:1 (clients horizontal:0) (clients horizontal:0)))"
D_LEFT = "(clients max:0 0x1e00004)"
D_RESIZED = "(split horizontal:0.3:0 (clients horizontal:0 0x1) (split vertical:0.7:1 (clients horizontal:1 0x2 0x3) (clients horizontal:0)))"
D_OTHER = "(split horizontal:0.5:1 (clients horizontal:0) (split horizontal:0.5:1 (clients horizontal:0) (clients horizontal:0)))"

tree = tui.parse_tree(D_3WAYR)
check("tree: a split of a frame and a stacked split",
      tree.kind == "split" and tree.direction == "horizontal" and tree.children[1].direction == "vertical")
check("tree: clients are counted, ids ignored", tui.parse_tree(D_LEFT).nclients == 1)
check("tree: structure ignores ids, fractions and selection",
      tui.tree_key(tui.parse_tree(D_RESIZED)) == tui.tree_key(tui.parse_tree(D_3WAYR.replace("0.5:1 (clients horizontal:0) (split", "0.5:0 (clients horizontal:0) (split"))))
check("tree: a different split direction is a different structure",
      tui.tree_key(tui.parse_tree(D_OTHER)) != tui.tree_key(tree))
for bad in ("", "(split horizontal:0.5:1 (clients max:0))", "(foo bar:1)", "(clients max:0) x"):
    try:
        tui.parse_tree(bad)
        check(f"tree: rejects {bad!r}", False)
    except ValueError:
        check(f"tree: rejects {bad!r}", True)

art = tui.draw_tree(tree, 36, 9)
check("draw: 9 lines of 36 characters", len(art) == 9 and all(len(l) == 36 for l in art), [len(l) for l in art])
check("draw: matches the approved mock",
      art == ["┏━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━┓",
              "┃ horizontal     ┃ horizontal      ┃",
              "┃                ┃                 ┃",
              "┃                ┃                 ┃",
              "┃                ┣━━━━━━━━━━━━━━━━━┫",
              "┃                ┃ horizontal      ┃",
              "┃                ┃                 ┃",
              "┃                ┃                 ┃",
              "┗━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━┛"], "\n".join(art))

# the checks use this fixed copy of the seeded layouts, never the real file (the TUI edits that one)
SEED_LAYOUTS = "# lname: Max\nmax='(\n    clients max:1\n)'\n\n# lname: Horizontal\nhorizontal='(\n    clients horizontal:0\n)'\n\n# lname: Split\nsplit='(\n    split horizontal:0.5:0\n        (clients vertical:0)\n        (clients vertical:0)\n)'\n\n# lname: 3-way right\nthree_way_r='(\n    split horizontal:0.5:1\n        (clients horizontal:0)\n        (split vertical:0.5:1\n            (clients horizontal:0) (clients horizontal:0)\n        )\n)'\n\n# lname: 3-way left\nthree_way_l='(\n    split horizontal:0.5:1\n        (split vertical:0.5:0\n            (clients horizontal:0) (clients horizontal:0)\n        )\n        (clients horizontal:0)\n)'\n\n# lname: Grid\ngrid='(\n    split horizontal:0.5:1\n        (split vertical:0.5:1\n            (clients horizontal:0) (clients horizontal:0)\n        )\n        (split vertical:0.5:0\n            (clients horizontal:0) (clients horizontal:0)\n        )\n)'\n"
_seed_dir = tempfile.TemporaryDirectory()
SEED_CONF = os.path.join(_seed_dir.name, "hlwm_layouts.conf")
with open(SEED_CONF, "w") as f:
    f.write(SEED_LAYOUTS)
tui.HLWM_LAYOUTS = SEED_CONF
defs = tui.parse_definitions(open(tui.HLWM_LAYOUTS).read())
assigns = tui.parse_assignments(open(tui.HLWM_TAG_LAYOUTS).read())
check("defs: six layouts with their lname", len(defs) == 6 and defs["three_way_r"][0] == "3-way right", list(defs))
check("defs: the value is the layout string", defs["max"][1].split() == ["(", "clients", "max:1", ")"], defs["max"])
check("defs: every value parses", all(tui.parse_tree(s) for _, s in defs.values()))
check("assign: both connected sets are read", set(assigns) == {"eDP-1", "DP-4 eDP-1"}, list(assigns))
check("assign: a tag maps to a variable", assigns["DP-4 eDP-1"]["3wayR|5"] == "three_way_r" and len(assigns["DP-4 eDP-1"]) == 7)
check("assign: tags 8 and 9 have no entry", "8" not in assigns["DP-4 eDP-1"] and "9" not in assigns["DP-4 eDP-1"])

key = "DP-4 eDP-1"
lab = lambda tag, dump, k=key, a=assigns, d=defs: tui.layout_label(tag, dump, k, d, a)
check("label: a matching tree shows the lname", lab("3wayR|5", D_3WAYR) == "3-way right")
check("label: a one-window max frame still matches (selection differs)", lab("left|3", D_LEFT) == "Max")
check("label: a resized split with windows still matches", lab("3wayR|5", D_RESIZED) == "3-way right")
check("label: a different structure is custom", lab("3wayR|5", D_OTHER) == "custom")
check("label: a tag with no entry is unassigned", lab("8", "(clients vertical:0)") == "unassigned")
check("label: a set with no block is unassigned", lab("left|3", D_LEFT, k="HDMI-1 eDP-1") == "unassigned")
check("label: a missing variable is reported", "unknown layout" in lab("left|3", D_LEFT, a={key: {"left|3": "nope"}}))
check("label: a variable with no lname falls back to its name",
      lab("left|3", D_LEFT, d={"max": ("", "(clients max:1)")}) == "max")

m = model(DOCKED)
check("details: numbered, primary starred",
      tui.monitor_details(m) == ["1*  eDP-1   2560x1600  +0+0", "2   DP-4    1920x1080  +2560+0"], tui.monitor_details(m))
diagram = tui.monitor_diagram(m, 92)
check("diagram: scaled 80 px per column, 160 per row (32x10 and 24x7)",
      len(diagram) == 10 and diagram[0] == "┏" + "━" * 30 + "┓┏" + "━" * 22 + "┓", diagram[:1])
check("diagram: numbers inside, * on the primary", diagram[1].startswith("┃ 1*") and "┃ 2 " in diagram[1], diagram[1])

# the whole overview through gather(), with a stub standing in for herbstclient
with tempfile.TemporaryDirectory() as tmp:
    stub = os.path.join(tmp, "hc")
    with open(stub, "w") as f:
        f.write('#!/bin/sh\ncase "$1" in\n get_attr) echo "3wayR|5" ;;\n dump) echo "%s" ;;\n *) exit 1 ;;\nesac\n' % D_3WAYR)
    os.chmod(stub, 0o755)
    fixture = os.path.join(tmp, "docked.q")
    with open(fixture, "w") as f:
        f.write(DOCKED)
    os.environ["XRANDR_FIXTURE"] = fixture
    tui.HC = stub
    data = tui.gather()
    check("gather: tag, label and key from the stubs", (data.tag, data.label, data.key) == ("3wayR|5", "3-way right", "DP-4 eDP-1"), (data.tag, data.label, data.key))

    text = lambda rs: ["".join(t for t, _ in r) for r in rs]
    H, W = 40, 100
    rows, footer = tui.render_overview(data, 0, W, H)
    lines = text(rows)
    check("heights: half each of what the two-row footer leaves (40 -> 19 + 19, 41 -> 19 + 20, 30 -> 14 + 14)",
          (tui.split_height(40), tui.split_height(41), tui.split_height(30)) == ((19, 19), (19, 20), (14, 14)))
    check("overview: two panels filling everything above the footer", len(rows) == 38, len(rows))
    check("overview: every row is exactly the window width", all(len(l) == W for l in lines), {len(l) for l in lines})
    check("overview: each panel has its label in the top left of the border",
          lines[0].startswith("┌─ Layout ─") and lines[19].startswith("┌─ Monitors ─"), (lines[0][:14], lines[19][:14]))
    check("overview: each panel is closed by a bottom border",
          lines[18] == "└" + "─" * 98 + "┘" and lines[37] == "└" + "─" * 98 + "┘")
    role_of = lambda rs, i: {r for t, r in rs[i]}
    check("selection: the first panel's border is selected, the second's is not",
          all(role_of(rows, i) <= {"border_sel", "text", "art"} for i in range(0, 19)) and "border_sel" in role_of(rows, 0)
          and all("border_sel" not in role_of(rows, i) for i in range(19, 38)))
    rows1, _ = tui.render_overview(data, 1, W, H)
    check("selection: moving it swaps which border is green",
          "border_sel" in role_of(rows1, 19) and all("border_sel" not in role_of(rows1, i) for i in range(0, 19)))
    check("selection: the label on the top line is plain, only the lines around it are coloured",
          [(t, r) for t, r in rows[0]][:2] == [("┌─", "border_sel"), (" Layout ", "text")] and rows[0][2][1] == "border_sel"
          and [(t, r) for t, r in rows1[19]][:2] == [("┌─", "border_sel"), (" Monitors ", "text")])
    check("selection: only the border changes, the content stays plain",
          {r for row in rows for t, r in row if t.strip(" ") and t[0] not in "┌│└─┐┘"} <= {"text", "art"})
    check("overview: tag and layout lines", any("Tag      3wayR|5" in l for l in lines) and any("Layout   3-way right" in l for l in lines))
    check("overview: the frame drawing is inside the first panel",
          [l[1 + tui.PAD: 1 + tui.PAD + 36] for l in lines[4 + tui.PAD_V: 13 + tui.PAD_V]] == tui.draw_tree(tui.parse_tree(D_3WAYR), 36, 9))
    check("overview: the monitors and their details are inside the second panel",
          any(l.startswith("│" + " " * tui.PAD + "┏" + "━" * 30 + "┓┏") for l in lines[19:]) and any("1*  eDP-1   2560x1600  +0+0" in l for l in lines[19:]))
    check("overview: footer is a page title and the key hints",
          footer == ("Overview", "↑/↓ select   Enter open   ← back   q quit"), footer)

    for hh, ww in ((20, 100), (14, 70), (8, 56), (60, 160)):
        r, _ = tui.render_overview(data, 0, ww, hh)
        ls = text(r)
        check(f"overview: {ww}x{hh} fills the window exactly", len(ls) == hh - 2 and all(len(l) == ww for l in ls), (len(ls), {len(l) for l in ls}))
    least = tui.footer_width(footer)
    least_h = tui.FOOTER_ROWS + 2 * tui.MIN_PANEL_ROWS
    check("fits: the least that works", tui.fits(least_h, least, footer) and not tui.fits(least_h - 1, 200, footer) and not tui.fits(40, least - 1, footer), least)

    ph, pf = tui.render_placeholder("Monitors", W, H)
    check("placeholder: one selected panel with the screen's name", text(ph)[0].startswith("┌─ Monitors ─") and len(ph) == 38 and "border_sel" in role_of(ph, 0))
    check("placeholder: footer", pf == ("Monitors", "Esc back   q quit"), pf)

    # painting: a fake window records where everything is drawn
    class FakeWin:
        def __init__(self, h, w):
            self.h, self.w, self.writes = h, w, []
        def getmaxyx(self): return self.h, self.w
        def erase(self): self.writes = []
        def refresh(self): pass
        def addstr(self, y, x, s, attr=0): self.writes.append((y, x, s, attr))
    cp = lambda n: n << 8
    tui.curses.color_pair = cp
    tui.ATTR.update(label=cp(1) | tui.curses.A_BOLD, key=tui.curses.A_BOLD, dim=cp(2), border_sel=cp(1), border=0, text=0)
    win = FakeWin(40, 140)
    rows, footer = tui.render_overview(data, 0, 140, 40)
    tui.paint(win, rows, footer)
    w_ = win.writes
    first = next(a for y, x, t, a in w_ if y == 0 and x == 0)
    second = next(a for y, x, t, a in w_ if y == 19 and x == 0)
    check("paint: the selected panel's border is green, the other's is not", first == cp(1) and second == 0, (first, second))
    label_attr = next(a for y, x, t, a in w_ if y == 0 and t == " Layout ")
    check("paint: the label text is drawn plain, not green", label_attr == 0, label_attr)
    check("paint: the panel content is drawn plain",
          all(a == 0 for y, x, t, a in w_ if y < 38 and "Tag " in t))
    check("paint: only the two border colours are used above the rule",
          {a for y, x, t, a in w_ if y < 38} == {0, cp(1)}, {a for y, x, t, a in w_ if y < 38})
    check("paint: a rule across the whole window sits directly above the footer, in bold green",
          [(y, x, len(t), a) for y, x, t, a in w_ if t == "─" * 140] == [(38, 0, 140, cp(1) | tui.curses.A_BOLD)])
    foot = [(y, x, t, a) for y, x, t, a in w_ if y == 39]
    hints = footer[1]
    check("paint: the page title is bold green at column 0 of the last row",
          foot[0] == (39, 0, "Overview", cp(1) | tui.curses.A_BOLD), foot[:1])
    check("paint: nothing joins the title to the hints (no dash)", all(t != " — " for _, _, t, _ in foot))
    check("paint: the hints sit at the right of the row, ending one column short of the edge",
          min(x for _, x, _, a in foot[1:]) == 140 - 1 - len(hints) and max(x + len(t) for _, x, t, _ in foot) == 139,
          (min(x for _, x, _, a in foot[1:]), max(x + len(t) for _, x, t, _ in foot)))
    check("paint: footer keys are bold, descriptions grey",
          [t for _, _, t, a in foot if a == tui.curses.A_BOLD] == ["↑/↓", "Enter", "←", "q"]
          and [t for _, _, t, a in foot if a == cp(2)] == [" select", " open", " back", " quit"])
    small = FakeWin(5, 140)
    tui.paint_too_small(small, 5, 140, footer)
    check("paint: a window too small says what it needs, in a message that fits",
          small.writes[0][2] == f"too small: need {tui.footer_width(footer)}x{tui.FOOTER_ROWS + 2 * tui.MIN_PANEL_ROWS}", small.writes)

    tui.HC = "/nonexistent/herbstclient"
    data = tui.gather()
    check("gather: herbstluftwm unreachable gives a message, monitors still drawn",
          "herbstluftwm" in data.error and len(data.model.outs) == 2, data.error)
    check("overview: shows the message in the layout panel",
          any("herbstluftwm" in l for l in text(tui.render_overview(data, 0, 100, 40)[0])[:19]))

print("\nLayout screen")
import shutil

with tempfile.TemporaryDirectory() as tmp:
    conf = os.path.join(tmp, "layouts.conf")
    shutil.copy(SEED_CONF, conf)
    tui.HLWM_LAYOUTS = conf
    live = {"tree": "(split horizontal:0.5:1 (clients horizontal:0 0x400001) "
                    "(split vertical:0.5:1 (clients horizontal:0) (clients horizontal:0)))", "loaded": []}

    def fake_hc(*a):
        if a[0] == "get_attr":
            return "3wayR"
        if a[0] == "dump":
            return live["tree"]
        if a[0] == "load":
            live["loaded"].append(a[1:])
            return ""
        raise tui.HlwmError("unexpected " + " ".join(a))

    tui.hc = fake_hc

    def keys(scr, *ks):
        for k in ks:
            scr.handle(k, 5)

    def typed(scr, text):
        for c in text:
            scr.handle(c, 5)

    bad_trees = {"empty": "", "unclosed": "(clients max:0", "direction": "(split diagonal:0.5:0 (clients max:0) (clients max:0))",
                 "fraction": "(split horizontal:1.5:0 (clients max:0) (clients max:0))", "algorithm": "(clients wide:0)",
                 "one child": "(split horizontal:0.5:0 (clients max:0))", "trailing": "(clients max:0) x",
                 "selection": "(clients max:x)", "no fraction": "(split horizontal (clients max:0) (clients max:0))"}
    for name, text in bad_trees.items():
        try:
            tui.parse_tree(text, strict=True)
            check(f"strict parse rejects: {name}", False)
        except ValueError:
            check(f"strict parse rejects: {name}", True)
    seeded = tui.parse_definitions(open(conf).read())
    check("strict parse accepts every seeded layout", all(tui.parse_tree(v[1], strict=True) for v in seeded.values()))
    tree = tui.parse_tree("(split horizontal:0.5:1 (clients horizontal:0 0x1) (split vertical:0.3:1 (clients max:0) (clients grid:0)))")
    check("format_tree round-trips and drops window ids",
          tui.tree_key(tui.parse_tree(tui.format_tree(tree), strict=True)) == tui.tree_key(tree) and "0x" not in tui.format_tree(tree))
    check("make_var from an lname", tui.make_var("3-way right", set()) == "layout_3_way_right"
          and tui.make_var("Grid", {"grid"}) == "grid_2" and tui.make_var("!!", set()) == "layout")

    scr = tui.LayoutScreen()
    check("loads six layouts, the tag, and names the live layout", len(scr.defs) == 6 and scr.tag == "3wayR" and scr.name == "3-way right" and not scr.custom)
    keys(scr, "RIGHT", "RIGHT")
    check("right moves one cell", scr.sel == 2)
    keys(scr, "LEFT", "LEFT", "LEFT")
    check("left stops at the first cell", scr.sel == 0)
    keys(scr, "DOWN")
    check("down moves a row", scr.sel == 5)
    keys(scr, "DOWN")
    check("down in the last row stays", scr.sel == 5)
    scr.sel = 1
    keys(scr, "DOWN")
    check("down into a shorter last row lands on its last cell", scr.sel == 6)
    scr.sel = 0
    keys(scr, "e", "d")
    check("e and d do nothing on Create new", scr.mode == "browse")
    scr.sel = 3
    keys(scr, "ENTER")
    check("Enter asks before setting", scr.mode == "confirm" and scr.footer() == ('Set "Split" on tag 3wayR?', "y yes   n no"), scr.footer())
    keys(scr, "x")
    check("other keys do not answer the question", scr.mode == "confirm")
    keys(scr, "n")
    check("n cancels, nothing loaded", scr.mode == "browse" and not live["loaded"])
    keys(scr, "ENTER", "y")
    check("y loads the layout on the focused tag", len(live["loaded"]) == 1 and live["loaded"][0][0] == "3wayR"
          and "split horizontal:0.5:0" in live["loaded"][0][1])
    scr.sel = 1
    keys(scr, "d")
    check("delete says how many tag assignments use it", scr.footer()[0] == 'Delete "Max"? Used by 4 tag assignments.', scr.footer())
    keys(scr, "ESC")
    check("Esc cancels the delete", scr.mode == "browse" and "max='" in open(conf).read())
    keys(scr, "d", "y")
    text = open(conf).read()
    check("y deletes the definition and its lname, and nothing else",
          "max='" not in text and "# lname: Max" not in text and "# lname: Horizontal" in text and len(scr.defs) == 5)
    scr.sel = 1
    keys(scr, "e")
    check("e opens the editor with the lname comment first", scr.mode == "edit" and scr.editor.lines[0] == "# lname: Horizontal")
    keys(scr, "END")
    typed(scr, "ish")
    keys(scr, "CTRL_S")
    text = open(conf).read()
    check("Ctrl-S saves the edit in place", "# lname: Horizontalish\nhorizontal='(" in text and scr.mode == "browse")
    scr.sel = 1
    keys(scr, "e", "DOWN", "HOME")
    typed(scr, "X")
    keys(scr, "CTRL_S")
    check("a bad layout stays open and says why", scr.mode == "edit" and scr.footer()[0] != "Edit", scr.footer())
    keys(scr, "ESC")
    check("Esc discards the edit", scr.mode == "browse" and "X(" not in open(conf).read())
    keys(scr, "e", "DOWN", "HOME")
    typed(scr, "y")
    keys(scr, "CTRL_S")
    check("the variable of an existing layout cannot change", scr.mode == "edit" and "must stay" in scr.footer()[0], scr.footer())
    keys(scr, "ESC")
    scr.sel = 0
    keys(scr, "ENTER")
    check("Create new opens an empty lname", scr.mode == "edit" and scr.editor.lines[0] == "# lname: ")
    keys(scr, "CTRL_S")
    check("an empty lname is refused", scr.mode == "edit" and "empty" in scr.footer()[0])
    typed(scr, "Mine ok")
    keys(scr, "CTRL_S")
    text = open(conf).read()
    check("a new layout is appended, its variable made up from the lname",
          text.endswith("# lname: Mine ok\nmine_ok='(\n    clients vertical:0\n)'\n") and "\n\n\n" not in text and scr.var() == "mine_ok")
    live["tree"] = "(split vertical:0.5:0 (clients max:0) (clients max:0))"
    scr.refresh()
    check("a shape that is not saved reads custom; the footer does not mention s", scr.custom and scr.name == "custom" and "s save" not in scr.footer()[1])
    cur_text = ["".join(t for t, _ in r) for r in scr.render(130, 36)[0]]
    check("the Current panel says how to save it: s, in bold, then what it does",
          any("Not saved as a layout." in l for l in cur_text) and any("s to save it" in l for l in cur_text)
          and any(seg == ("s", "bold") for r in scr.render(130, 36)[0][:12] for seg in r))
    keys(scr, "s")
    check("s opens the editor with the live shape, without window ids",
          scr.mode == "edit" and "split vertical:0.5:0" in scr.editor.text() and "0x" not in scr.editor.text())
    typed(scr, "Stack")
    keys(scr, "CTRL_S")
    check("after saving, the live layout has a name", scr.mode == "browse" and not scr.custom and scr.name == "Stack")
    for w, h in ((90, 20), (110, 40), (200, 60)):
        rows, foot, cur = tui.LayoutScreen().render(w, h)
        check(f"layout screen fills {w}x{h} exactly", len(rows) == h - tui.FOOTER_ROWS and all(sum(len(t) for t, _ in r) == w for r in rows))
    big = tui.LayoutScreen()
    top_rows = big.render(120, 36)[0]
    bar = lambda rows: ["".join(t for t, _ in r)[-4] for r in rows[14:-2]]
    check("a grid taller than the panel has a scroll bar, thumb at the top first", set(bar(top_rows)) == {"█", "░"} and bar(top_rows)[0] == "█" and bar(top_rows)[-1] == "░", bar(top_rows))
    big.sel = len(big.defs)
    check("the thumb moves to the bottom when the last cell is selected", bar(big.render(120, 36)[0])[-1] == "█" and bar(big.render(120, 36)[0])[0] == "░")
    check("no scroll bar when everything fits", set(bar(tui.LayoutScreen().render(120, 80)[0])) <= {" "})
    keys(scr, "e")
    rows, foot, cur = scr.render(90, 20)
    check("the editor puts the cursor inside its panel", cur == (1 + tui.PAD_V, 1 + tui.PAD + len(scr.editor.lines[0])) and foot[1] == "Ctrl-S save   Esc cancel", (cur, foot))
    rows, foot, cur = scr.render(130, 36)
    check("a wide window shows the editor and a Syntax panel side by side, cursor in the editor",
          all(sum(len(t) for t, _ in r) == 130 for r in rows) and "Syntax" in "".join(t for t, _ in rows[0])
          and "(clients ALGO:SEL)" in "".join(t for r in rows for t, _ in r) and cur == (1 + tui.PAD_V, 1 + tui.PAD + len(scr.editor.lines[0])), cur)
    rows, foot, cur = scr.render(90, 30)
    rows, foot, cur = scr.render(130, 36)
    check("every panel border is a border role, whatever the content of its row is",
          all(r[0][1] in ("border", "border_sel") and r[-1][1] in ("border", "border_sel") and r[0][0] in "┌│└" for r in rows if r[0][0] in "┌│└")
          and all(seg[1] in ("border", "border_sel") for r in rows for seg in r if seg[0] and seg[0][0] in "│┌┐└┘" and len(seg[0]) == 1))
    grid_rows = tui.LayoutScreen().render(130, 36)[0]
    check("the same on the grid screen, where rows hold grey drawings",
          all(seg[1] in ("border", "border_sel") for r in grid_rows for seg in r if seg[0] in ("│", "┌", "┐", "└", "┘")))
    rows, foot, cur = scr.render(90, 30)
    check("a narrow window shows the editor alone", "Syntax" not in "".join(t for r in rows for t, _ in r))
    keys(scr, "ESC")
    keys(scr, "ESC")
    check("Esc on the browse screen goes back", scr.handle("ESC", 5) == "back" and scr.handle("q", 5) == "quit")
    check("norm_key names the keys", tui.norm_key("\x1b") == "ESC" and tui.norm_key("\x13") == "CTRL_S"
          and tui.norm_key(tui.curses.KEY_UP) == "UP" and tui.norm_key("é") == "é")


print("\nMonitors screen")
if True:
    applied = []
    RATED = DOCKED.replace("   1280x720     60.00\nHDMI", "   1280x720     60.00\nHDMI").replace(
        "   1920x1080     60.00\n", "   1920x1080     60.00  59.94\n")
    tui.load_model = lambda: model(RATED)
    tui.apply_lines = lambda lines: (applied.append(list(lines)), (0, ""))[1]
    tui.DRY = True                       # keep the edited model instead of re-reading xrandr
    ms = tui.MonitorScreen()
    o1, o2 = ms.model.outs
    check("rates are read per line: 60.00 and 59.94 are separate entries, the current one flagged",
          ("1920x1080", "60.00", True, True) in o2.rates and ("1920x1080", "59.94", False, False) in o2.rates and sum(r[:2] == ("1920x1080", "60.00") for r in o2.rates) == 1 and ("2560x1600", "165.00", True, True) in o1.rates, o2.rates)
    check("the first monitor is selected", ms.name == "eDP-1" and ms.cur() is o1)
    ms.handle("RIGHT")
    check("Right selects the monitor on the right, Left comes back", ms.name == "DP-4")
    ms.handle("LEFT")
    check("Left selects the monitor on the left", ms.name == "eDP-1")
    ms.handle("UP")
    check("Up with nothing above stays put", ms.name == "eDP-1")

    # primary
    ms.handle("RIGHT"); ms.handle("p")
    check("p asks first", ms.mode == "confirm" and ms.footer() == ("Make DP-4 the primary?", "y yes   n no") and not applied, ms.footer())
    ms.handle("n")
    check("n cancels", ms.mode == "browse" and not applied and o1.primary)
    ms.handle("p"); ms.handle("y")
    check("y makes it primary and applies", ms.mode == "browse" and applied and "DP-4 1920x1080 --pos 2560x0 --primary" in applied[-1]
          and "eDP-1 2560x1600 --pos 0x0" in applied[-1], applied[-1:])
    ms.handle("p")
    check("an output that already is primary says so", ms.mode == "browse" and "already" in ms.message)

    # move
    ms.handle("m")
    check("m enters move mode with the position string in the info panel", ms.mode == "move" and "2560x1600+0+0" not in ms.info()[1][2][1][0] and ms.model.geometry(ms.cur()) == "1920x1080+2560+0")
    ms.handle("RIGHT")
    check("an arrow moves 10 px", ms.cur().x == 2570 and ms.model.geometry(ms.cur()) == "1920x1080+2570+0", ms.model.geometry(ms.cur()))
    check("the info panel shows the position as it moves", any("1920x1080+2570+0" in "".join(t for t, _ in line) for line in ms.info()[1]))
    ms.handle("CTRL_RIGHT")
    check("Ctrl moves 1 px", ms.cur().x == 2571)
    ms.handle("SHIFT_RIGHT")
    check("Shift moves 100 px", ms.cur().x == 2671)
    ms.handle("LEFT")
    ms.handle("SHIFT_LEFT")
    check("100 px left lands 1 px clear of the monitor beside it", ms.cur().x == 2561 and ms.message == "", (ms.cur().x, ms.message))
    ms.handle("SHIFT_LEFT")
    check("another 100 px would overlap it, so it stops", ms.cur().x == 2561 and ms.message == "would overlap eDP-1", (ms.cur().x, ms.message))
    ms.handle("CTRL_LEFT")
    check("Ctrl-Left to flush is allowed", ms.cur().x == 2560)
    ms.handle("CTRL_LEFT")
    check("one more pixel would overlap", ms.cur().x == 2560 and "overlap" in ms.message)
    ms.handle("ALT_LEFT")
    check("Alt jumps to the other side of the monitor beside it, keeping its vertical position",
          ms.cur().x == -1920 and ms.cur().y == 0 and ms.model.geometry(ms.cur()) == "1920x1080-1920+0", ms.model.geometry(ms.cur()))
    ms.handle("ALT_RIGHT")
    check("Alt back again", ms.cur().x == 2560 and ms.model.geometry(ms.cur()) == "1920x1080+2560+0")
    ms.handle("ALT_UP")
    check("Alt with nothing that way says so", ms.message == "no monitor that way")
    ms.handle("DOWN"); ms.handle("ESC")
    check("Esc cancels the whole move", ms.mode == "browse" and ms.cur().y == 0 and ms.cur().x == 2560)
    before = len(applied)
    ms.handle("m"); ms.handle("DOWN"); ms.handle("DOWN"); ms.handle("CTRL_S")
    check("Ctrl-S applies the move (positions measured from the top-left)", len(applied) == before + 1 and "DP-4 1920x1080 --pos 2560x20 --primary" in applied[-1], applied[-1])

    # edit the string
    ms.handle("e")
    check("e opens the geometry as herbstluftwm reads it", ms.mode == "edit" and ms.editor.text() == "1920x1080+2560+20", ms.editor.text())
    for _ in range(30): ms.handle("BACKSPACE")
    for ch in "1920x1080+2560+0": ms.handle(ch)
    ms.handle("CTRL_S")
    check("Ctrl-S applies the edited string", ms.mode == "browse" and "DP-4 1920x1080 --pos 2560x0 --primary" in applied[-1], applied[-1])
    ms.handle("e")
    for _ in range(20): ms.handle("BACKSPACE")
    for ch in "nonsense": ms.handle(ch)
    ms.handle("CTRL_S")
    check("a bad string stays in the editor and says what it expects", ms.mode == "edit" and "WxH+X+Y" in ms.message, ms.message)
    for _ in range(20): ms.handle("BACKSPACE")
    for ch in "1920x1080+100+0": ms.handle(ch)
    ms.handle("CTRL_S")
    check("an edit that would overlap is refused", ms.mode == "edit" and "overlap" in ms.message, ms.message)
    ms.handle("ESC")
    check("Esc closes the editor without applying", ms.mode == "browse")
    ms.handle("m"); ms.handle("e")
    check("e works from inside move mode too", ms.mode == "edit" and ms.prev == "move")
    ms.handle("ESC")
    check("Esc from there returns to move mode", ms.mode == "move")
    ms.handle("ESC")

    # resolution overlay
    ms.handle("r")
    names = [r[0] + " " + r[1] for r in ms.res_rows]
    check("r opens a list: Custom first, then each resolution and Hz on its own line, largest first",
          ms.mode == "resolution" and names[0] == "Custom… " and names[1:] == ["1920x1080 60.00", "1920x1080 59.94", "1280x720 60.00"], names)
    check("the current resolution starts selected", ms.res_rows[ms.res_sel][:2] == ("1920x1080", "60.00"))
    ms.handle("DOWN"); ms.handle("ENTER")
    check("Enter on a line sets that resolution and Hz and applies",
          ms.mode == "browse" and "DP-4 1920x1080 --rate 59.94 --pos 2560x0 --primary" in applied[-1], applied[-1])
    ms.handle("r"); ms.handle("HOME"); ms.handle("ENTER")
    check("Enter on Custom opens the values for editing, filled with the current ones", ms.mode == "custom" and ms.editor.text() == "1920x1080 59.94", ms.editor.text())
    for _ in range(20): ms.handle("BACKSPACE")
    for ch in "1600x900 75": ms.handle(ch)
    ms.handle("CTRL_S")
    check("Ctrl-S applies the custom resolution and rate", ms.mode == "browse" and "DP-4 1600x900 --rate 75 --pos 2560x0 --primary" in applied[-1], applied[-1])
    ms.handle("r"); ms.handle("HOME"); ms.handle("ENTER")
    for _ in range(20): ms.handle("BACKSPACE")
    for ch in "wide": ms.handle(ch)
    ms.handle("CTRL_S")
    check("a bad custom value is refused", ms.mode == "custom" and "WxH" in ms.message)
    ms.handle("ESC"); ms.handle("ESC")
    check("Esc backs out of the custom values and then the list", ms.mode == "browse")
    before = len(applied)
    ms.handle("ESC")

    # failures put the model back
    tui.apply_lines = lambda lines: (1, "xrandr: cannot do that")
    ms.handle("m"); ms.handle("DOWN"); ms.handle("CTRL_S")
    check("a failed apply puts the old positions back and says why", ms.message == "xrandr: cannot do that" and ms.mode == "browse", ms.message)
    tui.apply_lines = lambda lines: (applied.append(list(lines)), (0, ""))[1]

    # rendering
    for w, h in ((110, 30), (90, 20), (160, 50)):
        rows, foot, cur = tui.MonitorScreen().render(w, h)
        check(f"monitors screen fills {w}x{h} exactly", len(rows) == h - tui.FOOTER_ROWS and all(sum(len(t) for t, _ in r) == w for r in rows))
    sc = tui.MonitorScreen()
    rows = sc.render(110, 30)[0]
    flat = ["".join(t for t, _ in r) for r in rows]
    panel_end = next(i for i, l in enumerate(flat) if l.startswith("└"))
    drawn = [i for i, l in enumerate(flat[:panel_end]) if any(ch in l for ch in "┏┗┃")]
    cols = [x for i in drawn for x, ch in enumerate(flat[i]) if ch in "┏┓┗┛┃"]
    left, right = min(cols) - 1, 110 - 2 - max(cols)
    check("the monitor group is centred across the panel", abs(left - right) <= 1, (left, right))
    above, below = drawn[0] - 1, panel_end - 1 - drawn[-1]
    check("and down it", abs(above - below) <= 1, (above, below))
    sel_cells = {t for r in rows for t, role in r if role == "border_sel"}
    check("the selected monitor's box is green, the other's is grey drawing", "┏" in "".join(sel_cells) and any(role == "art" for r in rows for t, role in r))
    sc.handle("RIGHT"); sc.handle("r")
    rows, foot, cur = sc.render(110, 30)
    flat = ["".join(t for t, _ in r) for r in rows]
    check("the resolution list is an overlay in the middle of the screen",
          all(len(l) == 110 for l in flat) and any("Resolution" in l for l in flat) and any("Custom…" in l for l in flat) and "1920x1080" in "".join(flat[10:20]))
    sc.handle("ESC"); sc.handle("e")
    rows, foot, cur = sc.render(110, 30)
    check("the editor overlay puts the cursor in its field", cur is not None and rows[cur[0]][0] and foot[1] == "Ctrl-S apply   Esc cancel", cur)

    # a move holds the canvas and the numbering until it is saved
    tui.apply_lines = lambda lines: (applied.append(list(lines)), (0, ""))[1]
    mv = tui.MonitorScreen()
    mv.handle("RIGHT")                                    # DP-4, to the right of eDP-1
    def where(scr):
        rows = scr.render(110, 30)[0]
        flat = ["".join(t for t, _ in r) for r in rows]
        cols = {n: next((l.find(f"┃ {n}") for l in flat if f"┃ {n}" in l), -1) for n in "12"}
        return cols, flat
    start, flat0 = where(mv)
    mv.handle("m")
    where(mv)                                             # the first draw takes the canvas
    mv.handle("UP")
    check("the position string follows a move up past the others (it is not re-based)",
          any("1920x1080+2560-10" in "".join(t for t, _ in line) for line in mv.info()[1]), mv.info()[1])
    for _ in range(8): mv.handle("SHIFT_RIGHT")           # 800 px = 10 columns
    now, flat1 = where(mv)
    check("the others stay where they were on screen while one moves", now["1"] == start["1"], (start, now))
    check("the moved monitor really moves across the panel", now["2"] - start["2"] == 10, (start, now))
    mv.handle("ALT_LEFT")
    now, _ = where(mv)
    check("the moved monitor goes left of the first one without the group re-centring", now["2"] < now["1"] == start["1"], (start, now))
    check("and is still numbered 2 while the move is unsaved", "┃ 2" in "".join(flat1) and now["2"] != -1)
    mv.handle("CTRL_S")
    after, flat2 = where(mv)
    check("saving centres the group again and numbers it by position: the monitor now on the left is 1",
          after["1"] < after["2"] and "1" in after, after)
    left = min(l.find("┏") for l in flat2 if "┏" in l)
    right = 110 - 2 - max(l.rfind("┓") for l in flat2 if "┓" in l)
    check("centred after saving", abs(left - 1 - right) <= 1, (left, right))

    # a long list scrolls with a bar
    many = tui.Output("X"); many.mode = "1920x1080"; many.w, many.h = 1920, 1080; many.x = many.y = 0
    many.rates = [(f"{1000 + i}x{600 + i}", "60.00", False, False) for i in range(60)]
    sc2 = tui.MonitorScreen(); sc2.model = tui.Model([many]); sc2.name = "X"
    sc2.handle("r")
    for _ in range(30): sc2.handle("DOWN")
    rows, foot, cur = sc2.render(110, 30)
    flat = ["".join(t for t, _ in r) for r in rows]
    check("a long list scrolls to keep the selection in view and shows a scroll bar",
          sc2.res_top > 0 and any("█" in l for l in flat) and any("░" in l for l in flat) and sum("›" in l for l in flat) == 1)

    # keys: urxvt and xterm sequences
    seq = lambda *items: iter(items).__next__
    def feed(*items):
        it = iter(items)
        return lambda: next(it, None)
    check("a lone Esc is Esc", tui.decode_escape(feed()) == "ESC")
    check("urxvt Shift+Up is ESC [ a", tui.decode_escape(feed("[", "a")) == "SHIFT_UP")
    check("urxvt Ctrl+Left is ESC O d", tui.decode_escape(feed("O", "d")) == "CTRL_LEFT")
    check("urxvt Alt+Right: ESC then a key curses already knows", tui.decode_escape(feed(tui.curses.KEY_RIGHT)) == "ALT_RIGHT")
    check("urxvt Alt+Down as ESC ESC [ B", tui.decode_escape(feed("\x1b", "[", "B")) == "ALT_DOWN")
    check("xterm Ctrl+Up is ESC [ 1 ; 5 A", tui.decode_escape(feed("[", "1", ";", "5", "A")) == "CTRL_UP")
    check("xterm Shift+Down is ESC [ 1 ; 2 B", tui.decode_escape(feed("[", "1", ";", "2", "B")) == "SHIFT_DOWN")
    check("xterm Alt+Left is ESC [ 1 ; 3 D", tui.decode_escape(feed("[", "1", ";", "3", "D")) == "ALT_LEFT")
    check("anything else after Esc is just Esc", tui.decode_escape(feed("x")) == "ESC" and tui.decode_escape(feed("[", "Z")) == "ESC")
    check("curses' own shifted keys are named", tui.norm_key(tui.curses.KEY_SLEFT) == "SHIFT_LEFT" and tui.norm_key(tui.curses.KEY_SR) == "SHIFT_UP")
    check("layout_lines carries a chosen rate only for that output",
          "--rate" not in "".join(model(DOCKED).layout_lines()))

print(f"\n{passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
