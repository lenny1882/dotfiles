#!/bin/sh

# the bases and rules every colour comes from; setup/colours-derive reads this and writes colours.g.sh
# edit here, then run setup/colours-derive

# the bases are the only colours defined by value; every other colour is derived from one of them by a rule
base_black=#000000
base_white=#FFFFFF
base_grey=#AAAAAA
# the chromatic bases are invented, not colours that appear on screen: "oklch lightness chroma hue"
# a chroma beyond sRGB is allowed; a base as drawn has its chroma reduced until it fits (about the hex in each comment)
base_red="oklch 0.53728 0.27305 25.78633"	# about #C91C25
base_orange="oklch 0.76337 0.1837 80.63769"	# about #E2A627
base_yellow="oklch 0.89321 0.18686 109.37962"	# about #E6E526
base_green="oklch 0.75781 0.21236 144.00512"	# about #42D14B
base_blue="oklch 0.71825 0.16085 257.17296"	# about #69A5FA
base_purple="oklch 0.70966 0.1898 313.04886"	# about #CA78F4

# rules: one line per colour, "name base modifier step"
# a modifier is a chain word, with er or est added for level 2 or 3 (light, lighter, lightest); t = level * step
#   light, dark    OKLCH lightness toward white, toward black by t, chroma kept
#   soft, hard     OKLCH chroma times 1 - t, times 1 + t
#   pale, shade    RGB mixed with white, with black by t
#   muted          RGB mixed with the colour's own grey (0.2126 R + 0.7152 G + 0.0722 B) by t
#   warm, cool     OKLCH hue turned by t degrees toward orange (60), toward blue-cyan (230)
#   same           the base itself (no level; the step is ignored)
# the same modifier does the same operation in every group; the step may differ by up to 25% from the usual
# (light 0.12, dark 0.12, soft 0.30, hard 0.25, pale 0.20, shade 0.16, muted 0.25, warm 15, cool 15)
colour_rules='
col_red			base_red	soft		0.30
col_bright_red		base_red	lighter		0.15
col_nord11		base_red	paler		0.15
col_nord12		base_red	paler		0.20
col_magenta		base_red	coolest		11.25
col_orange		base_orange	warm		15
col_nord13		base_orange	palest		0.15
col_yellow		base_yellow	harder		0.1875
col_bright_yellow	base_yellow	lightest	0.15
col_green		base_green	shader		0.20
col_bright_green	base_green	muteder		0.1875
col_nord14		base_green	softest		0.225
col_emerald		base_green	cool		11.25
col_lime		base_green	warm		11.25
col_blue		base_blue	darker		0.12
col_bright_blue		base_blue	dark		0.12
col_nord10		base_blue	shader		0.12
col_nord9		base_blue	mutedest	0.1875
col_cyan		base_blue	coolest		15
col_bright_cyan		base_blue	coolest		11.25
col_purple		base_purple	darkest		0.12
col_violet		base_purple	shader		0.14
col_nord15		base_purple	mutedest	0.21875
col_bright_purple	base_purple	warm		15
col_black		base_black	same		0
col_white		base_white	same		0
col_bright_black	base_white	shadest		0.20
col_grey_light		base_white	darkest		0.10
col_almost_black	base_black	lighter		0.09
col_dark		base_black	lightest	0.09
col_dark2		base_black	pale		0.183
col_grey		base_grey	shadest		0.20
col_light		base_grey	palest		0.25
'
