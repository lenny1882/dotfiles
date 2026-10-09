# Monitor hotplug: real-hardware test checklist

Step 10 of `monitor_changes_plan.md`. Needs a herbstluftwm session and real monitors. Completed.

## Before you start

1. While docked, run `monitor_reconcile.sh --key` and note the output. Use that exact string as a key in `monitor_layouts.conf`.
2. Run `monitor_reconcile.sh --dry-run` first. It prints the xrandr commands it would run and changes nothing.
3. Watch the watcher's stderr. It prints which source it chose (`udevadm` or `xev`) and a `...: change` line per event. The hooks it emits are handled by `rule_hook.sh`, so check that the `herbstclient --idle` loop from `startup.autostart` is running (`pgrep -af 'herbstclient --idle'`).

## Cases

| # | Case | Expect |
|---|------|--------|
| 1 | Laptop only, fresh login | Panel on, wallpaper (`~/.fehbg`), polybar on the primary (the only monitor) |
| 2 | Plug one external, no layout entry | Fallback layout: external primary, panel to its left, solid colour background |
| 3 | Same set, with a layout entry | Your layout is used, wallpaper returns, panel on or off as the entry says |
| 4 | The 3-monitor desk setup, with a layout entry | Left, middle and right as configured, padding correct on each |
| 5 | Unplug back to laptop only | Panel on, wallpaper, bars rebuilt, no stale monitor |
| 6 | An unknown projector | Fallback layout, solid colour background |
| 7 | Unplug during a reconcile | Panel stays on, no blank screen |
| 8 | Monitor with a rejected EDID (kernel log: `EDID checksum invalid`) and a layout naming `1920x1080` | `xrandr --query` shows `1920x1080_custom` on that output and it is used |
| 9 | Reload config (`hc reload`) | No second watcher, no change to the layout |
| 10 | Primary is not the leftmost monitor (fallback layout with the panel on, or a layout with `--primary` on a non-left output) | Polybar and the top padding are on the `--primary` output only; every other monitor has no bar and no padding |

## TUI overview (step 11)

Spec and open questions: `tui_spec.md`. Reload first (`hc reload`) so Super+Alt+L loads. Try it with `monitor_tui.py` in a terminal first. Enter opens the Layout and Monitors screens (cases below).

| # | Case | Expect |
|---|------|--------|
| O1 | Open it with Super+Alt+L | A floating window with two bordered panels, `Layout` over `Monitors`, label in the top left of each border, each panel half the height after the footer |
| O2 | The footer | A green rule across the window, `Overview` bold green at the left, the key hints (bold keys, grey descriptions) at the right, nothing between them |
| O3 | Up / Down | The green border moves between the panels; only the border lines are green, the label and contents stay white |
| O4 | The green | The selected border is exactly the colour of your active window border (`#2E7D32`); no black background, the window is as translucent as the `nnn` window; after quitting, the terminal's colours are back to normal |
| O5 | Layout panel on a tag with a layout from `hlwm_tag_layouts.conf` (e.g. `3wayR|5`) | The tag name, the layout name, and a frame drawing that matches `hc layout` |
| O6 | Hand-split a frame on that tag, reopen | The layout name reads `custom`; tags 8 and 9 read `unassigned` |
| O7 | Monitors panel | Boxes are in proportion to each other and positioned as on the desktop, numbered with `*` on the primary; the numbered details are underneath |
| O8 | Enter, then Esc, then `q` (also `q` from a screen) | Enter opens the screen, the footer title changes to its name, Esc returns, `q` quits from either |
| O9 | Resize the window | The panels follow; at a very small size it says `too small: need 52x12` |
| O10 | Unplug the external, reopen | The Monitors panel shows one box, the Layout panel uses the `eDP-1` block |

## TUI Layout screen (step 11)

Open it from the overview (Enter on Layout). Work on a copy of `hlwm_layouts.conf` first (`HLWM_LAYOUTS=/path`); the real one is edited in place.

