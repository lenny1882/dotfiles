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
| 4 | System theme changer in the tui | 1 | 1 | 1 | 0.50 |
| 5 | Repo cleanup | 2 | 2 | 2 | 0.50 |
| 6 | Header bar and border fix for the wrapper windows | 3 | 1 | 2 | 0.50 |
| 7 | Initramfs holds stale copies of the /etc config | 1 | 2 | 1 | 0.33 |
| 8 | Script consistency and shared helpers | 5 | 5 | 3 | 0.30 |
| 9 | Lock screen look | 4 | 3 | 2 | 0.29 |
| 10 | GUI session environment lacks the shellrc exports | 2 | 2 | 1 | 0.25 |

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

## System theme changer in the tui

Weighting: effort 1, blast radius 1, improvement 1, priority 0.50 (rescored 2026-11-07 for the follow-ups left; the changer itself is built).

Switch the whole system between dark, light, etc. from the tui, setting every place that needs it.

Built and tried live (2026-11-07, commits `6c0b6ec` and `7433a74`): `setup/theme.sh` (`apply dark|light`, `current`, `scheme`), the four files in `setup/themes/`, the quickstart step "Theme (dark or light)", and a Theme panel on the tui overview under Tags. Enter on the panel starts the edit, ↑/↓ choose Dark or Light, Enter applies, Esc cancels; the footer shows `dark applied` or the error. The live test in the user's session was fine. The same session made Enter the commit key across the tui (Ctrl-S only in the layout editor, where Enter is a newline) and removed Ctrl-C; `tui_spec.md` and the checklist (T1 to T6) describe both.

Not needed: terminal, editor and wallpaper, which are set by hand.

Survey of the quickstart package list, by toolkit (checked by the libraries each binary links; the apps with no match were judged by hand, not tested):
- GTK 3: gnome-disk-utility, gthumb, gpick, peek, xarchiver, easystroke, dragon-drop, Inkscape, minecraft-launcher; Orca Slicer and Bambu Studio (wxWidgets on GTK).
- GTK 4: pavucontrol, scangearmp2.
- Qt 6: Krita, FreeCAD, easyeffects.
- Chromium or Electron: Vivaldi, Rambox, VS Code, Obsidian. Vivaldi links Qt too.
- Own UI, nothing for the changer to set: Blender, Sublime Text, mpv, tigervnc.
- Already themed by the colours project, not this feature: rofi, dunst, polybar, urxvt, feh.
- Versions: gtk3 3.24.52, gtk4 4.24.1, libadwaita 1.10.0, qt6-base 6.12.0.

Mechanisms found (tested 2026-11-07 in the X11 session, `XDG_SESSION_TYPE=x11`; the session sets `GTK_USE_PORTAL=1` and `QT_QPA_PLATFORMTHEME=xdgdesktopportal`):
- `gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'` (or `prefer-light`) covers Qt 6 and Chromium, with no file. Designer, Linguist and Assistant (Qt 6) and a local page in Vivaldi follow it on a fresh start.
- GTK 3 follows `gtk-application-prefer-dark-theme` (1 or 0) in `~/.config/gtk-3.0/settings.ini` (xarchiver: no file light, 1 dark, 0 light). It ignores `color-scheme`.
- GTK 4 follows `gtk-interface-color-scheme` in `~/.config/gtk-4.0/settings.ini` (pavucontrol). The value must be the name `dark` or `light`, not the enum number: `2` and `3` give "value that cannot be interpreted". `gtk-application-prefer-dark-theme` is read in GTK 4 but has no effect (deprecated since 4.20). `gtk4-query-settings` and `gtk-query-settings` print what GTK read, which is the quick check.
- `GTK_THEME=Adwaita:dark` also works, but it is an environment variable and cannot change a running session.

Why GTK 4 ignores the portal: `gtk-interface-color-scheme` reads `UNSUPPORTED` on X11. Strings in `libgtk-4.so.1` put the portal Settings reader (`org.freedesktop.appearance`, `ReadAll`) in `gdk/wayland/gdksettings-wayland.c`, and the X11 backend reads XSETTINGS, which has no key for it. From strings only, not the source. No XSETTINGS daemon is running.

Open windows do not update (tested with a window open while the setting was flipped):
- GTK 3 (xarchiver), GTK 4 (pavucontrol), Qt 6 (Designer, Linguist, Assistant, and a QML window): stay as they started. For Qt the portal signal arrives (`SettingChanged` on both namespaces, checked with `dbus-monitor`) and Qt's own scheme value changes (`Application.styleHints.colorScheme` went Light then Dark), but the window palette stays dark. The cause was not found; the plugin has a `settingChanged` slot and calls `requestColorScheme`.
- Chromium changes live: a local page in Vivaldi, Vivaldi's own tabs and toolbar, and Rambox when its theme is set to System.
- So a switch applies to programs started afterwards, except Chromium and Electron apps set to follow the system.

