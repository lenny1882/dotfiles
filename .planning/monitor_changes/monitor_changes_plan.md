# Monitor hotplug plan

Plan for `symlinks/home_@user@_.config_herbstluftwm/scripts/monitor_changes.sh` and the scripts around it. Written 2026-10-09. Steps 1-9 are built and committed; step 10 (real-hardware testing) is open. See `monitor_test_checklist.md` and `monitor_check.sh` in this directory.

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
- **Background:** known sets run `~/.fehbg`; unknown sets get a solid `col_grey` colour set through feh with a generated 1x1 image.

## Built

1. **Reconcile core** - `monitor_reconcile.sh`. Compares the connected set with the stored layout, applies xrandr and `set_monitors`, stores the new key. Flags: `--dry-run`, `--force`, `--key`, `--known`.
2. **Config format** - `monitor_layouts.conf`, `LAYOUTS["<key>"]` with one line per output (`OUTPUT MODE [xrandr args]`). Currently placeholders only.
3. **Safety guard** - the panel is only switched off after another output is confirmed active; any failure leaves it on.
4. **Hook plumbing** - `monitors_changed` triggers reconcile; reconcile emits `monitors_applied` after applying.
5. **udevadm event source** - `monitor_udev_events`.
6. **xev fallback and debounce** - auto-selected, `--xev` override.
7. **Startup integration** - `monitors.autostart` calls reconcile (falling back to `hc detect_monitors`); `startup.autostart` spawns the watcher in the first-autostart block.
8. **Bars and padding** - `monitors_applied` runs `panel.sh`.
9. **Background** - `background.sh`, run at startup and on `monitors_applied`.

## Open

10. **Real-hardware testing** - follow `monitor_test_checklist.md`. `monitor_check.sh` runs the safe, read-only checks first.

## Known gaps

- The fallback is simpler than first planned: the "half screens" and "stacked when under 1080p" heuristics are missing.
- Only the internal panel is guarded against being turned off; turning an external off is not checked.
- `monitor_layouts.conf` needs real entries: run `monitor_reconcile.sh --key` while docked.
- Polybar starts only on monitor 0 (`panel.sh`).
- The xev line format the gawk pattern expects, and the udevadm output fields, are unverified on real hardware.
- Identical monitors cannot be told apart by name; EDID serial or port position may be needed.
- `--auto` on a laptop-only boot picks the panel's preferred mode, which may differ from the old hardcoded 2560x1600.

## Risks

- **Event bursts.** One dock can fire several events; the debounce covers this. Raise `DEBOUNCE` if bars restart repeatedly.
- **No display left.** Turning the panel off on a bad detection is the worst failure; the guard in step 3 and the commented-out layouts keep the panel on until a layout says otherwise.
- **udevadm reliability.** It may not fire for every dock, which is why xev stays as a fallback.
