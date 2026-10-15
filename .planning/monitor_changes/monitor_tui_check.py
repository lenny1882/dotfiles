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
import time

sys.dont_write_bytecode = True

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

m = model(DOCKED)
e, d = m.outs
check("move_to moves an output where there is room", m.move_to(d, -1920, 0) == "" and d.x == -1920, d.x)
check("layout positions start at 0x0", m.layout_lines()[0] == "eDP-1 2560x1600 --pos 1920x0 --primary", m.layout_lines())
WIDE = """eDP-1 connected 2560x1600+0+0 (normal left inverted right x axis y axis) 340mm x 210mm
   2560x1600    165.00*+
DP-2 connected primary 5120x1440+2560+0 (normal left inverted right x axis y axis) 1200mm x 340mm
   5120x1440     60.00*+
"""
SPLIT_LIST = """Monitors: 3
 0: +*DP-2~1 1280/300x1440/340+2560+0  DP-2
 1: +DP-2~2 2560/600x1440/340+3840+0  none
 2: +DP-2~3 1280/300x1440/340+6400+0  none
"""
ws = model(WIDE)
tui.attach_splits(ws.outs, SPLIT_LIST)
check("virtual monitors are read back relative to their output",
      ws.outs[1].splits == ["1280x1440+0+0", "2560x1440+1280+0", "1280x1440+3840+0"], ws.outs[1].splits)
check("an output without virtual monitors has no splits", ws.outs[0].splits == [])
check("layout lines carry --split",
      ws.layout_lines()[1] == "DP-2 5120x1440 --pos 2560x0 --primary --split 1280x1440+0+0 2560x1440+1280+0 1280x1440+3840+0",
      ws.layout_lines())
check("layout lines are unchanged without splits", "--split" not in "".join(model(WIDE).layout_lines()))

wn = model(DOCKED)
wn.outs[1].label = "desk"
check("key is the sorted monitor names", wn.key() == "desk eDP-1", wn.key())
check("layout_lines writes ports by default", wn.layout_lines()[1].startswith("DP-4 "), wn.layout_lines())
check("layout_lines(names=True) writes monitor names", wn.layout_lines(names=True)[1] == "desk 1920x1080 --pos 2560x0" and wn.layout_lines(names=True)[0].startswith("eDP-1 "), wn.layout_lines(names=True))
check("layout line for DP-4", m.layout_lines()[1] == "DP-4 1920x1080 --pos 0x0", m.layout_lines())
e.rate = "165.00"
check("a chosen rate is written for that output only", m.layout_lines()[0] == "eDP-1 2560x1600 --rate 165.00 --pos 1920x0 --primary" and "--rate" not in m.layout_lines()[1], m.layout_lines())

m = model(DOCKED)
e, d = m.outs
e.mode = "off"
check("off outputs appear as 'off'", m.layout_lines()[0] == "eDP-1 off", m.layout_lines())
check("an output that is off cannot be primary", m.make_primary(e) != "")

m = model(DOCKED)
m.set_mode(m.outs[1], "1280x720")
check("set mode updates the size", (m.outs[1].w, m.outs[1].h) == (1280, 720))
m.set_mode(m.outs[1], "auto")
check("auto goes back to the preferred size", (m.outs[1].w, m.outs[1].h) == (1920, 1080), (m.outs[1].w, m.outs[1].h))

m = model(DOCKED)
m.make_primary(m.outs[1])
check("make primary moves the flag", m.outs[1].primary and not m.outs[0].primary)

with tempfile.TemporaryDirectory() as tmp:
    fixture = os.path.join(tmp, "docked.q")
    with open(fixture, "w") as f:
        f.write(DOCKED)
    os.environ["XRANDR_FIXTURE"] = fixture
    m = model(DOCKED)
    m.move_to(m.outs[1], -1920, 0)
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

# the checks use fixed copies of the seeded layouts and tag assignments, never the real files (the TUI edits that one)
SEED_LAYOUTS = "# lname: Max\nmax='(\n    clients max:1\n)'\n\n# lname: Horizontal\nhorizontal='(\n    clients horizontal:0\n)'\n\n# lname: Split\nsplit='(\n    split horizontal:0.5:0\n        (clients vertical:0)\n        (clients vertical:0)\n)'\n\n# lname: 3-way right\nthree_way_r='(\n    split horizontal:0.5:1\n        (clients horizontal:0)\n        (split vertical:0.5:1\n            (clients horizontal:0) (clients horizontal:0)\n        )\n)'\n\n# lname: 3-way left\nthree_way_l='(\n    split horizontal:0.5:1\n        (split vertical:0.5:0\n            (clients horizontal:0) (clients horizontal:0)\n        )\n        (clients horizontal:0)\n)'\n\n# lname: Grid\ngrid='(\n    split horizontal:0.5:1\n        (split vertical:0.5:1\n            (clients horizontal:0) (clients horizontal:0)\n        )\n        (split vertical:0.5:0\n            (clients horizontal:0) (clients horizontal:0)\n        )\n)'\n"
_seed_dir = tempfile.TemporaryDirectory()
SEED_CONF = os.path.join(_seed_dir.name, "hlwm_layouts.conf")
with open(SEED_CONF, "w") as f:
    f.write(SEED_LAYOUTS)
SEED_TAGS = 'declare -gA TAG_LAYOUTS=()\n\nTAG_LAYOUTS["eDP-1"]="\nleft|3   max\nmiddle|1 horizontal\nright|2  max\nsplit|4  split\n3wayR|5  three_way_r\n3wayL|6  three_way_l\ngrid|7   grid\n"\n\nTAG_LAYOUTS["DP-4 eDP-1"]="\nleft|3   max\nmiddle|1 horizontal\nright|2  max\nsplit|4  split\n3wayR|5  three_way_r\n3wayL|6  three_way_l\ngrid|7   grid\n"\n'
SEED_TAGS_CONF = os.path.join(_seed_dir.name, "hlwm_tag_layouts.conf")
with open(SEED_TAGS_CONF, "w") as f:
    f.write(SEED_TAGS)
