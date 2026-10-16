# Base set exploration

Written 2026-10-16. Status: design exploration only. Nothing here is implemented in `setup/colours.sh`; the 33 colours there are unchanged by this work. This file records the question, the decisions, the final candidate (tab 33) and what was tried, so none of it has to be rediscovered.

The interactive page with every attempt is an Artifact: https://claude.ai/artifact/H6fFomAmxEkJHAjhPAB4gV (tabs 1 to 33, click a base to see only its chain). Side-by-side of tabs 27 and 29: https://claude.ai/artifact/DaAJAhG6xehYumthdvfFbW. Purple options: https://claude.ai/artifact/KuMxsnwRtHxa8VdMT7688B. They are snapshots (hex values are embedded); they do not read `colours.sh`.

## The question

Can the base palette be reduced by deriving colours from a few base colours with simple, human-readable rules?

Scope: the 24 chromatic colours in `colours.sh`. The 9 greys (`col_black`, `col_almost_black`, `col_dark`, `col_dark2`, `col_grey`, `col_bright_black`, `col_grey_light`, `col_light`, `col_white`) are not part of this question (their levels are 0, 17, 37, 46, 63, 102, 158, 239 and 255 of 255, unevenly spaced, and treating them as a free "grey ramp" made earlier results look better than they were). They were searched separately with the same chains; see the Greys section.

## The final spec (user's words, in order of authority)

- 1 base colour per group, which does not need to be a colour currently in use.
- A single, human-understandable modifier for each derived colour. No combining modifiers (the user did not approve combinations).
- Each modifier is in a chain, such as light / lighter / lightest.
- Each modifier performs the same operation across all groups, but the exact amount may differ per group within an acceptable range.
- Hue shifts are fine only if the word makes sense: warm and cool, not numbers or invented jargon.
- Not acceptable: two bases in one family (two greens, two blues, a separate magenta), a seventh base just for `col_nord15`, hard on/off limits on `col_green` (use a weight instead).
- `col_green` matters most and must not change noticeably.
- Six bases are preferred to five.

## Result: tab 33

Six invented bases, nine chains, one modifier per derived colour. Error is the perceptual RGB distance between the real colour and what the rule gives (26 is the gap between `col_dark` and `col_dark2`; about 50 is clearly visible). The derived hex is what the rule would produce, not what is in `colours.sh` today.

### Chains and shared steps

A level is a multiple of the group's step. A group's step may differ from the shared step by up to plus or minus 25%. Levels 1 to 3 take the suffixes "", "er", "est" (light, lighter, lightest).

| Chain | Operation | Shared step |
|---|---|---|
| light / dark | lightness toward white / black in OKLCH, colourfulness kept | 0.12 each |
| soft / hard | colourfulness reduced by t / increased by t in OKLCH, lightness kept | 0.30 / 0.25 |
| pale | RGB mixed with white by t | 0.20 |
| shade | RGB mixed with black by t | 0.16 |
| muted | RGB mixed toward the colour's own grey (0.2126 R + 0.7152 G + 0.0722 B) by t | 0.25 |
| warm / cool | OKLCH hue turned toward orange (60 degrees) / toward blue-cyan (230 degrees) by the step, along the shorter way round | 15 degrees each |

For light: L' = L + (1 - L) t. For dark: L' = L (1 - t). Soft: C' = C (1 - t). Hard: C' = C (1 + t). Out-of-gamut results are brought in by reducing chroma (multiply by 0.93 until it fits sRGB). OKLab conversion is Ottosson's matrices.

### The six groups