| # | Case | Expect |
|---|------|--------|
| L1 | Open the screen | A Current panel (tag, layout name, drawing) above a grid; the first cell is Create new with a `+`; every layout is a cell with its name and a drawing without text |
| L2 | Arrow keys | The selected cell's border is green, the rest white; Down from a short last row lands on its last cell |
| L3 | Enter on a layout, then `n` | Footer asks `Set "X" on tag T?  y yes  n no`; nothing changes |
| L4 | Enter, then `y` | The focused tag takes the layout (windows stay: check with a tag that has windows, in a multi-frame layout) |
| L5 | `d`, then `y` | Footer names how many tag assignments use it; after `y` only that definition (and its lname) is gone from the file |
| L6 | `e`, change the lname, Ctrl-S | The file keeps its comments and the other entries; the cell and the Current panel show the new name |
| L7 | `e`, break the string (remove a bracket), Ctrl-S | The editor stays open and the footer says what is wrong; Esc discards |
| L8 | Create new, type a name, Ctrl-S | A new `layout=` is appended with a variable made up from the name |
| L9 | Split a frame by hand, reopen the screen | Current reads `custom` and says "Not saved as a layout. s to save it" (the footer does not mention it); `s`, name it, Ctrl-S: it now has that name |
| L10 | Esc from the grid | Back on the overview; Esc inside the editor or a prompt cancels only that |
| L11 | Ctrl-S inside the editor in urxvt | It saves (the terminal must not freeze) |

## TUI Monitors screen (step 11)

Use a second monitor you can lose without harm; changes apply immediately through `monitor_reconcile.sh --layout`.

| # | Case | Expect |
|---|------|--------|
| M1 | Open the screen | Monitors to scale, numbered, `*` on the primary, the selected one in green; an info panel below |
| M2 | Arrows | Selection moves to the neighbour in that direction; the info panel follows |
| M3 | `p`, then `n`, then `p`, `y` | Asks first; `y` makes it primary (check polybar moves to it, `xrandr` shows primary) |
| M4 | `m`, arrows / Ctrl / Shift | 10 px / 1 px / 100 px; the position string updates; overlapping another monitor is refused |
| M5 | `m`, Alt+arrow | Jumps to the other side of the next monitor, keeping its vertical (or horizontal) position |
| M6 | `m`, move, Esc | Back where it was, nothing applied |
| M7 | `m`, move, Ctrl-S | The monitor really moves (xrandr and the desktop agree), tags/polybar follow |
| M8 | `e`, change the string, Ctrl-S | Applied; a bad string or an overlap stays in the editor with the reason |
| M9 | `r` | A centred list, Custom first, a line per resolution and Hz, scroll bar when long; Enter applies |
| M10 | `r`, Custom, `1600x900 60`, Ctrl-S | That mode is created if the monitor does not list it, and applied |
| M11 | Ctrl, Shift and Alt with arrows in urxvt | All three work in move mode (Alt may be eaten by the window manager: say so) |
| M12 | An apply that xrandr rejects | The old positions are put back and the error's last line is shown |

## Check specifically

- **One event or several:** plugging a dock should log a burst but produce one `monitors_applied`. If bars restart repeatedly, raise `DEBOUNCE` in `monitor_changes.sh`.
- **udevadm output format:** the awk filter assumes the action is field 3 and the path is field 4. Run `udevadm monitor --udev --subsystem-match=drm` by hand and compare.
- **xev fallback:** run `monitor_changes.sh --xev` once and check the gawk pattern matches the lines xev prints.
- **Solid colour across monitors:** the 1x1 image should cover every monitor evenly. If not, switch `--bg-fill` to `--bg-scale` in `background.sh`.
- **Mode on laptop-only boot:** `--auto` may pick a different resolution from the old hardcoded 2560x1600. If so, give the panel an explicit mode in a layout entry.

## Known gaps

- The fallback layout is simpler than the plan: the "half screens" and "stacked when under 1080p" heuristics are missing.
- Only the internal panel is guarded against being turned off. Turning an external off isn't checked.
- `monitor_layouts.conf` has only the one docked entry (`DP-4 eDP-1`); the rest are commented examples.
- Polybar and its padding go on the xrandr primary monitor, matched to the herbstluftwm monitor by rect (`panel.sh`); monitor 0 if none matches. Checked on real hardware.
- "Unknown" means no layout entry for the output names, not an EDID check. Identical monitors can't be told apart.
- Monitors screen (not built): when built, changing a mode or position will not re-flow the other outputs; no rotation; no way to create a mode for a rejected EDID (use a layout entry).
