# Colours plan

Written 2026-10-14. The colours and their helpers are built (`setup/colours.sh`, checked by `colours_check.sh`); nothing else is yet.

## Goal

A script that lets me define colours in a single place and propagates them out to every file that uses them. The mechanism is decided (below).

## Decided (2026-10-16)

- **Source and helpers in one file:** `setup/colours.sh` holds the colours (`name=#RRGGBB` lines, all hex in uppercase; including the 16 terminal palette slots; lightened variants are their own lines) and the helpers below them. It is sourced by the wrappers, the generator and the prompt. Written in POSIX `sh` so that both `sh` and bash scripts can source it (`monitor-tui-wrap.sh` stays `#!/bin/sh`). Checked: `colours_check.sh` passes (53 checks) under `dash` and BusyBox 1.36.1 `sh` on Ubuntu 24.04, and under `bash --posix`. `/bin/sh` on the Arch machine is bash, with no `dash`, so a regression would only show under `bash --posix` there.
- **Helpers:** `colour_hex`, `colour_rgb` (`r;g;b`), `colour_alpha NAME AA` (`#RRGGBBAA`), `colour_argb NAME AA` (`#AARRGGBB`) and `colour_256`.
- **Overrides for formats a hex cannot convert to exactly:** a `NAME_256=N` line next to the colour in `colours.sh`. `colour_256` uses the override if there is one, otherwise returns the colour only if it is exactly an xterm 256 entry, otherwise fails (it never picks a nearest colour). The exact formats (hex, rgb, alpha, argb) have no override.
- **Anything that can run shell sources `colours.sh` directly:** the herbstluftwm files, `panel.sh`, `rule_hook.sh`, `background.sh`, `nnn-wrap.sh` and the bash prompt, each converting to the form it needs.
- **Programs that cannot read it directly:** wrap their launch in a script that sources `colours.sh` and injects the colours.
  - Xresources: `xrdb` run with `-D` flags (`startup.autostart:9`), with the file using macros for every colour including the palette slots. Checked: real `xrdb -n -Dcol_dark=#252526` fills in `#` values, including `[80]col_dark`.
  - polybar: env vars from `panel.sh`, extending the `${env:...}` it already uses; the alpha forms built by the helpers.
  - rofi: `-theme-str` overrides for the variables in `custom.rasi:10-17`, for the four keybindings in `shortcuts.autostart`. Checked with rofi 2.0.0: `-theme-str '* { col-dark1: #ff0000; }'` overrides the variable and everything that uses it (`var(col-dark1)`); the file has no hex outside that block.
  - bottom: `scripts/bottom-wrap.sh [cpu|memory|network|processes] [btm args]` renders `setup/templates/bottom[-view].tmpl` to a temp file in `$XDG_RUNTIME_DIR` and runs `btm -C <temp file>`, removing the file on exit. `pty_inset.py` stays generic and wraps the wrapper (`pty_inset.py bottom-wrap.sh cpu`). The Ctrl-Alt-Delete binding and the six `polybar.ini` clicks call it, and `alias btm` in `.shellrc_aliases` points at it so a bare `btm` gets the rendered colours too (decided 2026-10-16). Confirmed working live (2026-10-16); the five tracked `bottom*.toml` files were then removed, and `~/.config/bottom/bottom-defaults.toml` (all comments) stays.
  - monitor TUI: `monitor-tui-wrap.sh` exports the values the TUI needs (the exact green as RGB plus its 256-colour fallback, and the other 256-colour numbers) as environment variables; `monitor_tui.py` reads them with `os.environ`, defaulting to today's values. No Python port of the helpers.
  - `pty_inset.py` stays generic. It also wraps `bluetui`, `nmtui`, `nnn` and an `sh -c` update command, so it is not touched.
- **Programs where no wrapper works:** lemurs. It is generated from a template. (Nano is out of scope: real nano is not used, `nano` is aliased to micro, so the nanorc files are not migrated.)
- **Templates and generator:** templates live in `setup/templates/<program>.tmpl` with `@col_green@` placeholders (variants below). One renderer, `setup/colours-gen <program>`, is used by both the install step and the bottom wrapper (which renders to a temp file).
- **Generated files** are uncommitted. The output is written to the path `setup/config_links.sh` already links (`symlinks/etc_lemurs_config.toml`) and gitignored, so `config_links.sh` does not change. The old tracked file is removed from git with `git rm --cached`, and its contents move into the template. A separate step regenerates on demand.
- **Install order:** a new `step_colours` in `quickstart_arch.sh`, just before `step_config_links` (defined at line 295, called at line 584), runs the generator for lemurs. Until it has run, that link dangles (a broken login screen).

