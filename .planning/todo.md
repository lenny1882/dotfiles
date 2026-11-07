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
| 3 | Clipboard history | 2 | 1 | 2 | 0.67 |
| 4 | Repo cleanup | 2 | 2 | 2 | 0.50 |
| 5 | System theme changer in the tui | 5 | 4 | 3 | 0.33 |
| 6 | Script consistency and shared helpers | 5 | 5 | 3 | 0.30 |
| 7 | Lock screen look | 4 | 3 | 2 | 0.29 |
| 8 | GUI session environment lacks the shellrc exports | 2 | 2 | 1 | 0.25 |

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


## Clipboard history

Weighting: effort 2, blast radius 1, improvement 2, priority 0.67.

No clipboard manager is installed (nothing found for `xsel`, `clipmenu`, `greenclip`, `copyq`). `xclip` is installed, but only as the copy tool `scripts/screenshot.sh` pipes into; it keeps no history. The only other clipboard tools seen are the nnn plugins `cbcopy-mac` and `cbpaste-mac`. Options such as `clipmenu` (rofi-compatible; `rofi` is installed), `greenclip` and `copyq` were not checked against this setup. Not decided; the work is optional.

## Repo cleanup

Weighting: effort 2, blast radius 2, improvement 2, priority 0.50.

Findings from a read-only pass over the tracked files. "Referenced" means the file name appears in another tracked file outside `.planning/` and the backups; nothing was run. Git history keeps anything deleted.