tui.HLWM_TAG_LAYOUTS = SEED_TAGS_CONF
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
    box = "└" + "─" * 57 + "┘"; tbox = "└" + "─" * 38 + "┘"
    check("overview: each left panel is closed by a bottom border", lines[18][:59] == box and lines[37][:59] == box)
    def roles_in(rs, i, lo, hi):
        out, x = set(), 0
        for t, r in rs[i]:
            if x >= lo and x + len(t) <= hi:
                out.add(r)
            x += len(t)
        return out
    role_of = lambda rs, i: roles_in(rs, i, 0, 59)
    tag_role = lambda rs, i: roles_in(rs, i, 60, 100)
    check("selection: the first panel's border is selected, the second's and the tags' are not",
          all(role_of(rows, i) <= {"border_sel", "text", "art"} for i in range(0, 19)) and "border_sel" in role_of(rows, 0)
          and all("border_sel" not in role_of(rows, i) for i in range(19, 38))
          and all("border_sel" not in tag_role(rows, i) for i in range(0, 38)))
    rows1, _ = tui.render_overview(data, 1, W, H)
    check("selection: moving it swaps which border is green",
          "border_sel" in role_of(rows1, 19) and all("border_sel" not in role_of(rows1, i) for i in range(0, 19)))
    rows2, _ = tui.render_overview(data, 2, W, H)
    check("selection: the tags panel can be selected, and then neither left panel is",
          "border_sel" in tag_role(rows2, 0) and all("border_sel" not in role_of(rows2, i) for i in range(0, 38)))
    check("selection: the label on the top line is plain, only the lines around it are coloured",
          [(t, r) for t, r in rows[0]][:2] == [("┌─", "border_sel"), (" Layout ", "text")] and rows[0][2][1] == "border_sel"
          and [(t, r) for t, r in rows1[19]][:2] == [("┌─", "border_sel"), (" Monitors ", "text")])
    check("selection: only the border changes, the content stays plain",
          {r for row in rows for t, r in row if t.strip(" ") and t[0] not in "┌│└─┐┘"} <= {"text", "art", "green", "name", "italic"})
    check("overview: tag and layout lines", any("Tag      3wayR|5" in l for l in lines) and any("Layout   3-way right" in l for l in lines))
    check("overview: the frame drawing is inside the first panel",
          [l[1 + tui.PAD: 1 + tui.PAD + 36] for l in lines[4 + tui.PAD_V: 13 + tui.PAD_V]] == tui.draw_tree(tui.parse_tree(D_3WAYR), 36, 9))
    check("overview: the monitors and their details are inside the second panel",
          any(l.startswith("│" + " " * tui.PAD + "┏") and "┓┏" in l[:59] for l in lines[19:]) and any("1*  eDP-1   2560x1600  +0+0" in l[:59] for l in lines[19:]))
    check("overview: footer is a page title and the key hints",
          footer == ("Overview", "↑/↓ select   ←/→ column   Enter open   q quit"), footer)

    check("columns: one blank column separates the left panels from the tags panel",
          all(l[59] == " " for l in lines) and lines[0][60] == "┌" and lines[0][58] == "┐")
    check("columns: the tags panel is 40% of the width, a one-column gap, the left column the rest",
          [text(tui.render_overview(data, 0, w_, 40)[0])[0].index("┐") + 1 for w_ in (100, 101, 140)] == [59, 60, 83])
    check("tags: the panel is called Tags and runs the full height above the footer",
          lines[0][60:].startswith("┌─ Tags ─") and lines[37][60:] == tbox)
    tl = [l[61:99].split() for l in lines]
    check("tags: one row per tag with its key, name and layout name",
          tl[2][:3] == ["1", "left|3", "Max"] and tl[3] == [] and tl[4][:3] == ["2", "middle|1", "Horizontal"], tl[2:5])
    check("tags: tags 8 and 9 are padded as unassigned", ["8", "8", "unassigned"] in tl and ["9", "9", "unassigned"] in tl)
    TB = tui.parse_tag_blocks('TAG_LAYOUTS["S"]="\nleft|3   max  {3}  [spotify:00 rambox:01]\nmy tag grid\n"\n')
    check("tags: blocks parse in file order with the key and programs",
          TB == {"S": [("left|3", "max", "3", [("spotify", "00"), ("rambox", "01")]), ("my tag", "grid", "", [])]}, TB)
    TR = tui.tag_rows("S", TB, {"max": ("Max", ""), "grid": ("", "")})
    check("tags: rows take the key from {n} else the position, the lname else the variable, and pad to nine",
          len(TR) == 9 and TR[0] == ("3", "left|3", "Max", [("spotify", "00"), ("rambox", "01")]) and TR[1] == ("2", "my tag", "grid", [])
          and TR[2] == ("3", "3", "unassigned", []) and TR[8][1] == "9", TR)
    check("tags: a set with no block is nine unassigned tags named 1-9",
          [r[1:3] for r in tui.tag_rows("X", TB, {})] == [(str(n), "unassigned") for n in range(1, 10)])
    check("tags: an unknown layout variable is reported", tui.tag_rows("S", TB, {})[0][2] == "unknown layout 'max'")
    d2 = tui.Overview()
    d2.tags = [("1", "primary|1", "Split - Max", [("md.obsidian.obsidian", "11")]), ("2", "a", "A very long layout name indeed", [])]
    joined = lambda cs: ["".join(t for t, _ in l) for l in cs]
    c = joined(tui.tags_content(d2, 24, 20))
    check("tags: programs sit indented under their tag with the index after them",
          joined(tui.tags_content(d2, 40, 20))[1] == "     md.obsidian.obsidian  11", joined(tui.tags_content(d2, 40, 20)))
    check("tags: every line is cut to the width with an ellipsis, never longer",
          all(len(l) <= 24 for l in c) and c[1].endswith("…") and c[3].endswith("…"), c)
    check("tags: too many lines are cut with a final ellipsis",
          joined(tui.tags_content(d2, 40, 2)) == ["1  primary|1  Split - Max", "…"], joined(tui.tags_content(d2, 40, 2)))
    row = tui.tags_content(d2, 60, 20)
    check("tags: the program lines use the footer's description colour",
          tui.tags_content(d2, 40, 20)[1][0][1] == "dim")
    check("tags: the key is green, the tag name bold, the layout name plain",
          row[0][0] == ("1", "green") and row[0][2] == ("primary|1", "name") and row[0][-1] == ("Split - Max", "text"), row[0])
    d2.tags[1] = ("2", "a", "unassigned", [])
    check("tags: custom and unassigned layout names are italic",
          tui.tags_content(d2, 60, 20)[3][-1] == ("unassigned", "italic") and tui.tags_content(d2, 60, 20)[0][-1][1] == "text")
    check("overview: every row fills the window at odd and even widths",
          all(all(len(l) == ww for l in text(tui.render_overview(data, 0, ww, 30)[0])) for ww in (66, 67, 80, 101, 140)))

    for hh, ww in ((20, 100), (14, 70), (8, 56), (60, 160)):
        r, _ = tui.render_overview(data, 0, ww, hh)
        ls = text(r)
        check(f"overview: {ww}x{hh} fills the window exactly", len(ls) == hh - 2 and all(len(l) == ww for l in ls), (len(ls), {len(l) for l in ls}))
    least = tui.footer_width(footer)
    least_h = tui.FOOTER_ROWS + 2 * tui.MIN_PANEL_ROWS
    check("fits: the least that works", tui.fits(least_h, least, footer) and not tui.fits(least_h - 1, 200, footer) and not tui.fits(40, least - 1, footer), least)

    class FakeWin:
        def __init__(self, h, w):
            self.h, self.w, self.writes = h, w, []
        def getmaxyx(self): return self.h, self.w
        def erase(self): self.writes = []
        def refresh(self): pass
        def addstr(self, y, x, s, attr=0): self.writes.append((y, x, s, attr))
    cp = lambda n: n << 8
    tui.curses.color_pair = cp
    tui.ATTR.update(label=cp(1) | tui.curses.A_BOLD, key=tui.curses.A_BOLD, dim=cp(2), border_sel=cp(1), border=0, text=0,
                   green=cp(1), hilite=cp(4), name=tui.curses.A_BOLD, italic=tui.curses.A_ITALIC)
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
    check("paint: above the rule only green, bold and italic are used besides plain",
          {a for y, x, t, a in w_ if y < 38} == {0, cp(1), tui.curses.A_BOLD, tui.curses.A_ITALIC}, {a for y, x, t, a in w_ if y < 38})
    tag_first = next((t, a) for y, x, t, a in w_ if y == 2 and x >= 84 and t == "1")
    tag_name = next((t, a) for y, x, t, a in w_ if y == 2 and x >= 84 and t == "left|3")
    check("paint: a tag's key is drawn green and its name bold",
          tag_first == ("1", cp(1)) and tag_name[1] == tui.curses.A_BOLD, (tag_first, tag_name))
    check("paint: an unassigned layout name is drawn italic",
          any(t == "unassigned" and a == tui.curses.A_ITALIC for y, x, t, a in w_))
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
          [t for _, _, t, a in foot if a == tui.curses.A_BOLD] == ["↑/↓", "←/→", "Enter", "q"]
          and [t for _, _, t, a in foot if a == cp(2)] == [" select", " column", " open", " quit"])
    import copy
    dp = copy.copy(data)
    dp.tags = [("1", "t", "Max", [("spotify", "0")])] + data.tags[1:]
    wp = FakeWin(40, 140)
    rp, fp = tui.render_overview(dp, 0, 140, 40)
    tui.paint(wp, rp, fp)
    check("paint: the autostart program lines are drawn in the footer description grey",
          [a for y, x, t, a in wp.writes if "spotify" in t] == [cp(2)], [(t, a) for y, x, t, a in wp.writes if "spotify" in t])
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

    ms.handle("RIGHT"); ms.handle("p")
    check("p asks first", ms.mode == "confirm" and ms.footer() == ("Make DP-4 the primary?", "y yes   n no") and not applied, ms.footer())
    ms.handle("n")
    check("n cancels", ms.mode == "browse" and not applied and o1.primary)
    ms.handle("p"); ms.handle("y")
    check("y makes it primary and applies", ms.mode == "keep" and applied and "DP-4 1920x1080 --pos 2560x0 --primary" in applied[-1]
          and "eDP-1 2560x1600 --pos 0x0" in applied[-1], applied[-1:])
    ms.handle("y")
    ms.handle("p")
    check("an output that already is primary says so", ms.mode == "browse" and "already" in ms.message)

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
    ms.handle("y")

    ms.handle("e")
    check("e opens the geometry as herbstluftwm reads it", ms.mode == "edit" and ms.editor.text() == "1920x1080+2560+20", ms.editor.text())
    for _ in range(30): ms.handle("BACKSPACE")
    for ch in "1920x1080+2560+0": ms.handle(ch)
    ms.handle("CTRL_S")
    check("Ctrl-S applies the edited string", ms.mode == "keep" and "DP-4 1920x1080 --pos 2560x0 --primary" in applied[-1], applied[-1])
    ms.handle("y")
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

    ms.handle("r")
    names = [r[0] + " " + r[1] for r in ms.res_rows]
    check("r opens a list: Custom first, then each resolution and Hz on its own line, largest first",
          ms.mode == "resolution" and names[0] == "Custom… " and names[1:] == ["1920x1080 60.00", "1920x1080 59.94", "1280x720 60.00"], names)
    check("the current resolution starts selected", ms.res_rows[ms.res_sel][:2] == ("1920x1080", "60.00"))
    ms.handle("DOWN"); ms.handle("ENTER")
    check("Enter on a line sets that resolution and Hz and applies",
          ms.mode == "keep" and "DP-4 1920x1080 --rate 59.94 --pos 2560x0 --primary" in applied[-1], applied[-1])
    ms.handle("y")
    ms.handle("r"); ms.handle("HOME"); ms.handle("ENTER")
    check("Enter on Custom opens the values for editing, filled with the current ones", ms.mode == "custom" and ms.editor.text() == "1920x1080 59.94", ms.editor.text())
    for _ in range(20): ms.handle("BACKSPACE")
    for ch in "1600x900 75": ms.handle(ch)
    ms.handle("CTRL_S")
    check("Ctrl-S applies the custom resolution and rate", ms.mode == "keep" and "DP-4 1600x900 --rate 75 --pos 2560x0 --primary" in applied[-1], applied[-1])
    ms.handle("y")
    ms.handle("r"); ms.handle("HOME"); ms.handle("ENTER")
    for _ in range(20): ms.handle("BACKSPACE")
    for ch in "wide": ms.handle(ch)
    ms.handle("CTRL_S")
    check("a bad custom value is refused", ms.mode == "custom" and "WxH" in ms.message)
    ms.handle("ESC"); ms.handle("ESC")
    check("Esc backs out of the custom values and then the list", ms.mode == "browse")
    before = len(applied)
    ms.handle("ESC")

    before_lines = ms.model.layout_lines()
    ms.handle("m"); ms.handle("DOWN"); ms.handle("CTRL_S")
    check("an apply waits for a yes, showing the seconds left",
          ms.mode == "keep" and ms.footer() == ("Keep these settings? Reverting in 15s", "y keep   n revert"), ms.footer())
    ms.handle("UP"); ms.handle("q")
    check("other keys do nothing while it waits", ms.mode == "keep")
    n = len(applied)
    ms.handle("n")
    check("n puts the old positions back", ms.mode == "browse" and ms.message == "reverted" and len(applied) == n + 1
          and applied[-1] == before_lines, (applied[-1], before_lines))
    ms.handle("m"); ms.handle("DOWN"); ms.handle("CTRL_S")
    real_clock = time.monotonic
    time.monotonic = lambda: real_clock() + tui.KEEP_SECONDS + 1
    n = len(applied)
    ms.tick()
    check("with no answer for 15 s it reverts by itself", ms.mode == "browse" and ms.message == "reverted" and len(applied) == n + 1, ms.message)
    time.monotonic = real_clock
    ms.handle("m"); ms.handle("DOWN"); ms.handle("CTRL_S"); ms.tick()
    check("tick before the time is up changes nothing", ms.mode == "keep")
    ms.handle("ENTER")
    check("Enter keeps it", ms.mode == "browse" and ms.message == "applied")

    tui.apply_lines = lambda lines: (1, "xrandr: cannot do that")
    ms.handle("m"); ms.handle("DOWN"); ms.handle("CTRL_S")
    check("a failed apply puts the old positions back and says why", ms.message == "xrandr: cannot do that" and ms.mode == "browse", ms.message)
    tui.apply_lines = lambda lines: (applied.append(list(lines)), (0, ""))[1]

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
    mv.handle("CTRL_S"); mv.handle("y")
    after, flat2 = where(mv)
    check("saving centres the group again and numbers it by position: the monitor now on the left is 1",
          after["1"] < after["2"] and "1" in after, after)
    left = min(l.find("┏") for l in flat2 if "┏" in l)
    right = 110 - 2 - max(l.rfind("┓") for l in flat2 if "┓" in l)
    check("centred after saving", abs(left - 1 - right) <= 1, (left, right))

    tui.DRY = False
    fresh = []
    tui.load_model = lambda: (fresh.append(1), model(RATED))[1]
    tui.apply_lines = lambda lines: (1, "monitor_reconcile: xrandr failed")
    fl = tui.MonitorScreen(); fresh.clear()
    fl.handle("RIGHT"); fl.handle("m"); fl.handle("CTRL_S")
    check("after a failed apply the model is read from xrandr again", fresh == [1] and fl.message == "monitor_reconcile: xrandr failed", (fresh, fl.message))
    tui.DRY = True
    tui.load_model = lambda: model(RATED)
    tui.apply_lines = lambda lines: (applied.append(list(lines)), (0, ""))[1]

    ed = tui.MonitorScreen(); ed.handle("RIGHT"); ed.handle("m"); ed.render(110, 30)
    for _ in range(8): ed.handle("SHIFT_RIGHT")
    before_edit = ["".join(t for t, _ in r) for r in ed.render(110, 30)[0]][:20]
    ed.handle("e")
    under = ["".join(t for t, _ in r) for r in ed.render(110, 30)[0]][:3]
    check("opening the editor from a move does not re-centre the picture", under == before_edit[:3] and ed.frame is not None, under)
    check("the Layout footer's minimum width comes from the hints it really shows",
          tui.layout_min_width() == tui.footer_width(("Layout", tui.layout_hints(False))) and "s save" not in tui.layout_hints(False))

    many = tui.Output("X"); many.mode = "1920x1080"; many.w, many.h = 1920, 1080; many.x = many.y = 0
    many.rates = [(f"{1000 + i}x{600 + i}", "60.00", False, False) for i in range(60)]
    sc2 = tui.MonitorScreen(); sc2.model = tui.Model([many]); sc2.name = "X"
    sc2.handle("r")
    for _ in range(30): sc2.handle("DOWN")
    rows, foot, cur = sc2.render(110, 30)
    flat = ["".join(t for t, _ in r) for r in rows]
    check("a long list scrolls to keep the selection in view and shows a scroll bar",
          sc2.res_top > 0 and any("█" in l for l in flat) and any("░" in l for l in flat) and sum("›" in l for l in flat) == 1)

    # persist (Alt-S)
    TAGS = 'declare -gA TAG_LAYOUTS=()\n\nTAG_LAYOUTS["eDP-1"]="\nleft|3   max\nright|2  max\n"\n'
    t = tui.put_assignment(TAGS, "eDP-1", "left|3", "grid")
    check("an assignment replaces the layout of an existing tag line and keeps its padding", "left|3   grid" in t and "right|2  max" in t and t.count("left|3") == 1, t)
    t = tui.put_assignment(TAGS, "eDP-1", "grid", "grid")
    check("a tag without a line gets one at the end of the block", t.split("\n")[-3:] == ["grid grid", '"', ""] or "\ngrid grid\n\"" in t, t)
    t = tui.put_assignment(TAGS, "DP-4 eDP-1", "left|3", "max")
    check("a set without a block gets a new one", t.rstrip().endswith('TAG_LAYOUTS["DP-4 eDP-1"]="\nleft|3 max\n"') and 'TAG_LAYOUTS["eDP-1"]' in t, t)
    try:
        tui.put_assignment('TAG_LAYOUTS["eDP-1"]="\nleft|3 max\n', "eDP-1", "left|3", "grid")
        check("a block that never closes is refused", False)
    except ValueError:
        check("a block that never closes is refused", True)
    PT = 'declare -gA TAG_LAYOUTS=()\n\nTAG_LAYOUTS["eDP-1"]="\nleft|3   max  {3}  [spotify:00 rambox:01]\nmy tag  grid {2}\nplain  grid []\nright|2  max\n"\n'
    pa = tui.parse_assignments(PT)["eDP-1"]
    check("assign: the program list is not read as the layout", pa == {"left|3": "max", "my tag": "grid", "plain": "grid", "right|2": "max"}, pa)
    t = tui.put_assignment(PT, "eDP-1", "left|3", "grid")
    check("an assignment keeps the key and program list on the tag line", "left|3   grid  {3}  [spotify:00 rambox:01]" in t, t)
    MON = '# note\nLAYOUTS["DP-4 eDP-1"]="\neDP-1 auto --primary --pos 0x0\nDP-4 1920x1080 --right-of eDP-1\n"\n# LAYOUTS["DP-4 eDP-1"]="\n# x\n# "\n'
    t = tui.put_monitor_layout(MON, "DP-4 eDP-1", ["eDP-1 2560x1600 --pos 0x0 --primary", "DP-4 1920x1080 --pos 2560x0"])
    check("the monitor entry is replaced in place; comments and commented examples stay",
          t.startswith("# note\nLAYOUTS") and "--right-of" not in t and "DP-4 1920x1080 --pos 2560x0" in t and t.count('LAYOUTS["DP-4 eDP-1"]="') == 2 and t.endswith('# "\n'), t)
    t = tui.put_monitor_layout(MON, "HDMI-1 eDP-1", ["eDP-1 auto --pos 0x0"])
    check("a new set is appended", t.rstrip().endswith('LAYOUTS["HDMI-1 eDP-1"]="\neDP-1 auto --pos 0x0\n"') and "--right-of eDP-1" in t)

    with tempfile.TemporaryDirectory() as tmp:
        tags = os.path.join(tmp, "tags.conf"); mons = os.path.join(tmp, "mons.conf")
        open(tags, "w").write(TAGS); open(mons, "w").write(MON)
        tui.HLWM_TAG_LAYOUTS, tui.LAYOUTS_CONF, tui.HLWM_LAYOUTS = tags, mons, SEED_CONF
        tui.load_model = lambda: model(RATED)
        live["tree"] = "(split horizontal:0.5:1 (clients horizontal:0 0x1) (split vertical:0.5:1 (clients horizontal:0) (clients horizontal:0)))"
        ls = tui.LayoutScreen()
        ls.handle("ALT_s", 5)
        check("Alt-S on a saved layout asks first, naming the tag and the monitor set",
              ls.mode == "confirm" and ls.footer()[0] == f'Use "{ls.title(ls.var_now)}" for tag 3wayR with DP-4 eDP-1?', ls.footer())
        ls.handle("n", 5)
        check("n leaves the file alone", open(tags).read() == TAGS and ls.mode == "browse")
        ls.handle("ALT_s", 5); ls.handle("y", 5)
        check("y writes the tag's layout under the connected set", 'TAG_LAYOUTS["DP-4 eDP-1"]="\n3wayR ' in open(tags).read() and ls.message == "saved", open(tags).read())
        live["tree"] = "(split vertical:0.5:0 (clients max:0) (clients max:0) )"
        ls.refresh(); ls.handle("ALT_s", 5)
        check("Alt-S on a custom layout opens the save editor", ls.mode == "edit" and ls.edit_var is None and "split vertical" in ls.editor.text())
        check("the Layout footer lists Alt-S", "Alt-S persist" in tui.layout_hints(False) and "Alt-S persist" in tui.layout_hints(True))

        ms2 = tui.MonitorScreen()
        ms2.handle("ALT_s")
        check("Alt-S on the Monitors screen asks first", ms2.mode == "confirm" and ms2.footer()[0] == "Save these positions for DP-4 eDP-1?", ms2.footer())
        ms2.handle("n")
        check("n leaves monitor_layouts.conf alone", open(mons).read() == MON)
        ms2.handle("ALT_s"); ms2.handle("y")
        text = open(mons).read()
        check("y replaces the set's entry with the current layout", "eDP-1 2560x1600 --pos 0x0 --primary" in text and "DP-4 1920x1080 --pos 2560x0" in text and "--right-of" not in text and ms2.message == "saved", text)
        check("the Monitors footer lists Alt-S", "Alt-S persist" in tui.BROWSE_HINTS)

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
    check("Alt plus a letter is ALT_letter", tui.decode_escape(feed("s")) == "ALT_s" and tui.decode_escape(feed("S")) == "ALT_S")
    check("anything else after Esc is just Esc", tui.decode_escape(feed("[", "Z")) == "ESC" and tui.decode_escape(feed("5")) == "ESC")
    check("curses' own shifted keys are named", tui.norm_key(tui.curses.KEY_SLEFT) == "SHIFT_LEFT" and tui.norm_key(tui.curses.KEY_SR) == "SHIFT_UP")
    check("layout_lines carries a chosen rate only for that output",
          "--rate" not in "".join(model(DOCKED).layout_lines()))