### Template variants

Decided 2026-10-16: the renderer is built with plain `@name@` only. Every template today (lemurs, bottom) uses plain hex, so the variants below are added when a template needs one. Hex case is not preserved from the old files: output uses the stored uppercase, and a migration is checked by comparing case-insensitively.

| Placeholder | Output |
|---|---|
| `@col_green@` | `#2E7D32` |
| `@col_green:rgb@` | `46;125;50` |
| `@col_green:256@` | `28` (from the `col_green_256` override) |
| `@col_green:alpha=CC@` | `#2E7D32CC` (suffix) |
| `@col_green:argb=CC@` | `#CC2E7D32` (prefix, polybar) |

`colours.sh` has helpers with the same names. Quotes around a value (bottom's `"#rrggbb"`) stay in the template. Lemurs' named colours (`white`, `red`, `gray`, `dark gray`) stay as written in the template: they resolve through the Linux console palette, which `colours.sh` does not control.

### Names

Existing: `col_dark`, `col_light`, `col_grey`, `col_green`, `col_purple`, `col_blue`. New project colours:

| Name | Hex |
|---|---|
| `col_red` | `#D32F2F` |
| `col_orange` | `#FF9800` |
| `col_dark2` | `#2D2D30` |
| `col_chartblue` | `#2D77CE` |
| `col_cyan` | `#1F88A2` |
| `col_seagreen` | `#3CA341` |
| `col_lightgreen` | `#87D75F` |
| `col_grey_dark` | `#333333` |
| `col_grey_mid` | `#777777` |
| `col_grey_light` | `#999999` |
| `col_almost_black` | `#111111` (active frame background) |
| `col_lime` | `#00FF00` (man-page blink) |
| `col_nord4`, `col_nord9` … `col_nord15` | the eight nord colours bottom's CPU graph uses (`#D8DEE9`, `#81A1C1`, `#5E81AC`, `#BF616A`, `#D08770`, `#EBCB8B`, `#A3BE8C`, `#B48EAD`) |
| `tui_grey`, `tui_dimmed`, `tui_white` | the monitor TUI's 256-colour codes 245, 248 and 231 as hex |
| `nnn_symlink`, `nnn_details`, `nnn_context1`–`3` | nnn's codes `61`, `F7`, `a2`, `1f`, `4c` as hex (these are hex pairs in nnn, so decimal 97, 247, 162, 31, 76) |

Only colours that something uses get an entry. The unused nord defines, the commented-out palettes and the unused polybar colour files are left out.

The 16 palette slots are `ansi_black` … `ansi_bright_white`, (decided 2026-10-16: they keep the `ansi_*` names). They are live in `Xresources:75-90` and will be migrated when the colours are consolidated. A slot that is a project colour references it (`ansi_red=$col_red`, `ansi_purple=$col_purple`, `ansi_bright_white=$col_light`); `ansi_black` stays `#000000`, which is why the terminal background (`col_dark`) and ANSI black differ.

### Build order

1. `colours.sh` (done) and the bash prompt as the first consumer. The `rgb` helper is checked against the values already written in `shellrc:52-73`.
2. The template renderer `setup/colours-gen` (done), then lemurs (done: `setup/templates/lemurs.tmpl`, the `step_colours` install step, and `symlinks/etc_lemurs_config.toml` staged as a deletion, regenerated on disk, and gitignored; its rendered output is byte-identical to the old file), then bottom (done, confirmed live: templates, `bottom-wrap.sh`, call sites, alias, old toml files removed).

Each migration must leave the program's output unchanged. Colours that have a 256-colour value today (the TUI's 28, 245, 248 and 231, and nnn's `61`, `F7`, `a2`, `1f` and `4c`) get a name and, where the hex is not an exact xterm entry, an override that reproduces today's value.

`colours.md` in this directory lists every colour, what uses it and where it is defined. That is the starting inventory for this work.

## What the script has to cover

The colours are defined in these different formats today, so one source has to feed all of them:

- `#RRGGBB` and `#RRGGBBAA` hex in the Xresources, bottom, rofi and lemurs configs, and in herbstluftwm variables.
- polybar `#AARRGGBB` (alpha first), with `${env:...}` values passed in from `panel.sh`.
- truecolor `r;g;b` escape codes in the bash prompt.
- 256-colour numbers and palette slots in `nnn-wrap.sh` and `monitor_tui.py`, plus the one exact-RGB tuple in the TUI.
- named colours in lemurs.

## Open questions

None at the moment.

