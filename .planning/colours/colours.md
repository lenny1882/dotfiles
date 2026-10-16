# Colours

Refreshed 2026-10-16, after the migration, from a scan of tracked files on the `colours` branch. Every colour that something uses is now defined once, in `setup/colours.sh`; the plan and its decisions are in `colours_plan.md`. This file lists how each program gets its colours, what uses each colour, and what is still defined elsewhere.

Scope of the scan: tracked files, minus `symlinks/home_@user@_.config_nnn_plugins/` (third-party plugins), the `*.bak` and `*.orig-bak` autostart copies, and images. The untracked dotfiles in the repo root (`.bashrc`, `.zshrc` and the rest) were not readable, so they are not covered.

Path prefixes used below:

| Short | Full |
|---|---|
| `hlwm/` | `symlinks/home_@user@_.config_herbstluftwm/` |
| `Xresources` | `symlinks/home_@user@_.Xresources` |
| `templates/` | `setup/templates/` |

## 1. How each program gets its colours

| Program | Files | Mechanism |
|---|---|---|
| bash prompt, coloured man pages | `shellrc/.shellrc_custom` | sources `colours.sh`, builds truecolor escapes with `colour_rgb`, then `colours_unload` removes everything it defined from the shell |
| herbstluftwm | `hlwm/variables.autostart`, `hlwm/theme.autostart` | `variables.autostart` sources `colours.sh` (13 scripts source `variables.autostart`); `theme.autostart` uses the names, with alpha as string suffixes (`${col_grey}cc`) |
| polybar | `hlwm/scripts/panel.sh`, `hlwm/polybar/scripts/colors_vscode_dark` | `panel.sh` exports 12 `COLOUR_*` variables (alpha forms through `colour_argb`); the colour file reads them with `${env:…}`; active and urgent still arrive as arguments |
| bottom (btm) | `templates/bottom*.tmpl`, `hlwm/scripts/bottom-wrap.sh` | the wrapper renders a template to a temp file with `colours-gen` and runs `btm -C` on it; the Ctrl-Alt-Delete binding and the polybar clicks (through `pty_inset.py`) and the `btm` alias call the wrapper |
| lemurs | `templates/lemurs.tmpl` | generated at install (`step_colours`) into `symlinks/etc_lemurs_config.toml`, which is gitignored |
| urxvt and everything that draws in it | `Xresources`, `hlwm/scripts/xrdb-wrap.sh` | `xrdb -D name=#hex` for every colour; the file uses the names |
| rofi | `hlwm/scripts/rofi-wrap.sh`, `symlinks/home_@user@_.config_rofi/custom.rasi` | the wrapper passes a `-theme-str`; `custom.rasi` defines no colours |
| nnn | `hlwm/scripts/nnn-wrap.sh` | `NNN_FCOLORS` and `NNN_COLORS` built with `colour_256` |
| monitor TUI | `hlwm/scripts/monitor-tui-wrap.sh`, `hlwm/scripts/monitor_tui.py` | five `TUI_COLOUR_*` environment variables, read with defaults |
| eza, bluetui, git, ls | none | the terminal's ANSI palette (section 3) |
| picom | `symlinks/home_@user@_.config_compton.conf` | shadow colour `0.0 0.0 0.0` (black), left as is |
| bat, micro | none | bat uses a built-in theme name, micro has no colour scheme |

## 2. Colours and what uses them

Rows follow the order in `colours.sh`. "Alpha" means the colour is used with an alpha suffix or prefix.

