# herbstluftwm TUI: spec, decisions and open questions

The single record of the TUI (`monitor_tui.py`, launched with Super+Alt+L). It supersedes the step 11
text in `monitor_changes_plan.md`, which describes the first version (a screen of monitor-editing
keys with a revert prompt). Written 2026-10-09 so that nothing depends on conversation history.

## Scope

Two things, nothing else:
1. **Monitors** - per output: resolution, position, primary yes/no.
2. **Layouts** - herbstluftwm frame layouts (the split trees loaded with `hc load`), not monitor layouts.
   Hook into `hc`; list the existing layouts; create, update and delete layouts; set the layout for the
   current tag.

## How the user wants to work (also saved as memory files)

- Ask open questions about design; do not offer menus of options I have already decided.
- Do exactly what is asked. Do not remove, add or critique things that were not asked about.
- Report command results in the reply text; the user cannot use raw tool output.
- Explain a command before running it, and say if it (or a file it sources) deletes anything.
- Verify a reported problem before attributing a cause; never blame the user's config without evidence.
- Do not introduce a new language or runtime without asking. Python (stdlib `curses`) was accepted for
  this tool after the trade-off was explained, so Python 3 is needed on any machine that uses it.
- Copy the *styling* of the quickstart (`setup/quickstart_arch.sh`), not its layout limits (e.g. its 92
  column box width is not a rule for the TUI).

## Overview screen (built)

Two bordered panels stacked, btm-style. Up/Down select a panel, Enter opens its screen, Left goes back
a screen, `q` quits from any screen.

- **Borders:** the panel's own lines are white (the terminal default). The selected panel's *border lines
  only* are green; the label text on the top line and everything inside stay plain.
- **Label:** in the top left of the top border, e.g. `┌─ Layout ──...┐`.
- **Height:** each panel is half of the window height after the footer. The footer is 2 rows (the rule
  and the hint row). An odd leftover row goes to the bottom panel (40 rows: 19 + 19; 41 rows: 19 + 20).
- **Layout panel:** `Tag      <tag name>`, `Layout   <layout name>`, a blank line, then the focused tag's
  live frame tree drawn with box characters, each frame labelled with its algorithm (36 x 9 in the mock,
  shrinking to fit). `split horizontal` puts the children side by side, `split vertical` stacks them
  (man page: `right (= horizontal)`, `bottom (= vertical)`).
- **Monitors panel:** the active monitors drawn to scale (80 px per column, 160 px per row, shrinking to
  fit), a number inside each box with `*` after the primary's, then one numbered details line per
  monitor: `1*  eDP-1   2560x1600  +0+0`. Numbers run left to right; outputs that are off come last.
- **Green:** exactly `#2E7D32` (`col_green`). The 256-colour palette has nothing close (nearest is a
  teal), so the TUI redefines colour slot 200 to the exact value (urxvt supports this: `ccc`/`initc`),
  uses it for the selected border, the footer title and the rule, and puts the slot back on exit.
  Fallback if the terminal cannot redefine colours: xterm colour 28. The terminal's own ANSI green is not
  used anywhere. `curses.use_default_colors()` is called so there is no black background over the
  translucent urxvt (`URxvt*background: [80]col_dark`).
