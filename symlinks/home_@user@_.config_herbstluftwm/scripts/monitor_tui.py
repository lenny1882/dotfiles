#!/usr/bin/env python3
"""Curses TUI for herbstluftwm layouts and monitors.

The overview shows two rows: the focused tag's layout (tag name, layout name, a
drawing of its frame tree) and the monitors (to scale, numbered, * on the
primary, details underneath).

  Up / Down   select a row       Enter  open it       Left  back       q  quit

The Layout screen (Enter on Layout) shows the focused tag above a grid of the layouts in
hlwm_layouts.conf: arrows select, Enter sets (asks first), e edits, d deletes (asks first), s saves a
custom layout, Esc goes back. Create new is the first cell.

The Monitors screen (Enter on Monitors) shows the active monitors to scale, numbered, * on the primary,
with an info panel for the selected one. Arrows select; p makes it primary (asks first); m moves it
(arrows 10 px, Ctrl 1 px, Shift 100 px, Alt hops to the other side of the next monitor; Ctrl-S applies,
Esc cancels); r opens a list of resolutions and refresh rates with Custom first; e edits the WxH+X+Y
string. Changes are applied at once through monitor_reconcile.sh --layout.

Layout name: the focused tag's entry for the current set of connected monitors
in hlwm_tag_layouts.conf gives a layout variable; hlwm_layouts.conf gives its
`# lname:` text. If the tag's live frame tree no longer has the same structure
as that layout (ignoring window ids, split fractions and selection) it shows
"custom"; with no entry it shows "unassigned".

  monitor_tui.py --print [WIDTH]   print the overview as plain text and exit

Environment (for testing): HERBSTCLIENT (command to use instead of herbstclient),
XRANDR_FIXTURE (file holding `xrandr --query` output), HLWM_LAYOUTS and
HLWM_TAG_LAYOUTS (paths to the two conf files).

Not handled: rotation (positions assume unrotated outputs).
"""
import copy
import curses
import os
import re
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RECONCILE = os.path.join(SCRIPT_DIR, "monitor_reconcile.sh")
LAYOUTS_CONF = os.environ.get("LAYOUTS_CONF", os.path.join(SCRIPT_DIR, "monitor_layouts.conf"))
HLWM_LAYOUTS = os.environ.get("HLWM_LAYOUTS", os.path.join(SCRIPT_DIR, "hlwm_layouts.conf"))
HLWM_TAG_LAYOUTS = os.environ.get("HLWM_TAG_LAYOUTS", os.path.join(SCRIPT_DIR, "hlwm_tag_layouts.conf"))
HC = os.environ.get("HERBSTCLIENT", "herbstclient")
DRY = bool(os.environ.get("MONITOR_TUI_DRY"))
NUDGE = 10
SAVED_COMMENT = "# Saved by monitor_tui.py:"

GEOM = re.compile(r"^(\d+)x(\d+)\+(-?\d+)\+(-?\d+)$")
GEOM_SIGNED = re.compile(r"^(\d+)x(\d+)([+-]\d+)([+-]\d+)$")
MODE = re.compile(r"^(\d+)x(\d+)")


# ------------------------------------------------------------------ monitors

def dims(mode):
    m = MODE.match(mode or "")
    return (int(m.group(1)), int(m.group(2))) if m else None


class Output:
    def __init__(self, name):
        self.name = name
        self.modes = []      # as listed, _custom stripped
        self.pref = None     # the preferred mode
        self.rates = []      # (mode, rate, current, preferred) for every line of the mode list
        self.rate = None     # a refresh rate chosen in the TUI; None leaves it to xrandr
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
            for tok in f[1:]:
                r = re.match(r"^(\d+(?:\.\d+)?)([*+]*)$", tok)
                if r:
                    now, pref = "*" in r.group(2), "+" in r.group(2)
                    dup = next((i for i, e in enumerate(cur.rates) if e[:2] == (name, r.group(1))), None)
                    if dup is None:     # a _custom mode and the real one list the same rate twice
                        cur.rates.append((name, r.group(1), now, pref))
                    else:
                        e = cur.rates[dup]
                        cur.rates[dup] = (name, r.group(1), e[2] or now, e[3] or pref)
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
        return any(self.overlaps_any(o, o.x, o.y) for o in self.active())

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

    def normalise(self):
        """Shift the active outputs so the top-left of all of them is 0,0 (as xrandr reports)."""
        act = self.active()
        if act:
            minx, miny = min(o.x for o in act), min(o.y for o in act)
            for o in act:
                o.x, o.y = o.x - minx, o.y - miny

    def geometry(self, o):
        """WxH+X+Y as xrandr and herbstluftwm write it (a minus sign if it has been moved past 0)."""
        return f"{o.w}x{o.h}{o.x:+d}{o.y:+d}"

    def move_by(self, o, dx, dy):
        """Move o by dx,dy pixels; refuses (returns the reason) if it would overlap another output."""
        return self.move_to(o, o.x + dx, o.y + dy)

    def move_to(self, o, x, y):
        for a in self.active():
            if a is not o and x < a.x + a.w and a.x < x + o.w and y < a.y + a.h and a.y < y + o.h:
                return f"would overlap {a.name}"
        o.x, o.y = x, y
        return ""

    def hop(self, o, dx, dy):
        """Jump to the other side of the nearest output in a direction, keeping the other coordinate."""
        cx, cy = o.x + o.w / 2, o.y + o.h / 2
        ahead = [a for a in self.active() if a is not o
                 and ((a.x + a.w / 2 - cx) * dx > 0 or (a.y + a.h / 2 - cy) * dy > 0)]
        if not ahead:
            return "no monitor that way"
        a = min(ahead, key=lambda a: abs(a.x + a.w / 2 - cx) if dx else abs(a.y + a.h / 2 - cy))
        if dx:
            return self.move_to(o, a.x - o.w if dx < 0 else a.x + a.w, o.y)
        return self.move_to(o, o.x, a.y - o.h if dy < 0 else a.y + a.h)

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
            s = f"{o.name} {o.mode}" + (f" --rate {o.rate}" if o.rate else "") + f" --pos {o.x - minx}x{o.y - miny}"
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


# ------------------------------------------------------------- herbstluftwm

class HlwmError(Exception):
    pass


def hc(*args):
    try:
        p = subprocess.run([HC, *args], capture_output=True, text=True)
    except OSError as e:
        raise HlwmError(f"cannot run {HC}: {e.strerror}")
    if p.returncode != 0:
        raise HlwmError(p.stderr.strip() or p.stdout.strip() or f"{HC} {' '.join(args)} failed")
    return p.stdout.strip()


class Node:
    """A frame: a split (two children) or a leaf holding clients."""

    def __init__(self, kind, direction="", frac=0.5, algo="", nclients=0):
        self.kind = kind            # split | clients
        self.direction = direction  # horizontal (side by side) | vertical (stacked)
        self.frac = frac
        self.algo = algo
        self.nclients = nclients
        self.children = []


ALGOS = ("vertical", "horizontal", "max", "grid")


def parse_tree(text, strict=False):
    """Parse a `hc dump` / `hc load` frame tree string.

    strict also checks the words and numbers (for layouts typed by hand): the split
    direction, the fraction, the algorithm, and that any selection is a number."""
    toks = re.findall(r"\(|\)|[^\s()]+", text)
    pos = 0

    def take():
        nonlocal pos
        if pos >= len(toks):
            raise ValueError("unexpected end of layout")
        pos += 1
        return toks[pos - 1]

    def node():
        if take() != "(":
            raise ValueError("expected (")
        kind, spec = take(), take()
        parts = spec.split(":")
        if strict and kind in ("split", "clients"):
            if kind == "split":
                if parts[0] not in ("horizontal", "vertical"):
                    raise ValueError(f"a split is horizontal or vertical, not '{parts[0]}'")
                try:
                    frac = float(parts[1])
                except (IndexError, ValueError):
                    raise ValueError("a split needs a fraction, as in horizontal:0.5:0")
                if not 0 < frac < 1:
                    raise ValueError("a split fraction must be between 0 and 1")
                extra = parts[2:]
            else:
                if parts[0] not in ALGOS:
                    raise ValueError(f"'{parts[0]}' is not a frame algorithm ({', '.join(ALGOS)})")
                extra = parts[1:]
            if len(extra) > 1 or (extra and not extra[0].isdigit()):
                raise ValueError("what follows the last colon must be a number")
        if kind == "split":
            n = Node("split", direction=parts[0], frac=float(parts[1]))
            n.children = [node(), node()]
        elif kind == "clients":
            n = Node("clients", algo=parts[0])
            while pos < len(toks) and toks[pos] != ")":
                take()
                n.nclients += 1
        else:
            raise ValueError(f"unknown frame kind {kind}")
        if take() != ")":
            raise ValueError("expected )")
        return n

    try:
        root = node()
    except (IndexError, ValueError) as e:
        raise ValueError(str(e))
    if pos != len(toks):
        raise ValueError("trailing text after layout")
    return root


