# Colours

Every colour in the repo, what uses it, and where it is defined. Written 2026-10-14 from a scan of tracked files.

## Colour by location

A ✓ means the colour is defined in that location, whatever the format (hex, `r;g;b`, 256-colour number, `0x` tuple, or with an alpha prefix or suffix). Rows are exact colours, so the same colour spelled two ways is one row. Only colours that something actually uses are listed: colours that exist only in commented-out palettes, unused polybar colour files or old autostart copies are left out (they are in the sections below). A definition nothing references still gets a ✓ if the colour is used elsewhere, for example the nord defines at `Xresources:1-16`. Sorted greys first (dark to light), then by hue.

| Column | Location |
|---|---|
| Xres | `symlinks/home_@user@_.Xresources` live lines: the `#define`s (`:1-22`) and the palette (`:75-90`) |
| hlwm vars | `hlwm/variables.autostart` |
| hlwm theme | `hlwm/theme.autostart` (literal values only; the rest comes from hlwm vars) |
| polybar | `hlwm/polybar/scripts/colors_vscode_dark` |
| rofi | `cfg/rofi/custom.rasi` |
| bottom | the six `cfg/bottom_bottom*.toml` files |
| lemurs | `symlinks/etc_lemurs_config.toml` |
| prompt | `shellrc/.shellrc_custom` (bash prompt and coloured man pages) |
| monitor TUI | `hlwm/scripts/monitor_tui.py` (includes the 256-colour numbers 28, 231, 245, 248, shown as their hex) |
| nnn | `hlwm/scripts/nnn-wrap.sh` (the 256-colour codes `61`, `F7`, `a2`, `1f`, `4c`, shown as their hex; the palette-slot entries are not definitions) |

Notes: `#000000` in polybar is the fully transparent `#00000000`. Polybar and herbstluftwm often define the colour with an alpha value, which this table ignores; the sections below list the alphas.