### Smaller items
- Polybar `ups` still shows `? | ?` after any restart of the panel that is not a lock: a real monitor layout change, a herbstluftwm reload, or a `polybar.ini` save (polybar's own `--reload`). `panel.sh` skips the `hook 0` send after its first run (`my_not_first_autostart_panel`), and a polybar reload never runs `panel.sh`. Lock/unlock no longer restarts it since the `get_attr` fix in `monitor_reconcile.sh`. Left as is: these restarts are rare and a count refresh means querying aur.

### Simplify (judgment calls, not read in depth)
- Colours files: `colours.sh`, `colours.g.sh`, `colours.rules.sh`, `colours-derive`, `colours-gen`. Recent work; their contents were not looked at.
- `.planning/monitor_changes/monitor_tui_check.py` (76K) and `monitor_check.sh` (28K): test scaffolding for work that may be finished.

Not covered: the large scripts (`monitor_tui.py`, `monitor_reconcile.sh`, the rest of `quickstart_arch.sh`) were not read for internal simplification.

## System theme changer in the tui

Weighting: effort 5, blast radius 4, improvement 3, priority 0.33.

Switch the whole system between dark, light, etc. from the tui, setting every place that needs it.

Places known so far:
- `gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'` (needed for vivaldi to use its dark theme)
- GTK theme
- Qt theme

Not needed: terminal, editor and wallpaper, which are set by hand.

Survey of the quickstart package list, by toolkit (checked by the libraries each binary links; the apps with no match were judged by hand, not tested):
- GTK 3: gnome-disk-utility, gthumb, gpick, peek, xarchiver, easystroke, dragon-drop, Inkscape, minecraft-launcher; Orca Slicer and Bambu Studio (wxWidgets on GTK).
- GTK 4: pavucontrol, scangearmp2.
- Qt 6: Krita, FreeCAD, easyeffects.
- Chromium or Electron: Vivaldi, Rambox, VS Code, Obsidian. Vivaldi links Qt too.
- Own UI, nothing for the changer to set: Blender, Sublime Text, mpv, tigervnc.
- Already themed by the colours project, not this feature: rofi, dunst, polybar, urxvt, feh.
- Versions: gtk3 3.24.52, gtk4 4.24.1, libadwaita 1.10.0, qt6-base 6.12.0.

State and tests so far (2026-11-02):
- `color-scheme` is `prefer-dark` and `gtk-theme` is `Adwaita`. `~/.config/gtk-3.0` and `gtk-4.0` are empty (no `settings.ini`). The session sets `GTK_USE_PORTAL=1` and `QT_QPA_PLATFORMTHEME=xdgdesktopportal`; `GTK_THEME` is not set.
- The portal follows `color-scheme`: `org.freedesktop.appearance color-scheme` reads 1 for `prefer-dark` and 2 for `prefer-light` (`busctl --user call org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop org.freedesktop.portal.Settings Read ss org.freedesktop.appearance color-scheme`). The first read after a change was stale once (still 1); the cause was not found, and later reads were right at once. `portals.conf` has `default=gtk`, so Settings comes from `xdg-desktop-portal-gtk`.
- pavucontrol (GTK 4) ignores `color-scheme`: screenshots of a fresh launch under `prefer-light` and under `prefer-dark` are identical and both light. Not a live-update problem. Why is unknown: libgtk-4 has `gtk-interface-color-scheme`, and nothing pins the theme.
- `GTK_THEME=Adwaita:dark pavucontrol` opens dark, so the GTK theme name is a mechanism that works.
- Krita and Vivaldi: no visible change could be seen on a `color-scheme` change. Not a clear test; Vivaldi's browser UI has its own theme setting ("Use system theme"), and a page that follows the system would be the better test.
- Not tested: GTK 3 apps (gthumb is the one to try), whether Qt apps follow anything, and whether the "needed for vivaldi" note still holds.

Idea to test first (not built): write `~/.config/gtk-3.0/settings.ini` and `~/.config/gtk-4.0/settings.ini` with `gtk-application-prefer-dark-theme` (1 or 0) and keep `color-scheme` set alongside for the Chromium apps; then launch pavucontrol and gthumb in each mode. Unknown whether the settings files work for GTK 4 as `GTK_THEME` did. The files would be tracked through `symlinks/`.

When building: the Qt apps and the Chromium apps still need a mechanism found; the survey above says what to cover.

## Script consistency and shared helpers

Weighting: effort 5, blast radius 5, improvement 3, priority 0.30.

Go through all of the scripts: simplify them, make them consistent with each other, and look at improvements, including shared helpers and utils. Nothing decided; the notes below come from a quick survey of the tracked scripts (headers, indentation and helper names only; the bodies were not read).

Scripts, by area (approximate lines):
- `setup/`: `quickstart_arch.sh` (1,141), `add_drive_fstab.sh` (227), `colours-derive` (152), `colours.sh` (145), `config_links.sh` (80), `colours.rules.sh` (63), `shell_loader.sh` (42), `colours-gen` (38), `symlinks.sh` (24).
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

## GUI session environment lacks the shellrc exports

Weighting: effort 2, blast radius 2, improvement 1, priority 0.25.

Deferred. The session never reads the shellrc files. lemurs starts it through a non-interactive login shell (`shell_login_flag = "short"`), which reads `~/.bash_profile`, which sources `~/.bashrc`, which returns at line 6 (`[[ $- != *i* ]] && return`) before the injected block that sources `shellrc/`. Checked live: none of `SSH_AUTH_SOCK`, `EDITOR`, `VISUAL` or `BROWSER`, exported in `shellrc/.shellrc_env`, are in herbstluftwm's environment, so they only reach apps started from a terminal.

Nothing depends on them today, so the gain is small:
- `SSH_AUTH_SOCK`: the GitHub key (`~/.ssh/github_lenny1882`, set in `~/.ssh/config`) has no passphrase, so git over ssh from a GUI app (VS Code) reads the key file directly and does not need the agent. It would matter for a key with a passphrase, which `AddKeysToAgent yes` would cache.
- `BROWSER`: GUI apps open links through `xdg-open`, and `xdg-settings` already returns `vivaldi-stable.desktop`.
- `EDITOR` and `VISUAL`: `micro` runs in a terminal; a GUI app launching it would have no terminal.
- The portal variables for the file dialogs are already set with `hc export` in `startup.autostart`, which is where any of these would go (instant, tracked). The alternative is the lemurs session script `etc_lemurs_wms_herbstluftwm` (needs a re-login and the `/etc` link).
- Revisit if a passphrase key is added, or a keybinding or script needs one of these.