| Group | Base (invented) | Colour | Real hex | Rule gives | Error | Modifier |
|---|---|---|---|---|---|---|
| red | `#C91C25` | `col_red` | `#D32F2F` | `#C5292C` | 27 | soft (1 step of 0.30) |
| | | `col_bright_red` | `#EF5350` | `#FC5550` | 22 | lighter (2 steps of 0.15) |
| | | `col_nord11` | `#BF616A` | `#DA6067` | 45 | paler (2 steps of 0.15) |
| | | `col_nord12` | `#D08770` | `#DF777C` | 45 | paler (2 steps of 0.20) |
| | | `col_magenta` | `#D70087` | `#C2077B` | 42 | coolest (3 steps of 11.25 degrees) |
| orange | `#E2A627` | `col_orange` | `#FF9800` | `#FA9800` | 9 | warm (1 step of 15) |
| | | `col_nord13` | `#EBCB8B` | `#EFCE88` | 10 | palest (3 steps of 0.15) |
| yellow | `#E6E526` | `col_yellow` | `#E5E510` | `#E6E510` | 2 | harder (2 steps of 0.19) |
| | | `col_bright_yellow` | `#F5F543` | `#F5F541` | 2 | lightest (3 steps of 0.15) |
| green | `#42D14B` | `col_green` | `#2E7D32` | `#287D2D` | 12 | shader (2 steps of 0.20) |
| | | `col_bright_green` | `#66BB6A` | `#69C26F` | 16 | muteder (2 steps of 0.19) |
| | | `col_nord14` | `#A3BE8C` | `#96BC95` | 25 | softest (3 steps of 0.22) |
| | | `col_emerald` | `#0DBC79` | `#12D17B` | 43 | cool (1 step of 11.25) |
| | | `col_lime` | `#5FD700` | `#78CB03` | 46 | warm (1 step of 11.25) |
| blue (with cyan) | `#69A5FA` | `col_blue` | `#2472C8` | `#286ECC` | 12 | darker (2 steps of 0.12) |
| | | `col_bright_blue` | `#3B8EEA` | `#4489E9` | 16 | dark (1 step of 0.12) |
| | | `col_nord10` | `#5E81AC` | `#507EBE` | 37 | shader (2 steps of 0.12) |
| | | `col_nord9` | `#81A1C1` | `#87A1C6` | 13 | mutedest (3 steps of 0.19) |
| | | `col_cyan` | `#11A8CD` | `#1FB7D0` | 37 | coolest (3 steps of 15) |
| | | `col_bright_cyan` | `#29B8DB` | `#1DB5DF` | 20 | coolest (3 steps of 11.25) |
| purple | `#CA78F4` | `col_purple` | `#7B1FA2` | `#7A259F` | 13 | darkest (3 steps of 0.12) |
| | | `col_violet` | `#875FAF` | `#9156B0` | 24 | shader (2 steps of 0.14) |
| | | `col_nord15` | `#B48EAD` | `#A689B4` | 28 | mutedest (3 steps of 0.22) |
| | | `col_bright_purple` | `#D670D6` | `#DE70DC` | 16 | warm (1 step of 15) |

Steps actually used per chain: soft 0.22 to 0.30, light 0.15, pale 0.15 to 0.20, cool 11.25 to 15, warm 11.25 to 15, hard 0.19, shade 0.12 to 0.20, muted 0.19 to 0.22, dark 0.12. All inside plus or minus 25% of the shared step.

### Weak points (known)

- Red group: `col_nord11` and `col_nord12` are 45 off, `col_magenta` 42, and no base position does better under the shared rules.
- Green group: `col_emerald` 43 and `col_lime` 46. `col_green` was kept close (12) by weighting it 4 times in the search, at the cost of lime (46 against 63 at weight 10, where `col_green` is 6).
- Blue group: `col_nord10` and `col_cyan` are 37.
- `col_nord15` is 28 and reads grey: its hue is 333 degrees, the derived colours come out at 310 to 315. Fitting it in any other group was worse (48 to 65 against 24 to 28 in purple). It is a real Nord colour (`#B48EAD`, the last Aurora colour in the official palette).
- Several derived colours are named by their position against an invented base, so `col_blue` is "the blue base, darker", and `col_bright_blue` is "dark" of that base.

## Why the colours do not follow one rule

