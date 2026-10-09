# Monitor hotplug plan

Plan for `symlinks/home_@user@_.config_herbstluftwm/scripts/monitor_changes.sh` and the scripts around it. Written 2026-10-09. Steps 1-9 are built and committed, with custom-mode handling added after hardware testing; step 10 (real-hardware testing) is done, and step 11 (monitor TUI) is built but not yet tried in a live session. See `monitor_test_checklist.md` and `monitor_check.sh` in this directory.

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

1. **Reconcile core** - `monitor_reconcile.sh`. Compares the connected set with the stored layout, applies xrandr and `set_monitors`, stores the new key. Flags: `--dry-run`, `--force`, `--key`, `--known`.
2. **Config format** - `monitor_layouts.conf`, `LAYOUTS["<key>"]` with one line per output (`OUTPUT MODE [xrandr args]`). One active entry (`DP-4 eDP-1`: panel primary, DP-4 to its right at 1920x1080); the rest are commented examples.
3. **Safety guard** - the panel is only switched off after another output is confirmed active; any failure leaves it on.
4. **Hook plumbing** - `monitors_changed` triggers reconcile; reconcile emits `monitors_applied` after applying.
5. **udevadm event source** - `monitor_udev_events`.
6. **xev fallback and debounce** - auto-selected, `--xev` override.
7. **Startup integration** - `monitors.autostart` calls reconcile (falling back to `hc detect_monitors`); `startup.autostart` spawns the watcher in the first-autostart block.
8. **Bars and padding** - `monitors_applied` runs `panel.sh`.
9. **Background** - `background.sh`, run at startup and on `monitors_applied`.
10. **Real-hardware testing** - done, following `monitor_test_checklist.md` (`monitor_check.sh` for the read-only checks).
11. **Monitor TUI** - `monitor_tui.py` (Python curses), opened with Super+Alt+L in a floating `urxvt` (`shortcuts.autostart`, `$ModPri-l`). It replaced a rofi menu, which was too restrictive.
    - **Show:** a scaled picture of the active outputs, with the selected one highlighted, and a list of every connected output with its mode, position and primary flag (or `off`). The header shows the set key and whether the set uses a configured or the fallback layout.
    - **Change:** arrows/hjkl jump the selected output to the next edge-aligned spot that doesn't overlap another; `HJKL` nudge by 10 px (this can overlap, e.g. to mirror); `o` on/off, `p` primary, `m` mode, `Tab`/`1-9` select, `u` undo edits, `a` apply, `s` apply and save to `monitor_layouts.conf`, `R` reset to the configured layout, `q` quit.
    - **How it applies:** it edits a working copy of the current xrandr state and sends the result to `monitor_reconcile.sh --layout /dev/stdin`, so the panel guard and custom-mode creation still apply and no temp files are used. After an apply there are 15 seconds to press `y`; otherwise the previous layout is restored.
    - **Decisions made:**
      - *Manual choice vs hotplug:* no extra "pinned" attribute. `--layout` stores the normal key, so the choice holds until the connected set changes, and a restart or `R` goes back to the configured layout.
      - *Saving:* `s` replaces the active `LAYOUTS["key"]` entry in `monitor_layouts.conf`, or appends one under a `# Saved by monitor_tui.py:` comment. Commented examples are left alone. Saved layouts use absolute `--pos` values.
      - *Language:* Python curses (standard library, no extra install), chosen over Textual, Go or Rust to avoid a new dependency; it does mean Python 3 is needed on any machine that uses it.
      - *Last active output:* the TUI refuses to turn it off.
    - **Try it safely:** `MONITOR_TUI_DRY=1 monitor_tui.py` runs the whole interface but applies nothing (reconcile `--dry-run`).
    - **Tested:** `monitor_tui_check.py` (33 checks: parsing, moving, the turn-off guard, the layout it generates, saving to the conf, and a dry run through `--layout` over stdin) and a pseudo-terminal smoke run with a fixture. `monitor_check.sh` runs the first.
    - **Not yet tried:** the real screen on a display, a live apply with the revert prompt, saving to the real conf, and `R`. See the "Monitor TUI" section of `monitor_test_checklist.md`.

## Open

12. **TUI testing in a live session** - follow the "Monitor TUI" section of `monitor_test_checklist.md`.

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
- TUI: changing an output's mode or position does not re-flow the others, so a neighbour placed earlier can be left with a gap or an overlap. Move the neighbours again afterwards.
- TUI: rotation is not handled; positions assume unrotated outputs.
- TUI: the mode list holds only modes the output lists, so it cannot create one for a monitor with a rejected EDID. Use a layout entry naming the `WxH`.
- TUI: the revert prompt restores the layout read when the TUI last loaded (or last applied), not any earlier one.

## Risks

- **Event bursts.** One dock can fire several events; the debounce covers this. Raise `DEBOUNCE` if bars restart repeatedly.
- **No display left.** Turning the panel off on a bad detection is the worst failure; the guard in step 3 and the commented-out layouts keep the panel on until a layout says otherwise.
- **udevadm reliability.** It may not fire for every dock, which is why xev stays as a fallback.
