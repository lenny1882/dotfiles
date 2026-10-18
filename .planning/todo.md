# Todo

Ordered from the cheapest win (1) to the least worthwhile (last). A new item gets a table row and a section; place both by its priority.

## How items are weighted and ordered

Each item is scored 1 to 5 on three things. The scores are judgments from the notes in the section, not measurements; revisit them when the notes change.

- Effort: how much work it is. 1 is a few minutes or one small edit, 3 is a script or a few files plus checking, 5 is a large piece of design and build.
- Blast radius: how much existing setup a change can break, or how hard it is to undo. 1 is additive or isolated, 3 touches shared setup scripts or system files, 5 touches most of the repo.
- Improvement: how much better things are afterwards. 1 is cosmetic or tidying, 3 is a clear everyday gain or a fix for something broken, 5 protects against data loss or removes a major pain.

Priority = improvement / (effort + blast radius), to two decimals. Higher is a better win and goes nearer the top. Ties: the lower-effort item goes first.

Each section carries a `Weighting:` line under its heading with the same numbers. When adding an item, score it, compute the priority, insert its row in the table and its section in the same position, and renumber.

| # | Item | Effort | Blast | Improvement | Priority |
|---|------|--------|-------|-------------|----------|
| 1 | Backups | 4 | 1 | 5 | 1.00 |
| 2 | Automount removable drives on plug-in | 3 | 2 | 4 | 0.80 |
| 3 | Picom config | 2 | 2 | 3 | 0.75 |
| 4 | Keybinding cheat-sheet | 2 | 1 | 2 | 0.67 |
| 5 | Clipboard history | 2 | 1 | 2 | 0.67 |
| 6 | Repo cleanup | 2 | 2 | 2 | 0.50 |
| 7 | Quickstart steps for makepkg and the power group | 2 | 2 | 2 | 0.50 |
| 8 | Skip machine-specific symlinks | 3 | 3 | 3 | 0.50 |
| 9 | nnn as the default file explorer | 3 | 2 | 2 | 0.40 |
| 10 | Remove unused network managers | 1 | 2 | 1 | 0.33 |
| 11 | System theme changer in the tui | 5 | 4 | 3 | 0.33 |
| 12 | Script consistency and shared helpers | 5 | 5 | 3 | 0.30 |
| 13 | Lock screen look | 4 | 3 | 2 | 0.29 |

## Backups

Weighting: effort 4, blast radius 1, improvement 5, priority 1.00.

Likely file backups only, not system backups: the os is ephemeral because the dotfiles are versioned and the quickstart scripts rebuild it. Mechanism, target and scope not decided.

Current state:
- No backup or snapshot tool is installed (checked: timeshift, snapper, borg, restic, rsnapshot, btrbk, rclone). `rsync` is installed.
- `dropbox` is installed, but it is sync, not a backup: a deletion propagates.
- Both drives are internal NVMe with ext4: `/` (34G used of 455G) and `/media/Storage` (638G used, 231G free). `/media/Storage` holds the dotfiles repo and, by default, the user directories (`symlinks.sh` links Documents, Downloads, Music, Pictures and Videos from `/media/Storage/User`; `USER_DIR` overrides). No external drive was seen.
- Nothing has a second copy, so a drive failure or a bad delete loses data. The dotfiles repo is in git.

Options, file-level backup:
- `restic` or `borg`: deduplicated, versioned, can be encrypted; to an external drive, a remote over ssh (`openssh` is installed), or cloud storage.
- `rsync` with `--link-dest` (or `rsnapshot`): plain folders of hardlinked snapshots, readable without special tools; `rsync` is already installed.

Not planned, system rollback: real snapshots need a filesystem or volume change (btrfs, or lvm; `lvm2` is installed but the disks are plain partitions), and `timeshift` is aimed at system files. Listed in case that changes.

To decide:
- what to protect: user data on `/media/Storage`, and whether anything outside it matters (`/etc`, the package list; whether the package list is already kept in the repo was not checked)
- where it goes: an external drive, a second machine or remote over ssh, cloud storage
- how often, and whether it runs from a systemd timer (as `fstrim.timer` does) or by hand

## Automount removable drives on plug-in

Weighting: effort 3, blast radius 2, improvement 4, priority 0.80.

Nothing mounts a drive when it is plugged in; mounting is manual through the nnn plugins (`nmount`, `umounttree`, `mtpmount`; not read, inferred from their names). Mechanism not decided.