| Colour | Name | Xres | hlwm vars | hlwm theme | polybar | rofi | bottom | lemurs | prompt | monitor TUI | nnn |
|---|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| `#000000` |  | ✓ |  |  | ✓ |  |  |  |  |  |  |
| `#111111` |  |  |  | ✓ |  |  |  |  |  |  |  |
| `#252526` | col_dark | ✓ | ✓ |  | ✓ | ✓ |  |  |  |  |  |
| `#2d2d30` | dark2 |  |  |  | ✓ | ✓ |  |  |  |  |  |
| `#333333` |  |  |  |  |  |  |  |  | ✓ |  |  |
| `#3e3e42` | col_grey |  | ✓ |  | ✓ | ✓ |  | ✓ |  |  |  |
| `#666666` |  | ✓ |  |  |  |  |  |  |  |  |  |
| `#777777` |  |  |  |  |  |  | ✓ |  |  |  |  |
| `#8a8a8a` |  |  |  |  |  |  |  |  |  | ✓ |  |
| `#999999` |  |  |  |  |  |  |  |  | ✓ |  |  |
| `#9e9e9e` |  |  |  |  |  |  |  |  |  |  | ✓ |
| `#a8a8a8` |  |  |  |  |  |  |  |  |  | ✓ |  |
| `#e5e5e5` |  | ✓ |  |  |  |  |  |  |  |  |  |
| `#ffffff` |  |  |  |  |  |  |  |  |  | ✓ |  |
| `#d32f2f` | red | ✓ |  |  | ✓ |  | ✓ |  | ✓ |  |  |
| `#ef5350` |  | ✓ |  |  |  |  |  |  |  |  |  |
| `#d08770` | nord12 | ✓ |  |  |  |  | ✓ |  |  |  |  |
| `#ff9800` | orange |  |  |  | ✓ |  |  |  |  |  |  |
| `#ebcb8b` | nord13 | ✓ |  |  |  |  | ✓ |  |  |  |  |
| `#e5e510` |  | ✓ |  |  |  |  |  |  |  |  |  |
| `#f5f543` |  | ✓ |  |  |  |  |  |  |  |  |  |
| `#a3be8c` | nord14 | ✓ |  |  |  |  | ✓ |  |  |  |  |
| `#5fd700` |  |  |  |  |  |  |  |  |  |  | ✓ |
| `#87d75f` | light green |  |  |  |  | ✓ | ✓ |  |  |  |  |
| `#008700` |  |  |  |  |  |  |  |  |  | ✓ |  |
| `#00ff00` |  |  |  |  |  |  |  |  | ✓ |  |  |
| `#66bb6a` |  | ✓ |  |  |  |  |  |  |  |  |  |
| `#3ca341` | sea green |  |  |  |  |  | ✓ |  | ✓ |  |  |
| `#2e7d32` | col_green | ✓ | ✓ |  |  | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| `#0dbc79` |  | ✓ |  |  |  |  |  |  |  |  |  |
| `#29b8db` |  | ✓ |  |  |  |  |  |  |  |  |  |
| `#11a8cd` |  | ✓ |  |  |  |  |  |  |  |  |  |
| `#1f88a2` | cyan |  |  |  |  |  |  |  | ✓ |  |  |
| `#0087af` |  |  |  |  |  |  |  |  |  |  | ✓ |
| `#81a1c1` | nord9 | ✓ |  |  |  |  | ✓ |  |  |  |  |
| `#2472c8` |  | ✓ |  |  |  |  |  |  |  |  |  |
| `#3b8eea` |  | ✓ |  |  |  |  |  |  |  |  |  |
| `#1565c0` | col_blue | ✓ | ✓ |  |  |  |  |  |  |  |  |
| `#2d77ce` | chart blue |  |  |  |  |  | ✓ |  | ✓ |  |  |
| `#5e81ac` | nord10 | ✓ |  |  |  |  | ✓ |  |  |  |  |
| `#eceff4` | col_light / nord6 | ✓ | ✓ |  | ✓ | ✓ | ✓ |  | ✓ |  |  |
| `#d8dee9` | nord4 | ✓ |  |  | ✓ |  | ✓ |  |  |  |  |
| `#875faf` |  |  |  |  |  |  |  |  |  |  | ✓ |
| `#7b1fa2` | col_purple | ✓ | ✓ |  |  | ✓ |  | ✓ | ✓ |  |  |
| `#d670d6` |  | ✓ |  |  |  |  |  |  |  |  |  |
| `#b48ead` | nord15 | ✓ |  |  |  |  | ✓ |  |  |  |  |
| `#d70087` |  |  |  |  |  |  |  |  |  |  | ✓ |
| `#bf616a` | nord11 | ✓ |  |  |  |  | ✓ |  |  |  |  |


Scope of the scan: tracked files, minus `symlinks/home_@user@_.config_nnn_plugins/` (third-party plugins), the `*.bak` and `*.orig-bak` autostart copies, and images. The untracked dotfiles in the repo root (`.bashrc`, `.zshrc` and the rest) were not readable, so they are not covered. Colours that terminal programs get from the ANSI palette (eza, bluetui, git, ls) have no config of their own and are listed under the palette.

Path prefixes used below:

| Short | Full |
|---|---|
| `hlwm/` | `symlinks/home_@user@_.config_herbstluftwm/` |
| `cfg/` | `symlinks/home_@user@_.config_` (so `cfg/bottom_bottom.toml` is `symlinks/home_@user@_.config_bottom_bottom.toml`) |
| `Xresources` | `symlinks/home_@user@_.Xresources` |
| `lemurs` | `symlinks/etc_lemurs_config.toml` |
| `shellrc` | `shellrc/.shellrc_custom` |

A line number in *italics* is commented out, so it does not take effect.

## 1. Where colours are defined

There is no single source. Each of these is its own definition site, and most repeat the same handful of colours:

