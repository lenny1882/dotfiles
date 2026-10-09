# Monitor hotplug: real-hardware test checklist

Step 10 of `monitor_changes_plan.md`. Needs a herbstluftwm session and real monitors. Completed.

## Before you start

1. While docked, run `monitor_reconcile.sh --key` and note the output. Use that exact string as a key in `monitor_layouts.conf`.
2. Run `monitor_reconcile.sh --dry-run` first. It prints the xrandr commands it would run and changes nothing.
3. Watch the watcher's stderr. It prints which source it chose (`udevadm` or `xev`) and a `...: change` line per event.

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

## Monitor TUI (step 11)

Reload first (`hc reload`) so Super+Alt+L loads. Try it with `MONITOR_TUI_DRY=1 .../monitor_tui.py` in a terminal before applying for real. Pending: not yet tried in a live session.

| # | Case | Expect |
|---|------|--------|
| T1 | Open it (Super+Alt+L) | A floating window with a picture of the active monitors, a list below with mode, position and `primary`, and a header with the set key and configured or fallback |
| T2 | Select with Tab and 1-9, then move with the arrows | The highlight follows the selection; the output jumps to edge-aligned spots and never onto another output; the picture updates |
| T3 | Nudge with HJKL | Moves by 10 px; the status line shows OVERLAP if it now overlaps another output |
| T4 | Turn an external off, press `a`, then `y` | The external goes off, bars and padding rebuild, the header drops `[modified]` |
| T5 | Make the other monitor primary, `a`, `y` | Polybar and the top padding move to it (same check as case 10) |
| T6 | Pick a lower mode on an external with `m`, `a`, `y` | The mode changes and the bars rebuild |
| T7 | Turn off the only active output | Refused with a message; nothing changes |
| T8 | Press `a` and then do nothing for 15 seconds | The previous layout comes back, status says reverted |
| T9 | Press `s`, then `y`; save again after a different change | `monitor_layouts.conf` has one active entry for the key, replaced (not duplicated) the second time; after a logout the saved layout is used |
| T10 | `R` | The configured or fallback layout comes back |
| T11 | `u` after some edits | The edits are dropped and the picture returns to the current state |
| T12 | `q` or Escape | The window closes and nothing changes |
| T13 | Make a manual change, then unplug and replug a monitor | The set's configured or fallback layout is used again, not the manual one |
| T14 | Resize the window (it is floating) | The picture and list redraw without garbage |
| T15 | Run it with Python missing or `monitor_reconcile.sh` not executable | A clear one-line error, not a traceback |

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
- TUI: changing a mode or position does not re-flow the other outputs, so move the neighbours again afterwards.
- TUI: no rotation, and no way to create a mode for a rejected EDID (use a layout entry).