Installed: `udisks2`, `gvfs`. Not installed: `udiskie`.

Options:
- `udiskie`: small daemon (optional tray icon) that automounts through `udisks2`, no file manager needed. Needs installing and starting from the herbstluftwm autostart.
- `gvfs`: already installed; can automount through its udisks2 volume monitor. Not checked here whether it runs outside a gnome-style session.
- `x-systemd.automount` fstab entries: only for known, fixed drives, not arbitrary pen drives; `setup/add_drive_fstab.sh` could add the option.
- Custom udev rule plus a systemd mount unit: the most manual, and the most control over where and how drives mount.

To decide: where drives should mount (`/run/media/$USER` is the udisks2 default), whether phones (mtp) are included, and whether a notification is wanted on mount.

## Picom config

Weighting: effort 2, blast radius 2, improvement 3, priority 0.75.

herbstluftwm starts picom with the old compton config (`startup.autostart` line 10: `picom --config ~/.config/compton.conf`).
- Rename the config to `picom.conf`, updating the flag, the symlink and `setup/notes.txt`.
- `compton.conf` sets `backend` twice (`"glx"` on line 3, `"xrender"` on line 33). The later one probably wins, so the glx/vsync tearing fix is likely not in effect. Not confirmed; check which backend picom loads, then remove the duplicate.

## Keybinding cheat-sheet

Weighting: effort 2, blast radius 1, improvement 2, priority 0.67.

A popup that lists the herbstluftwm keybinds so one can be looked up without opening the files.

Current state:
- Binds are defined in `keybindings.autostart` (36 `keybind` lines) and `shortcuts.autostart` (19). Counts are of lines containing `keybind`, not checked for comments or duplicates.
- No existing cheat-sheet or bind-listing script was found in `scripts/`.
- `rofi` is installed and configured (`config.rasi`, `custom.rasi`), with a `scripts/rofi-wrap.sh` wrapper.

Not decided or checked:
- whether to build the list from the live bindings (`herbstclient list_keybinds`) or from the autostart files; the files carry comments, the live list does not
- whether the nnn and micro bindings are included, or only herbstluftwm

## Clipboard history

Weighting: effort 2, blast radius 1, improvement 2, priority 0.67.

No clipboard manager is installed (nothing found for `xclip`, `xsel`, `clipmenu`, `greenclip`, `copyq`). The only clipboard tools seen are the nnn plugins `cbcopy-mac` and `cbpaste-mac`. Options such as `clipmenu` (rofi-compatible; `rofi` is installed), `greenclip` and `copyq` were not checked against this setup. Not decided; the work is optional.

## Repo cleanup

Weighting: effort 2, blast radius 2, improvement 2, priority 0.50.

Findings from a read-only pass over the tracked files. "Referenced" means the file name appears in another tracked file outside `.planning/` and the backups; nothing was run. Git history keeps anything deleted.

### herbstluftwm folder (`symlinks/home_@user@_.config_herbstluftwm`)
- Backups with no references: `autostart.bak`, `autostart.bak.bak`, `autostart.orig-bak`, `autostart-3monitors` (about 1,000 lines in total).
- Other files with no references: `12palette`, `scripts/supplemental.kmap` (a console keymap), and the polybar scripts `0` (empty), `colors_nord`, `info-hlwm-workspaces.sh`, `pipewire.sh`.
- `[module/dsp]` in `polybar/polybar.ini` is defined but not listed in any `modules-` line.
- `autostart` ends with about 20 blank lines.

### `setup/quickstart_arch.sh`
- About 50 commented-out lines at the end (easystroke, sublime, unifi), and the commented `yay -Rdd ttf-harmonyos-sans` at line 377. `easystroke` and `sublime-text-4` are installed, so those blocks look like leftovers.

### Root
- `screenshot.png` (2.6M) is at the repo root and nothing references it.

### `setup/disable_ipv6.sh`
- Nothing calls it, and ipv6 is currently on (`/proc/sys/net/ipv6/conf/all/disable_ipv6` is 0). Either wire it into the quickstart or delete it.

### nnn
- `symlinks/home_@user@_.config_nnn_plugins` holds 60 files, but `NNN_PLUG` in `scripts/nnn-wrap.sh` binds only three (`fzopen`, `dragdrop`, `xdgdefault`). The rest look like the upstream plugin set, including `*-mac` ones and ones for programs that may not be installed (`kdeconnect`, `mocq`, `cmusq`). Plugins can be run other ways, so unused is not certain. They could be fetched at install time with the `getplugs` plugin instead of tracked.
- `symlinks/home_@user@_.config_nnn_sessions_startup` is a binary nnn session file holding machine paths: state, not config.