print("\nTags screen")

TAGS3 = ('declare -gA TAG_LAYOUTS=()\n\nTAG_LAYOUTS["DP-4 eDP-1"]="\nleft|3   max         {3}  [spotify:0 rambox:0]\n'
         'middle|1 horizontal  {1}\nright|2  max         {2}  [vivaldi-stable:1]\nsplit    split\n"\n\nTAG_LAYOUTS["eDP-1"]="\nonly max\n"\n')
RULES3 = ('hc rule --focus=on\n\n# autostart rules\nhc rule once --instance=vivaldi-stable --tag="x"\nhc rule once --instance=spotify --tag="x"\n'
          'hc rule --instance=rambox --tag="x" --label=r\n# note\n\n# floating\nhc rule --instance=pavucontrol --floating=on\n')
check("rules: the instances come from the autostart block only, in file order",
      tui.parse_rule_instances(RULES3) == ["vivaldi-stable", "spotify", "rambox"], tui.parse_rule_instances(RULES3))
rws = tui.build_rows(tui.parse_tag_blocks(TAGS3)["DP-4 eDP-1"])
check("rows: always nine; the lines first, keyed by {n} or position, then none-tags named by position",
      len(rws) == 9 and [r["var"] for r in rws] == ["max", "horizontal", "max", "split"] + ["none"] * 5
      and [r["key"] for r in rws] == [3, 1, 2, 4, 5, 6, 7, 8, 9] and [r["tag"] for r in rws][4:] == ["5", "6", "7", "8", "9"], rws)