Apps with their own theme setting ignore `color-scheme` until that setting is changed in the app (not part of the changer):
- Rambox 3.1.2: was set to Dark; on System it follows live (tested).
- Krita 6.0.4.1: dark under both `prefer-light` and `prefer-dark` on a fresh launch (tested); `kritarc` has no theme key.
- VS Code 1.145.2: `workbench.colorTheme` is `Dark Modern` and `window.autoDetectColorScheme` is unset (config only). `window.autoDetectColorScheme` with `workbench.preferredDarkColorTheme` and `workbench.preferredLightColorTheme` should make it follow; not tested.
- Obsidian 1.14.5: `appearance.json` has `"theme": "obsidian"` (fixed dark), with the Minimal community theme (config only). `"system"` should make it follow; not tested.
- FreeCAD 1.1.4: `Theme` is `FreeCAD Dark` with its own stylesheet in `user.cfg` (config only, not launched).
- gthumb stays dark whatever the GTK 3 file says (its binary contains `prefer-dark`, so it likely sets it itself).

Other findings: the old "needed for vivaldi" note holds. The earlier "pavucontrol ignores `color-scheme`" result is explained by GTK 4 on X11 above, and "Krita and Vivaldi show no change" by their own theme settings. `gtk-interface-color-scheme=default` is accepted by GTK 4 and renders light, the same as no setting, so the changer can use `dark` and `light`.

