#!/usr/bin/env python3
"""Curses editor for the monitor layout.

Shows the connected outputs as a scaled picture and a list; change them with
single keys, then apply. Applying goes through `monitor_reconcile.sh --layout`
(layout lines on stdin), so the panel guard and custom-mode creation still
apply. After an apply there is a 15 s window to keep the result, otherwise the
previous layout is restored.

  arrows / hjkl   move the selected output to the next free, edge-aligned spot
  H J K L         nudge it by 10 px (may overlap, e.g. to mirror)
  Tab, 1-9        select an output        o  turn on/off     p  make primary
  m               choose a mode           u  undo edits
  a               apply                   s  apply and save to monitor_layouts.conf
  R               reset to the configured layout            q  quit

MONITOR_TUI_DRY=1 applies nothing (reconcile --dry-run). XRANDR_FIXTURE=<file>
reads `xrandr --query` output from a file instead of the display.

Not handled: rotation (positions assume unrotated outputs), and moving an
output does not re-flow the others.
"""
import copy
import curses
import os
import re
import subprocess
import sys
import time

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RECONCILE = os.path.join(SCRIPT_DIR, "monitor_reconcile.sh")
LAYOUTS_CONF = os.environ.get("LAYOUTS_CONF", os.path.join(SCRIPT_DIR, "monitor_layouts.conf"))
DRY = bool(os.environ.get("MONITOR_TUI_DRY"))
REVERT_SECONDS = 15
NUDGE = 10
SAVED_COMMENT = "# Saved by monitor_tui.py:"

GEOM = re.compile(r"^(\d+)x(\d+)\+(-?\d+)\+(-?\d+)$")
MODE = re.compile(r"^(\d+)x(\d+)")


def dims(mode):
    m = MODE.match(mode or "")
    return (int(m.group(1)), int(m.group(2))) if m else None


class Output:
    def __init__(self, name):
        self.name = name
        self.modes = []      # as listed, _custom stripped
        self.pref = None     # the preferred mode
        self.mode = "off"    # off | auto | WxH
        self.x = self.y = self.w = self.h = 0
        self.primary = False

    @property
    def on(self):
        return self.mode != "off"


def parse_xrandr(text):
    """Connected outputs from `xrandr --query` output."""
    outs, cur = [], None
    for line in text.splitlines():
        if line and not line[0].isspace():
            f = line.split()
            cur = None
            if len(f) > 1 and f[1] == "connected":
                cur = Output(f[0])
                outs.append(cur)
                cur.primary = len(f) > 2 and f[2] == "primary"
                for tok in f[2:]:
                    m = GEOM.match(tok)
                    if m:
                        cur.w, cur.h, cur.x, cur.y = (int(v) for v in m.groups())
                        cur.mode = "auto"
                        break
        elif cur is not None and line.strip():
            f = line.split()
            name = re.sub(r"_custom$", "", f[0])
            if not MODE.match(name):
                continue
            flags = "".join(f[1:])
            if name not in cur.modes:
                cur.modes.append(name)
            if "+" in flags and cur.pref is None:
                cur.pref = name
            if "*" in flags and cur.mode != "off":
                cur.mode = name
    for o in outs:
        if not o.on:
            d = dims(o.pref or (o.modes[0] if o.modes else None))
            if d:
                o.w, o.h = d
            o.primary = False
    return outs