def tree_key(n):
    """The structure of a tree: ignores window ids, fractions and selection."""
    if n.kind == "split":
        return ("split", n.direction, tree_key(n.children[0]), tree_key(n.children[1]))
    return ("clients", n.algo)


_UP, _DOWN, _LEFT, _RIGHT = 1, 2, 4, 8
_BOX = {_UP | _DOWN: "┃", _LEFT | _RIGHT: "━", _DOWN | _RIGHT: "┏", _DOWN | _LEFT: "┓",
        _UP | _RIGHT: "┗", _UP | _LEFT: "┛", _UP | _DOWN | _RIGHT: "┣", _UP | _DOWN | _LEFT: "┫",
        _LEFT | _RIGHT | _DOWN: "┳", _LEFT | _RIGHT | _UP: "┻",
        _UP | _DOWN | _LEFT | _RIGHT: "╋", _UP: "┃", _DOWN: "┃", _LEFT: "━", _RIGHT: "━"}   # heavy lines


def draw_tree(root, w, h, labels=True):
    """The frame tree as h lines of w characters, algorithm named in each frame
    (labels=False draws the boxes only)."""
    bits = [[0] * w for _ in range(h)]
    labels_ = []

    def rect(x0, y0, x1, y1):
        for x in range(x0, x1 + 1):
            for y in (y0, y1):
                bits[y][x] |= (_LEFT if x > x0 else 0) | (_RIGHT if x < x1 else 0)
        for y in range(y0, y1 + 1):
            for x in (x0, x1):
                bits[y][x] |= (_UP if y > y0 else 0) | (_DOWN if y < y1 else 0)

    def walk(n, x0, y0, x1, y1):
        if n.kind == "clients":
            rect(x0, y0, x1, y1)
            labels_.append((x0 + 2, y0 + 1, n.algo, x1 - 1))
        elif n.direction == "horizontal":
            xm = max(x0 + 2, min(x1 - 2, int(x0 + n.frac * (x1 - x0))))
            walk(n.children[0], x0, y0, xm, y1)
            walk(n.children[1], xm, y0, x1, y1)
        else:
            ym = max(y0 + 2, min(y1 - 2, int(y0 + n.frac * (y1 - y0))))
            walk(n.children[0], x0, y0, x1, ym)
            walk(n.children[1], x0, ym, x1, y1)

    walk(root, 0, 0, w - 1, h - 1)
    rows = [[_BOX.get(b, "+") if b else " " for b in row] for row in bits]
    for x, y, text, xmax in (labels_ if labels else []):
        for i, ch in enumerate(text):
            if x + i < xmax and y < h - 1:
                rows[y][x + i] = ch
    return ["".join(r) for r in rows]


# -------------------------------------------------------------- layout files

def parse_definitions(text):
    """{variable: (lname or '', layout string)} from hlwm_layouts.conf."""
    defs, pending, lines, i = {}, "", text.split("\n"), 0
    while i < len(lines):
        line = lines[i]
        m = re.match(r"^\s*#\s*lname:\s*(.*?)\s*$", line)
        v = re.match(r"^([A-Za-z_]\w*)='(.*)$", line)
        if m:
            pending = m.group(1)
        elif v:
            rest, chunk = v.group(2), []
            while "'" not in rest and i + 1 < len(lines):
                chunk.append(rest)
                i += 1
                rest = lines[i]
            chunk.append(rest.split("'")[0])
            defs[v.group(1)] = (pending, "\n".join(chunk))
            pending = ""
        elif line.strip() and not line.lstrip().startswith("#"):
            pending = ""
        i += 1
    return defs


def parse_assignments(text):
    """{connected-set key: {tag: variable}} from hlwm_tag_layouts.conf."""
    out, lines, i = {}, text.split("\n"), 0
    while i < len(lines):
        m = re.match(r'^TAG_LAYOUTS\["(.*)"\]="(.*)$', lines[i])
        if m:
            block, rest = {}, m.group(2)
            while True:
                closed = rest.rstrip().endswith('"')
                body = rest.rstrip()[:-1] if closed else rest
                body = body.strip()
                if body:
                    tag, _, var = body.rpartition(" ")
                    if tag.strip():
                        block[tag.strip()] = var
                if closed or i + 1 >= len(lines):
                    break
                i += 1
                rest = lines[i]
            out[m.group(1)] = block
        i += 1
    return out


def read_file(path):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return ""


def layout_label(tag, dump, key, defs, assigns):
    """The name to show for a tag: the layout's lname, 'custom' or 'unassigned'."""
    var = assigns.get(key, {}).get(tag)
    if not var:
        return "unassigned"
    if var not in defs:
        return f"unknown layout '{var}'"
    lname, string = defs[var]
    try:
        same = tree_key(parse_tree(dump)) == tree_key(parse_tree(string))
    except ValueError:
        return f"invalid layout '{var}'"
    return (lname or var) if same else "custom"


# ------------------------------------------------------------------ overview

class Overview:
    def __init__(self):
        self.error = ""
        self.tag = self.label = ""
        self.tree = None
        self.model = Model([])
        self.key = ""


def gather():
    data = Overview()
    try:
        data.model = load_model()
        data.key = data.model.key()
    except (OSError, subprocess.CalledProcessError) as e:
        data.error = f"monitors: {e}"
    try:
        data.tag = hc("get_attr", "tags.focus.name")
        dump = hc("dump", data.tag)
        data.tree = parse_tree(dump)
        data.label = layout_label(data.tag, dump, data.key,
                                  parse_definitions(read_file(HLWM_LAYOUTS)),
                                  parse_assignments(read_file(HLWM_TAG_LAYOUTS)))
    except (HlwmError, ValueError) as e:
        data.error = f"herbstluftwm: {e}"
    return data


def numbered(model):
    """Outputs in display order: active left to right, then the ones that are off."""
    on = sorted(model.active(), key=lambda o: (o.x, o.y))
    return on + [o for o in model.outs if not o.on]


def monitor_diagram(model, avail, max_rows=None):
    """The active monitors to scale (80 px per column, 160 per row), numbered.

    Shrinks, keeping the proportions, to fit `avail` columns and `max_rows` rows."""
    return ["".join(r) for r in draw_monitors(model, avail, max_rows)[0]]


def draw_monitors(model, avail, max_rows=None):
    """(character grid, {id(output): (x0, y0, x1, y1)}) behind monitor_diagram."""
    act = model.active()
    if not act:
        return [], {}
    boxes = {}
    nums = {id(o): i + 1 for i, o in enumerate(numbered(model))}
    minx, miny = min(o.x for o in act), min(o.y for o in act)
    tw = max(o.x + o.w for o in act) - minx
    th = max(o.y + o.h for o in act) - miny
    px = max(80.0, tw / max(avail, 1), th / (2 * max_rows) if max_rows else 0)
    cols = max(int(round((o.x - minx + o.w) / px)) for o in act)
    rows = max(int(round((o.y - miny + o.h) / (2 * px))) for o in act)
    grid = [[" "] * cols for _ in range(rows)]
    for o in act:
        x0, y0 = int(round((o.x - minx) / px)), int(round((o.y - miny) / (2 * px)))
        x1 = max(x0 + 5, int(round((o.x - minx + o.w) / px)) - 1)
        y1 = max(y0 + 2, int(round((o.y - miny + o.h) / (2 * px))) - 1)
        x1, y1 = min(x1, cols - 1), min(y1, rows - 1)
        boxes[id(o)] = (x0, y0, x1, y1)
        for x in range(x0, x1 + 1):
            for y in (y0, y1):
                grid[y][x] = "━"
        for y in range(y0, y1 + 1):
            for x in (x0, x1):
                grid[y][x] = "┃"
        for (x, y), ch in (((x0, y0), "┏"), ((x1, y0), "┓"), ((x0, y1), "┗"), ((x1, y1), "┛")):
            grid[y][x] = ch
        for x in range(x0 + 1, x1):
            for y in range(y0 + 1, y1):
                grid[y][x] = " "
        label = f"{nums[id(o)]}{'*' if o.primary else ''}"
        for i, ch in enumerate(label):
            grid[y0 + 1][x0 + 2 + i] = ch
    return grid, boxes