| Definition site | Format | Feeds |
|---|---|---|
| `Xresources:18-22` (`#define col_*`) | `#RRGGBB` | urxvt background and cursor, urxvt border colour |
| `Xresources:75-90` (`*.color0-15`) | `#rrggbb` | the 16-colour terminal palette, for every program in urxvt |
| `hlwm/variables.autostart:10-16` | bash variables, `#RRGGBB` | herbstluftwm window and frame colours, polybar active/urgent colours, background fallback |
| `hlwm/polybar/scripts/colors_vscode_dark` | polybar `#AARRGGBB` | polybar |
| `cfg/rofi/custom.rasi:10-17` | rasi variables, `#RRGGBB` | rofi |
| `cfg/bottom_bottom*.toml` (6 files) | `"#rrggbb"` | bottom (btm) |
| `lemurs:92-295` | `"#RRGGBB"` and named colours | lemurs login screen |
| `shellrc:52-73` | truecolor escape codes `r;g;b` | bash prompt |
| `hlwm/scripts/monitor_tui.py:2040-2084` | 256-colour numbers, one `(0x2E,0x7D,0x32)` tuple | the monitor and layout TUI |
| `hlwm/scripts/nnn-wrap.sh:12-17` | palette slots and 256-colour numbers | nnn |
| `cfg/nano_nanorc:213-217`, `cfg/compton.conf:15-17`, `lemurs` named colours | named or ANSI colours | nano, compton, lemurs (see section 5) |

## 2. Project colours

These are the colours chosen for the setup (VS Code dark and Material palettes, per the comment in `hlwm/variables.autostart:8-9`). Hex is shown as it is written; polybar alpha prefixes are noted.

### `#252526` dark background (`col_dark`)
- **Used by:** the urxvt, nnn, bottom and wrapper window backgrounds (at 80% and 95% opacity via `[80]` / `[95]`); rofi window background; polybar `bg_dark` (the date, battery, bluetooth, volume and updates modules, and the power-logout button) at alpha `CC`.
- **Defined in:** `Xresources:18`, *`Xresources:41`* (old nnn-based palette); `hlwm/variables.autostart:10`; `cfg/rofi/custom.rasi:10` (`col-dark1`); `hlwm/polybar/scripts/colors_vscode_dark:6` (alpha `CC`).
- The herbstluftwm `col_dark` variable is defined but no live file references it.

### `#ECEFF4` light text (`col_light`, nord6)
- **Used by:** terminal foreground and cursor (`Xresources:92,94`); palette slot 15; herbstluftwm window title colour (`hlwm/theme.autostart:49`); rofi text; bottom text, titles, graph and selected text; polybar `fg_white`, plus `fg_disabled` and `fg_monitor_empty` at alpha `33`; bash prompt foreground.
- **Defined in:** `Xresources:7` (`nord6`), `Xresources:19` (`col_light`), *`Xresources:56`*, `Xresources:90` (palette slot 15); `hlwm/variables.autostart:11`; `cfg/rofi/custom.rasi:13`; `hlwm/polybar/scripts/colors_vscode_dark:16,19,21`; every bottom file: `cfg/bottom_bottom.toml:22,25,26,28,30`, `cfg/bottom_bottom-cpu.toml:4,7,8,10,12`, `cfg/bottom_bottom-memory.toml:7,10,11,13`, `cfg/bottom_bottom-network.toml:4,7,8,10`, `cfg/bottom_bottom-processes.toml:7,10,11,13`; `shellrc:66` (as `236;239;244`).

### `#3E3E42` grey (`col_grey`)
- **Used by:** herbstluftwm frame and window borders, window backgrounds and title backgrounds (`hlwm/theme.autostart:38-48`); the solid background shown on an unknown monitor set (`hlwm/scripts/background.sh:39`); rofi input bar; polybar `bg_light` (cpu, memory, network, keyboard and workspace modules) at alpha `CC`, and `bg_dark_translucent` (the bar itself) at alpha `55`; lemurs unfocused text and borders.
- **Defined in:** `hlwm/variables.autostart:12`; `cfg/rofi/custom.rasi:12` (`col-grey`); `hlwm/polybar/scripts/colors_vscode_dark:7` (alpha `CC`), `:10` (alpha `55`); `lemurs:105,121,166,181,215,250,251,260,283,284,293`.