The colours come from three designers: Material/MUI (`col_red`, `col_bright_red`, `col_green`, `col_bright_green`, `col_purple`, `col_orange`), VS Code's terminal palette (`col_yellow`, `col_bright_yellow`, `col_blue`, `col_bright_blue`, `col_cyan`, `col_bright_cyan`, `col_emerald`, `col_bright_purple`) and Nord (`col_nord9` to `col_nord15`). A rule recovers a relationship only where one designer chose both colours as a pair.

- VS Code's own normal to bright pairs are mechanical: about 20% of the way to white in perceptual lightness, hue and colourfulness kept (red 0.20, green 0.20, blue 0.20, magenta 0.26, cyan 0.15).
- Applied to our pairs, that single rule gives errors of 13 (red), 12 (blue), 27 (cyan), 49 (yellow, near white), 89 (green) and 129 (purple). Green fails because `col_green` is MUI's dark green and `col_bright_green` its light one; purple because `col_purple` is MUI's and `col_bright_purple` is VS Code's bright magenta.
- The Nord colours are pastels (35 to 57% of the maximum colourfulness at their hue) and each has a hue 12 to 20 degrees off its family: nord13 +20, nord15 +20, nord14 -13, nord12 +12.
- Shared lightness-and-colourfulness tiers (nord set, brights, deep colours) fit badly (mean error 68 to 89), as did OKLCH gamut-relative chroma.

## What was tried and dropped (so it is not repeated)

| Approach | Why dropped |
|---|---|
| Mixing with white, black or own grey, shared rules used 3 or more times | Best was 15 bases at tolerance 45; most nord colours 40 to 50 off |
| Numeric rules with hue rotation (2, 3, 4 rules) | Found 10, 6 and 4 bases but with arbitrary rotations such as red from orange; rejected as unreadable |
| Keywords with different settings under one word (three "pastel") | Not a scale |
| Combining modifiers (`light soft warm`) | Not approved; also hid how poor the fits were |
| Hue words as degrees ("hue -12") | Unreadable; replaced by warm and cool |
| Five bases (orange and yellow merged) | Worse fit; six preferred |
| Blue and cyan as two bases, magenta its own base | Rejected by the user |
| Pinning `col_green` as a hard limit | Rejected; weighted instead |
| Fitting `col_nord15` in another group | Worse everywhere (48 to 65) |
| Base hue shifted one or two steps warm or cool in any group | Each group's base is already at its compromise; every step breaks more than it fixes |

## Greys

Decided 2026-10-16: three bases, `col_black` (`#000000`) and `col_white` (`#FFFFFF`) stay exactly black and white as bases themselves, plus one neutral grey base `#AAAAAA`. Only the chain definitions and step ranges above are used, on neutral greys; soft, hard, muted, warm and cool do nothing to a neutral. Nothing is implemented.

Search: every base from 0 to 255, chains dark, light, shade and pale, levels 1 to 3, steps varied by up to plus or minus 25% of the shared step (dark and light 0.12, shade 0.16, pale 0.20), all nine greys as targets, errors on the scale above. One base fits nothing within error 26. Two bases fit at worst error 12 (`#010101` and about `#EFEFEF`) but make black and white derived. Three free bases fit at 9.5. With black and white forced as bases the best is 18, only for a grey base of 169 to 171.

| Colour | Real | Rule gives | Error | Rule |
|---|---|---|---|---|
| `col_black` | `#000000` | `#000000` | 0 | base |
| `col_white` | `#FFFFFF` | `#FFFFFF` | 0 | base |
| `col_bright_black` | `#666666` | `#666666` | 0 | white, shadest (3 steps of 0.20) |
| `col_grey_light` | `#9E9E9E` | `#9E9E9E` | 0 | white, darkest (3 steps of 0.10) |
| `col_almost_black` | `#111111` | `#121212` | 3 | black, lighter (2 steps of 0.09) |
| `col_dark` | `#252526` | `#262626` | 2.5 | black, lightest (3 steps of 0.09) |
| `col_dark2` | `#2D2D30` | `#2F2F2F` | 5 | black, pale (1 step of 0.183) |
| `col_grey` | `#3E3E42` | `#444444` | 15 | `#AAAAAA`, shadest (3 steps of 0.20) |
| `col_light` | `#ECEFF4` | `#EAEAEA` | 18 | `#AAAAAA`, palest (3 steps of 0.25) |