def monitor_details(model):
    lines = []
    for n, o in enumerate(numbered(model), 1):
        star = "*" if o.primary else " "
        if o.on:
            res = o.mode if dims(o.mode) else f"{o.w}x{o.h}"
            lines.append(f"{n}{star}  {o.name:<8}{res:<9}  +{o.x}+{o.y}")
        else:
            lines.append(f"{n}{star}  {o.name:<8}off")
    return lines


PAD = 2                 # spaces between a panel's border and its content, each side
PAD_V = 1               # blank rows between a panel's border and its content, top and bottom
FOOTER = "↑/↓ select   Enter open   ← back   q quit"
FOOTER_ROWS = 2         # the rule and the hint line
MIN_PANEL_ROWS = 3 + 2 * PAD_V   # a border, padding, one line of content, padding, a border


def panel(title, content, w, h, selected):
    """A bordered panel as h rows of (text, role) segments, label in the top left.

    Only the lines of the border carry a role (border / border_sel); the label and the
    content are plain.
    """
    role = "border_sel" if selected else "border"
    iw, ih = w - 2, h - 2
    label = (" " + title + " ")[: max(0, iw - 1)]
    # the label sits on the top border line but stays plain; only the lines are coloured
    rows = [[("┌─", role), (label, "text"), ("─" * (iw - 1 - len(label)) + "┐", role)]]
    for i in range(ih):
        j = i - PAD_V
        item = content[j] if 0 <= j < min(len(content), ih - 2 * PAD_V) else ""
        if isinstance(item, str):
            body = [((" " * PAD + item)[: iw - PAD].ljust(iw), "text")]
        else:   # already (text, role) segments, e.g. other panels
            room, clipped = iw - PAD, []
            for text, seg_role in item:
                clipped.append((text[: max(0, room)], seg_role))
                room -= len(text)
            body = [(" " * PAD, "text"), *clipped, (" " * max(0, room), "text")]
        rows.append([("│", role), *body, ("│", role)])
    rows.append([("└" + "─" * iw + "┘", role)])
    return rows


def layout_content(data, cw, ch):
    """What goes inside the Layout panel: tag, layout name, the frame drawing."""
    if data.tree is None:
        return [data.error or "no layout"]
    lines = [f"Tag      {data.tag}", f"Layout   {data.label}", ""]
    th, tw = min(9, ch - len(lines)), min(36, cw)
    if th >= 3 and tw >= 8:
        lines += [[(l, "art")] for l in draw_tree(data.tree, tw, th)]   # drawings are grey
    return lines


def monitors_content(data, cw, ch):
    """What goes inside the Monitors panel: the diagram, then the numbered details."""
    if not data.model.outs:
        return [data.error or "no monitors"]
    details = monitor_details(data.model)
    room = ch - len(details) - 1
    diagram = monitor_diagram(data.model, cw, room) if room >= 3 else []
    return [[(l, "art")] for l in diagram] + ([""] if diagram else []) + details


def split_height(height):
    """Heights of the two panels: half each of what the footer leaves, the odd row to the bottom one."""
    avail = height - FOOTER_ROWS
    return avail // 2, avail - avail // 2


def footer_width(footer):
    """The least width the footer needs: title, a gap, the hints, and the unwritable last cell."""
    title, hints = footer
    return len(title) + 2 + len(hints) + 1


def fits(height, width, footer):
    return height >= FOOTER_ROWS + 2 * MIN_PANEL_ROWS and width >= footer_width(footer)


def overview_footer():
    """(page title, key hints): the title goes on the left, the hints on the right."""
    return "Overview", FOOTER


def placeholder_footer(name):
    return name, "Esc back   q quit"


def render_overview(data, sel, width, height):
    """The overview as (rows, footer): rows are lists of (text, role) segments."""
    h1, h2 = split_height(height)
    cw = width - 2 - 2 * PAD
    rows = panel("Layout", layout_content(data, cw, h1 - 2 - 2 * PAD_V), width, h1, sel == 0)
    rows += panel("Monitors", monitors_content(data, cw, h2 - 2 - 2 * PAD_V), width, h2, sel == 1)
    return rows, overview_footer()


def render_placeholder(name, width, height):
    rows = panel(name, ["Not built yet."], width, height - FOOTER_ROWS, True)
    return rows, placeholder_footer(name)


# ------------------------------------------------------------- layout screen

SCROLLBAR_W = 2                         # a gap and the bar, kept free so the grid does not shift
CELL_W, CELL_H, CELL_GAP = 28, 11, 1    # one cell of the layouts grid
THUMB_W, THUMB_H = 22, 7                # the drawing inside a cell (about a monitor's shape: a character is twice as tall as wide)
CUR_DRAW_W, CUR_DRAW_H = 26, 8          # the drawing in the Current panel
CUR_H = CUR_DRAW_H + 2 + 2 * PAD_V      # border, padding, drawing, padding, border
LAYOUT_MIN_ROWS = FOOTER_ROWS + CUR_H + CELL_H + 2 + 2 * PAD_V
NEW_LAYOUT = "(\n    clients vertical:0\n)"

HINTS_MOVE = "↑↓←→ select"
HINTS_END = "Esc back   q quit"
PLUS = ["", "", "  ┃  ", "━━╋━━", "  ┃  ", "", ""]   # THUMB_H rows, 5 wide


REF_W = 50                  # the syntax column of the editor
EDIT_TWO_COLUMNS = 100      # narrower windows get the editor alone

def _title(text, desc="", width=0):
    return [(text.ljust(width), "bold")] + ([("  " + desc, "dim")] if desc else [])


def _desc(text):
    return [(text, "dim")]


_NESTED = ["(split horizontal:0.5:0",
           "    (clients max:0)",
           "    (split vertical:0.5:0",
           "        (clients max:0)",
           "        (clients max:0)))"]

# bold white for each thing, light grey for what it means
SYNTAX = [
    _title("(clients ALGO:SEL)"),
    _desc("  a frame that holds windows"),
    _title("(split DIR:FRAC:SEL A B)"),
    _desc("  cuts a frame in two; A and B are frames"),
    "",
    _title("Nesting"),
    _desc("  A or B can be another split:"),
    *[[(line, "text")] for line in _NESTED],
    _desc("  the left half; the right half cut in two:"),
    *[[(line, "art")] for line in draw_tree(parse_tree("\n".join(_NESTED)), 22, 5, labels=False)],
    "",
    _title("ALGO", "how windows share a frame", 6),
    _title("  vertical", "stacked", 14),
    _title("  horizontal", "side by side", 14),
    _title("  max", "one at a time", 14),
    _title("  grid", "in a grid", 14),
    _title("DIR", "where A goes", 6),
    _title("  horizontal", "A left, B right", 14),
    _title("  vertical", "A above, B below", 14),
    _title("FRAC", "A's share: above 0, below 1", 6),
    _title("SEL", "a number; 0 will do", 6),
    _desc("No single quote anywhere in LAYOUT."),
]


def entry_text(var, lname, string):
    return f"# lname: {lname}\n{var}='{string}'"


def entry_span(lines, var):
    """(first, last) line numbers of var's definition in hlwm_layouts.conf, including the
    `# lname:` line directly above it; None if there is no such variable."""
    i = 0
    while i < len(lines):
        m = re.match(r"^([A-Za-z_]\w*)='(.*)$", lines[i])
        if m:
            j, rest = i, m.group(2)
            while "'" not in rest and j + 1 < len(lines):
                j += 1
                rest = lines[j]
            if m.group(1) == var:
                named = i > 0 and re.match(r"^\s*#\s*lname:", lines[i - 1])
                return (i - 1 if named else i), j
            i = j
        i += 1
    return None


def put_entry(text, var, lname, string):
    """The file text with var's definition replaced, or added at the end."""
    lines, new = text.split("\n"), entry_text(var, lname, string).split("\n")
    span = entry_span(lines, var)
    if span:
        lines[span[0]: span[1] + 1] = new
    else:
        while lines and lines[-1] == "":
            lines.pop()
        lines += ([""] if lines else []) + new + [""]
    return "\n".join(lines)


def drop_entry(text, var):
    """The file text without var's definition (and the blank line after it)."""
    lines = text.split("\n")
    span = entry_span(lines, var)
    if not span:
        return text
    a, b = span
    if b + 2 < len(lines) and lines[b + 1] == "":
        b += 1
    del lines[a: b + 1]
    while len(lines) > 1 and lines[-1] == "" and lines[-2] == "":
        lines.pop()
    return "\n".join(lines)