check("block: {n} is written only where the key differs from the position, programs in brackets",
      tui.block_lines(rws) == ["left|3    max         {3}  [spotify:0 rambox:0]", "middle|1  horizontal  {1}",
                              "right|2   max         {2}  [vivaldi-stable:1]", "split     split",
                              "5         none", "6         none", "7         none", "8         none", "9         none"], tui.block_lines(rws))
rt = tui.put_tag_block(TAGS3, "DP-4 eDP-1", rws)
check("block: rewriting an unchanged set parses back to the same rows, the other set is untouched",
      tui.build_rows(tui.parse_tag_blocks(rt)["DP-4 eDP-1"]) == rws and 'TAG_LAYOUTS["eDP-1"]="\nonly max\n"' in rt, rt)
check("block: a set with no block gets a new one",
      tui.put_tag_block(TAGS3, "X", rws[:1]).rstrip().endswith('TAG_LAYOUTS["X"]="\nleft|3  max  {3}  [spotify:0 rambox:0]\n"'))

with tempfile.TemporaryDirectory() as tmp:
    tfile, rfile = os.path.join(tmp, "tags.conf"), os.path.join(tmp, "rules.autostart")
    open(tfile, "w").write(TAGS3); open(rfile, "w").write(RULES3)
    tui.HLWM_TAG_LAYOUTS, tui.RULES_FILE, tui.HLWM_LAYOUTS = tfile, rfile, SEED_CONF
    tui.load_model = lambda: model(DOCKED)
    ts = tui.TagsScreen()
    saved = lambda: tui.build_rows(tui.parse_tag_blocks(open(tfile).read())["DP-4 eDP-1"])
    send = lambda *ks: [ts.handle(k) for k in ks]
    typed = lambda text: setattr(ts, "editor", tui.Editor(text))

    check("tags: Esc goes back and q quits", (ts.handle("ESC"), ts.handle("q")) == ("back", "quit"))
    send("DOWN", "DOWN", "UP")
    check("tags: up and down move the selection and stop at the ends",
          ts.sel == 1 and (send(*["UP"] * 5), ts.sel)[1] == 0 and (send(*["DOWN"] * 20), ts.sel)[1] == 8)
    send(*["UP"] * 20)

    send("k")
    check("key: k opens an input for the tag's key", ts.mode == "key" and ts.footer()[0] == "Key of left|3", ts.footer())
    typed("0"); send("CTRL_S")
    check("key: 0 is refused and the input stays open", ts.mode == "key" and "1 to 9" in ts.message, ts.message)
    typed("8"); send("CTRL_S")
    check("key: a key held by an unassigned tag swaps with it like any other",
          ts.mode == "confirm" and ts.footer()[0].startswith("Key of left|3: 3 to 8, 8 gets 3."), ts.footer())
    send("n", "k"); typed("1"); send("CTRL_S")
    check("key: Ctrl-S asks before persisting and names the swap",
          ts.mode == "confirm" and ts.footer() == ("Key of left|3: 3 to 1, middle|1 gets 3. Persist to hlwm_tag_layouts.conf?", "y yes   n no"), ts.footer())
    send("n")
    check("key: n leaves the file alone", open(tfile).read() == TAGS3 and ts.mode == "browse")
    send("k"); typed("1"); send("CTRL_S", "y")
    got = saved()
    check("key: y writes it, and the other tag takes the old key",
          [r["key"] for r in got[:4]] == [1, 3, 2, 4] and ts.message == "saved", [r["key"] for r in got])
    check("key: the file now carries {3} on the swapped tag only", "middle|1" in open(tfile).read() and open(tfile).read().count("{") == 2, open(tfile).read())
    check("key: keys stay one each", sorted(r["key"] for r in ts.rows) == list(range(1, 10)))

    send("DOWN", "n")
    check("name: n opens the name input prefilled", ts.mode == "name" and ts.editor.text() == "middle|1")
    typed("a$b"); send("CTRL_S")
    check("name: a name with $ is refused", ts.mode == "name" and "cannot" in ts.message, ts.message)
    typed("middle"); send("CTRL_S", "y")
    check("name: y writes the new name (the key is unchanged, names need not be unique)",
          saved()[1]["tag"] == "middle" and saved()[1]["key"] == 3, saved()[1])
    send("n"); typed("middle"); send("CTRL_S")
    check("name: an unchanged name says so and closes", ts.mode == "browse" and ts.message == "no change", ts.message)

    send("l")
    check("layout: l opens the list on the current layout (None is the first entry)", ts.mode == "layout" and ts.lay_sel == list(ts.defs).index("horizontal") + 1, ts.lay_sel)
    send("DOWN", "ENTER")
    check("layout: Enter chooses it and asks before persisting",
          ts.mode == "confirm" and ts.footer()[0] == 'Layout of middle: "Split". Persist to hlwm_tag_layouts.conf?', ts.footer())
    send("y")
    check("layout: y writes it", saved()[1]["var"] == "split")

    ts.sel = 5
    send("l")
    check("layout: the list starts with None, and a tag with no layout sits on it",
          ts.mode == "layout" and ts.lay_sel == 0, ts.lay_sel)
    send("DOWN", "DOWN", "ENTER")
    check("none-tags: a tag with no line yet can be given a layout like any other (its place is its position)",
          ts.footer()[0] == 'Layout of 6: "Horizontal". Persist to hlwm_tag_layouts.conf?', ts.footer())
    send("y")
    check("none-tags: the file now has all nine lines, and the layout is on the sixth",
          len(tui.parse_tag_blocks(open(tfile).read())["DP-4 eDP-1"]) == 9 and saved()[5]["var"] == "horizontal" and saved()[4]["var"] == "none")
    ts.sel = 4
    send("n")
    check("none-tags: the name of an unassigned tag can be edited directly", ts.mode == "name" and ts.editor.text() == "5", ts.mode)
    typed("five"); send("CTRL_S", "y")
    check("none-tags: and it stays unassigned", saved()[4]["tag"] == "five" and saved()[4]["var"] == "none")
    ts.sel = 3
    send("l")
    send("HOME", "ENTER")
    check("layout: choosing None asks, and means unassigned",
          ts.footer()[0] == "Layout of split: unassigned. Persist to hlwm_tag_layouts.conf?", ts.footer())
    send("y")
    check("layout: None writes the none variable", saved()[3]["var"] == "none" and "none" in open(tfile).read())
    ts.sel = 3
    send("l", "HOME", "ENTER")
    check("layout: choosing what is already set says so", ts.mode == "browse" and ts.message == "no change", ts.message)

    ts.sel = 0
    send("r")
    ov = {e["inst"]: e for e in ts.ov}
    check("rules: r opens the list of every instance, ticked where they sit on this tag",
          ts.mode == "rules" and [e["inst"] for e in ts.ov] == ["vivaldi-stable", "spotify", "rambox"]
          and [e["on"] for e in ts.ov] == [False, True, True] and ov["vivaldi-stable"]["other"] == "right|2", ts.ov)
    send(" ")
    check("rules: ticking one that sits on another tag asks to move it",
          ts.mode == "move" and ts.footer() == ("Move vivaldi-stable from right|2 to left|3?", "y yes   n no"), ts.footer())
    send("n")
    check("rules: n leaves it unticked", ts.mode == "rules" and not ts.ov[0]["on"])
    send(" ", "y")
    check("rules: y ticks it, keeping its index", ts.mode == "rules" and ts.ov[0]["on"] and ts.ov[0]["idx"] == "1", ts.ov[0])
    send("1", "0", "BACKSPACE", "2", "DOWN", " ")
    check("rules: 0 and 1 edit the index, any other digit is ignored, Backspace deletes, Space unticks",
          ts.ov[0]["idx"] == "11" and not ts.ov[1]["on"], (ts.ov[0]["idx"], ts.ov[1]["on"]))
    send("CTRL_S")
    check("rules: Ctrl-S asks, naming the add, the move and the one left without a tag",
          ts.mode == "confirm" and "+vivaldi-stable from right|2" in ts.footer()[0] and "-spotify (no tag left)" in ts.footer()[0]
          and ts.footer()[0].endswith("Persist to hlwm_tag_layouts.conf?"), ts.footer())
    send("y")
    got = saved()
    check("rules: y writes them, taking the moved one off its old tag",
          got[0]["progs"] == [["vivaldi-stable", "11"], ["rambox", "0"]] and got[2]["progs"] == [], [r["progs"] for r in got[:3]])
    send("r", "CTRL_S")
    check("rules: nothing changed says so", ts.mode == "browse" and ts.message == "no change", ts.message)
    send("r", "ESC")
    check("rules: Esc discards", ts.mode == "browse" and ts.work is None)

    for mode_keys in ((), ("k",), ("n",), ("l",), ("r",), ("r", " ")):
        ts.mode, ts.work = "browse", None
        ts.sel = 0
        send(*mode_keys)
        for w_, h_ in ((100, 24), (72, 12), (140, 40)):
            rws_, foot_, cur_ = ts.render(w_, h_)
            check(f"render: {mode_keys or 'table'} at {w_}x{h_} fills the rows above the footer and nothing is wider than the window",
                  len(rws_) == h_ - 2 and all(sum(len(t) for t, _ in r) <= w_ for r in rws_) and isinstance(foot_, tuple), (len(rws_), h_))
    ts.mode, ts.work = "browse", None
    import re as _re
    words = lambda l: l.split()
    tp = tui.TOP_PAD
    trows = ts.render(100, 24)[0]
    check("table: blank rows above the header match the left margin's distance (two columns to a row)",
          tp >= 1 and all(not r for r in trows[:tp]) and trows[tp], trows[:tp + 1])
    trows = trows[tp:]
    tbl = ["".join(t for t, _ in r) for r in trows]
    check("table: a header row of four columns, then a dashed green line under it, as long as the table needs",
          words(tbl[0]) == ["Key", "Name", "Layout", "Rules"] and 40 < len(tbl[1].strip()) < 100
          and {role for _, role in trows[1]} <= {"text", "green"}, tbl[:2])
    check("table: the dashed line is one column on and one off",
          _re.fullmatch(r"(─ )*─? *", tbl[1].strip()) is not None and tui.HDASH == "─ ", tbl[1])
    check("table: there are no vertical dividers", not any("╵" in l or "│" in l for l in tbl[:12]), tbl[:4])
    check("table: a tag per line, its further rules on their own lines in the Rules column",
          words(tbl[2]) == ["1", "left|3", "Max", "vivaldi-stable", "11"] and words(tbl[3]) == ["rambox", "0"], tbl[2:4])
    check("table: the key is plain text, not green",
          [role for t, role in trows[4] if t.strip() == "3"] == ["text"], trows[4])
    check("table: the unattached rules are listed under the table",
          tbl[-2].strip() == "Unattached rules" or "Unattached rules" in "".join(tbl[-3:]), tbl[-4:])
    ts.rows[0]["progs"] = []
    tbl2 = ["".join(t for t, _ in r) for r in ts.render(100, 24)[0][tp:]]
    check("table: a rule with no tag in the set appears there",
          any(l.strip() == "Unattached rules" for l in tbl2) and any(l.strip() == "rambox" for l in tbl2[-4:]), tbl2[-4:])
    trall = ts.render(110, 40)[0][tp:]
    tall = ["".join(t for t, _ in r) for r in trall]
    check("table: with room, half a line of highlight shows above and below the selected tag, in the padding lines",
          tall[2] == "▄" * 110 and "left|3" in tall[3] and tall[4] == "▀" * 110 and {r for _, r in trall[2]} == {"green"}, tall[2:5])
    check("table: the padding between tags is one line, shared, with the next tag straight after it",
          "middle" in tall[5] and words(tall[6]) == [] and "right|2" in tall[7], tall[4:8])
    check("table: without room the padding goes and the tags are on consecutive lines",
          "left|3" in tbl2[2] and "middle" in tbl2[3] and not any(l.startswith(("▄", "▀")) for l in tbl2), tbl2[:5])
    wide = ["".join(t for t, _ in r) for r in ts.render(160, 40)[0][tp:]]
    check("table: it is sized by its columns, not stretched to the window", len(wide[1].rstrip()) < 110 and len(wide[1].rstrip()) == len(tall[1].rstrip()), len(wide[1].rstrip()))
    ts.rows[0]["progs"] = [["a", "0"], ["b", "1"]]
    r0 = ts.render(110, 40)[0][tp:]
    hl = [r for r in r0 if r and all(role == "hilite" for _, role in r)]
    caps = [r for r in r0 if r and r[0][0][:1] in "▄▀"]
    check("table: the selected tag's own lines are highlighted across the whole width, with a half-line band each side",
          len(hl) == 2 and all(sum(len(t) for t, _ in r) == 110 for r in hl) and len(caps) == 2, (len(hl), len(caps)))
    ts.sel = 1
    r1 = ts.render(110, 40)[0][tp:]
    check("table: the padding shared with the tag above gives this tag its top band",
          len([r for r in r1 if r and all(role == "hilite" for _, role in r)]) == 1 and len([r for r in r1 if r and r[0][0][:1] in "▄▀"]) == 2)
    ts.sel = 8
    shown = ts.render(110, 14)[0]
    short = ["".join(t for t, _ in r) for r in shown]
    ts.sel = 8
    short = ["".join(t for t, _ in r) for r in ts.render(110, 14)[0]]
    shown = ts.render(110, 14)[0]
    check("table: the selected tag stays in view when it has to scroll",
          any(r and all(role == "hilite" for _, role in r) for r in shown), short)
    ts.sel = 0
    tui.load_model = lambda: tui.Model([])
    ts2 = tui.TagsScreen(); ts2.handle("k")
    check("tags: with no monitors an edit says there is nothing to save it for", ts2.mode == "browse" and ts2.message == "no monitors to save it for", ts2.message)