class Model:
    def __init__(self, outs):
        self.outs = outs

    def copy(self):
        return copy.deepcopy(self)

    def key(self):
        return " ".join(sorted(o.name for o in self.outs))

    def active(self):
        return [o for o in self.outs if o.on]

    def overlaps_any(self, o, x, y):
        for a in self.active():
            if a is not o and x < a.x + a.w and a.x < x + o.w and y < a.y + a.h and a.y < y + o.h:
                return True
        return False

    def has_overlap(self):
        act = self.active()
        return any(self.overlaps_any(o, o.x, o.y) for o in act)

    def toggle(self, o):
        """Returns an error message, or '' on success."""
        if o.on:
            if len(self.active()) < 2:
                return "at least one output must stay on"
            o.mode = "off"
            if o.primary:
                o.primary = False
                self.active()[0].primary = True
        else:
            others = self.active()
            o.mode = "auto"
            d = dims(o.pref or (o.modes[0] if o.modes else None))
            if d:
                o.w, o.h = d
            if others:
                o.x = max(a.x + a.w for a in others)
                o.y = min(a.y for a in others)
        return ""

    def set_mode(self, o, mode):
        o.mode = mode
        d = dims(o.pref or (o.modes[0] if o.modes else None)) if mode == "auto" else dims(mode)
        if d:
            o.w, o.h = d

    def make_primary(self, o):
        if not o.on:
            return "an output that is off cannot be primary"
        for a in self.outs:
            a.primary = a is o
        return ""

    def snap(self, o, dx, dy):
        """Jump to the next edge-aligned spot in a direction that doesn't overlap."""
        others = [a for a in self.active() if a is not o]
        if not o.on or not others:
            return False
        if dx:
            cands = set()
            for a in others:
                cands |= {a.x, a.x + a.w, a.x - o.w, a.x + a.w - o.w}
            pool = sorted(v for v in cands if (v > o.x if dx > 0 else v < o.x)
                          and not self.overlaps_any(o, v, o.y))
            if not pool:
                return False
            o.x = pool[0] if dx > 0 else pool[-1]
        else:
            cands = set()
            for a in others:
                cands |= {a.y, a.y + a.h, a.y - o.h, a.y + a.h - o.h}
            pool = sorted(v for v in cands if (v > o.y if dy > 0 else v < o.y)
                          and not self.overlaps_any(o, o.x, v))
            if not pool:
                return False
            o.y = pool[0] if dy > 0 else pool[-1]
        return True

    def nudge(self, o, dx, dy):
        if o.on:
            o.x += dx * NUDGE
            o.y += dy * NUDGE

    def layout_lines(self):
        """Layout lines for monitor_reconcile.sh; positions start at 0x0."""
        act = self.active()
        minx = min((o.x for o in act), default=0)
        miny = min((o.y for o in act), default=0)
        lines = []
        for o in self.outs:
            if not o.on:
                lines.append(f"{o.name} off")
                continue
            s = f"{o.name} {o.mode} --pos {o.x - minx}x{o.y - miny}"
            lines.append(s + (" --primary" if o.primary else ""))
        return lines


def query_xrandr():
    fix = os.environ.get("XRANDR_FIXTURE")
    if fix:
        with open(fix) as f:
            return f.read()
    return subprocess.run(["xrandr", "--query"], capture_output=True, text=True, check=True).stdout


def load_model():
    return Model(parse_xrandr(query_xrandr()))


def run_reconcile(args, stdin_text=None):
    p = subprocess.run([RECONCILE, *args], input=stdin_text, capture_output=True, text=True)
    return p.returncode, p.stderr.strip()


def is_known():
    return subprocess.run([RECONCILE, "--known"], capture_output=True).returncode == 0


def apply_lines(lines):
    args = (["--dry-run"] if DRY else []) + ["--layout", "/dev/stdin"]
    return run_reconcile(args, "\n".join(lines) + "\n")


def save_conf(conf, key, lines):
    """Replace the key's active LAYOUTS entry in conf, or append one."""
    with open(conf) as f:
        text = f.read()
    start = f'LAYOUTS["{key}"]="'
    kept, skipping = [], False
    for line in text.split("\n"):
        if skipping:
            skipping = line != '"'
            continue
        if line.startswith(start):
            skipping = True
            if kept and kept[-1] == SAVED_COMMENT:
                kept.pop()
            continue
        kept.append(line)
    body = "\n".join(kept).rstrip("\n")
    body += f"\n\n{SAVED_COMMENT}\n{start}\n" + "\n".join(lines) + '\n"\n'
    with open(conf, "w") as f:
        f.write(body)


# ---------------------------------------------------------------- drawing

