# Colours plan

Written 2026-10-14. Built on the `colours` branch (not yet merged into `main`): `setup/colours.sh` (the helpers; since 2026-10-17 the hexes are generated into `setup/colours.g.sh` from the bases in `setup/colours.rules.sh`), the renderer `setup/colours-gen`, and every consumer in the build order below. Checks: `colours_check.sh` and `colours_gen_check.sh`.

## Goal

A script that lets me define colours in a single place and propagates them out to every file that uses them. The mechanism is decided (below).

## Decided (2026-10-16)

- **Source and helpers in one file:** `setup/colours.sh` holds the colours (`name=#RRGGBB` lines, all hex in uppercase; including the 16 terminal palette slots; lightened variants are their own lines) and the helpers below them. It is sourced by the wrappers, the generator and the prompt. Written in POSIX `sh` so that both `sh` and bash scripts can source it (`monitor-tui-wrap.sh` stays `#!/bin/sh`). Checked: `colours_check.sh` passed (53 checks when written; 72 on 2026-10-17 under `sh` and `bash`) under `dash` and BusyBox 1.36.1 `sh` on Ubuntu 24.04, and under `bash --posix`. `/bin/sh` on the Arch machine is bash, with no `dash`, so a regression would only show under `bash --posix` there.
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
- **Generated files** are uncommitted. The output is written to the path `setup/config_links.sh` already links (`symlinks/etc_lemurs_config.toml`) and gitignored, so `config_links.sh` does not change. The old tracked file is removed from git with `git rm --cached`, and its contents move into the template. Regenerating by hand: `setup/colours-gen lemurs`.
- **Install:** the lemurs colours belong to the lemurs install (decided 2026-10-16): `step_display_manager` in `quickstart_arch.sh` runs `colours-gen lemurs` into `symlinks/etc_lemurs_config.toml` when lemurs is chosen, before enabling the service. There is no separate colours step and no step triggers another. If "Link config files" runs without the lemurs install, the `/etc` link dangles.

### Template variants

Decided 2026-10-16: the renderer is built with plain `@name@` only. Every template today (lemurs, bottom) uses plain hex, so the variants below are added when a template needs one. Hex case is not preserved from the old files: output uses the stored uppercase, and a migration is checked by comparing case-insensitively.

| Placeholder | Output |
|---|---|
| `@col_green@` | `#287D2D` |
| `@col_green:rgb@` | `40;125;45` |
| `@col_green:256@` | `28` (from the `col_green_256` override) |
| `@col_green:alpha=CC@` | `#287D2DCC` (suffix) |
| `@col_green:argb=CC@` | `#CC287D2D` (prefix, polybar) |