### `#2E7D32` green (`col_green`, also `col_active`)
- **Used by:** the active window and frame colour in herbstluftwm (`col_active`, `hlwm/theme.autostart:41,42`); polybar active workspace and the power-lock button; selected rows and highlighted borders in bottom; rofi prompt and selected row; focused borders in lemurs; the selection colour in the monitor TUI; the directory segment of the bash prompt.
- **Defined in:** `Xresources:21`; `hlwm/variables.autostart:14` (and `:16`, `col_active=$col_green`); `cfg/rofi/custom.rasi:15`; `lemurs:262,295`; bottom, `highlighted_border_color` and `selected_bg_color` in each file: `cfg/bottom_bottom.toml:24,27`, `cfg/bottom_bottom-cpu.toml:6,9`, `cfg/bottom_bottom-memory.toml:9,12`, `cfg/bottom_bottom-network.toml:6,9`, `cfg/bottom_bottom-processes.toml:9,12`; `hlwm/scripts/monitor_tui.py:2042` (as `0x2E, 0x7D, 0x32`); `shellrc:55,67` (as `46;125;50`); *`Xresources:43`* (old palette slot 2).
- Passed at runtime: `hlwm/startup.autostart:35` calls `panel.sh $col_active $col_purple`, `hlwm/scripts/panel.sh:71-72` exports them as `COLOUR_ACTIVE` and `COLOUR_URGENT`, and polybar reads them with `${env:COLOUR_ACTIVE}` (`colors_vscode_dark:4,11,14,22`). `hlwm/scripts/rule_hook.sh:43` does the same when panels restart.

### `#7B1FA2` purple (`col_purple`)
- **Used by:** herbstluftwm urgent window colour (`hlwm/theme.autostart:50,51`); polybar urgent workspace (`COLOUR_URGENT`); lemurs login background; rofi urgent text and urgent selected row; the clock segment of the bash prompt; **terminal palette slot 5** (so anything that asks for ANSI magenta/purple).
- **Defined in:** `Xresources:20`, `Xresources:80` (palette slot 5), *`Xresources:46`*; `hlwm/variables.autostart:13`; `cfg/rofi/custom.rasi:17`; `lemurs:92`; `shellrc:60,72` (as `123;31;162`).

### `#1565C0` blue (`col_blue`)
- **Used by:** the border of the floating `wrapper` urxvt windows (nnn, bottom, monitor TUI) at `Xresources:132`.
- **Defined in:** `Xresources:22`; `hlwm/variables.autostart:15` (defined there, not referenced).

### `#D32F2F` red
- **Used by:** the power-off button, low-battery text and the `bg_red`/`line_red` colours in polybar; bottom's average CPU, swap and transmit colours; error segment of the bash prompt; **terminal palette slot 1**.
- **Defined in:** `hlwm/polybar/scripts/colors_vscode_dark:13,17,24`; `cfg/bottom_bottom.toml:31,35,38`, `cfg/bottom_bottom-cpu.toml:13`, `cfg/bottom_bottom-memory.toml:16`, `cfg/bottom_bottom-network.toml:13`; `Xresources:76` (slot 1), *`Xresources:42`*; `shellrc:15,61,73` (as `211;47;47`; line 15 is the man-page underline colour).

### `#2D77CE` blue (the "chart blue")
- **Used by:** bottom's RAM and receive colours; the git-branch segment of the bash prompt.
- **Defined in:** `cfg/bottom_bottom.toml:34,37`, `cfg/bottom_bottom-memory.toml:15`, `cfg/bottom_bottom-network.toml:12`; `shellrc:53,64` (as `45;119;206`); *`Xresources:45`* (old palette slot 4); the `#2d77ce` shown in the old nnn colour table is gone from `hlwm/scripts/nnn-wrap.sh`.
- This is **not** the live ANSI blue (see section 3).