def make_var(lname, taken):
    """A variable name made up from an lname: lowercase, digits, underscores, unused."""
    base = re.sub(r"[^a-z0-9]+", "_", lname.lower()).strip("_") or "layout"
    if base[0].isdigit():
        base = "layout_" + base
    var, n = base, 2
    while var in taken:
        var, n = f"{base}_{n}", n + 1
    return var


def check_edit(text, orig_var, defs):
    """(variable, lname, layout) from what the editor holds, or ValueError saying what is wrong.

    A new layout (orig_var None) gets its variable made up from the lname; an existing
    one must keep its variable."""
    if text.count("'") != 2:
        raise ValueError("the layout goes in one pair of single quotes, with none inside it")
    m = re.fullmatch(r"\s*#\s*lname:[ \t]*([^\n]*?)[ \t]*\n([A-Za-z_]\w*)='(.*)'\s*", text, re.S)
    if not m:
        raise ValueError("expected a '# lname: NAME' line, then variable='( ... )'")
    lname, var, string = m.groups()
    if not lname:
        raise ValueError("the lname is empty")
    if orig_var is None:
        var = make_var(lname, set(defs))
    elif var != orig_var:
        raise ValueError(f"the variable must stay '{orig_var}'")
    try:
        parse_tree(string, strict=True)
    except ValueError as e:
        raise ValueError(f"layout: {e}")
    return var, lname, string


def format_tree(n):
    """A frame tree as a layout string in the style of hlwm_layouts.conf (no window ids)."""
    def lines(n, ind):
        pad = " " * ind
        if n.kind == "clients":
            return [f"{pad}(clients {n.algo}:0)"]
        out = [f"{pad}(split {n.direction}:{n.frac:g}:0"]
        for c in n.children:
            out += lines(c, ind + 4)
        return out + [f"{pad})"]

    if n.kind == "clients":
        return f"(\n    clients {n.algo}:0\n)"
    body = [f"    split {n.direction}:{n.frac:g}:0"]
    for c in n.children:
        body += lines(c, 8)
    return "(\n" + "\n".join(body) + "\n)"


def current_name(tree, defs):
    """(name, is_custom): the lname of the first saved layout with the tree's structure."""
    for var, (lname, string) in defs.items():
        try:
            if tree_key(parse_tree(string)) == tree_key(tree):
                return lname or var, False
        except ValueError:
            continue
    return "custom", True


def thumbnail(string):
    try:
        return draw_tree(parse_tree(string), THUMB_W, THUMB_H, labels=False)
    except ValueError:
        return ["", "  invalid layout"]