`colours.sh` has helpers with the same names. Quotes around a value (bottom's `"#rrggbb"`) stay in the template. Lemurs' named colours (`white`, `red`, `gray`, `dark gray`) stay as written in the template: they resolve through the Linux console palette, which `colours.sh` does not control.

### Names

The hex in this table is as first written (2026-10-14 to 16). Since 2026-10-17 the colours come from the nine bases; the current values are in `setup/colours.g.sh` and `colours.md`.

Existing: `col_dark`, `col_light`, `col_grey`, `col_green`, `col_purple`, `col_blue` (the last later merged into `ansi_blue`). New project colours:

| Name | Hex |
|---|---|
| `col_red` | `#D32F2F` |
| `col_orange` | `#FF9800` |
| `col_dark2` | `#2D2D30` |
| `col_grey_light` | `#9E9E9E` |
| `col_almost_black` | `#111111` (active frame background) |
| `col_nord9` … `col_nord15` | the seven nord colours bottom's CPU graph uses (`#81A1C1`, `#5E81AC`, `#BF616A`, `#D08770`, `#EBCB8B`, `#A3BE8C`, `#B48EAD`); its eighth core colour is `col_light` |
| `col_white` | the monitor TUI's 256-colour code 231 as hex (first named `tui_white`) |
| `col_violet`, `col_magenta`, `col_lime` (first named `nnn_symlink`, `nnn_context1`, `nnn_context3`) | nnn's codes `61`, `F7`, `a2`, `1f`, `4c` as hex (these are hex pairs in nnn, so decimal 97, 247, 162, 31, 76; only the three that survived the consolidation keep a name) |

Only colours that something uses get an entry. The unused nord defines, the commented-out palettes and the unused polybar colour files are left out.

The 16 palette slots are `ansi_black` … `ansi_bright_white`, (decided 2026-10-16 to keep the `ansi_*` names; changed later the same day: they are renamed `col_*`, with `ansi_green` becoming `col_emerald` because `col_green` is the project green, and `ansi_red` and `ansi_purple` folding into `col_red` and `col_purple`, which carry the slot numbers). They are live in `Xresources:75-90` and will be migrated when the colours are consolidated. A slot that is a project colour references it (`ansi_red=$col_red`, `ansi_purple=$col_purple`, `ansi_bright_white=$col_light`); `ansi_black` stays `#000000`, which is why the terminal background (`col_dark`) and ANSI black differ.

### Build order

1. `colours.sh` (done) and the bash prompt as the first consumer. The `rgb` helper is checked against the values already written in `shellrc:52-73`.
2. The template renderer `setup/colours-gen` (done), then lemurs (done: `setup/templates/lemurs.tmpl`, the generation in `step_display_manager`, and `symlinks/etc_lemurs_config.toml` staged as a deletion, regenerated on disk, and gitignored; its rendered output is byte-identical to the old file), then bottom (done, confirmed live: templates, `bottom-wrap.sh`, call sites, alias, old toml files removed).
3. The herbstluftwm files (done, confirmed live 2026-10-16): `variables.autostart` sources `colours.sh` (found through the real path of its own directory, `../../setup`) in place of its six colour definitions, and `theme.autostart`'s `#11111177` literal is `${col_almost_black}77`. `col_active` stays in `variables.autostart`. The alpha suffixes in `theme.autostart` (`${col_grey}cc` and so on) are left as plain string concatenation, which produces the same text as `colour_alpha`.
4. `panel.sh` and the polybar colour file (done, confirmed live 2026-10-16): `panel.sh` sources `colours.sh` and exports twelve `COLOUR_*` variables (the argb alpha forms through `colour_argb`, the plain ones through `colour_hex`); `polybar/scripts/colors_vscode_dark` reads them with `${env:COLOUR_…}` for every key that has a literal and is used. `COLOUR_ACTIVE` and `COLOUR_URGENT` still come from the arguments. Left as literals because nothing uses them: `bg_med`, `line_yellow` and `line_red` (the last is only in a commented-out line).
5. `nnn-wrap.sh` (done, confirmed live 2026-10-16): it sources `colours.sh` and builds `NNN_FCOLORS` and `NNN_COLORS` from `colour_256`, printed as two lowercase hex digits. The palette-slot entries (directory, executable and so on) come from the 16 `ansi_*` palette colours, each of which now carries its slot number as a `_256` override (`ansi_blue_256=4`), since a palette slot is its own 256-colour number; the symlink, details and context colours were `nnn_symlink`, `nnn_details` and `nnn_context1`–`3` (details is now `col_grey_light`, context 2 is `ansi_cyan`). `_unknown` stays the literal `00` (no colour). The old values were mixed case; the new ones are all lowercase.
6. The monitor TUI (done, confirmed live 2026-10-16): `monitor-tui-wrap.sh` sources `colours.sh` and exports five variables, `TUI_COLOUR_ART` (245, now 247 `col_grey_light`), `TUI_COLOUR_DIM` (248, now 247 `col_grey_light`), `TUI_COLOUR_HILITE` (231, `col_white`), `TUI_COLOUR_SELECT_256` (28, the `col_green_256` override) and `TUI_COLOUR_SELECT_RGB` (`40;125;45` since 2026-10-17, was `46;125;50`; `col_green`). `monitor_tui.py` reads them with `os.environ`, defaulting to today's values, so it still runs without the wrapper. No Python port of the helpers.
7. Xresources (done, confirmed live 2026-10-16): `scripts/xrdb-wrap.sh` sources `colours.sh` and runs `xrdb` with a `-D name=#hex` flag for every `col_*` colour (50 flags; the `_256` overrides are skipped). `startup.autostart` calls it in place of `xrdb`. `home_@user@_.Xresources` loses its five `#define col_*` lines and the live palette (`*.color0`–`15`) now reads `ansi_black` … `ansi_bright_white`; `col_dark` and `col_light` are used as before (`col_blue` was merged into `ansi_blue` later). Left alone because they are unused or commented out: the `nord0`–`nord15` defines and the three commented palettes. The palette is now uppercase hex instead of lowercase, which urxvt reads the same.
8. rofi (done, confirmed live 2026-10-16): `scripts/rofi-wrap.sh [rofi args]`, also reachable as `alias rofi` in `.shellrc_aliases` like `btm`, sources `colours.sh` and runs rofi with a `-theme-str` that sets `col-dark1`, `col-dark2`, `col-grey`, `col-light`, `col-green` and `col-purple`. The four rofi keybindings in `shortcuts.autostart` call it. The colour definitions are removed from `custom.rasi` (decided 2026-10-16), so a rofi launched without the wrapper is visibly unthemed; the unused `col-light-green` went with them.

Each migration must leave the program's output unchanged. Colours that have a 256-colour value today (the TUI's 28, 245, 248 and 231, and nnn's `61`, `F7`, `a2`, `1f` and `4c`) get a name and, where the hex is not an exact xterm entry, an override that reproduces today's value.

`colours.md` in this directory lists how each program gets its colours, every colour and what uses it, and what is still defined elsewhere. Refreshed 2026-10-16 after the migration; the hex values were updated 2026-10-17.

## What the script has to cover

The colours are defined in these different formats today, so one source has to feed all of them:

- `#RRGGBB` and `#RRGGBBAA` hex in the Xresources, bottom, rofi and lemurs configs, and in herbstluftwm variables.
- polybar `#AARRGGBB` (alpha first), with `${env:...}` values passed in from `panel.sh`.
- truecolor `r;g;b` escape codes in the bash prompt.
- 256-colour numbers and palette slots in `nnn-wrap.sh` and `monitor_tui.py`, plus the one exact-RGB tuple in the TUI.
- named colours in lemurs.

## Open questions

Not decided or not done (written down 2026-10-16 so they survive the session):

- **Status 2026-10-17:** the whole base-set palette is confirmed live. Xresources (`xrdb -query`), the herbstluftwm active border (`#287d2d`) and the running polybar's `COLOUR_*` environment all match `colours.g.sh`; rofi, nnn, bottom and the monitor TUI are launched through wrappers that read it each time, and their values were checked from the repo. The lemurs config was stale (generated 2026-10-16 17:51, before the bases) and was regenerated 2026-10-17; it matches `colours-gen lemurs`.

- **Merging `colours` into `main`:** `symlinks/etc_lemurs_config.toml` is tracked on `main` and deleted on this branch, so the merge removes it from the working tree. Regenerate straight after: `setup/colours-gen lemurs > symlinks/etc_lemurs_config.toml.new && mv symlinks/etc_lemurs_config.toml.new symlinks/etc_lemurs_config.toml`. Not cleanly tested. In a scratch repo, switching to `main` while the file is gitignored silently replaced it with main's tracked copy, and with it not ignored the checkout was refused.
- **Consolidation:** (`nnn_symlink`, `nnn_context1`, `nnn_context3` renamed `col_violet`, `col_magenta`, `col_lime`, 2026-10-16; `col_white` and `col_bright_white` merged into `col_light`, `tui_white` renamed `col_white`, 2026-10-16; the palette was renamed `ansi_*` to `col_*` on 2026-10-16, `ansi_green` becoming `col_emerald`; notes below use the names of the time) blues, greens and greys done (2026-10-16: `col_chartblue` into `ansi_blue`; `col_seagreen` and `col_lightgreen` into `ansi_bright_green`; `col_grey_dark` into `col_grey`; the mid and light greys into `col_grey_light` at `#9E9E9E`). Darks were looked at and kept (2026-10-16). Whites (`col_nord4`, `ansi_white` into `col_light`), `col_blue` into `ansi_blue` and cyans (`col_cyan`, `nnn_context2` into `ansi_cyan`) and lime (`col_lime` into `nnn_context3`) also done. Closed 2026-10-17: the remaining `ansi_*` item no longer exists, since the palette is `col_*` and every colour is derived from the nine bases (no `ansi_` name is left in `colours.sh`, `colours.g.sh`, `colours.rules.sh` or the Xresources); `colours.md` section 5 carries a note that its hexes are historical. Each is a one-line edit in `colours.sh` followed by a look at the result.
- **Left as literals on purpose** (unused or not hex): polybar `bg_med`, `line_yellow`, `line_red`; the `nord0`–`nord15` defines and three commented palettes in Xresources; lemurs' four named colours.

## Base set exploration (2026-10-16)

Implemented 2026-10-17: see the Implementation section of `base_set.md`. `colours.rules.sh` holds the nine bases and the rules, `colours-derive` generates `colours.g.sh` (the hexes) from it, and `colours.sh` sources that and holds the helpers. The paragraph below is the background.

Whether the 24 chromatic colours can be derived from a few base colours with named modifier chains (light, lighter, lightest and so on) was explored at length. The final candidate (tab 33: six invented bases, nine chains, one modifier per derived colour, worst error 46, mean about 25), the rules, the decisions and everything that was tried are in `base_set.md`. The nine greys were searched separately and a decision is recorded in its Greys section: three bases (`col_black` and `col_white` stay exact, plus a grey base `#AAAAAA`), worst error 18, with `col_grey` and `col_light` the visible shifts. 