### `#1F88A2` cyan
- **Used by:** the reverse-video highlight in coloured man pages; the prompt's cyan variables (`_bgcyan`, `_fgcyan`), which no prompt segment uses.
- **Defined in:** `shellrc:14,52,63` (as `31;136;162`); *`Xresources:47`*.

### `#3CA341` sea green
- **Used by:** bottom's table headers in the combined layout; the `N<level>` (nested nnn) segment of the bash prompt.
- **Defined in:** `cfg/bottom_bottom.toml:21`; `shellrc:56,68` (as `60;163;65`).

### `#87D75F` light green
- **Used by:** table headers in the separate bottom widgets (cpu, memory, network, processes).
- **Defined in:** `cfg/bottom_bottom-cpu.toml:3`, `cfg/bottom_bottom-memory.toml:6`, `cfg/bottom_bottom-network.toml:3`, `cfg/bottom_bottom-processes.toml:6`; `cfg/rofi/custom.rasi:16` (`col-light-green`, never used in the theme).

### `#FF9800` orange
- **Used by:** the power-reboot button and `line_yellow` in polybar.
- **Defined in:** `hlwm/polybar/scripts/colors_vscode_dark:12,23`.

### `#2D2D30` dark grey
- **Used by:** a rofi element background (`cfg/rofi/custom.rasi:99`); polybar `bg_med` (not referenced in `polybar.ini`).
- **Defined in:** `cfg/rofi/custom.rasi:11` (`col-dark2`); `hlwm/polybar/scripts/colors_vscode_dark:8` (alpha `CC`).

### `#333333`, `#777777`, `#999999` neutral greys
- `#333333`: bash prompt grey segment (`shellrc:57,69` as `51;51;51`). Also the legacy polybar `colors:5` (alpha `CC`).
- `#777777`: bottom's border colour in every bottom file (`cfg/bottom_bottom.toml:23`, `cfg/bottom_bottom-cpu.toml:5`, `cfg/bottom_bottom-memory.toml:8`, `cfg/bottom_bottom-network.toml:5`, `cfg/bottom_bottom-processes.toml:8`).
- `#999999`: bash prompt light-grey text (`shellrc:58,71` as `153;153;153`); *`Xresources:48`* (old palette slot 7).

### Transparent and alpha-only values
- `#00000000` is used for transparent backgrounds and foregrounds in polybar (`colors_vscode_dark:9,20`: `bg_transparent`, `fg_transparent`).
- `#11111177` (`RRGGBBAA`) is the active frame background in herbstluftwm: `hlwm/theme.autostart:37`.
- herbstluftwm builds its other values by appending alpha to a variable, for example `${col_grey}cc`, `${col_active}dd`, `${col_purple}ff` (`hlwm/theme.autostart:38-51`).
- Polybar's other values are `#CC3e3e42`, `#CC2d2d30`, `#CC252526`, `#553e3e42` (bar background), `#33ECEFF4` and `#77D8DEE9` (disabled and label text); the last pair is `#ECEFF4` / `#D8DEE9` at partial alpha. All in `hlwm/polybar/scripts/colors_vscode_dark:6-10,16-21`.

## 3. Terminal palette (ANSI slots 0-15)

Live in `Xresources:75-90`. Everything that draws with ANSI colours in urxvt (eza, bluetui, git, ls, nnn, nano, bat when not truecolor) reads these.