The open Qt windows not re-theming: searched, no matching bug found. [QTBUG-116197](https://bugreports.qt.io/browse/QTBUG-116197) added the portal `SettingChanged` subscription (reported picked to 6.6 and 6.7), which fits the signal and Qt's scheme value updating here; [QTBUG-65475](https://bugreports-test.qt.io/browse/QTBUG-65475) says runtime palette changes are not propagated to all widgets. Cause still open.

Still open (small follow-ups; none block the changer, and the item can be dropped once they are done or declined):
- easyeffects (Qt 6, no theme setting seen) has not been launched under each setting.
- FreeCAD has not been launched; its config pins it to `FreeCAD Dark`.
- VS Code (`window.autoDetectColorScheme`) and Obsidian (`"theme": "system"`) set to follow the system have not been tried.
- Why open Qt windows do not re-theme: cause not found.

Decided (2026-11-07), and built as described:
- The `settings.ini` files: the repo tracks a dark and a light copy for GTK 3 and for GTK 4 (four small files, outside `symlinks/` because an entry there encodes a single target), and the changer points `~/.config/gtk-3.0/settings.ini` and `~/.config/gtk-4.0/settings.ini` at the chosen copy. The link lives in the home directory, so a switch does not dirty the git tree. A quickstart step sets the initial mode, including `color-scheme`, which nothing in the repo sets today (it was set by hand and lives in dconf).
- Open windows: nothing. The tui shows no note and offers no restart; a switch applies to programs started afterwards (and to Chromium and Electron apps set to follow the system).

Also decided (2026-11-07), and built:
- The four files live in `setup/themes/` (next to `setup/templates/`, outside the linker), named `gtk-3.0.dark.ini`, `gtk-3.0.light.ini`, `gtk-4.0.dark.ini` and `gtk-4.0.light.ini`.
- The tui lists a fixed pair of modes, dark and light, mapped to `prefer-dark` and `prefer-light` plus the matching file pair. A third mode is added when one exists; its `color-scheme` value has no obvious meaning yet.
- The current mode is read from both the link targets and `color-scheme`. It shows as dark or light when they agree and as "mixed" when they do not. Applying a mode sets all three places.

## Repo cleanup

Weighting: effort 2, blast radius 2, improvement 2, priority 0.50.

Findings from a read-only pass over the tracked files. "Referenced" means the file name appears in another tracked file outside `.planning/` and the backups; nothing was run. Git history keeps anything deleted.

### Smaller items
- Polybar `ups` still shows `? | ?` after any restart of the panel that is not a lock: a real monitor layout change, a herbstluftwm reload, or a `polybar.ini` save (polybar's own `--reload`). `panel.sh` skips the `hook 0` send after its first run (`my_not_first_autostart_panel`), and a polybar reload never runs `panel.sh`. Lock/unlock no longer restarts it since the `get_attr` fix in `monitor_reconcile.sh`. Left as is: these restarts are rare and a count refresh means querying aur.

### Simplify (judgment calls, not read in depth)
- Colours files: `colours.sh`, `colours.g.sh`, `colours.rules.sh`, `colours-derive`, `colours-gen`. Recent work; their contents were not looked at.
- `tests/monitor_tui_check.py` (76K) and `tests/monitor_check.sh` (28K): test scaffolding for work that may be finished.

Not covered: the large scripts (`monitor_tui.py`, `monitor_reconcile.sh`, the rest of `quickstart_arch.sh`) were not read for internal simplification.

## Header bar and border fix for the wrapper windows

Weighting: effort 3, blast radius 1, improvement 2, priority 0.50 (scores are a first guess; nothing is built or mocked).

The wrapper windows (nnn, btm, the monitor tui, bluetui, nmtui, the yay update) are `urxvt -name wrapper` windows, floating and centred at 1280x720 by the `wrapper` rule in `rules.autostart`. The blue border is urxvt's own: `wrapper*borderColor: col_blue` and `wrapper*internalBorder: 2` in `.Xresources`. `scripts/pty_inset.py` runs the program in a pty `M` cells smaller on every side (`M = 1`), rewriting cursor addressing so the program draws inside a blank margin. nnn goes through `nnn-wrap.sh` without `pty_inset.py`.

Idea: a header bar like a normal window's, drawn by `pty_inset.py` in a taller top margin (a row or two): a title passed as an argument, filled with a colour from the colours project. The program cannot scroll or overwrite it, because the scroll region is already pinned and the pty is already smaller. Possible additions, none tried: a clickable close button (the script already intercepts and shifts mouse reports), and live text redrawn on the 0.2 s select timeout. Limits: cell-sized, not pixel-sized; nnn would have to be routed through `pty_inset.py` to get one; the header must be redrawn after a resize. Herbstluftwm's own title bar (`theme.title_when`, `theme.floating.title_when`) is a separate option and was not tried; `theme.autostart` sets a title height and font but no `title_when`.

Bug to fix as part of it (reported by the user, not reproduced or investigated): making a floating wrapper window non-floating messes up the borders. The right and bottom borders come out about 4 times their normal size; the left and top stay the same. For reference, `theme.autostart` sets `theme.border_width 3` and `theme.floating.border_width 4`, and urxvt's `internalBorder` is 2; whether either is involved was not checked.

To decide: title bar in the wrapper (cells) or in herbstluftwm (pixels), a close button or not, and whether nnn is routed through `pty_inset.py`. Mock it first.

## Initramfs holds stale copies of the /etc config

Weighting: effort 1, blast radius 2, improvement 1, priority 0.33.

dracut builds the initramfs in hostonly mode (`/usr/lib/dracut/dracut.conf.d/hostonly/10-hostonly.conf`), and three of its modules copy host config into it: `80base` copies `/etc/modprobe.d/*.conf`, `11systemd-sysctl` copies `/etc/sysctl.d/*.conf`, and `74udev-rules` copies `/etc/udev/rules.d/*.rules`. A listing of the initramfs (`lsinitrd`, pasted by the user) showed the symlinks from `symlinks/` and also the files they point to, copied in; it was built 2026-11-01 22:10 by the `90-kernel-install.hook` run for kernel 7.2.14. Those copies are frozen until the next kernel install or a manual `dracut --force`.

What that does today (checked from the boot journal and the listing, not on a fresh install):
- `99-swappiness.conf`: the only thing that sets `vm.swappiness` (nothing in `/etc/sysctl.d`, `/usr/lib/sysctl.d` or `/run/sysctl.d` mentions it). It reads 10 because the initramfs's `systemd-sysctl` applies its embedded copy. The real root's `systemd-sysctl` runs at about 6.45s, before `/media/Storage` mounts at about 7.1s, so it sees a dangling link. A change to the repo file does not apply until the initramfs is rebuilt.
- Inferred, not tried: on a fresh install the links are made after the first kernel install, so no embedded copy exists and swappiness stays at the kernel default until a later rebuild.
- `90-backlight.rules` and `51-android.rules` are embedded too, but `udev-reload.service` reloads the rules after the mount, so repo edits take effect.
- `audio_power_save.conf` is embedded, but `snd_hda_intel` loads after the root switch, so the copy is never read; `module-options.service` now applies it after the mount.

Options:
- A post-mount step that runs `systemd-sysctl`, in the same style as `udev-reload.service` and `module-options.service` (`RequiresMountsFor=/media/Storage`): swappiness then follows the repo file, with no rebuild. A line in `udev-reload.service` would be the smallest change, or a unit of its own. Not tried.
- Rebuild the initramfs from the quickstart (`dracut --force`) after the config links: heavy, slower, and the copy is stale again after the next edit.
- Leave it: only swappiness is affected.

To decide: which option, and whether the fresh-install case is worth a test (it needs a fresh machine or a VM).

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