- **Rule:** a solid bold green `─` line across the whole window directly above the footer (the
  quickstart's `hr`; no width cap).
- **Footer (last row):** the page title on the left (`Overview`, or `Layout` / `Monitors` on their
  screens), bold, the same green; the key hints on the right, ending one column short of the edge (the
  last cell of the last row cannot be written): `↑/↓ select   Enter open   ← back   q quit`. Keys bold in
  the default colour, descriptions grey (xterm 248), three spaces between items. Nothing joins the title
  to the hints. This follows the quickstart's menu hint line (`C_PKG` keys, `C_DIM` descriptions).
- **Too small:** each screen has a minimum size and shows `too small: need WxH` below it: the overview 12 rows
  (2 panels of 5 + the footer's 2) by 52 columns; the Layout screen 29 rows by 72; the Monitors screen 20
  rows by 87 (the width is that of the screen's longest footer).
- Enter opens the Layout or Monitors screen (both described below).

### Launching

`shortcuts.autostart`: `hc keybind $ModPri-l spawn urxvt -name wrapper -e $SCRIPTS_DIR/monitor-tui-wrap.sh`
(`$ModPri` is Super+Alt). The `wrapper` instance name makes the window float, centered, 1280x720 (rule in
`rules.autostart`), like `nnn` and `btm`. `monitor-tui-wrap.sh` follows `nnn-wrap.sh`: a `/bin/sh` wrapper
that sets what a keybinding session lacks (a UTF-8 locale for the box characters) and runs the TUI.
`hc reload` is needed for a changed keybinding to load. `MONITOR_TUI_DRY=1` makes applies dry runs.
`monitor_tui.py --print [WIDTH [HEIGHT]]` prints the overview as plain text (testing aid).

## Layout feature

### Facts established (docs, man page, partial source, the user's real dumps)

- herbstluftwm 0.9.6 has **no named layouts, presets or tag-to-layout attachment**. A tag has one layout:
  its frame tree. `hc dump <tag>` prints it, `hc load <tag> '<tree>'` replaces it. Upstream's
  `savestate.sh`/`loadstate.sh` save `tag: dump` lines, keyed by tag name. (The source search covered
  `src/tag.cpp` and the upstream `scripts/` only; the sandbox blocks cloning github.com.)
- Today `layouts.autostart` loads one string per tag name (`hc load "left|3" '(...)'`). There are nine tags
  (`tags.autostart`): `left|3`, `middle|1`, `right|2`, `split|4`, `3wayR|5`, `3wayL|6`, `grid|7`, `8`, `9`.
  Only the first seven have a string; **8 and 9 have none** (their live tree is the default
  `(clients vertical:0)`). `left|3` and `right|2` are the same string, `(clients max:1)`.
- The number after an algorithm or split direction is a **selection index** (which window or child is
  selected), live state and not structure. That is why `left|3` is `max:1` in the file but `max:0` live
  (one window), and `split|4` is `:0` in the file and `:1` live. Window IDs appear in dumps once a tag has
  windows. Split fractions print as `0.5` in this version.
- Documented ways to get the tag: `hc get_attr tags.focus.name` (focused tag), `monitors.<N>.tag` (tag on a
  monitor), `clients.focus.tag`, `hc complete 1 use` (all tag names). Not run live.
- `hc load` on a tag with windows (source, `src/frametree.cpp`, summarised): windows are collected first;
  ones the string names go into their frames; unmentioned ones stay on the tag and are put in the frame that
  takes the old subtree's place, after any listed. Which frame gets them in a multi-frame layout is **not
  confirmed**. Windows named in the string but on another tag are moved onto this one.
- Comparing the user's nine live dumps with the strings: after normalising, all seven defined tags match in
  structure.

### Decisions

1. **Layout definitions file** (`scripts/hlwm_layouts.conf`, seeded): one bash variable per layout, a
   single-quoted `hc load` string (so no single quote inside). The **variable name is the key**. A
   `# lname: Display Name` comment on the line directly above is the human readable name; it need not match
   the variable name. A variable with no lname falls back to its name.
2. **Tag assignment file** (`scripts/hlwm_tag_layouts.conf`, seeded): `TAG_LAYOUTS["<connected set>"]="..."`
   blocks, one line per tag: the tag name, then the layout variable as the last word (the tag may contain
   spaces). The **connected set** is the key `monitor_reconcile.sh --key` prints (connected outputs, sorted,
   space-separated, e.g. `DP-4 eDP-1`). The file refers to the variable *name*, never the expanded string,
   so the name is not lost.
3. **Finding the name for the focused tag:** tag name (herbstluftwm) -> set key -> the block's line for
   that tag -> variable name -> definition and lname.
4. **What the overview shows for a layout name:**
   - the lname if the live tree matches the assigned definition **in structure** (split directions,
     nesting, each frame's algorithm; window ids, split fractions and selection index ignored);
   - `custom` if it does not match;
   - `unassigned` if the set has no block or the tag has no line (tags 8 and 9 are unassigned).
   - A line naming a variable that does not exist shows `unknown layout '<name>'`.
5. **Auto-load when the connected set changes, and at startup:** apply the assigned layouts. Rules:
   - a tag with **no windows** is overwritten with its assigned layout, custom or not;
   - a tag **with windows** keeps a custom tree (never overwrite a custom layout); if it still matches the
     layout last applied to it, it is replaced with the new assigned layout;
   - the layout last applied is **remembered per tag in a herbstluftwm attribute** (the user agreed);
   - a tag or set with no entry is left alone.
   It would run as a third command in `rule_hook.sh`'s `monitors_applied` case (next to
   `panel.sh` and `background.sh`), and at startup in place of the hand-written `hc load` lines.
   Sketch: source both files, `key=$(monitor_reconcile.sh --key)`, read the block, split each line on its
   last space, `hc load "$tag" "${!name}"`; skip an unknown variable or tag with a message.

### Known limits of the key

The set key lists *connected* outputs. So panel-on and panel-off with the same plugged monitors share one
block, and one physical monitor split into virtual monitors (`xrandr --setmonitor`) is the same key as one
without. If either needs different tag layouts, the key needs more than output names.

## Layout screen (built, not yet seen live)

Decided with the user (2026-10-09):
- Two parts: a **Current** panel (tag, layout name, the live frame drawing; no text inside the drawing),
  and a **Layouts** panel with a grid of cells. Each cell: the lname in its top border, a small drawing with no
  text. Selected cell: green border. The first cell is **Create new** with a big `+`.
- Keys: arrows move; **Enter** sets the layout on the focused tag, after a `y/n` confirmation;
  **e** opens the editor on that layout; **d** deletes after `y/n` (says how many tag assignments use it);
  **s** (only when the live layout is `custom`; the Current panel says "Not saved as a layout. s to save it", the footer does not list it) opens the editor with the live shape, to save it;
  **Esc** goes back (and cancels the editor and the prompts); **q** quits. There is no rename key: the
  `# lname:` line is part of the editor text, so renaming is editing.
- On Create new / **s**: the editor opens on `# lname: ` plus `layout='...'`; the variable is made up from
  the lname on save (`3-way right` -> `layout_3_way_right`, unique). An existing layout keeps its variable.
- Embedded editor (own code, Python curses): arrows, Home/End, Backspace, Delete, Enter, typing;
  **Ctrl-S** saves, **Esc** cancels. Ctrl-S needs `curses.raw()` (otherwise the terminal swallows it).
- Validation is the parser only (`parse_tree(strict=True)`: direction, fraction 0-1, algorithm, numeric
  selection, brackets, no single quote). herbstluftwm has no validate / dry-run; the throwaway-tag check was
  offered and declined (it would show in polybar's `ewmh` module for an instant).
- "Current" names the live layout by structure against *all* saved layouts (the overview names it by the
  tag's assignment); no match = `custom`.
- Edits rewrite only the one definition in `hlwm_layouts.conf` (comments and other entries are kept).

**Persist (Alt-S, decided 2026-10-09):** Enter and every monitor change only affect what is live. **Alt-S** (Ctrl-Shift-S cannot
be told from Ctrl-S in a terminal) on the Layout screen asks `y/n`, then writes the layout that is current on the focused
tag under the current set of connected monitors in `hlwm_tag_layouts.conf`; if the tag's layout is `custom` it opens
the save editor instead. On the Monitors screen it asks `y/n`, then replaces the set's active entry in `monitor_layouts.conf`
with the current layout (comments around it are left alone).

Still open for this screen: `hc load` on a tag with windows is unverified; deleting a layout leaves the assignments that name it
(they then read `unknown layout`).

## Monitors screen (built, not yet seen live)

Decided with the user (2026-10-09):
- The active monitors drawn to scale, numbered, `*` on the primary (grey drawing; the selected monitor is green),
  and an info panel at the bottom for the selected one (output, primary, mode and Hz, position as `WxH+X+Y`).
- Arrows select (the nearest monitor within 45 degrees of the direction).
- **p** make primary, with `y/n`. **m** move mode: arrows 10 px, Ctrl 1 px, Shift 100 px, Alt hops to the other
  side of the next monitor in that direction keeping the other coordinate; the position string updates as it
  moves; a move that would overlap another monitor is refused; **Ctrl-S** applies, **Esc** cancels.
- **e** (also from move mode) edits the geometry string as herbstluftwm reads it (`2560x1600+0+0`); Ctrl-S applies,
  Esc cancels.
- **r** opens an overlay list, vertical only with a scroll bar: `Custom…` first, then each resolution, one line per
  refresh rate, largest first; Enter chooses; Enter on Custom opens `WxH [Hz]` for editing, Ctrl-S applies.
- Ctrl-S is the save/apply key everywhere something is typed; Esc always cancels / goes back.
- Changes are applied at once through `monitor_reconcile.sh --layout` (a failure puts the old model back and shows the
  last line of the error). Modified arrows are decoded for urxvt (terminfo extended keys, `ESC ESC [ D` for Alt) and xterm.

Not decided / not done: whether a change is also written to `monitor_layouts.conf` for the connected set (today it holds
only until the connected set changes); a revert-after-N-seconds safety prompt; outputs that are off are not shown or
selectable (no turn on/off); rotation; resizing does not move the neighbours (an overlap is refused instead).

## Built so far (state of the work)

All committed (`5f8c892` and later): the overview, Layout and Monitors screens in `scripts/monitor_tui.py`,
`monitor-tui-wrap.sh`, the two conf files (`hlwm_layouts.conf` holds the user's own edits; the seeded
`hlwm_tag_layouts.conf` assignments are still placeholders, identical per set, and nothing loads from them
yet), the `Super+Alt+L` keybinding, and the checks (`monitor_tui_check.py`, run by section 4 of
`monitor_check.sh`; they use a fixed copy of the seeded layouts, never the live file).

Hook handling is in one place: `monitor_changes.sh` only emits `monitors_changed`; `rule_hook.sh` (the
unfiltered `herbstclient --idle` loop started by `startup.autostart`) runs `monitor_reconcile.sh` on
`monitors_changed` and `panel.sh` + `background.sh` on `monitors_applied`. Both loops in `startup.autostart`
are guarded so a reload does not start a second one.

**Tests:** `monitor_check.sh` -> all passed (shellcheck is missing, no live display), including a stubbed
dispatch check of `rule_hook.sh`. Pseudo-terminal runs of the real program were used for escape codes, colours
and key decoding. Scratch scripts live outside the repo.

**Seen live by the user:** the Layout screen (approved), the primary change moving polybar. Not yet confirmed
live: the Monitors screen's move / resolution / edit paths against real monitors, and Alt+arrow under the window
manager.

## Open questions and remaining work

Layouts:
1. Deleting a layout leaves the tag assignments that name it (the confirmation says how many).
2. Decided: setting a layout is live only; Alt-S persists it (see above).
3. **What `custom` should look like**: the word alone for now, plus a note on how to save it.
4. **The auto-load script** is not written. Needs a live test of `hc load` on tags with windows,
   especially which frame gets the windows in a multi-frame layout, and of the per-tag attribute. It would
   be a new case in `rule_hook.sh` (or called from it).
5. **Switching startup** from `layouts.autostart`'s hand-written `hc load` lines to the new files.
6. **Whether the key needs more than the connected outputs** (see "Known limits of the key").
7. Replace the placeholder per-set assignments with the user's own.

Monitors:
8. Whether to add a keep-or-revert prompt after an apply. Not decided. (Saving is Alt-S, see above.)

General:
9. Frame labels are cut off when a frame is narrow (e.g. `horizon`); cosmetic.
10. Not handled: rotation (positions assume unrotated outputs).
11. `hc load` on a tag with windows, and everything touching a live herbstluftwm beyond what the user has
    run, is unverified: a throwaway herbstluftwm under `Xvnc` could not be started in the sandbox.