| Slot | Role | Hex | Taken from |
|---|---|---|---|
| 0 | black | `#000000` | VS Code Dark+ |
| 1 | red | `#d32f2f` | project (`#D32F2F`) |
| 2 | green | `#0dbc79` | VS Code Dark+ |
| 3 | yellow | `#e5e510` | VS Code Dark+ |
| 4 | blue | `#2472c8` | VS Code Dark+ |
| 5 | purple | `#7b1fa2` | project (`#7B1FA2`) |
| 6 | cyan | `#11a8cd` | VS Code Dark+ |
| 7 | white | `#e5e5e5` | VS Code Dark+ |
| 8 | bright black | `#666666` | VS Code Dark+ |
| 9 | bright red | `#ef5350` | lightened from `#d32f2f` |
| 10 | bright green | `#66bb6a` | lightened from `#2E7D32` |
| 11 | bright yellow | `#f5f543` | VS Code Dark+ |
| 12 | bright blue | `#3b8eea` | VS Code Dark+ |
| 13 | bright purple | `#d670d6` | VS Code Dark+ |
| 14 | bright cyan | `#29b8db` | VS Code Dark+ |
| 15 | bright white | `#eceff4` | project (`col_light`) |

Alternatives kept as comments: the nord set (`Xresources:24-39`, built from the `nord0`-`nord15` defines at `:1-16`), the project-only set (`Xresources:41-56`) and full VS Code Dark+ (`Xresources:58-73`). The same VS Code values are also the reference for VS Code's own terminal.

## 4. nnn

`hlwm/scripts/nnn-wrap.sh:12-17`. Entries are palette slots unless marked.

| File type | Value | Colour |
|---|---|---|
| directory | `04` | slot 4, `#2472c8` |
| executable | `02` | slot 2, `#0dbc79` |
| regular file | `07` | slot 7, `#e5e5e5` |
| hard link | `06` | slot 6, `#11a8cd` |
| symlink | `61` (256-colour) | `#875faf` |
| missing / file details | `F7` (256-colour) | `#9e9e9e` |
| block device | `07` | slot 7 |
| char device | `0b` | slot 11, `#f5f543` |
| orphaned symlink | `09` | slot 9, `#ef5350` |
| fifo | `03` | slot 3, `#e5e510` |
| socket | `0D` | slot 13, `#d670d6` |
| unknown | `00` | no colour (terminal default text) |
| contexts 1-4 (`NNN_COLORS="#a21f4c07"`, line 17) | `a2` `1f` `4c` `07` | 256-colour `#d70087`, `#0087af`, `#5fd700`; slot 7 |

nnn's own background is `nnn*background: [95]col_dark` (`Xresources:125`).

## 5. Per-program map

| Program | Config | Where its colours come from |
|---|---|---|
| urxvt | `Xresources` | slots 0-15 (`:75-90`), foreground/background/cursor (`:92-94`), per-window backgrounds (`:105,125,128,131`), wrapper border (`:132`) |
| herbstluftwm | `hlwm/theme.autostart:37-51` | `hlwm/variables.autostart:10-16`; literal `#11111177` at `theme.autostart:37` |
| polybar | `hlwm/polybar/polybar.ini` | `include-file = scripts/colors_vscode_dark` (`polybar.ini:1`); active/urgent from env set in `hlwm/scripts/panel.sh:71-72` |
| background (feh) | `hlwm/scripts/background.sh:39` | `col_blue` on a monitor that is not the panel and not listed in `MONITORS` (the wrapper border blue); the others use the wallpaper |
| rofi | `cfg/rofi/custom.rasi` | its own variables (`:10-17`); `config.rasi:1` selects the theme |
| bottom (btm) | `cfg/bottom_bottom.toml` and four widget files | hex in each file; `cfg/bottom_bottom-defaults.toml` is all comments |
| lemurs | `lemurs` | hex plus the named colours `white`, `red`, `gray`, `dark gray` (`:95,185,204,208,219,230,235,254,255,287,288`) |
| bash prompt, coloured man pages | `shellrc:52-73` (prompt), `:12-15` (man) | truecolor escapes; `:12` uses ANSI bold red (slot 1) |
| monitor TUI | `hlwm/scripts/monitor_tui.py:2040-2084` | exact green via a redefined colour slot 200 (`SELECT_RGB`, falls back to 256-colour 28), grey 245, dimmed text 248, highlight foreground 231 |
| nano | `cfg/nano_nanorc:213-217` | named colours `lightwhite`, `grey`, `white`, `red`, `black`, `lightyellow`, `magenta` |
| bat | `shellrc/.shellrc_aliases:45` | theme name `Monokai Extended Origin` (built-in, not in the repo) |
| compton / picom | `cfg/compton.conf:15-17` | shadow colour `0.0 0.0 0.0` (black) |
| eza, bluetui, git, ls | none | terminal palette (section 3) |
| micro | `cfg/micro_config.json` | no colourscheme set; micro's default |