### Smaller items
- Two nano configs, `root_.nanorc` and `home_@user@_.config_nano_nanorc`, alongside micro. Which editors are in use was not checked.
- `etc_pacman.d_hooks_expressvpn.hook` has the header comment `# /etc/pacman.d/hooks/clean-cache.hook`; a copy-paste slip, the hook itself is fine.
- `monitor_check.sh` has one failing check, "background: the solid image" (it fails the same way without the reconcile fix); likely a stale expected colour after the Colours renames. Not looked into.
- Polybar `ups` still shows `? | ?` after any restart of the panel that is not a lock: a real monitor layout change, a herbstluftwm reload, or a `polybar.ini` save (polybar's own `--reload`). `panel.sh` skips the `hook 0` send after its first run (`my_not_first_autostart_panel`), and a polybar reload never runs `panel.sh`. Lock/unlock no longer restarts it since the `get_attr` fix in `monitor_reconcile.sh`. Left as is: these restarts are rare and a count refresh means querying aur.

### Simplify (judgment calls, not read in depth)
- `setup/notes.txt`: the numlock, xsession and swap sections are now done by `startup.autostart`, `config_links.sh` and the swappiness symlink, so they could go.
- Colours files: `colours.sh`, `colours.g.sh`, `colours.rules.sh`, `colours-derive`, `colours-gen`. Recent work; their contents were not looked at.
- `.planning/monitor_changes/monitor_tui_check.py` (76K) and `monitor_check.sh` (28K): test scaffolding for work that may be finished.

Not covered: the large scripts (`monitor_tui.py`, `monitor_reconcile.sh`, the rest of `quickstart_arch.sh`) were not read for internal simplification.

## Quickstart steps for makepkg and the power group

Weighting: effort 2, blast radius 2, improvement 2, priority 0.50.

Two manual steps from `setup/notes.txt` that `quickstart_arch.sh` does not script yet.
- Makepkg: turn `debug` into `!debug` in the `OPTIONS=` line of `/etc/makepkg.conf`. Already set on this machine; the step must be safe to rerun.
- Power group: create the `npwpower` group if missing and add the user to it. The polkit rule that gives the group its rights already comes from `config_links.sh`. The old `visudo` line in the notes looks replaced by that rule; not confirmed.

## Skip machine-specific symlinks

Weighting: effort 3, blast radius 3, improvement 3, priority 0.50.

`setup/config_links.sh` links every entry in `symlinks/` except names containing `.bak`. The nvidia conf (`etc_X11_mhwd.d_nvidia.conf`) is still linked on this amd machine.
- Prefix: extend the `.bak` rule so a prefix marks a file as ignored.
- Selection: the quickstart lists the symlink entries and lets you pick which to install, like the package selection. Asks every run; choices are not remembered.
- The shellrc files already use a prefix to opt out of loading (`shell_loader.sh` sources only `.shellrc*`, so renaming a file to `_.shellrc_*` disables it). The same prefix could be used to ignore symlinks, so there is one convention for both.

## nnn as the default file explorer

Weighting: effort 3, blast radius 2, improvement 2, priority 0.40.

Every program that opens a file explorer currently uses its own. Find how to make nnn the default for everything.

Current state:
- `inode/directory` already resolves to `nnn.desktop` (checked with `xdg-mime query default`), and `~/.config/mimeapps.list` has no directory entry, so the default comes from the `.desktop` files.
- Which programs still open their own explorer has not been checked.

Places to look (not checked):
- programs that ignore the mime default and run their own explorer or call one directly
- file open/save dialogs in GTK and Qt programs, which are not file-explorer launches and may need separate handling
- how nnn is launched from a gui program, since it is a terminal program and `nnn.desktop` would need a terminal

## Remove unused network managers

Weighting: effort 1, blast radius 2, improvement 1, priority 0.33.

NetworkManager is the one in use (enabled, default wpa_supplicant backend). `iwd` and `netctl` are explicitly installed but not enabled or configured, and nothing requires them. Remove both.

## System theme changer in the tui

Weighting: effort 5, blast radius 4, improvement 3, priority 0.33.

Switch the whole system between dark, light, etc. from the tui, setting every place that needs it.

Places known so far:
- `gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'` (needed for vivaldi to use its dark theme)
- GTK theme
- Qt theme

Not needed: terminal, editor and wallpaper, which are set by hand.

When building: survey the installed programs and the ui framework each is built with, so each can be made to read the system theme.

## Script consistency and shared helpers

Weighting: effort 5, blast radius 5, improvement 3, priority 0.30.

Go through all of the scripts: simplify them, make them consistent with each other, and look at improvements, including shared helpers and utils. Nothing decided; the notes below come from a quick survey of the tracked scripts (headers, indentation and helper names only; the bodies were not read).

Scripts, by area (approximate lines):
- `setup/`: `quickstart_arch.sh` (1,141), `add_drive_fstab.sh` (227), `colours-derive` (152), `colours.sh` (145), `config_links.sh` (80), `colours.rules.sh` (63), `shell_loader.sh` (42), `colours-gen` (38), `symlinks.sh` (24), `disable_ipv6.sh`.
- herbstluftwm `*.autostart` files (11 to 77 lines each) and `scripts/`: `monitor_tui.py` (2,515), `monitor_reconcile.sh` (392), `pty_inset.py` (163), `panel.sh` (93), `tag_layouts.sh` (80), `tag_windows.sh`, `background.sh`, `tags.sh`, `rule_hook.sh`, `monitor_changes.sh`, `brightness.sh`, `volume.sh`, `tag_programs.sh`, `screenshot.sh`, plus the small wrappers `nnn-wrap.sh`, `bottom-wrap.sh`, `monitor-tui-wrap.sh`, `rofi-wrap.sh`, `xrdb-wrap.sh`.
- `polybar/scripts/`: `network-interfaces.sh` and the unreferenced ones listed under Repo cleanup.

Inconsistencies seen:
- Indentation: the `setup/` scripts use tabs; the herbstluftwm scripts use spaces; `panel.sh` has both.
- Shebangs: `#!/usr/bin/env bash`, `#!/bin/bash`, `#!/bin/sh` and `#! /bin/sh` are all used. Which scripts need bash and which are posix sh was not checked.
- The `hc()` herbstclient wrapper is defined separately in `panel.sh`, `rule_hook.sh`, `tag_layouts.sh`, `tag_windows.sh`, `tags.sh` and `variables.autostart`.
- `nnn-wrap.sh`, `monitor-tui-wrap.sh`, `rofi-wrap.sh`, `xrdb-wrap.sh`, `panel.sh` and `variables.autostart` all reference the colours code (`colours.sh` / `colour_hex`); whether they share a pattern was not checked.

Not decided: a shared helpers file (for `hc` and the colours lookup, for example), one indentation style, and one shebang convention. Also the repo's existing preference for bash over adding a new language (`monitor_tui.py` and `pty_inset.py` are already python).
## Lock screen look

Weighting: effort 4, blast radius 3, improvement 2, priority 0.29.

physlock is a bare lock screen. The aim is to improve how it looks, ideally so login (lemurs) and unlock share one look; at the least, the lock screen looks better. Whether physlock itself can be extended, or something else would have to replace it, is not known.

Constraints from the user:
- physlock replaces the wm view on a console instead of drawing a program over it, and blocks switching to another tty; programs that draw above the wm/de can show rendering problems or be bypassed.
- Whatever is used must keep that: no bypass through another tty, no rendering problems.

Current state (checked):
- physlock 13-5, installed setuid root (`/usr/bin/physlock`). Run as `physlock -dsm` from `Super-l` (`shortcuts.autostart`) and from a polybar click (`polybar/polybar.ini`); it is in the quickstart packages. The usage line lists `-dhLlmsv` and `-p MSG`.
- Its PAM service (`/etc/pam.d/physlock`) is plain `pam_unix.so` for auth, account, password and session.
- lemurs runs on tty 2 with its own PAM service (`pam_service = "lemurs"` in the generated `etc_lemurs_config.toml`; `/etc/pam.d/lemurs` exists). Its colours come from the colours templates.
- `xss-lock` (idle locking) is an optional dependency of physlock and is not installed; idle lock was ruled out.

Not checked (from memory, to confirm):
- what the flags mean (`-d` detach, `-s` disable SysRq, `-m` mute kernel messages, `-p` prompt message) and whether `-p` gives any control over the look
- whether lemurs can be run as a locker at all, or is only a login screen that starts a session; if it only starts sessions, unlocking would mean ending the session
- whether physlock's source has hooks or options for how the prompt is drawn
- alternatives that also take over a console, if any exist