print("\nA monitor that is off")
if True:
    ids = {}
    applied = []
    tui.load_model = lambda: model(OFF)
    tui.apply_lines = lambda lines: (applied.append(list(lines)), (0, ""))[1]
    tui.DRY = True
    mo = tui.MonitorScreen()
    e, d = mo.model.outs
    d.edid = "00ffffffffffff0005e3bbbbbbbbbbbb"
    check("an off monitor is drawn right of the active ones, top-aligned, with a gap", mo.model.spots() == {"eDP-1": (0, 0), "DP-4": (2560 + tui.OFF_GAP, 0)}, mo.model.spots())
    d.w, d.h = 1920, 1200               # whatever its preferred mode is, the outline is 16:9
    check("an off monitor is always drawn 16:9", mo.model.size(d) == (1920, 1080) and mo.model.size(e) == (e.w, e.h), mo.model.size(d))
    rows = ["".join(t for t, _ in r) for r in mo.diagram(100, 12)]
    flat = "\n".join(rows)
    check("the diagram draws it with heavy dashes, one cell of line and one of gap, and the active one solid", "┏ ━ ━ ━" in flat and "┏━━━" in flat, flat)
    check("the dashed outline carries its number and no star", any("┃" in r and "2" in r for r in rows) and "2*" not in flat, rows)
    box = [b for b in tui.monitor_boxes(mo.model, tui.frame_for(mo.model, 100, 12)) if b[0] is d][0]
    check("drawn in cells it is wider than tall, 16:9 once a cell's two-to-one shape is counted", (box[3] - box[1] + 1) / ((box[4] - box[2] + 1) * 2) > 1.5, box)
    check("an off monitor is tall enough to show a dash on each side", sum(r.count("┃") for r in rows) >= 2 + 3, rows)
    mo.handle("RIGHT")
    check("Right selects the off monitor", mo.name == "DP-4" and mo.cur() is d)
    title, lines = mo.info()
    text = " ".join("".join(t for t, _ in l) for l in lines)
    check("the info panel says it is off and still shows its EDID", title == "2  DP-4" and "off" in text and "00ffffffffffff0005e3bbbbbbbbbbbb" in text, text)
    rows = ["".join(t for t, _ in r) for r in mo.diagram(100, 12)]
    check("selected, the dashed outline is still dashed", any("┏ ━ ━" in r for r in rows))
    for key in ("p", "m", "e"):
        mo.handle(key)
        check(f"{key} on an off monitor says to turn it on first", mo.mode == "browse" and mo.message == "DP-4 is off: r to turn it on", mo.message)
    mo.handle("r")
    check("r opens the resolution list for it", mo.mode == "resolution" and len(mo.res_rows) > 1)
    mo.handle("DOWN") if mo.res_sel == 0 else None
    mo.handle("ENTER")
    check("choosing one turns it on at the right of the others and asks to keep it",
          mo.mode == "keep" and applied and any(l.startswith("DP-4 1920x1080") and "--pos 2560x0" in l for l in applied[-1]), applied[-1:])
    mo.handle("n")
    check("n turns it off again", mo.message == "reverted" and applied[-1][-1] == "DP-4 off", applied[-1])
    d2 = mo.model.outs[1]
    check("and it is back to being drawn dashed", not d2.on)
    tui.load_model = lambda: model(OFF.replace("eDP-1 connected primary 2560x1600+0+0", "eDP-1 connected 340mm x 210mm").replace("   2560x1600    165.00*+", "   2560x1600    165.00 +"))
    none = tui.MonitorScreen()
    rows = ["".join(t for t, _ in r) for r in none.diagram(100, 12)]
    check("with every monitor off they are all drawn dashed", len(none.model.active()) == 0 and any("┏ ━ ━" in r for r in rows) and not any("━━" in r for r in rows), rows)

