# Monitor hotplug plan

Plan for `symlinks/home_@user@_.config_herbstluftwm/scripts/monitor_changes.sh` and the scripts around it. Written 2026-10-09. Steps 1-13 are built and committed. Step 10 (real-hardware testing) is done, and step 11 (the monitor and layout TUI) has been tried live for the Layout screen and for setting the primary; the rest of the Monitors screen and the persist logic are untested live. Details of the TUI are in `tui_spec.md`. See `monitor_test_checklist.md` and `monitor_check.sh` in this directory.

## Goal

Detect monitors being plugged or unplugged, work out the right layout, and apply it with xrandr and `hc set_monitors`, with no manual steps.

## Decisions made

- **One trigger.** Connected and Disconnected are not distinguished. Either fires a single `monitors_changed` hook, and the handler compares the current state with the stored `my_monitor_layout` attribute. It acts only if they differ.
- **Layout key: sorted output names**, space-separated (`monitor_reconcile.sh --key` prints it). EDID hashes may be added later to tell identical monitors apart.
- **Layouts keyed by the exact monitor set**, in `monitor_layouts.conf`. Each layout carries its own laptop-panel setting: on (with a position) or `off`. The panel is not turned off globally, only where a layout says so.
- **Unknown sets** keep the panel on and use a fallback: first external is primary, the rest go to its right, the panel goes to its left.
- **The script owns xrandr.** The layout config drives both the xrandr calls and `hc set_monitors`.
- **Event source:** `udevadm monitor` on DRM events by default; xev if udevadm is missing or when forced with `monitor_changes.sh --xev`. Both feed one debounce (0.5 s of quiet ends a burst).
- **Unknown means no layout entry.** A set is known if it has an entry in `monitor_layouts.conf` or is only the internal panel.
- **Missing modes are created.** A monitor whose EDID is missing or rejected lists only fallback modes (the ASUS VS247 behind the Framework HDMI Expansion Card reports 640x480 because its EDID checksum is invalid). When a layout asks for a `WxH` the output does not list, reconcile adds it with `xrandr --newmode` and `--addmode` (named `WxH_custom`; 1920x1080 uses the standard HDMI timing, others use `cvt`).
- **Background:** known sets run `~/.fehbg`; unknown sets get a solid `col_grey` colour set through feh with a generated 1x1 image.

## Built

1. **Reconcile core** - `monitor_reconcile.sh`. Compares the connected set with the stored layout, applies xrandr and `set_monitors`, stores the new key. Flags: `--dry-run`, `--force`, `--key`, `--known`, `--layout FILE` (what the TUI uses; implies `--force`).
2. **Config format** - `monitor_layouts.conf`, `LAYOUTS["<key>"]` with one line per output (`OUTPUT MODE [xrandr args]`). One active entry (`DP-4 eDP-1`: panel primary, DP-4 to its right at 1920x1080); the rest are commented examples.
3. **Safety guard** - the panel is only switched off after another output is confirmed active; any failure leaves it on.
4. **Hook plumbing** - `monitor_changes.sh` is only the event source: it emits `monitors_changed`. `rule_hook.sh`, the one place hooks are handled (the unfiltered `herbstclient --idle` loop in `startup.autostart`), reacts: `monitors_changed` runs reconcile, which emits `monitors_applied` after applying, and `monitors_applied` runs `panel.sh` and `background.sh`.
5. **udevadm event source** - `monitor_udev_events`.
6. **xev fallback and debounce** - auto-selected, `--xev` override.
7. **Startup integration** - `monitors.autostart` calls reconcile (falling back to `hc detect_monitors`); `startup.autostart` spawns the watcher on every autostart (a reload too) if `pgrep` does not find it running.
8. **Bars and padding** - `monitors_applied` runs `panel.sh` (from `rule_hook.sh`).
9. **Background** - `background.sh`, run at startup and on `monitors_applied`.
10. **Real-hardware testing** - done, following `monitor_test_checklist.md` (`monitor_check.sh` for the read-only checks).
11. **Monitor and layout TUI** - `monitor_tui.py` (Python curses), opened with Super+Alt+L through `monitor-tui-wrap.sh`. Overview (Layout and Monitors panels), Layout screen (grid of named layouts, embedded editor with a syntax reference, set, edit, delete, save a custom layout) and Monitors screen (to-scale diagram, primary, move, resolution and refresh-rate list, geometry edit). Changes are live only; Alt-S persists (see below). Checks: `monitor_tui_check.py`, run by `monitor_check.sh`.
12. **Layout files** - `hlwm_layouts.conf` (named frame layouts, one variable each, display name in a `# lname:` line) and `hlwm_tag_layouts.conf` (which layout each tag gets, per connected set). The TUI reads and writes both. Nothing else loads them yet.
13. **Persist** - Alt-S on the Layout screen writes the focused tag's current layout into `hlwm_tag_layouts.conf` for the connected set (or opens the save editor if it is custom); on the Monitors screen it replaces the set's entry in `monitor_layouts.conf` with the current layout. Both ask first.