def put(win, y, x, s, attr=0):
    h, w = win.getmaxyx()
    if y < 0 or y >= h or x >= w:
        return
    x = max(x, 0)
    try:
        win.addstr(y, x, s[: max(0, w - x - 1)], attr)
    except curses.error:
        pass


def draw_canvas(win, model, sel, top, rows):
    h, w = win.getmaxyx()
    act = model.active()
    if not act or rows < 6:
        return
    minx, miny = min(o.x for o in act), min(o.y for o in act)
    tw = max(o.x + o.w for o in act) - minx
    th = max(o.y + o.h for o in act) - miny
    px = max(tw / max(w - 4, 1), th / (rows * 2), 1)  # pixels per column; rows are ~2x taller
    chosen = model.outs[sel]
    for o in sorted(act, key=lambda o: o is chosen):
        left = 1 + int((o.x - minx) / px)
        t = top + int((o.y - miny) / (2 * px))
        label = [o.name + (" *" if o.primary else ""), o.mode, f"+{o.x}+{o.y}"]
        ww = max(int(o.w / px), max(len(s) for s in label) + 4)
        hh = max(int(o.h / (2 * px)), 5)
        attr = curses.A_REVERSE if o is chosen else curses.A_NORMAL
        put(win, t, left, "+" + "-" * (ww - 2) + "+", attr)
        for r in range(1, hh - 1):
            put(win, t + r, left, "|" + " " * (ww - 2) + "|", attr)
        put(win, t + hh - 1, left, "+" + "-" * (ww - 2) + "+", attr)
        for i, s in enumerate(label):
            put(win, t + 1 + i, left + 2, s, attr | (curses.A_BOLD if i == 0 else 0))


def draw(win, model, sel, status, origin, dirty):
    win.erase()
    h, w = win.getmaxyx()
    mark = "  [modified]" if dirty else ""
    put(win, 0, 1, f"Monitors: {model.key()}   ({origin} layout){mark}" + ("   DRY RUN" if DRY else ""),
        curses.A_BOLD)
    list_top = h - 3 - len(model.outs) - 1
    draw_canvas(win, model, sel, 2, max(0, list_top - 3))
    put(win, list_top, 0, "-" * (w - 1))
    for i, o in enumerate(model.outs):
        pos = f"+{o.x}+{o.y}" if o.on else ""
        line = f" {i + 1}  {o.name:<9} {o.mode:<12} {pos:<12} {'primary' if o.primary else ''}"
        put(win, list_top + 1 + i, 0, line.ljust(w - 1), curses.A_REVERSE if i == sel else 0)
    put(win, h - 3, 1, "arrows/hjkl move  HJKL nudge  Tab/1-9 select  o on/off  p primary  m mode")
    put(win, h - 2, 1, "a apply  s apply+save  u undo  R reset to configured  q quit")
    warn = "  OVERLAP" if model.has_overlap() else ""
    put(win, h - 1, 1, (status + warn)[: w - 2], curses.A_BOLD)
    win.refresh()


