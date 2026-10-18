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
| 3 | GUI session environment lacks the shellrc exports | 2 | 2 | 3 | 0.75 |
| 4 | Clipboard history | 2 | 1 | 2 | 0.67 |
| 5 | Repo cleanup | 2 | 2 | 2 | 0.50 |
| 6 | nnn as the default file explorer | 3 | 2 | 2 | 0.40 |
| 7 | Remove unused network managers | 1 | 2 | 1 | 0.33 |
| 8 | System theme changer in the tui | 5 | 4 | 3 | 0.33 |
| 9 | Script consistency and shared helpers | 5 | 5 | 3 | 0.30 |
| 10 | Lock screen look | 4 | 3 | 2 | 0.29 |

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

## GUI session environment lacks the shellrc exports

Weighting: effort 2, blast radius 2, improvement 3, priority 0.75.

The session never reads the shellrc files. lemurs starts it through a non-interactive login shell (`shell_login_flag = "short"`), which reads `~/.bash_profile`, which sources `~/.bashrc`, which returns at line 6 (`[[ $- != *i* ]] && return`) before the injected block that sources `shellrc/`. Checked: `BROWSER`, `EDITOR` and `SSH_AUTH_SOCK`, exported in `shellrc/.shellrc_env`, are not in herbstluftwm's environment, so they only reach apps started from a terminal.
- `SSH_AUTH_SOCK` may matter for GUI apps that use ssh (git in an editor, for example). Not checked.
- The portal variables for the file dialogs are already set with `hc export` in `startup.autostart`, for this reason.
- Options: more `hc export` lines in `startup.autostart` (instant, tracked), or exports in the lemurs session script `etc_lemurs_wms_herbstluftwm` (needs a re-login and the `/etc` link). Not decided which of the shellrc exports belong in the session.

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

## nnn as the default file explorer

Weighting: effort 3, blast radius 2, improvement 2, priority 0.40.

Folders opened from GUI programs now go to nnn. File open and save dialogs do not, and are what is left.

Done:
- No other file manager is installed, so `inode/directory` resolves to `nnn.desktop` only. The package's entry ran plain `nnn`, and `xdg-open` ignores `Terminal=true`, so a GUI program's "open folder" ran nnn with no terminal (`xdg-open /tmp` printed `0 entries` and opened nothing).
- `symlinks/home_@user@_.local_share_applications_nnn.desktop` overrides it: `Exec=urxvt -name wrapper -e …/nnn-wrap.sh %f`, `Terminal=false`. Checked live: `xdg-open /tmp` opens a styled nnn window. The path is hardcoded to `/home/lenny`, as `home_@user@_.fehbg` is.
- A session load ignores the `PATH` argument, so `nnn-wrap.sh`, given a folder, starts nnn with `-s startup -P o`, where `o` is an inline `NNN_PLUG` command writing `+c<folder>` to nnn's plugin pipe (`+` is the first inactive context after the current one). Checked live: the folder opens in context 5 and nnn switches to it. Contexts 1 to 4 still hold the session. The plugins folder must be a working link (`~/.config/nnn/plugins` to `/usr/share/nnn/plugins`, see the "nnn plugins" quickstart step); a dangling link made the plugin fail with "no such file or directory".
- VS Code's "Open Containing Folder" asks the portal first, and GLib found no handler for folders (the user-level `nnn.desktop` shadows the package's, and the user `mimeinfo.cache` did not list it), so an empty "Open With" chooser appeared before the `xdg-open` fallback. Fixed by `update-desktop-database ~/.local/share/applications`, now run by the quickstart's "Link config files" step. Checked live: it opens straight in nnn, for "Open Containing Folder" and for the command palette's "Open Logs Folder" and similar commands.

File open and save dialogs: built as our own portal backend, no new package. VS Code's "Open Folder" is a `GtkFileChooserDialog` served by `xdg-desktop-portal-gtk`, so the portal's FileChooser backend had to be replaced, not a launcher.
- `scripts/nnn-portal.py` (Python, Gio) owns `org.freedesktop.impl.portal.desktop.nnn` and implements `OpenFile` and `SaveFile`. Each dialog runs `nnn-wrap.sh --pick file|dir|save OUT START [NAME]` in the urxvt wrapper window; nnn writes the chosen path to OUT, which is gone or empty on a cancel (replied as cancelled). The startup session is loaded and the application's `current_folder` opens in the first inactive context (`-P o`).
- Keys in picker mode: Enter picks a file or the selection, `;p` (or Alt+p) picks the folder shown (dir dialogs), `;s` (Alt+s) asks for a file name, prefilled, in the folder shown (`scripts/nnn-pick-save.sh`, which ends the pick with the plugin pipe's `0p`).
- Registration, linked from `symlinks/`: the D-Bus activation file, `/usr/share/xdg-desktop-portal/portals/nnn.portal`, and `~/.config/xdg-desktop-portal/portals.conf` (FileChooser prefers `nnn;gtk`). The portal does not fall back to gtk when the backend fails at runtime.
- Checked live: VS Code's File > Open Folder works, with contexts 1 to 4 populated, and cancelling no longer hangs VS Code (a cleanup crash on a missing output file was not sending the reply).
- Checked live since: Open File, Open Folder and Save As (`;s`) all work. Vivaldi and Rambox open the right folder from the downloads list, and Vivaldi's Open File uses nnn. `SaveFiles` (several files at once) is not implemented: nothing known calls it (`libportal` is not installed), held off.
- Which apps reach it depends on the app. `startup.autostart` exports `GTK_USE_PORTAL=1` and `QT_QPA_PLATFORMTHEME=xdgdesktopportal` (`hc export`, so everything herbstluftwm starts has them), which sends GTK native choosers and Qt native dialogs through the portal. Checked with xprop and by trying each app, with the variables confirmed in the running processes:
  - nnn: VS Code, Vivaldi, Rambox (portal); Orca Slicer, Sublime Text (GTK native chooser); FreeCAD (Qt native dialog).
  - Own dialog, the variables do not help: Inkscape (plain `GtkFileChooserDialog`; known to ignore `GTK_USE_PORTAL`, see upstream issue inkscape/inbox 783), Bambu Studio (statically linked wxWidgets references only `gtk_file_chooser_dialog_new`, where Orca's references `gtk_file_chooser_native_new`), Blender (draws its own file browser), Krita (Qt's own widget dialog).
  - Krita has a setting, not yet tried: Settings > Configure Krita > General > Miscellaneous > "Enable native file dialogs" (`DontUseNativeFileDialog` in `kritarc`; greyed out in AppImage builds, this is the Arch package). From forum threads, not verified here.
- Fresh install: after "Link config files" the D-Bus services folder did not exist when the session bus started, so the bus config needs a reload (`busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig`) and the portal a restart (`systemctl --user restart xdg-desktop-portal`) once. No quickstart step does that yet.
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
