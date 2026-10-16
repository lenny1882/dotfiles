# Colours plan

Written 2026-10-14. Nothing is built yet.

## Goal

A script that lets me define colours in a single place and propagates them out to every file that uses them. The mechanism is decided in outline (below); the details are still open.

## Decided (2026-10-16)

- **Source:** a shell-sourceable file of `name=#RRGGBB` lines ("A"), in `setup/`. Plain hex only. Every colour is a name, including the 16 terminal palette slots; alpha is applied by helpers, and lightened variants are their own lines.
- **Helpers:** `setup/colours.sh`, sourced by the wrappers, the generator and the prompt. Functions for hex, `r;g;b`, 256-colour and alpha. Written in POSIX `sh` so that both `sh` and bash scripts can source it (`monitor-tui-wrap.sh` stays `#!/bin/sh`). `/bin/sh` here is bash and `dash`, `checkbashisms` and `shellcheck` are not installed, so POSIX-ness can only be checked with `bash --posix` here.
- **Anything that can run shell sources A and the helpers directly:** the herbstluftwm files, `panel.sh`, `rule_hook.sh`, `background.sh`, `nnn-wrap.sh` and the bash prompt, each converting to the form it needs.
- **Programs that cannot read A:** wrap their launch in a script that sources A and injects the colours.
  - Xresources: `xrdb` run with `-D` flags (`startup.autostart:9`), with the file using macros for every colour including the palette slots. To be checked: that `cpp` accepts a `#` value in `-D`.
  - polybar: env vars from `panel.sh`, extending the `${env:...}` it already uses; the alpha forms built by the helpers.
  - rofi: `-theme-str` overrides in the four keybindings in `shortcuts.autostart`. To be tested.
  - bottom: a new `bottom-wrap.sh` (for example `bottom-wrap.sh cpu`) renders the template to a temp file and runs `pty_inset.py btm -C <temp file>`. The `btm` lines in `polybar.ini` and the `shortcuts.autostart` keybinding change to call it.
  - monitor TUI: `monitor-tui-wrap.sh` exports the values the TUI needs (the exact green as RGB plus its 256-colour fallback, and the other 256-colour numbers) as environment variables; `monitor_tui.py` reads them with `os.environ`, defaulting to today's values. No Python port of the helpers.
  - `pty_inset.py` stays generic. It also wraps `bluetui`, `nmtui`, `nnn` and an `sh -c` update command, so it is not touched.
- **Programs where no wrapper works:** lemurs (root, from a system service at boot, before the repo's disk may be mounted) and root's `nanorc` (`nano` is aliased to micro, so only real nano as root matters). These are generated from templates.
- **Templates and generator:** templates live in `setup/templates/<program>.tmpl` with `@col_green@` placeholders (a variant form for alpha / RGB is still to be designed). One renderer, `setup/colours-gen <program>`, is used by both the install step and the bottom wrapper (which renders to a temp file).
- **Generated files** are uncommitted. The output is written to the path `setup/config_links.sh` already links (`symlinks/etc_lemurs_config.toml`, `symlinks/root_.nanorc`) and gitignored, so `config_links.sh` does not change. The old tracked files are removed from git with `git rm --cached`, and their contents move into the templates. A separate step regenerates on demand.
- **Install order:** a new `step_colours` in `quickstart_arch.sh`, just before `step_config_links` (defined at line 295, called at line 584), runs the generator for lemurs and root's `nanorc`. Until it has run, those two links dangle (for lemurs, a broken login screen).

### Template variants

| Placeholder | Output |
|---|---|
| `@col_green@` | `#2E7D32` |
| `@col_green:rgb@` | `46;125;50` |
| `@col_green:256@` | `28` |
| `@col_green:alpha=CC@` | `#2E7D32CC` (suffix) |
| `@col_green:argb=CC@` | `#CC2E7D32` (prefix, polybar) |

`colours.sh` has helpers with the same names. Quotes around a value (bottom's `"#rrggbb"`) stay in the template. Lemurs' named colours (`white`, `red`, `gray`, `dark gray`) stay as written in the template and do not go through A.

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

The 16 palette slots are `ansi_black` … `ansi_bright_white`. A slot that is a project colour references it (`ansi_red=$col_red`, `ansi_purple=$col_purple`, `ansi_bright_white=$col_light`); `ansi_black` stays `#000000`, which is why the terminal background (`col_dark`) and ANSI black differ.

### Build order

1. A, `colours.sh` and the bash prompt as the first consumer. The `rgb` helper is checked against the values already written in `shellrc:52-73`.
2. The template renderer, then bottom.

`colours.md` in this directory lists every colour, what uses it and where it is defined. That is the starting inventory for this work.

## What the script has to cover

The colours are defined in these different formats today, so one source has to feed all of them:

- `#RRGGBB` and `#RRGGBBAA` hex in the Xresources, bottom, rofi and lemurs configs, and in herbstluftwm variables.
- polybar `#AARRGGBB` (alpha first), with `${env:...}` values passed in from `panel.sh`.
- truecolor `r;g;b` escape codes in the bash prompt.
- 256-colour numbers and palette slots in `nnn-wrap.sh` and `monitor_tui.py`, plus the one exact-RGB tuple in the TUI.
- named colours in lemurs and nano.

## Open questions

Nothing is undecided in the design. These are to be checked while building:

- Whether `cpp` accepts a `#` value in `xrdb -D`.
- Whether rofi's `-theme-str` overrides the variables in `custom.rasi`.
- That `colours.sh` is POSIX (only `bash --posix` is available here).
- Names for the values with none yet: the `#111111` literal at `theme.autostart:37`, polybar's transparent `#000000`, and the nord block in Xresources.
- Root's `nanorc` uses named colours, not hex, so its template needs a name mapping or the colours stay literal.
