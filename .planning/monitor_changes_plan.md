# Monitor hotplug plan

Plan for `scripts/monitor_changes.sh`. Written 2026-10-09.

## Goal and current state

`monitor_changes.sh` should detect monitors being plugged or unplugged, work out the right layout, and apply it with xrandr and `hc set_monitors`, with no manual steps.

Today the script only watches `xev -root -event randr`, filters Connected/Disconnected lines with gawk, prints them, and emits a placeholder `test` hook. Nothing consumes the hook. `monitors.autostart` still hardcodes `hc set_monitors 2560x1600+0+0` (laptop panel only).

## Decisions made

- **One trigger.** Connected and Disconnected are not distinguished. Either fires a single "monitors changed" event, and the handler compares the current state with the stored `my_monitor_layout` attribute. It acts only if they differ.
- **Layouts keyed by the exact monitor set**, matched by output names or EDIDs. Each layout carries its own laptop-panel setting: on (with a position) or off. The panel is not turned off globally, only where a layout says so (per-combination rule).
- **Unknown sets** keep the panel on and use the heuristic fallback: primary fullscreen, half screens on the others, stacked fullscreen if under 1080p.
- **Layout data lives in a separate config file** sourced by the script.
- **The script owns xrandr.** The layout config drives both the xrandr calls and `hc set_monitors`.
- **Event source:** try `udevadm monitor` first and always keep xev as a fallback. Both feed the same debounced trigger.

## Implementation steps

Steps 1 and 2 come first. Everything else builds on them, and they can be tested by hand, with no hotplug events involved.

1. **FIRST: Reconcile core.** A single `reconcile` function that reads the current state (active outputs, modes, EDID identity per output), builds a canonical layout string, and compares it with the `my_monitor_layout` attribute. If equal, do nothing. If different: pick a layout, run xrandr, run `hc set_monitors`, store the new string. Callable from the command line so it can be tested without events.
2. **FIRST: Config format.** A sourced file (e.g. `monitor_layouts.conf`) mapping an exact monitor set to its layout: per-output mode, position, primary, and the laptop panel as `on <position>` or `off`. Define the key format (sorted output names or EDID hashes) and the lookup function. Includes the unknown-set fallback rules.
3. **Safety guard.** Never turn the panel off unless another output is active and the xrandr call for it succeeded. If anything fails, leave the panel on.
4. **Hook plumbing.** Replace the placeholder `test` hook with a real name (e.g. `monitors_changed`) and a consumer that runs `reconcile`.
5. **Event source: udevadm.** Trial `udevadm monitor` on DRM events as the primary trigger. Test on real hardware.
6. **Event source: xev fallback and debounce.** Keep the existing xev pipeline as the fallback, chosen automatically if `udevadm` is missing or not working, with an override flag. Both sources feed one debounce that collapses bursts of events into a single `reconcile`.
7. **Startup integration.** Replace the static `set_monitors` in `monitors.autostart` with one call to `reconcile`, and check ordering against `startup.autostart` (the panel/padding unlock comment).
8. **Bars and padding.** After a layout change, reload polybar/lemonbar and reapply padding so panels land on the right monitors.
9. **Unknown-monitor wallpaper.** If any current EDID is not in the known list, switch to an inoffensive wallpaper. Replace the plain-text EDID scraping with something robust that tells identical monitors apart.
10. **Testing.** Walk through plug/unplug cases on real hardware: laptop only, laptop plus one external, the 3-monitor desk setup, an unknown projector, and unplugging mid-reconcile.

## Risks and open items

- **Event bursts.** One dock can fire several events. The debounce in step 6 and a short wait for xrandr to settle should cover this.
- **No display left.** Turning the panel off on a bad detection is the worst failure; step 3 guards it.
- **Identical monitors.** Name-based matching cannot tell two of the same model apart; EDID serial or port position may be needed.
- **udevadm reliability.** It may not fire on every kind of hotplug (e.g. some docks), which is why xev stays as a fallback.
- [ ] Choose the layout key: output names, EDID hashes, or both.
- [ ] Choose how the fallback is selected: auto-detect only, or auto-detect plus a `--xev` override flag.