Weak points: `col_grey` (borders, bars, lemurs, prompt) and `col_light` (text everywhere) are the visible shifts, and all the slight blue tint on `col_dark`, `col_dark2`, `col_grey` and `col_light` is lost. A tinted grey base `#A6AAB2` gives 15.8 and 16.1 for the same two colours, a small gain. Alpha changes were considered and rejected as not within reason: a colour drawn at alpha `a` is off by about `a` times its solid error, which only helps `col_almost_black` (alpha `77`, error about 13 effective). `col_bright_black` is palette slot 8 and `col_grey_light` is read as xterm 247 by nnn and the monitor TUI, so `col_grey_light` would need `col_grey_light_256=247`. The visual comparison of this and two other base sets is an Artifact: https://claude.ai/artifact/Wuws5b1pUDxgvntG8LtXyD

## Tab history (permanent numbers; new tabs are only ever added at the end)

1 Tint and mute with greys as a ramp, tolerance 45 / 2 same at 60 / 3 greys excluded, 45 / 4 greys excluded, 60 / 5 two numeric rules with hue rotation / 6 three / 7 four / 8 keywords, unscaled, 45 / 9 same at 60 / 10 scaled keywords in RGB mixing, 45 / 11 same at 60 / 12 perceptual steps, 30 / 13 same at 20 / 14 same at 45 / 15 new bases, no hue shift / 16 hue shift up to 24 degrees / 17 up to 12 degrees / 18 warm and cool, up to 12 degrees / 19 warm, warmer, cool, cooler, up to 24 / 20 one modifier per colour / 21 one modifier, bases 40 degrees apart, tolerance 60 / 22 eight families, existing colours as bases / 23 every member tried as the base / 24 six bases, blue with cyan, magenta under red / 25 nine chains, six bases / 26 five bases / 27 `col_green` weighted 4 times, six bases / 28 same, five bases / 29 weighted 10 times, six bases / 30 same, five bases / 31 groups chosen from 27 and 29 under one set of steps / 32 purple base `#C47BFA` / 33 purple base `#CA78F4` (the current candidate).

## If this is implemented

Not decided and not started.

- `colour_256` returns an exact xterm entry or a `NAME_256` override. Derived hexes would not be exact xterm entries, so any derived colour read through `colour_256` needs an override that keeps today's number. The colours that go through `colour_256` today (in `nnn-wrap.sh` and `monitor-tui-wrap.sh`) are `col_blue`, `col_bright_purple`, `col_bright_red`, `col_bright_yellow`, `col_cyan`, `col_emerald`, `col_green`, `col_light` and `col_yellow`, which already have `_256` overrides, and `col_violet` (97), `col_magenta` (162), `col_lime` (76), `col_grey_light` (247) and `col_white` (231), which have none because their hex is an exact xterm entry. If `col_violet`, `col_magenta` or `col_lime` become derived, each needs an override line (`col_violet_256=97` and so on) so nnn does not change. The two greys are outside this work.
- Colour changes are visible by the error amounts above. `col_green` 12 and `col_bright_green` 16 should be near-invisible; red-group and green-group rows 42 to 46 will visibly shift.
- Every consumer (Xresources `-D` macros, bottom templates, polybar env vars, lemurs, the prompt) still needs a final hex per name. The OKLCH maths is awkward in POSIX `sh`, so the likely route is to generate the hex values once (a script outside `colours.sh`) and paste them, with the bases and rules recorded as comments or as `colours-gen` input.
- The search and page scripts are not in the repo: they were throwaway Python in the session scratch area, and the repo is bash. The method above is enough to redo them. Say if you want them kept under `.planning/` for reference.
- Existing colours were merged earlier the same day (blues, greens, greys, whites, cyans, lime, and the `ansi_` to `col_` rename); that work is in `colours.md` and is committed (latest `2a3ef2d`).