## Open

14. **First: the user tests the persist logic** (Alt-S on the Layout and Monitors screens; cases `L12` and `M13` in `monitor_test_checklist.md`). It writes `hlwm_tag_layouts.conf` and `monitor_layouts.conf`, and has only been run against copies and stubs.
15. **Auto-load tag layouts** - not written. On a connected-set change and at startup, load each tag's assigned layout: an empty tag is overwritten, a tag with windows keeps a custom layout, and the layout last applied is remembered per tag in an attribute. It would be a new case in `rule_hook.sh`. Needs a live test of `hc load` on tags with windows first. Then `layouts.autostart` stops loading its own strings, and the placeholder assignments in `hlwm_tag_layouts.conf` are replaced with real ones.
16. **Live testing of the Monitors screen** - move (including Ctrl, Shift and Alt arrows under the window manager), resolution, custom resolution and geometry edit against real monitors: cases `M1`-`M12`. Decide whether an apply needs a keep-or-revert prompt.

## Known gaps

- The fallback is simpler than first planned: the "half screens" and "stacked when under 1080p" heuristics are missing.
- Only the internal panel is guarded against being turned off; turning an external off is not checked.
- `monitor_layouts.conf` has only the one docked entry; add others (for example the 3-monitor desk) using `monitor_reconcile.sh --key` while connected.
- Polybar and its padding go on the xrandr primary monitor, matched to the herbstluftwm monitor by rect (`panel.sh`); monitor 0 if none matches. Checked on real hardware.
- The xev line format the gawk pattern expects, and the udevadm output fields, are unverified on real hardware.
- Identical monitors cannot be told apart by name; EDID serial or port position may be needed.
- An unknown set still uses `auto` for every output, so a monitor with a rejected EDID gets 640x480 from the fallback. Custom modes only apply where a layout names a `WxH`.
- The root cause of the ASUS VS247's bad EDID is unknown (monitor, or the HDMI Expansion Card). Trying another input or card would tell.
- `--auto` on a laptop-only boot picks the panel's preferred mode, which may differ from the old hardcoded 2560x1600.
- Monitors screen: changing a mode or position does not move the other outputs; an overlap is refused.
- Monitors screen: outputs that are off are not shown or selectable, so it cannot turn one on or off. Rotation is not handled.
- Monitors screen: there is no keep-or-revert prompt, so a mode the monitor cannot show is not undone. A failed apply puts the old state back.
- A letter typed within 40 ms of Esc is read as Alt plus that letter.
- Layout screen: setting a layout does not say whether `hc load` kept the windows; unverified on tags with windows. Deleting a layout leaves the tag assignments that name it.
- The layout set key is the sorted connected output names, so the panel on and off, and virtual monitors, share one key.

## Risks

- **Event bursts.** One dock can fire several events; the debounce covers this. Raise `DEBOUNCE` if bars restart repeatedly.
- **No display left.** Turning the panel off on a bad detection is the worst failure; the guard in step 3 and the commented-out layouts keep the panel on until a layout says otherwise.
- **udevadm reliability.** It may not fire for every dock, which is why xev stays as a fallback.