print("\nRotation and re-flow")
if True:
    ROT = """\
eDP-1 connected primary 2560x1600+0+0 (normal left inverted right x axis y axis) 340mm x 210mm
   2560x1600    165.00*+
DP-4 connected 1080x1920+2560+0 left (normal left inverted right x axis y axis) 530mm x 300mm
   1920x1080     60.00*+
   2560x1440     60.00
HDMI-1 connected 1920x1080+3640+0 (normal left inverted right x axis y axis) 530mm x 300mm
   1920x1080     60.00*+
DP-5 connected 1920x1080+0+1600 (normal left inverted right x axis y axis) 530mm x 300mm
   1920x1080     60.00*+
"""
    m = model(ROT)
    e, d, h, v = m.outs
    check("parse: a rotated output keeps its rotation and the rotated size", d.rot == "left" and (d.w, d.h) == (1080, 1920) and e.rot == "normal", (d.rot, d.w, d.h))
    check("a rotated output's layout line carries --rotate, a normal one does not", "DP-4 1920x1080 --pos 2560x0 --rotate left" in m.layout_lines() and not any("eDP-1" in l and "rotate" in l for l in m.layout_lines()), m.layout_lines())
    m.set_mode(d, "2560x1440")
    check("a mode on a sideways output is stored rotated", (d.w, d.h) == (1440, 2560), (d.w, d.h))

    m = model(ROT)
    e, d, h, v = m.outs
    m.rotate(d, "normal")
    check("rotating back swaps width and height", (d.w, d.h) == (1920, 1080), (d.w, d.h))
    check("the monitor beyond the grown edge moves out by the growth and still touches", h.x == d.x + d.w == 4480, (h.x, d.x + d.w))
    check("a monitor beyond neither edge does not move", (v.x, v.y) == (0, 1600) and (e.x, e.y) == (0, 0), (v.x, v.y))
    m.rotate(d, "left")
    check("rotating the other way pulls it back in", h.x == d.x + d.w == 3640, h.x)

    m = model(ROT)
    e, d, h, v = m.outs
    ow, oh = e.w, e.h
    m.set_mode(e, "1920x1080")
    m.reflow(e, ow, oh)
    check("a shrink pulls in everything beyond the right edge, chained", d.x == 1920 and h.x == 3000, (d.x, h.x))
    check("and what sat below the shrunk edge moves up", v.y == 1080, v.y)

    tui.load_model = lambda: model(ROT)
    applied = []
    tui.apply_lines = lambda lines: (applied.append(list(lines)), (0, ""))[1]
    tui.DRY = True
    rs = tui.MonitorScreen()
    rs.handle("RIGHT")
    check("the rotated monitor is selected and the info panel says so", rs.name == "DP-4" and "rotated left" in " ".join("".join(t for t, _ in l) for l in rs.info()[1]))
    def rot_pick(screen, label):
        screen.handle("o")
        while tui.ROT_LABELS[screen.rot_sel] != label:
            screen.handle("DOWN" if tui.ROT_LABELS.index(label) > screen.rot_sel else "UP")
        screen.handle("ENTER")

    rs.handle("o")
    check("o opens a menu of the four rotations with the current one selected", rs.mode == "rotate" and tui.ROTATIONS[rs.rot_sel] == "left", rs.mode)
    rs.handle("ESC")
    check("Esc closes it and changes nothing", rs.mode == "browse" and rs.model.outs[1].rot == "left")
    rot_pick(rs, "Left 90°")
    check("choosing the current rotation says so and applies nothing", rs.mode == "browse" and "already" in rs.message, rs.message)
    rot_pick(rs, "Right 90°")
    check("choosing Right 90° applies it and asks to keep it", rs.mode == "keep" and any(l.startswith("DP-4") and "--rotate right" in l for l in applied[-1]), applied[-1:])
    rs.handle("y")
    rot_pick(rs, "180°")
    check("180° is inverted", any(l.startswith("DP-4") and "--rotate inverted" in l for l in applied[-1]) and rs.model.outs[1].rot == "inverted", applied[-1:])
    rs.handle("y")
    rot_pick(rs, "Normal")
    check("Normal sends --rotate normal (xrandr keeps the old rotation otherwise) and moves what was beyond it", rs.model.outs[1].rot == "normal" and rs.model.outs[2].x == 4480 and any(l.startswith("DP-4") and "--rotate normal" in l for l in applied[-1]), applied[-1:])
    rs.handle("y")
    rot_pick(rs, "Left 90°")
    check("Left 90° pulls the monitor beyond it in", rs.model.outs[1].rot == "left" and rs.model.outs[2].x == 3640, (rs.model.outs[1].rot, rs.model.outs[2].x))
    rs.handle("n")
    check("n undoes it, neighbours included", rs.model.outs[1].rot == "normal" and rs.model.outs[2].x == 4480, (rs.model.outs[1].rot, rs.model.outs[2].x))

    tui.load_model = lambda: model(ROT)
    rs = tui.MonitorScreen(); rs.handle("RIGHT"); rs.handle("e")
    check("e shows the geometry as rotated", rs.editor.text() == "1080x1920+2560+0", rs.editor.text())
    for _ in range(30): rs.handle("BACKSPACE")
    for ch in "1080x1920+2560+0": rs.handle(ch)
    rs.handle("CTRL_S")
    check("typing it back applies the mode of the rotated monitor, not its swapped size", any(l.startswith("DP-4 1920x1080") and "--rotate left" in l for l in applied[-1]), applied[-1:])
    rs.handle("y")

    tui.load_model = lambda: model(ROT)
    rs = tui.MonitorScreen(); rs.handle("RIGHT"); rs.handle("r")
    rs.res_sel = next(i for i, r in enumerate(rs.res_rows) if r[0] == "2560x1440")
    rs.handle("ENTER")
    mm = rs.model.outs
    check("a resolution change re-flows the monitors beyond it", rs.mode == "keep" and (mm[1].w, mm[1].h) == (1440, 2560) and mm[2].x == mm[1].x + mm[1].w, [(o.name, o.x, o.w) for o in mm])
    rs.handle("y")

    tui.load_model = lambda: model(OFF)
    ro = tui.MonitorScreen(); ro.handle("RIGHT"); ro.handle("o")
    check("o on a monitor that is off says to turn it on first", ro.message == "DP-4 is off: r to turn it on", ro.message)

print(f"\n{passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