## 6. Other colour values

- **Nord palette, kept for reference:** `#2E3440 #3B4252 #434C5E #4C566A #D8DEE9 #E5E9F0 #ECEFF4 #8FBCBB #88C0D0 #81A1C1 #5E81AC #BF616A #D08770 #EBCB8B #A3BE8C #B48EAD`. Defined as `nord0`-`nord15` at `Xresources:1-16` and used in comments at `Xresources:24-39`. Eight of them are also bottom's CPU core colours (`#5e81ac #81a1c1 #d8dee9 #b48ead #a3be8c #ebcb8b #d08770 #bf616a`): `cfg/bottom_bottom.toml:32`, `cfg/bottom_bottom-cpu.toml:14`.
- **Bottom's own colour comment:** `cfg/bottom_bottom.toml:5-16` lists a reference table (cyan, blue, green, sea green, grey, purple, magenta, orange, red, yellow `FFFF5F`, black, white). It is documentation only.
- **Lemurs example:** `lemurs:22` mentions `#87CEEB` in a comment.

## 7. Where the same colour is defined in several places

- **Green `#2E7D32`:** 8 hex definition sites (Xresources, herbstluftwm variables, rofi, lemurs, six bottom files), plus two other spellings of the same colour (`46;125;50` in the prompt, `0x2E, 0x7D, 0x32` in the monitor TUI).
- **Light text `#ECEFF4`:** repeated in every bottom file (about 22 lines), polybar, rofi, herbstluftwm and Xresources.
- **Grey `#3E3E42`:** lemurs repeats it 11 times; also in herbstluftwm, rofi and polybar.
- **Blues:** four blues are in use for similar jobs: `#1565C0` (wrapper border), `#2D77CE` (bottom, prompt), `#2472c8` (terminal slot 4, so nnn directories, eza directories, bluetui), `#3b8eea` (slot 12).
- **Greys:** `#3E3E42`, `#333333` (prompt), `#777777` (bottom borders), `#999999` (prompt text), `#666666` (palette slot 8).
- **Greens:** `#2E7D32` (UI), `#0dbc79` (slot 2, so nnn executables), `#3CA341`, `#87D75F` (bottom headers), `#66bb6a` (slot 10).
- **Dark background `#252526`** is the terminal background but terminal slot 0 is `#000000`, so ANSI black and the background differ.
- **Defined but not referenced by any live file:** herbstluftwm `col_dark` and `col_blue`; rofi `col-light-green`; polybar `bg_med`; the whole `nord0`-`nord15` block.

## 8. Legacy and unused files

- `hlwm/polybar/scripts/colors` and `colors_nord`: polybar colour files not included by `polybar.ini` (only `colors_vscode_dark` is). `colors_nord` is the nord set at alpha `CC`; `colors` is a grey/orange/red set.
- `hlwm/autostart-3monitors`, `hlwm/autostart.bak*`, `hlwm/autostart.orig-bak`: old herbstluftwm autostart variants with their own colour tables (`col_dark4`-`col_purple` at `autostart-3monitors:27-51`, `#11111177` at `:197`).
- `hlwm/12palette`: a stylesheet of unrelated chart colours (`.generation`, `.coal`, `.solar`...). It is not referenced anywhere and does not look like part of this setup.
