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

## Monitor popup (step 11)

Open it with Super+Alt+L (reload first with `hc reload` so the binding loads). Pending: not yet tried in a live session.

| # | Case | Expect |
|---|------|--------|
| P1 | Open the popup | A "Monitors" menu lists each connected output with mode, position and `primary`, and shows the set key and whether the layout is configured or the fallback |
| P2 | Turn an external off, Apply | The external goes off, bars and padding rebuild, the stored key is unchanged |
| P3 | Make the other monitor primary, Apply | Polybar and the top padding move to it (same check as case 10) |
| P4 | Place one output left of / right of / above / below another, Apply | Positions are as chosen, no negative-position error from xrandr |
| P5 | Pick a lower mode on an external, Apply | The mode changes and the bars rebuild |
| P6 | Turn off the only active output | Refused with a message; nothing changes |
| P7 | Apply and save, then save again with a different change | `monitor_layouts.conf` gets one active entry for the key, replaced (not duplicated) the second time; after a logout the saved layout is used |
| P8 | Reset to the configured layout | The configured or fallback layout comes back |
| P9 | Escape or Cancel | Nothing changes |
| P10 | Make a manual change, then unplug and replug a monitor | The set's configured or fallback layout is used again, not the manual one |
| P11 | Apply, with the watcher's stderr visible | No "cannot read layout file" message (this is the pipe check for `--layout`) |

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
- Popup: changing a mode or position does not re-flow the other outputs, so place the neighbours again afterwards.
- Popup: no rotation, no way to create a mode for a rejected EDID (use a layout entry), and no revert timer after Apply.