def pick(win, title, items, current):
    """A small list; returns the chosen item or None."""
    idx = items.index(current) if current in items else 0
    while True:
        h, w = win.getmaxyx()
        n = min(len(items), h - 6)
        first = max(0, min(idx - n // 2, len(items) - n))
        bw = max(len(title), *(len(i) for i in items)) + 6
        top, left = (h - n - 2) // 2, (w - bw) // 2
        box = win.derwin(n + 2, bw, top, left)
        box.erase()
        box.box()
        put(box, 0, 2, f" {title} ")
        for r in range(n):
            item = items[first + r]
            put(box, r + 1, 2, item.ljust(bw - 4), curses.A_REVERSE if first + r == idx else 0)
        box.refresh()
        ch = win.getch()
        if ch in (curses.KEY_UP, ord("k")):
            idx = (idx - 1) % len(items)
        elif ch in (curses.KEY_DOWN, ord("j")):
            idx = (idx + 1) % len(items)
        elif ch in (10, 13, curses.KEY_ENTER):
            return items[idx]
        elif ch in (27, ord("q")):
            return None


def confirm_or_revert(win, baseline_lines):
    """After an apply: keep it on `y`, otherwise restore the previous layout."""
    deadline = time.time() + REVERT_SECONDS
    win.timeout(250)
    try:
        while True:
            left = int(deadline - time.time()) + 1
            h, w = win.getmaxyx()
            put(win, h - 1, 1, " " * (w - 2))
            put(win, h - 1, 1, f"Keep this layout?  y = keep, n = revert now.  Reverting in {left}s",
                curses.A_BOLD | curses.A_REVERSE)
            win.refresh()
            ch = win.getch()
            if ch in (ord("y"), ord("Y")):
                return True
            if left <= 0 or ch in (ord("n"), ord("N"), 27):
                apply_lines(baseline_lines)
                return False
    finally:
        win.timeout(-1)


KEYS_DIR = {
    curses.KEY_LEFT: (-1, 0), ord("h"): (-1, 0),
    curses.KEY_RIGHT: (1, 0), ord("l"): (1, 0),
    curses.KEY_UP: (0, -1), ord("k"): (0, -1),
    curses.KEY_DOWN: (0, 1), ord("j"): (0, 1),
}
KEYS_NUDGE = {ord("H"): (-1, 0), ord("L"): (1, 0), ord("K"): (0, -1), ord("J"): (0, 1)}


def run(win):
    try:
        curses.curs_set(0)
    except curses.error:
        pass
    model = load_model()
    if not model.outs:
        return "no connected outputs"
    baseline = model.copy()
    origin = "configured" if is_known() else "fallback"
    sel, status = 0, ""

    def reload():
        nonlocal model, baseline, origin, sel
        model = load_model()
        baseline = model.copy()
        origin = "configured" if is_known() else "fallback"
        sel = min(sel, len(model.outs) - 1)

    while True:
        dirty = model.layout_lines() != baseline.layout_lines()
        draw(win, model, sel, status, origin, dirty)
        status = ""
        ch = win.getch()
        o = model.outs[sel]
        if ch in (ord("q"), 27):
            return ""
        elif ch == curses.KEY_RESIZE:
            continue
        elif ch == 9:
            sel = (sel + 1) % len(model.outs)
        elif ch == curses.KEY_BTAB:
            sel = (sel - 1) % len(model.outs)
        elif ord("1") <= ch <= ord("9") and ch - ord("1") < len(model.outs):
            sel = ch - ord("1")
        elif ch in KEYS_DIR:
            if not model.snap(o, *KEYS_DIR[ch]):
                status = "no free spot that way (use HJKL to nudge)"
        elif ch in KEYS_NUDGE:
            model.nudge(o, *KEYS_NUDGE[ch])
        elif ch == ord("o"):
            status = model.toggle(o)
        elif ch == ord("p"):
            status = model.make_primary(o)
        elif ch == ord("m"):
            choice = pick(win, f"{o.name} mode", ["auto", *o.modes], o.mode)
            if choice:
                model.set_mode(o, choice)
        elif ch == ord("u"):
            model = baseline.copy()
            status = "edits undone"
        elif ch == ord("R"):
            rc, err = run_reconcile((["--dry-run"] if DRY else []) + ["--force"])
            status = "reset to the configured layout" if rc == 0 else f"reset failed: {err.splitlines()[-1:]}"
            if not DRY:
                reload()
        elif ch in (ord("a"), ord("s")):
            lines = model.layout_lines()
            previous = baseline.layout_lines()
            rc, err = apply_lines(lines)
            if rc != 0:
                status = "apply failed: " + (err.splitlines()[-1] if err else f"exit {rc}")
                continue
            if DRY:
                status = "dry run: nothing applied"
                continue
            if not confirm_or_revert(win, previous):
                reload()
                status = "reverted"
                continue
            if ch == ord("s"):
                save_conf(LAYOUTS_CONF, model.key(), lines)
                status = "applied and saved"
            else:
                status = "applied"
            reload()


def main():
    if not os.access(RECONCILE, os.X_OK):
        sys.exit(f"cannot run {RECONCILE}")
    msg = curses.wrapper(run)
    if msg:
        print(msg)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