def grid_geometry(width, height):
    """(columns of cells, lines of grid showing) in the Layouts panel."""
    ncols = max(1, (width - 2 - 2 * PAD - SCROLLBAR_W + CELL_GAP) // (CELL_W + CELL_GAP))
    lines = max(1, height - FOOTER_ROWS - CUR_H - 2 - 2 * PAD_V)
    return ncols, lines


def layout_min_width():
    return footer_width(("Layout", f"{HINTS_MOVE}   Enter set   e edit   d delete   s save   {HINTS_END}"))


def write_file(path, text):
    with open(path, "w") as f:
        f.write(text)


class Editor:
    """A small multi-line text editor: lines, a cursor, scroll offsets."""

    def __init__(self, text):
        self.lines = text.split("\n")
        self.row, self.col = 0, len(self.lines[0])
        self.top = self.left = 0

    def text(self):
        return "\n".join(self.lines)

    def handle(self, key):
        lines, r, c = self.lines, self.row, self.col
        if key == "LEFT":
            if c > 0:
                c -= 1
            elif r > 0:
                r, c = r - 1, len(lines[r - 1])
        elif key == "RIGHT":
            if c < len(lines[r]):
                c += 1
            elif r + 1 < len(lines):
                r, c = r + 1, 0
        elif key == "UP" and r > 0:
            r -= 1
        elif key == "DOWN" and r + 1 < len(lines):
            r += 1
        elif key == "HOME":
            c = 0
        elif key == "END":
            c = len(lines[r])
        elif key == "BACKSPACE":
            if c > 0:
                lines[r] = lines[r][: c - 1] + lines[r][c:]
                c -= 1
            elif r > 0:
                c = len(lines[r - 1])
                lines[r - 1] += lines.pop(r)
                r -= 1
        elif key == "DELETE":
            if c < len(lines[r]):
                lines[r] = lines[r][:c] + lines[r][c + 1:]
            elif r + 1 < len(lines):
                lines[r] += lines.pop(r + 1)
        elif key == "ENTER":
            lines[r:r + 1] = [lines[r][:c], lines[r][c:]]
            r, c = r + 1, 0
        elif len(key) == 1 and key.isprintable():
            lines[r] = lines[r][:c] + key + lines[r][c:]
            c += 1
        self.row, self.col = r, min(c, len(lines[r]))

    def scroll(self, ih, iw):
        """Keep the cursor inside an ih x iw window onto the text."""
        self.top = max(0, min(self.top, self.row), self.row - ih + 1)
        self.left = max(0, min(self.left, self.col), self.col - iw + 1)


class LayoutScreen:
    """The Layout screen: the focused tag's layout above a grid of the saved layouts.

    handle() takes the key names from norm_key() and returns "back", "quit" or None."""

    def __init__(self):
        self.sel = self.top = 0         # sel 0 is the Create new cell, then the layouts in file order
        self.mode = "browse"            # browse | confirm | edit
        self.message = ""
        self.confirm = None             # ("set" | "delete", variable)
        self.editor = None
        self.edit_var = None            # variable being edited; None for a new layout
        self.refresh()

    def refresh(self):
        self.defs = parse_definitions(read_file(HLWM_LAYOUTS))
        self.error, self.tag, self.tree = "", "", None
        try:
            self.tag = hc("get_attr", "tags.focus.name")
            self.tree = parse_tree(hc("dump", self.tag))
        except (HlwmError, ValueError) as e:
            self.error = f"herbstluftwm: {e}"
        self.name, self.custom = current_name(self.tree, self.defs) if self.tree else ("", False)
        self.sel = min(self.sel, len(self.defs))

    def var(self):
        """The selected cell's variable; None on Create new."""
        return None if self.sel == 0 else list(self.defs)[self.sel - 1]

    def title(self, var):
        return self.defs[var][0] or var

    def used_by(self, var):
        assigns = parse_assignments(read_file(HLWM_TAG_LAYOUTS))
        return sum(1 for blk in assigns.values() for v in blk.values() if v == var)

    # ---- keys

    def handle(self, key, ncols):
        self.message = ""
        if self.mode == "edit":
            return self.handle_edit(key)
        if self.mode == "confirm":
            return self.handle_confirm(key)
        n = len(self.defs) + 1
        if key in ("q", "CTRL_C"):
            return "quit"
        if key == "ESC":
            return "back"
        if key == "LEFT":
            self.sel = max(0, self.sel - 1)
        elif key == "RIGHT":
            self.sel = min(n - 1, self.sel + 1)
        elif key == "UP" and self.sel - ncols >= 0:
            self.sel -= ncols
        elif key == "DOWN":
            if self.sel + ncols < n:
                self.sel += ncols
            elif self.sel // ncols < (n - 1) // ncols:
                self.sel = n - 1
        elif key == "ENTER":
            if self.sel == 0:
                self.begin_edit(None, NEW_LAYOUT)
            elif self.tree is None:
                self.message = self.error or "no tag to set it on"
            else:
                self.confirm, self.mode = ("set", self.var()), "confirm"
        elif key == "e" and self.sel > 0:
            self.begin_edit(self.var(), self.defs[self.var()][1])
        elif key == "d" and self.sel > 0:
            self.confirm, self.mode = ("delete", self.var()), "confirm"
        elif key == "s" and self.custom and self.tree:
            self.begin_edit(None, format_tree(self.tree))
        return None

    def begin_edit(self, var, string):
        lname = self.defs[var][0] if var else ""
        self.editor = Editor(entry_text(var or "layout", lname, string))
        self.edit_var, self.mode = var, "edit"

    def handle_edit(self, key):
        if key in ("ESC", "CTRL_C"):
            self.mode = "browse"
        elif key == "CTRL_S":
            self.save()
        elif key not in ("RESIZE", "TAB"):
            self.editor.handle(key)
        return None

    def save(self):
        try:
            var, lname, string = check_edit(self.editor.text(), self.edit_var, self.defs)
            write_file(HLWM_LAYOUTS, put_entry(read_file(HLWM_LAYOUTS), var, lname, string))
        except (ValueError, OSError) as e:
            self.message = str(e)
            return
        self.mode = "browse"
        self.refresh()
        self.sel = list(self.defs).index(var) + 1

    def handle_confirm(self, key):
        if key in ("n", "ESC", "CTRL_C"):
            self.mode = "browse"
        elif key == "y":
            action, var = self.confirm
            self.mode = "browse"
            try:
                if action == "set":
                    hc("load", self.tag, self.defs[var][1])
                else:
                    write_file(HLWM_LAYOUTS, drop_entry(read_file(HLWM_LAYOUTS), var))
            except (HlwmError, OSError) as e:
                self.message = str(e)
            self.refresh()
        return None

    # ---- drawing

    def footer(self):
        if self.mode == "confirm":
            action, var = self.confirm
            if action == "set":
                prompt = f'Set "{self.title(var)}" on tag {self.tag}?'
            else:
                n = self.used_by(var)
                prompt = f'Delete "{self.title(var)}"?' + (f" Used by {n} tag assignment{'s' * (n != 1)}." if n else "")
            return prompt, "y yes   n no"
        if self.mode == "edit":
            return self.message or "Edit", "Ctrl-S save   Esc cancel"
        keys = ["Enter create"] if self.sel == 0 else ["Enter set", "e edit", "d delete"]
        return self.message or "Layout", "   ".join([HINTS_MOVE, *keys, HINTS_END])

    def scroll(self, ncols, lines, total):
        """The grid scrolls a line at a time inside its panel (self.top is the first line
        showing), by the least that brings the selected cell fully into view."""
        first = self.sel // ncols * CELL_H
        self.top = max(0, min(self.top, first), first + CELL_H - lines)
        self.top = min(self.top, max(0, total - lines))

    def cell(self, i, selected):
        if i == 0:
            art = [" " * ((THUMB_W - 5) // 2) + line for line in PLUS]
            return panel("Create new", [[(line, "art")] for line in art], CELL_W, CELL_H, selected)
        var = list(self.defs)[i - 1]
        return panel(self.title(var), [[(line, "art")] for line in thumbnail(self.defs[var][1])], CELL_W, CELL_H, selected)

    def current_content(self, cw):
        """The Current panel: Tag and Layout (bold label, plain value) with the drawing beside them."""
        if self.tree is None:
            return [self.error or "no layout"]
        note = [[("Not saved as a layout.", "dim")], [("s", "bold"), (" to save it", "dim")]] if self.custom else []
        lw = max(7 + max(len(self.tag), len(self.name)), *(sum(len(t) for t, _ in n) for n in note), 0) + 4
        dw = min(CUR_DRAW_W, cw - lw)
        art = draw_tree(self.tree, dw, CUR_DRAW_H, labels=False) if dw >= 8 else []
        rows = []
        for i in range(CUR_DRAW_H):
            label, value = (("Tag", self.tag), ("Layout", self.name))[i] if i < 2 else ("", "")
            left = [(label, "bold"), (" " * (7 - len(label)) + value, "text")] if label else []
            if 3 <= i < 3 + len(note):
                left = list(note[i - 3])
            left.append((" " * (lw - sum(len(t) for t, _ in left)), "text"))
            rows.append(left + ([(art[i], "art")] if art else []))
        return rows

    def render(self, width, height):
        """(rows, footer, cursor)."""
        if self.mode == "edit":
            return self.render_edit(width, height)
        ncols, lines = grid_geometry(width, height)
        cw = width - 2 - 2 * PAD
        current = self.current_content(cw)
        rows = panel("Current", current, width, CUR_H, False)
        cells = len(self.defs) + 1
        grid = []
        for r in range((cells + ncols - 1) // ncols):
            idx = list(range(r * ncols, min(cells, (r + 1) * ncols)))
            boxes = [self.cell(i, i == self.sel) for i in idx]
            for k in range(CELL_H):
                line = []
                for b, box in enumerate(boxes):
                    line += ([(" " * CELL_GAP, "text")] if b else []) + box[k]
                grid.append(line)
        self.scroll(ncols, lines, len(grid))
        total = len(grid)
        grid = grid[self.top: self.top + lines]
        if total > lines:   # a scroll bar at the right edge: a light track and a white thumb
            thumb = max(1, round(lines * lines / total))
            start = round(self.top / (total - lines) * (lines - thumb))
            for k, line in enumerate(grid):
                used = sum(len(t) for t, _ in line)
                bar = ("█", "text") if start <= k < start + thumb else ("░", "dim")
                grid[k] = line + [(" " * (cw - 1 - used), "text"), bar]
        rows += panel("Layouts", grid, width, height - FOOTER_ROWS - CUR_H, False)
        return rows, self.footer(), None

    def render_edit(self, width, height):
        """The editor on the left; on a wide enough window the syntax reference on the right."""
        ed = self.editor
        h = height - FOOTER_ROWS
        left_w = width - REF_W - 1 if width >= EDIT_TWO_COLUMNS else width
        ih, iw = h - 2 - 2 * PAD_V, left_w - 2 - 2 * PAD
        ed.scroll(ih, iw)
        shown = [line[ed.left: ed.left + iw] for line in ed.lines[ed.top: ed.top + ih]]
        title = "New layout" if self.edit_var is None else self.title(self.edit_var)
        rows = panel(title, shown, left_w, h, True)
        if left_w < width:
            rows = [a + [(" ", "text")] + b for a, b in zip(rows, panel("Syntax", SYNTAX, REF_W, h, False))]
        return rows, self.footer(), (1 + PAD_V + ed.row - ed.top, 1 + PAD + ed.col - ed.left)


# ----------------------------------------------------------- monitors screen

ARROW_DIRS = {"UP": (0, -1), "DOWN": (0, 1), "LEFT": (-1, 0), "RIGHT": (1, 0)}
MON_INFO_H = 3 + 2 + 2 * PAD_V          # the info panel: three lines in a bordered, padded panel
MONITORS_MIN_ROWS = FOOTER_ROWS + MON_INFO_H + 2 + 2 * PAD_V + 7
BROWSE_HINTS = "←↑↓→ select   p primary   m move   r resolution   e edit   Esc back   q quit"
MOVE_HINTS = "←↑↓→ 10px   Ctrl 1px   Shift 100px   Alt hop   Ctrl-S done   Esc cancel"
INPUT_HINTS = "Ctrl-S apply   Esc cancel"
RES_HINTS = "↑↓ select   Enter choose   Esc cancel"
RES_W = 44                              # width of the resolution overlay
CUSTOM_ROW = ("Custom…", "", False, False)


def monitors_min_width():
    return max(footer_width(("Monitors", h)) for h in (BROWSE_HINTS, MOVE_HINTS))


def neighbour(model, o, dx, dy):
    """The nearest other active output in a direction (the offset across counts double), or None."""
    cx, cy = o.x + o.w / 2, o.y + o.h / 2
    best, best_score = None, None
    for a in model.active():
        if a is o:
            continue
        ax, ay = a.x + a.w / 2 - cx, a.y + a.h / 2 - cy
        along = ax * dx + ay * dy
        across = abs(ay * dx) + abs(ax * dy)
        if along <= 0 or across > along:        # only what lies within 45 degrees of the direction
            continue
        score = along + 2 * across
        if best_score is None or score < best_score:
            best, best_score = a, score
    return best


def frame_for(model, avail, rows):
    """(origin x, origin y, px per column) of a canvas avail x rows with the group centred in it,
    scaled so the group takes at most 80% of either side (room to move it about)."""
    act = model.active()
    minx, miny = min(o.x for o in act), min(o.y for o in act)
    tw = max(o.x + o.w for o in act) - minx
    th = max(o.y + o.h for o in act) - miny
    px = max(80.0, tw / (0.8 * max(avail, 1)), th / (2 * 0.8 * max(rows, 1)))
    return minx + tw / 2 - px * avail / 2, miny + th / 2 - px * rows, px


def draw_canvas(model, avail, rows, frame, nums, selected=None):
    """The whole canvas as `rows` rows of (text, role) segments: monitors at their place in `frame`,
    numbered by `nums` {name: number}, the selected one's lines and number in border_sel."""
    ox, oy, px = frame
    grid = [[(" ", "art")] * avail for _ in range(rows)]
    for o in sorted(model.active(), key=lambda a: a is selected):
        x0, y0 = round((o.x - ox) / px), round((o.y - oy) / (2 * px))
        x1 = max(x0 + 5, round((o.x + o.w - ox) / px) - 1)
        y1 = max(y0 + 2, round((o.y + o.h - oy) / (2 * px)) - 1)
        role = "border_sel" if o is selected else "art"
        cells = {}
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                edge_x, edge_y = x in (x0, x1), y in (y0, y1)
                cells[(x, y)] = ("┏┓┗┛"[(y == y1) * 2 + (x == x1)] if edge_x and edge_y
                                 else "━" if edge_y else "┃" if edge_x else " ")
        label = f"{nums.get(o.name, '?')}{'*' if o.primary else ''}"
        for i, ch in enumerate(label):
            cells[(x0 + 2 + i, y0 + 1)] = ch
        for (x, y), ch in cells.items():
            if 0 <= x < avail and 0 <= y < rows:
                grid[y][x] = (ch, role)
    return [runs_of([(ch, role) for ch, role in row]) for row in grid]


def cells_of(row, width):
    cells = [(ch, role) for text, role in row for ch in text]
    return cells + [(" ", "text")] * (width - len(cells))


def runs_of(cells):
    out = []
    for ch, role in cells:
        if out and out[-1][1] == role:
            out[-1] = (out[-1][0] + ch, role)
        else:
            out.append((ch, role))
    return out


def overlay(rows, box, top, left, width):
    """The rows with the panel `box` drawn over them at (top, left)."""
    out = []
    for y, row in enumerate(rows):
        if top <= y < top + len(box):
            cells = cells_of(row, width)
            b = cells_of(box[y - top], 0)
            cells[left: left + len(b)] = b
            row = runs_of(cells)
        out.append(row)
    return out


def scroll_bar(k, total, shown, top):
    """The scroll bar cell for line k of `shown` lines in a list of `total` starting at `top`."""
    thumb = max(1, round(shown * shown / total))
    start = round(top / (total - shown) * (shown - thumb))
    return ("█", "text") if start <= k < start + thumb else ("░", "dim")


def kv(label, value):
    return [(label.ljust(12), "bold"), (value, "text")]


class MonitorScreen:
    """The Monitors screen: the monitors to scale above an info panel for the selected one.

    handle() takes the key names from read_key() and returns "back", "quit" or None.
    Changes are applied through monitor_reconcile.sh --layout as soon as they are confirmed."""

    def __init__(self):
        self.mode, self.message, self.name = "browse", "", ""
        self.confirm = self.editor = self.before = None
        self.prev = "browse"
        self.frame = self.nums = None       # a move keeps its canvas and its numbering until saved
        self.res_rows, self.res_sel, self.res_top = [], 0, 0
        self.reload()

    def reload(self, keep=None):
        keep = keep or self.name
        try:
            self.model, self.error = load_model(), ""
        except (OSError, subprocess.CalledProcessError) as e:
            self.model, self.error = Model([]), f"monitors: {e}"
        names = [o.name for o in self.model.active()]
        self.name = keep if keep in names else (names[0] if names else "")

    def cur(self):
        return next((o for o in self.model.active() if o.name == self.name), None)

    # ---- keys

    def handle(self, key, ncols=0):
        self.message = ""
        return getattr(self, "key_" + self.mode)(key)

    def key_browse(self, key):
        o = self.cur()
        if key in ("q", "CTRL_C"):
            return "quit"
        if key == "ESC":
            return "back"
        if not o:
            return None
        if key in ARROW_DIRS:
            a = neighbour(self.model, o, *ARROW_DIRS[key])
            if a:
                self.name = a.name
        elif key == "p":
            if o.primary:
                self.message = f"{o.name} is already the primary"
            else:
                self.confirm, self.mode = f"Make {o.name} the primary?", "confirm"
        elif key == "m":
            self.before = self.model.copy()
            self.nums = {a.name: i + 1 for i, a in enumerate(numbered(self.model))}
            self.frame = None           # taken on the first draw, then held
            self.mode = "move"
        elif key == "e":
            self.begin_edit()
        elif key == "r":
            self.begin_resolution()
        return None

    def key_confirm(self, key):
        if key == "y":
            self.before = self.model.copy()
            self.model.make_primary(self.cur())
            self.apply()
        elif key in ("n", "ESC", "CTRL_C"):
            self.mode = "browse"
        return None

    def key_move(self, key):
        o = self.cur()
        if key == "ESC":
            self.model, self.mode = self.before, "browse"
            self.frame = self.nums = None
        elif key == "CTRL_S":
            self.apply()
        elif key == "e":
            self.begin_edit()
        else:
            m = re.fullmatch(r"(CTRL_|SHIFT_|ALT_)?(UP|DOWN|LEFT|RIGHT)", key)
            if m:
                dx, dy = ARROW_DIRS[m.group(2)]
                if m.group(1) == "ALT_":
                    self.message = self.model.hop(o, dx, dy)
                else:
                    step = {"CTRL_": 1, "SHIFT_": 100, None: 10}[m.group(1)]
                    self.message = self.model.move_by(o, dx * step, dy * step)
        return None

    def begin_edit(self):
        self.prev = self.mode
        if self.mode == "browse":
            self.before = self.model.copy()
        self.editor = Editor(self.model.geometry(self.cur()))
        self.mode = "edit"

    def key_edit(self, key):
        if key in ("ESC", "CTRL_C"):
            self.mode = self.prev
            if self.prev == "browse":
                self.model = self.before
        elif key == "CTRL_S":
            m = GEOM_SIGNED.match(self.editor.text().strip())
            if not m:
                self.message = "expected WxH+X+Y, like 1920x1080+0+0"
                return None
            w, h, x, y = (int(v) for v in m.groups())
            self.set_size_and_position(f"{w}x{h}", None, x, y)
        elif key not in ("ENTER", "TAB", "RESIZE"):
            self.editor.handle(key)
        return None

    def set_size_and_position(self, mode, rate, x=None, y=None):
        """Try a resolution (and position) on a copy; apply it unless it would overlap another output."""
        trial = self.model.copy()
        o = next(a for a in trial.active() if a.name == self.name)
        if mode != o.mode:
            o.rate = None
        trial.set_mode(o, mode)
        if rate:
            o.rate = rate
        err = trial.move_to(o, o.x if x is None else x, o.y if y is None else y)
        if err:
            self.message = err
            return
        self.model = trial
        self.apply()

    def begin_resolution(self):
        o = self.cur()
        entries = o.rates or [(m, "", False, False) for m in o.modes]
        area = lambda e: (dims(e[0]) or (0, 0))[0] * (dims(e[0]) or (0, 0))[1]
        self.res_rows = [CUSTOM_ROW] + sorted(entries, key=lambda e: (-area(e), -float(e[1] or 0)))
        self.res_sel = next((i for i, e in enumerate(self.res_rows) if i and e[2]), 1 if len(self.res_rows) > 1 else 0)
        self.res_top = 0
        self.before = self.model.copy()
        self.mode = "resolution"

    def key_resolution(self, key):
        n = len(self.res_rows)
        if key in ("ESC", "CTRL_C"):
            self.mode = "browse"
        elif key == "UP":
            self.res_sel = max(0, self.res_sel - 1)
        elif key == "DOWN":
            self.res_sel = min(n - 1, self.res_sel + 1)
        elif key == "PGUP":
            self.res_sel = max(0, self.res_sel - 8)
        elif key == "PGDN":
            self.res_sel = min(n - 1, self.res_sel + 8)
        elif key == "HOME":
            self.res_sel = 0
        elif key == "END":
            self.res_sel = n - 1
        elif key == "ENTER":
            o = self.cur()
            if self.res_sel == 0:
                self.editor = Editor(f"{o.w}x{o.h}" + (f" {o.rate}" if o.rate else ""))
                self.mode = "custom"
            else:
                mode, rate, _, _ = self.res_rows[self.res_sel]
                self.set_size_and_position(mode, rate)
        return None

    def key_custom(self, key):
        if key in ("ESC", "CTRL_C"):
            self.mode = "resolution"
        elif key == "CTRL_S":
            m = re.fullmatch(r"(\d+)x(\d+)(?:\s+(\d+(?:\.\d+)?))?", self.editor.text().strip())
            if not m:
                self.message = "expected WxH, or WxH and the Hz, like 1920x1080 60"
                return None
            self.set_size_and_position(f"{m.group(1)}x{m.group(2)}", m.group(3))
        elif key not in ("ENTER", "TAB", "RESIZE"):
            self.editor.handle(key)
        return None

    def apply(self):
        """Apply self.model through monitor_reconcile.sh; on failure put self.before back."""
        self.mode = "browse"
        self.frame = self.nums = None       # saved: centre the group again and number by position
        rc, err = apply_lines(self.model.layout_lines())
        if rc != 0:
            self.model = self.before
            self.message = err.splitlines()[-1] if err else "applying failed"
            return
        if not DRY:
            self.reload(keep=self.name)
        self.message = "applied"

    # ---- drawing

    def footer(self):
        if self.mode == "confirm":
            return self.confirm, "y yes   n no"
        if self.mode == "move":
            return self.message or f"Move {self.name}", MOVE_HINTS
        if self.mode in ("edit", "custom"):
            return self.message or ("Edit " if self.mode == "edit" else "Custom resolution ") + self.name, INPUT_HINTS
        if self.mode == "resolution":
            return self.message or f"Resolution {self.name}", RES_HINTS
        return self.message or "Monitors", BROWSE_HINTS

    def diagram(self, avail, rows):
        """The monitors on a canvas filling the panel. Browsing centres the group and numbers it by
        position; a move holds the canvas and the numbers as they were, so the monitor moves freely."""
        if not self.model.active():
            return []
        if self.mode == "move" and self.frame is None:
            self.frame = frame_for(self.model, avail, rows)
        frame = self.frame if self.mode == "move" else frame_for(self.model, avail, rows)
        return draw_canvas(self.model, avail, rows, frame, self.numbers(), self.cur())

    def numbers(self):
        return self.nums if self.mode in ("move", "edit", "custom", "resolution") and self.nums else \
            {a.name: i + 1 for i, a in enumerate(numbered(self.model))}

    def info(self):
        o = self.cur()
        if not o:
            return "", [self.error or "no active monitors"]
        nums = self.numbers()
        rate = o.rate or next((r for m, r, c, _ in o.rates if c and m == o.mode), "")
        mode = o.mode if dims(o.mode) else f"{o.w}x{o.h}"
        lines = [kv("Output", o.name.ljust(14)) + kv("Primary", "yes" if o.primary else "no"),
                 kv("Mode", mode + (f" @ {rate} Hz" if rate else "")),
                 kv("Position", self.model.geometry(o)) + ([("   moving", "dim")] if self.mode == "move" else [])]
        return f"{nums[o.name]}{'*' if o.primary else ''}  {o.name}", lines

    def render(self, width, height):
        """(rows, footer, cursor)."""
        top_h = height - FOOTER_ROWS - MON_INFO_H
        cw = width - 2 - 2 * PAD
        o = self.cur()
        content = self.diagram(cw, top_h - 2 - 2 * PAD_V) if o else [self.error or "no active monitors"]
        rows = panel("Monitors", content, width, top_h, False)
        title, lines = self.info()
        rows += panel(title, lines, width, MON_INFO_H, False)
        cursor = None
        body = height - FOOTER_ROWS
        if self.mode == "resolution":
            box, top = self.res_box(body)
            rows = overlay(rows, box, top, (width - RES_W) // 2, width)
        elif self.mode in ("edit", "custom"):
            box, top, cursor = self.input_box(body, width)
            left = self.box_left(box, width)
            rows = overlay(rows, box, top, left, width)
            cursor = (cursor[0], left + cursor[1])
        return rows, self.footer(), cursor

    @staticmethod
    def box_left(box, width):
        return (width - sum(len(t) for t, _ in box[0])) // 2

    def res_box(self, body):
        n = len(self.res_rows)
        bh = max(7, min(n + 2 + 2 * PAD_V, body - 2))
        vis = bh - 2 - 2 * PAD_V
        iw = RES_W - 2 - 2 * PAD
        self.res_top = max(0, min(self.res_top, self.res_sel), self.res_sel - vis + 1)
        lines = []
        for k, (mode, rate, cur, pref) in enumerate(self.res_rows[self.res_top: self.res_top + vis]):
            i = self.res_top + k
            text = mode if i == 0 else f"{mode:<12}{rate:>8}{' Hz' if rate else ''}  {'*' if cur else ' '}{'+' if pref else ' '}"
            text = ("› " if i == self.res_sel else "  ") + text
            line = [(text, "label" if i == self.res_sel else "text")]
            if n > vis:
                line += [(" " * (iw - 1 - len(text)), "text"), scroll_bar(k, n, vis, self.res_top)]
            lines.append(line)
        return panel("Resolution", lines, RES_W, bh, True), (body - bh) // 2

    def input_box(self, body, width):
        edit = self.mode == "edit"
        bw = min(54, width - 4)
        bh = 3 + 2 + 2 * PAD_V
        ed = self.editor
        iw = bw - 2 - 2 * PAD
        ed.scroll(1, iw)
        help_ = "WxH+X+Y, as herbstluftwm reads it" if edit else "WxH, and the Hz after a space if you want one"
        lines = [[(help_, "dim")], "", ed.lines[0][ed.left: ed.left + iw]]
        top = (body - bh) // 2
        cursor = (top + 1 + PAD_V + 2, 1 + PAD + ed.col - ed.left)
        return panel(("Edit " if edit else "Custom resolution ") + self.name, lines, bw, bh, True), top, cursor


# ----------------------------------------------------------------- curses UI

def put(win, y, x, s, attr=0):
    h, w = win.getmaxyx()
    if y < 0 or y >= h or x >= w:
        return
    room = w - x if y < h - 1 else w - x - 1   # the bottom-right cell cannot be written
    try:
        win.addstr(y, max(x, 0), s[: max(0, room)], attr)
    except curses.error:
        pass


ART_GREY = 245                  # xterm #8a8a8a; the footer descriptions use 248
SELECT_SLOT = 200               # a colour slot we redefine to the exact green
SELECT_RGB = (0x2E, 0x7D, 0x32)  # col_green
ATTR = {"art": 0, "bold": curses.A_BOLD, "label": 0, "key": 0, "dim": 0, "border": 0, "border_sel": 0, "text": 0}


def cube_rgb(n):
    """The standard xterm 256-colour value of slot n (16..231), to restore it."""
    levels = (0, 95, 135, 175, 215, 255)
    n -= 16
    return levels[n // 36], levels[(n // 6) % 6], levels[n % 6]


def init_colours():
    """Set up colours; returns a function that puts the terminal's colours back."""
    # wrapper() starts colour mode, which otherwise paints explicit white-on-black
    # over the terminal's own (here translucent) background
    try:
        curses.use_default_colors()
    except curses.error:
        pass
    restore = lambda: None
    green = curses.COLOR_GREEN
    dim_fg = curses.COLOR_WHITE
    if curses.COLORS >= 256:
        dim_fg = 248                # C_DIM in setup/quickstart_arch.sh
        green = 28                  # fallback: the nearest green hue in the fixed palette
        if curses.can_change_color():
            # the fixed palette has nothing close to #2E7D32, so define it exactly
            try:
                curses.init_color(SELECT_SLOT, *(round(v * 1000 / 255) for v in SELECT_RGB))
                green = SELECT_SLOT
                restore = lambda: curses.init_color(SELECT_SLOT, *(round(v * 1000 / 255) for v in cube_rgb(SELECT_SLOT)))
            except curses.error:
                pass
    try:
        curses.init_pair(1, green, -1)          # the one green: selected border, footer label, rule
        curses.init_pair(2, dim_fg, -1)         # footer descriptions, like C_DIM
        ATTR["border_sel"] = curses.color_pair(1)
        ATTR["label"] = curses.color_pair(1) | curses.A_BOLD   # bold like C_PROMPT, same green
        ATTR["key"] = curses.A_BOLD             # footer keys, like C_PKG: bold, default colour
        ATTR["dim"] = curses.color_pair(2) | (0 if curses.COLORS >= 256 else curses.A_DIM)
        curses.init_pair(3, ART_GREY if curses.COLORS >= 256 else curses.COLOR_WHITE, -1)
        ATTR["art"] = curses.color_pair(3)      # the drawings: light grey, lighter than the footer's grey
    except curses.error:
        pass
    return restore


def put_footer(win, y, footer):
    """The page title on the left (bold, the one green); the key hints on the right as in
    the quickstart menu: key bold, description grey, 3 spaces apart."""
    title, hints = footer
    _, w = win.getmaxyx()
    x = w - 1 - len(hints)
    put(win, y, 0, title[: max(0, x - 2)], ATTR["label"])
    for chunk in hints.split("   "):
        key, _, desc = chunk.partition(" ")
        put(win, y, x, key, ATTR["key"])
        put(win, y, x + len(key), " " + desc, ATTR["dim"])
        x += len(chunk) + 3


def put_rule(win, y, w):
    """A solid bold green rule across the whole window, like the quickstart's hr."""
    try:
        win.addstr(y, 0, "─" * w, ATTR["label"])
    except curses.error:
        pass


def paint(win, rows, footer, cursor=None):
    """The panels from the top; a rule and the footer pinned to the bottom.

    cursor is a (y, x) to show the text cursor at, or None to hide it."""
    win.erase()
    h, w = win.getmaxyx()
    for y, row in enumerate(rows):
        x = 0
        for text, role in row:
            put(win, y, x, text, ATTR.get(role, 0))
            x += len(text)
    put_rule(win, h - FOOTER_ROWS, w)
    put_footer(win, h - 1, footer)
    try:
        curses.curs_set(1 if cursor else 0)
    except curses.error:
        pass
    if cursor:
        win.move(*cursor)
    win.refresh()


def paint_too_small(win, height, width, footer, need=None):
    win.erase()
    need_h, need_w = need or (FOOTER_ROWS + 2 * MIN_PANEL_ROWS, footer_width(footer))
    put(win, 0, 0, f"too small: need {need_w}x{need_h}")
    win.refresh()


def norm_key(ch):
    """A get_wch() result as a name ("UP", "ENTER", "ESC", "CTRL_S", ...) or the character."""
    names = {curses.KEY_UP: "UP", curses.KEY_DOWN: "DOWN", curses.KEY_LEFT: "LEFT",
             curses.KEY_RIGHT: "RIGHT", curses.KEY_HOME: "HOME", curses.KEY_END: "END",
             curses.KEY_DC: "DELETE", curses.KEY_BACKSPACE: "BACKSPACE",
             curses.KEY_ENTER: "ENTER", curses.KEY_RESIZE: "RESIZE",
             curses.KEY_SLEFT: "SHIFT_LEFT", curses.KEY_SRIGHT: "SHIFT_RIGHT",
             curses.KEY_SR: "SHIFT_UP", curses.KEY_SF: "SHIFT_DOWN",
             curses.KEY_PPAGE: "PGUP", curses.KEY_NPAGE: "PGDN"}
    chars = {"\n": "ENTER", "\r": "ENTER", "\x1b": "ESC", "\x7f": "BACKSPACE", "\b": "BACKSPACE",
             "\x13": "CTRL_S", "\x03": "CTRL_C", "\t": "TAB"}
    if isinstance(ch, int):
        return names.get(ch) or terminfo_arrow(ch)
    return chars.get(ch, ch)


def terminfo_arrow(code):
    """Name a key that only the terminfo knows (kUP5 is Ctrl+Up, kLFT3 Alt+Left, kDN Shift+Down)."""
    try:
        name = curses.keyname(code).decode()
    except (ValueError, curses.error):
        return ""
    m = re.fullmatch(r"k(UP|DN|LFT|RIT)([2-7]?)", name)
    if not m:
        return ""
    mods = {"": "SHIFT_", "2": "SHIFT_", "3": "ALT_", "5": "CTRL_"}.get(m.group(2))
    direction = {"UP": "UP", "DN": "DOWN", "LFT": "LEFT", "RIT": "RIGHT"}[m.group(1)]
    return (mods + direction) if mods else ""


ESC_WAIT_MS = 40        # how long after Esc to wait for the rest of an escape sequence
CSI_ARROWS = {"A": "UP", "B": "DOWN", "C": "RIGHT", "D": "LEFT"}
RXVT_ARROWS = {"a": "UP", "b": "DOWN", "c": "RIGHT", "d": "LEFT"}
XTERM_MODS = {"2": "SHIFT_", "3": "ALT_", "5": "CTRL_"}   # ESC [ 1 ; MOD A
DIRECTIONS = ("UP", "DOWN", "LEFT", "RIGHT")


def decode_escape(nxt):
    """The key name for what follows an Esc, reading with nxt() (None when nothing more comes).

    urxvt sends Shift+arrow as ESC [ a..d, Ctrl+arrow as ESC O a..d and Alt+arrow as ESC then
    the plain arrow; xterm sends ESC [ 1 ; MOD A..D. A lone Esc is "ESC"."""
    c = nxt()
    if c is None:
        return "ESC"
    if isinstance(c, int):          # Esc, then a key curses already knew: Alt+arrow
        name = norm_key(c)
        return "ALT_" + name if name in DIRECTIONS else "ESC"
    if c == "\x1b":                 # Esc Esc [ A: Alt+arrow in a terminal that sends the Esc first
        name = decode_escape(nxt)
        return "ALT_" + name if name in DIRECTIONS else name
    if c in "[O":
        params, d = "", nxt()
        while isinstance(d, str) and (d.isdigit() or d == ";"):
            params += d
            d = nxt()
        if not isinstance(d, str):
            return "ESC"
        if d in RXVT_ARROWS and not params:
            return ("SHIFT_" if c == "[" else "CTRL_") + RXVT_ARROWS[d]
        if d in CSI_ARROWS:
            return XTERM_MODS.get(params.split(";")[-1] if ";" in params else "", "") + CSI_ARROWS[d]
    return "ESC"


def read_key(win):
    """The next key as a name: norm_key's, plus SHIFT_/CTRL_/ALT_ with UP, DOWN, LEFT, RIGHT."""
    ch = win.get_wch()
    if ch != "\x1b":
        return norm_key(ch)

    def nxt():
        win.timeout(ESC_WAIT_MS)
        try:
            return win.get_wch()
        except curses.error:
            return None
        finally:
            win.timeout(-1)

    return decode_escape(nxt)


def run(win):
    try:
        curses.curs_set(0)
    except curses.error:
        pass
    curses.raw()    # Ctrl-S must reach us, not stop the terminal's output
    restore = init_colours()
    try:
        loop(win, ["overview"], 0, gather())
    finally:
        restore()


def loop(win, stack, sel, data):
    screens = {}
    while True:
        h, w = win.getmaxyx()
        name, footer, need, cursor = stack[-1], None, None, None
        if name == "overview":
            footer = overview_footer()
        elif name == "Layout":
            need = (LAYOUT_MIN_ROWS, layout_min_width())
        elif name == "Monitors":
            need = (MONITORS_MIN_ROWS, monitors_min_width())
        else:
            footer = placeholder_footer(name)
        if (h >= need[0] and w >= need[1]) if need else fits(h, w, footer):
            if name == "overview":
                rows, _ = render_overview(data, sel, w, h)
            elif name in screens:
                rows, footer, cursor = screens[name].render(w, h)
            else:
                rows, _ = render_placeholder(name, w, h)
            paint(win, rows, footer, cursor)
        else:
            paint_too_small(win, h, w, footer, need)
        try:
            key = read_key(win)
        except curses.error:
            continue
        if key in ("RESIZE", ""):
            continue
        if name in screens:
            act = screens[name].handle(key, grid_geometry(w, h)[0])
            if act == "quit":
                return
            if act == "back":
                stack.pop()
                data = gather()
            continue
        if key in ("q", "CTRL_C"):
            return
        if name == "overview":
            if key == "UP":
                sel = 0
            elif key == "DOWN":
                sel = 1
            elif key == "ENTER":
                name = "Layout" if sel == 0 else "Monitors"
                stack.append(name)
                screens[name] = LayoutScreen() if sel == 0 else MonitorScreen()
        elif key in ("LEFT", "ESC"):
            stack.pop()
            data = gather()


def main():
    args = sys.argv[1:]
    if args[:1] == ["--print"]:
        screen = "layout" if args[1:2] == ["layout"] else "overview"
        args = args[:1] + args[2:] if screen == "layout" else args
        width = int(args[1]) if len(args) > 1 else 100
        height = int(args[2]) if len(args) > 2 else 40
        if screen == "layout":
            rows, footer, _ = LayoutScreen().render(width, height)
        else:
            rows, footer = render_overview(gather(), 0, width, height)
        for row in rows:
            print("".join(t for t, _ in row))
        print("─" * width)
        print(footer[0] + footer[1].rjust(width - 1 - len(footer[0])))
        return 0
    if args:
        sys.exit("usage: monitor_tui.py [--print [WIDTH [HEIGHT]]]")
    os.environ.setdefault("ESCDELAY", "25")     # Esc must not wait for an escape sequence
    curses.wrapper(run)
    return 0


if __name__ == "__main__":
    sys.exit(main())
