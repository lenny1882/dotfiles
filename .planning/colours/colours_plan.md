# Colours plan

Written 2026-10-14. Nothing is built yet.

## Goal

A script that lets me define colours in a single place and propagates them out to every file that uses them. The mechanism is not decided; we will work it out later.

`colours.md` in this directory lists every colour, what uses it and where it is defined. That is the starting inventory for this work.

## What the script has to cover

The colours are defined in these different formats today, so one source has to feed all of them:

- `#RRGGBB` and `#RRGGBBAA` hex in the Xresources, bottom, rofi and lemurs configs, and in herbstluftwm variables.
- polybar `#AARRGGBB` (alpha first), with `${env:...}` values passed in from `panel.sh`.
- truecolor `r;g;b` escape codes in the bash prompt.
- 256-colour numbers and palette slots in `nnn-wrap.sh` and `monitor_tui.py`, plus the one exact-RGB tuple in the TUI.
- named colours in lemurs and nano.

## Open questions

- Where the single definition lives, and in what format.
- How it is propagated: generate the config files, substitute values at install time (`setup/symlinks.sh`), or have each program read it at start.
- How to handle the files that are symlinked from this repo into `~` and `/etc` (the generated output must still land in the repo or the symlink targets).
- What to do with colours that are derived (alpha variants, lightened variants) and with the 16-slot terminal palette, where the choices are not just a name and a value.
