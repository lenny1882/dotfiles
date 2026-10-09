# Monitor hotplug: real-hardware test checklist

Step 10 of `monitor_changes_plan.md`. Needs a herbstluftwm session and real monitors.

## Before you start

1. While docked, run `monitor_reconcile.sh --key` and note the output. Use that exact string as a key in `monitor_layouts.conf`.
2. Run `monitor_reconcile.sh --dry-run` first. It prints the xrandr commands it would run and changes nothing.
3. Watch the watcher's stderr. It prints which source it chose (`udevadm` or `xev`) and a `...: change` line per event.

## Cases

| # | Case | Expect |
|---|------|--------|
| 1 | Laptop only, fresh login | Panel on, wallpaper (`~/.fehbg`), polybar on monitor 0 |
| 2 | Plug one external, no layout entry | Fallback layout: external primary, panel to its left, solid colour background |
| 3 | Same set, with a layout entry | Your layout is used, wallpaper returns, panel on or off as the entry says |
| 4 | The 3-monitor desk setup, with a layout entry | Left, middle and right as configured, padding correct on each |
| 5 | Unplug back to laptop only | Panel on, wallpaper, bars rebuilt, no stale monitor |
| 6 | An unknown projector | Fallback layout, solid colour background |
| 7 | Unplug during a reconcile | Panel stays on, no blank screen |
| 8 | Reload config (`hc reload`) | No second watcher, no change to the layout |

## Check specifically

- **One event or several:** plugging a dock should log a burst but produce one `monitors_applied`. If bars restart repeatedly, raise `DEBOUNCE` in `monitor_changes.sh`.
- **udevadm output format:** the awk filter assumes the action is field 3 and the path is field 4. Run `udevadm monitor --udev --subsystem-match=drm` by hand and compare.
- **xev fallback:** run `monitor_changes.sh --xev` once and check the gawk pattern matches the lines xev prints.
- **Solid colour across monitors:** the 1x1 image should cover every monitor evenly. If not, switch `--bg-fill` to `--bg-scale` in `background.sh`.
- **Mode on laptop-only boot:** `--auto` may pick a different resolution from the old hardcoded 2560x1600. If so, give the panel an explicit mode in a layout entry.

## Known gaps

- The fallback layout is simpler than the plan: the "half screens" and "stacked when under 1080p" heuristics are missing.
- Only the internal panel is guarded against being turned off. Turning an external off isn't checked.
- `monitor_layouts.conf` has only commented placeholder layouts.
- Polybar starts only on monitor 0 (`panel.sh`).
- "Unknown" means no layout entry for the output names, not an EDID check. Identical monitors can't be told apart.