| Name | Hex | Used by |
|---|---|---|
| `col_dark` | `#252526` | urxvt, nnn, bottom and wrapper window backgrounds (`[80]` and `[95]` opacity); rofi window background; polybar `bg_dark` (alpha `CC`) |
| `col_dark2` | `#2D2D30` | rofi element background |
| `col_light` | `#ECEFF4` | terminal foreground and cursor, palette slot 15; bottom text and titles; rofi text; herbstluftwm window title; polybar `fg_white` and, with alpha `33`, `fg_disabled` and `fg_monitor_empty`; prompt text |
| `col_grey` | `#3E3E42` | herbstluftwm borders, backgrounds and titles (alpha `FF`/`cc`/`dd`); rofi input bar; polybar `bg_light` (alpha `CC`) and the bar background (alpha `55`); lemurs unfocused text and borders |
| `col_grey_dark` | `#333333` | prompt grey segments |
| `col_grey_mid` | `#777777` | bottom borders |
| `col_grey_light` | `#999999` | prompt success-symbol text |
| `col_green` | `#2E7D32` | herbstluftwm active window and frame (`col_active`, alpha `dd`); polybar active workspace and power-lock button; bottom selected rows and borders; rofi prompt and selected row; lemurs focused borders; monitor TUI selected panel (RGB and its 256 fallback, 28); prompt directory segment |
| `col_purple` | `#7B1FA2` | herbstluftwm urgent (alpha `dd`/`ff`); polybar urgent workspace; lemurs login background; rofi urgent; prompt clock; palette slot 5 |
| `col_blue` | `#1565C0` | urxvt `wrapper` window border; `background.sh` solid colour on a monitor with no wallpaper |
| `col_red` | `#D32F2F` | polybar power-off button, error and low-battery text; bottom average CPU, swap and transmit; prompt failed-command symbol and man-page underline; palette slot 1 |
| `col_orange` | `#FF9800` | polybar power-reboot button |
| `col_chartblue` | `#2D77CE` | bottom RAM and receive; prompt git-branch segment |
| `col_cyan` | `#1F88A2` | man-page reverse video (the prompt's own cyan variables are unused) |
| `col_seagreen` | `#3CA341` | bottom combined-layout table headers; prompt nested-nnn level |
| `col_lightgreen` | `#87D75F` | bottom table headers in the cpu, memory, network and processes layouts |
| `col_almost_black` | `#111111` | herbstluftwm active frame background (alpha `77`) |
| `col_lime` | `#00FF00` | man-page blink |
| `col_nord4` | `#D8DEE9` | polybar label text (alpha `77`); bottom CPU core colour |
| `col_nord9`–`col_nord15` | `#81A1C1` `#5E81AC` `#BF616A` `#D08770` `#EBCB8B` `#A3BE8C` `#B48EAD` | bottom CPU core colours (nord9, nord10, nord11, nord12, nord13, nord14, nord15) |
| `tui_grey` | `#8A8A8A` | monitor TUI art (256-colour 245) |
| `tui_dimmed` | `#A8A8A8` | monitor TUI dimmed text (248) |
| `tui_white` | `#FFFFFF` | monitor TUI highlighted-selection foreground (231) |
| `nnn_symlink` | `#875FAF` | nnn symlinks (`61`) |
| `nnn_details` | `#9E9E9E` | nnn missing files and file details (`F7`) |
| `nnn_context1`–`nnn_context3` | `#D70087` `#0087AF` `#5FD700` | nnn contexts 1 to 3 (`a2`, `1f`, `4c`); context 4 is palette slot 7 |
| `ansi_black` | `#000000` | palette slot 0; polybar transparent (alpha `00`) |

The 256-colour override `col_green_256=28` (the TUI's fallback) is the only override on a project colour. `colours.sh` also holds `ansi_*_256` slot numbers (section 3).

## 3. Terminal palette (ANSI slots 0–15)

Live in `Xresources` as `*.color0`–`*.color15`, written as the `ansi_*` names. Everything that draws with ANSI colours in urxvt reads these: eza, bluetui, git, ls and nnn's palette-slot entries. Nano and a Linux console are not covered (see section 4).

| Slot | Name | Hex | Note |
|---|---|---|---|
| 0 | `ansi_black` | `#000000` | VS Code Dark+ |
| 1 | `ansi_red` | `#D32F2F` | is `col_red` |
| 2 | `ansi_green` | `#0DBC79` | VS Code Dark+; nnn executables |
| 3 | `ansi_yellow` | `#E5E510` | VS Code Dark+; nnn fifos |
| 4 | `ansi_blue` | `#2472C8` | VS Code Dark+; nnn directories |
| 5 | `ansi_purple` | `#7B1FA2` | is `col_purple` |
| 6 | `ansi_cyan` | `#11A8CD` | VS Code Dark+; nnn hard links |
| 7 | `ansi_white` | `#E5E5E5` | VS Code Dark+; nnn block devices, regular files and context 4 |
| 8 | `ansi_bright_black` | `#666666` | VS Code Dark+ |
| 9 | `ansi_bright_red` | `#EF5350` | nnn orphaned symlinks |
| 10 | `ansi_bright_green` | `#66BB6A` | |
| 11 | `ansi_bright_yellow` | `#F5F543` | nnn character devices |
| 12 | `ansi_bright_blue` | `#3B8EEA` | VS Code Dark+ |
| 13 | `ansi_bright_purple` | `#D670D6` | nnn sockets |
| 14 | `ansi_bright_cyan` | `#29B8DB` | VS Code Dark+ |
| 15 | `ansi_bright_white` | `#ECEFF4` | is `col_light` |

Each carries its slot number as a `_256` override (`ansi_blue_256=4`), which `nnn-wrap.sh` uses. The terminal background (`col_dark`) differs from slot 0.

## 4. Defined outside `colours.sh`

All of these are unused, not hex, or intentionally left:

- **polybar:** `bg_med`, `line_yellow` and `line_red` in `hlwm/polybar/scripts/colors_vscode_dark` (unused; `line_red` is only in a commented-out line).
- **Xresources:** the `nord0`–`nord15` defines and three commented-out palettes (nord, a project-only set and full VS Code Dark+).
- **lemurs:** the named colours `white`, `red`, `gray` and `dark gray`, plus `#87CEEB` in a comment. They resolve through the Linux console palette, which neither `colours.sh` nor Xresources controls.
- **picom:** the black shadow colour in `compton.conf`.
- **nano:** `cfg/nano_nanorc` and `symlinks/root_.nanorc` use named colours; real nano is not used, so they are not migrated.
- **Legacy files:** `hlwm/autostart-3monitors` (an old autostart with its own colour table), `hlwm/autostart.bak*` and `autostart.orig-bak`, the polybar files `colors` and `colors_nord` (not included by `polybar.ini`), and `hlwm/12palette`, an unrelated chart stylesheet.

## 5. Near-duplicates, for the later consolidation

- **Blues:** `col_blue` `#1565C0` (wrapper border, background), `col_chartblue` `#2D77CE` (bottom, prompt), `ansi_blue` `#2472C8` (palette slot 4, so nnn and eza directories), `ansi_bright_blue` `#3B8EEA`.
- **Greys:** `col_grey` `#3E3E42`, `col_grey_dark` `#333333`, `col_grey_mid` `#777777`, `col_grey_light` `#999999`, `ansi_bright_black` `#666666`, `tui_grey` `#8A8A8A`, `tui_dimmed` `#A8A8A8`.
- **Greens:** `col_green` `#2E7D32`, `ansi_green` `#0DBC79`, `col_seagreen` `#3CA341`, `col_lightgreen` `#87D75F`, `ansi_bright_green` `#66BB6A`.
- **Darks:** `col_dark` `#252526` is the terminal background but palette slot 0 is `#000000`.
