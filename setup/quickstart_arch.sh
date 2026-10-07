#!/usr/bin/env bash

# directory the script itself lives in - steps that `cd` elsewhere (eg. into
# DOWNLOAD_DIR) still need this to find ./symlinks.sh and ./shell_loader.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --------------------------------
# general setup

# wrappers for whichever aur helper is installed
if hash yay 2>/dev/null; then
	builder() { yay -S --needed "$@"; }
	installer() { yay -S --needed "$@"; }
	local-installer() { yay -U --needed "$@"; }
elif hash pamac 2>/dev/null; then
	builder() { pamac build "$@"; }
	installer() { pamac install "$@"; }
	local-installer() { pamac install "$@"; }
fi

# colours, matching yay's own scheme (magenta index, bold names, bold green prompts)
if [[ -t 1 ]]; then
	C_NUM=$'\033[35m'
	C_PKG=$'\033[1m'
	C_PROMPT=$'\033[1;32m'
	C_OK=$'\033[32m'
	C_CYAN=$'\033[36m'
	C_DIM=$'\033[38;5;248m'
	C_RESET=$'\033[0m'
else
	C_NUM="" C_PKG="" C_PROMPT="" C_OK="" C_CYAN="" C_DIM="" C_RESET=""
fi

# --------------------------------
# drawing helpers

boxWidth() {
	local w
	w=$(tput cols 2>/dev/null) || w=80
	(( w > 92 )) && w=92
	printf '%d' "$w"
}

hr() {
	local width=$(boxWidth)
	printf "${C_PROMPT}%s${C_RESET}\n" "$(printf '─%.0s' $(seq 1 "$width"))"
}

# a quieter divider for command-output screens (dashed, dim) - the solid
# green hr() is reserved for primary chrome like the main menu
hrMuted() {
	local width=$(boxWidth)
	# alternating dash/space, trimmed to width - bigger, more spaced-out
	# dashes than a repeated ╌ glyph gives
	local pattern
	pattern=$(printf '─ %.0s' $(seq 1 $(( (width + 1) / 2 ))))
	printf "${C_DIM}%s${C_RESET}\n" "${pattern:0:width}"
}

# visually separate an interactive selection from the command output that
# follows it: blank line, then a divider
beginOutput() {
	printf "\n"
	hrMuted
}

# colourise a command's output line by line (optionally in $1's colour) -
# called as the read side of a pipe around a step's actual commands. This
# variant doesn't touch the cursor or redraw anything itself - the pinned
# footer below (see stickyFooterOn) stays in place on its own once the
# scroll region is set, no per-line action needed:
#   { installer foo; systemctl enable foo; } 2>&1 | pinnedOutput
#   { installer foo; systemctl enable foo; } 2>&1 | pinnedOutput "$C_DIM"
pinnedOutput() {
	local color=$1 line
	while IFS= read -r line; do
		printf '%s%s%s\n' "$color" "$line" "${color:+$C_RESET}"
	done
}

# the current step's footer text (eg. "Step 2 of 5 — Fonts"), and how many
# rows it takes at the bottom of the screen
FOOTER_TEXT=""
FOOTER_LINES=1

# restrict scrolling to rows 1..(LINES-footerLines), leaving the bottom
# $1 rows as a pinned footer. This is the mirror image of the header attempt
# that broke scrollback: a scroll region whose TOP margin isn't row 1 never
# feeds scrolled-off content into the terminal's native scrollback on
# xterm-likes (incl. urxvt) - but a region whose top margin IS row 1 (this
# one) does, since only the bottom is restricted. The tradeoff is pinning
# context at the bottom instead of the top
stickyFooterOn() {
	local footerLines=$1 rows
	rows=$(tput lines 2>/dev/null) || rows=24
	printf '\033[1;%dr' "$(( rows - footerLines ))"
	# changing the scroll region moves the cursor to its home position -
	# that's exactly where we want it (top of the now-restricted scrollable
	# area), so no extra repositioning needed here
}

# release the scrolling region back to the full screen - must be called
# before the next clear/redraw, or the restricted region sticks around
stickyFooterOff() {
	printf '\033[r'
}

# draw (or redraw) the pinned footer without disturbing the cursor - only
# needs calling once per step, since its row never scrolls once the region
# from stickyFooterOn is active
drawFooter() {
	local rows
	rows=$(tput lines 2>/dev/null) || rows=24
	printf '\0337'
	tput cup "$(( rows - FOOTER_LINES ))" 0 2>/dev/null
	printf '\033[K%s' "$FOOTER_TEXT"
	printf '\0338'
}

# a titled, rounded box - used for the menu header and each step's screen
boxHeader() {
	local label=$1 width inner padLen pad
	width=$(boxWidth)
	inner=$(( width - 2 ))
	# pad manually using character count (${#label}) rather than printf's
	# %-*s, which pads by byte count and misaligns on multibyte glyphs (—)
	padLen=$(( inner - 2 - ${#label} ))
	(( padLen < 0 )) && padLen=0
	pad=$(printf '%*s' "$padLen" '')
	printf "${C_PROMPT}╭%s╮${C_RESET}\n" "$(printf '─%.0s' $(seq 1 "$inner"))"
	printf "${C_PROMPT}│${C_RESET}  %s%s${C_PROMPT}│${C_RESET}\n" "$label" "$pad"
	printf "${C_PROMPT}╰%s╯${C_RESET}\n" "$(printf '─%.0s' $(seq 1 "$inner"))"
}

# --------------------------------
# package-selection helpers

# print a pacman-group-style, column-packed numbered list (no prompt line -
# callers print their own, since "pick one" and "pick a subset" read differently)
printNumbered() {
	local -a items=("$@")
	local n=${#items[@]} numWidth maxLen=0 len pkg
	numWidth=${#n}
	for pkg in "${items[@]}"; do
		len=${#pkg}
		(( len > maxLen )) && maxLen=$len
	done
	local termWidth colWidth cols
	termWidth=$(tput cols 2>/dev/null) || termWidth=80
	colWidth=$(( numWidth + maxLen + 4 ))
	cols=$(( termWidth / colWidth ))
	(( cols < 1 )) && cols=1
	local i idx numPart namePart
	printf "\n"
	for i in "${!items[@]}"; do
		idx=$((i+1))
		numPart=$(printf "%${numWidth}d)" "$idx")
		namePart=$(printf "%-${maxLen}s" "${items[i]}")
		printf "${C_NUM}%s${C_RESET} ${C_PKG}%s${C_RESET}  " "$numPart" "$namePart"
		(( idx % cols == 0 )) && printf "\n"
	done
	(( n % cols != 0 )) && printf "\n"
}

# print a numbered list and read a single choice - for steps that pick one
# of several alternatives (eg. display manager), not a subset to install.
# stores the chosen 1-based index into the caller's result var (nameref, not
# a $(...) return - selectAndInstall's list/prompt output must reach the
# terminal directly, not get swallowed by command substitution)
selectOne() {
	local -n result=$1
	shift
	local -a items=("$@")
	local n=${#items[@]} input
	printNumbered "${items[@]}"
	printf "${C_PROMPT}==>${C_RESET} Enter a selection (default=1): "
	read -r input
	input=${input:-1}
	# out-of-range/non-numeric input intentionally falls through to an empty
	# result - every caller's case statement already treats "no match" as a
	# silent no-op, so there's nothing extra to handle here
	result=""
	[[ $input =~ ^[0-9]+$ ]] && (( input >= 1 && input <= n )) && result=$input
}

# expand a pacman-style selection string (space-separated "N", "N-M", "^N", "^N-M")
# into the indices (1..n) that should be kept
parseSelection() {
	local n=$1 input=$2
	local -A selected=() excluded=()
	local hasPlain=false token range start end i
	for token in $input; do
		if [[ $token == ^* ]]; then
			range=${token#^}
		else
			range=$token
			hasPlain=true
		fi
		if [[ $range == *-* ]]; then
			start=${range%-*}
			end=${range#*-}
		else
			start=$range
			end=$range
		fi
		# a reversed range (eg. "5-2") intentionally yields nothing rather
		# than erroring - the loop below just never executes
		for ((i=start; i<=end; i++)); do
			if [[ $token == ^* ]]; then
				excluded[$i]=1
			else
				selected[$i]=1
			fi
		done
	done
	for ((i=1; i<=n; i++)); do
		if $hasPlain; then
			[[ -n ${selected[$i]:-} && -z ${excluded[$i]:-} ]] && printf '%d\n' "$i"
		else
			[[ -z ${excluded[$i]:-} ]] && printf '%d\n' "$i"
		fi
	done
}

# read a pacman-style selection line for a list of n items, print the kept indices
selectIndices() {
	local n=$1 input
	local -a keepIdx=()
	read -r input
	if [[ -z $input ]]; then
		local i; for ((i=1; i<=n; i++)); do keepIdx+=("$i"); done
	else
		mapfile -t keepIdx < <(parseSelection "$n" "$input")
	fi
	printf '%s\n' "${keepIdx[@]}"
}

# print a numbered list, read a pacman-style selection line, and store the
# kept 1-based indices into the caller's result array (nameref) - shared by
# every step that offers "pick a subset of these" (selectAndInstall, step_apps)
promptSelection() {
	local -n outIdx=$1
	shift
	local -a items=("$@")
	printNumbered "${items[@]}"
	printf "${C_PROMPT}==>${C_RESET} Enter a selection (eg: 1 2 3, 1-3 or ^4) (default=all): "
	mapfile -t outIdx < <(selectIndices "${#items[@]}")
}

# show a numbered list of items, read a pacman-style selection, install the result
selectAndInstall() {
	local -a all=("$@") toInstall=() keepIdx=()
	local i
	promptSelection keepIdx "${all[@]}"
	for i in "${keepIdx[@]}"; do
		toInstall+=("${all[i-1]}")
	done
	if [[ ${#toInstall[@]} -gt 0 ]]; then
		beginOutput
		{ installer "${toInstall[@]}"; } 2>&1 | pinnedOutput "$C_DIM"
	fi
}

# --------------------------------
# step functions
# (each one used to be gated by its own "Install X? [Y]es/[n]o" prompt;
#  that gate is now the menu checkbox itself, so the prompts were dropped)

step_system_update() {
	{ sudo pacman -Syu; } 2>&1 | pinnedOutput
}

step_symlinks() {
	{ "$SCRIPT_DIR/symlinks.sh"; } 2>&1 | pinnedOutput
}

step_shell_loader() {
	{
		case $SHELL in
			/bin/bash) "$SCRIPT_DIR/shell_loader.sh" bash ;;
			/bin/zsh)  "$SCRIPT_DIR/shell_loader.sh" zsh ;;
			#*)    echo "Cannot add to ~/.{shell}rc" ;;
		esac
	} 2>&1 | pinnedOutput
}

step_nvidia() {
	{
		installer nvidia-inst
		nvidia-inst
		yay -Rscu nvidia-inst
	} 2>&1 | pinnedOutput
}

step_display_manager() {
	echo -n "Which display manager do you want to install:"
	local choice svc
	selectOne choice "lemurs" "ly"
	case $choice in
		1) svc=lemurs ;;
		2) svc=ly ;;
		*) return ;;
	esac
	beginOutput
	{ installer "$svc"; systemctl enable "$svc.service"; } 2>&1 | pinnedOutput "$C_DIM"
}

step_firewall() {
	{
		installer ufw
		systemctl enable --now ufw
		sudo ufw enable
	} 2>&1 | pinnedOutput
}

step_fonts() {
	echo -n "Which fonts do you want to install:"
	selectAndInstall \
		adobe-source-han-sans-otc-fonts \
		adobe-source-han-serif-otc-fonts \
		noto-fonts \
		noto-fonts-cjk \
		noto-fonts-tc \
		ttf-dejavu-nerd \
		ttf-tw \
		ttf-ubraille
	# yay -Rdd ttf-harmonyos-sans
}

step_printers() {
	{ installer cups; systemctl enable --now org.cups.cupsd.service; } 2>&1 | pinnedOutput
}

step_ssd_trim() {
	{ systemctl enable fstrim.timer; } 2>&1 | pinnedOutput
}

step_terminal() {
	echo -n "Which terminal emulator do you want to install:"
	local choice
	selectOne choice "urxvt" "other - manual"
	case $choice in
		1) beginOutput
		   { installer rxvt-unicode-truecolor-wide-glyphs; } 2>&1 | pinnedOutput "$C_DIM"
		   ;;
		2) ;;
		*) ;;
	esac
}

step_window_manager() {
	{
		installer herbstluftwm
		installer polybar
		mkdir -p ~/.config/herbstluftwm
		cp /etc/xdg/herbstluftwm/autostart ~/.config/herbstluftwm/
	} 2>&1 | pinnedOutput
}

step_packages() {
	echo -n "Which packages do you want to install:"
	selectAndInstall \
		bambustudio-bin \
		bat \
		blender \
		bottom \
		dragon-drop \
		dropbox \
		dunst \
		easyeffects \
		easystroke \
		eruler-git \
		eza \
		feh \
		freecad \
		fzf \
		gnome-disk-utility \
		gpick \
		gthumb \
		gvfs \
		inkscape \
		krita \
		lsp-plugins-lv2 \
		micro \
		minecraft-launcher \
		mpv \
		ncdu \
		nnn-nerd \
		numlockx \
		obsidian-appimage \
		orca-slicer-unstable-bin \
		patchelf \
		pavucontrol \
		peek \
		physlock \
		picom \
		playerctl \
		rambox-pro-bin \
		rofi \
		rofi-calc \
		scangearmp2-sane-git \
		scrot \
		sublime-text-4 \
		tigervnc \
		tldr \
		unzip \
		visual-studio-code-bin \
		vivaldi \
		xarchiver \
		yaycache \
		yaycache-hook
}

# individual app install routines - each has its own post-install steps
# (service enablement, gpg key import, ...) so they can't be reduced to a
# plain package name for selectAndInstall; step_apps lists them the same
# way selectAndInstall lists packages, then runs the chosen routines
_app_claude() {
	curl -fsSL https://claude.ai/install.sh | bash
}

_app_expressvpn() {
	installer expressvpn
	systemctl enable --now expressvpn.service
	expressvpn preferences set auto_connect true
	expressvpn preferences set network_lock on
}

_app_spotify() {
	# pamac without sudo so gpg key is recognised (as not added to sudo keychain!)
	curl -sS https://download.spotify.com/debian/pubkey_0D811D58.gpg | gpg --import -
	builder spotify
}

_app_teamviewer() {
	installer teamviewer
	systemctl enable --now teamviewerd
}

APP_NAMES=(Claude ExpressVPN Spotify TeamViewer)
APP_FUNCS=(_app_claude _app_expressvpn _app_spotify _app_teamviewer)

step_apps() {
	echo -n "Which apps do you want to install:"
	local -a keepIdx=()
	promptSelection keepIdx "${APP_NAMES[@]}"
	local i
	if [[ ${#keepIdx[@]} -gt 0 ]]; then
		beginOutput
		{
			for i in "${keepIdx[@]}"; do
				"${APP_FUNCS[i-1]}"
			done
		} 2>&1 | pinnedOutput "$C_DIM"
	fi
}

# --------------------------------
# step registry (menu order, grouped by purpose)

# within each group: priority items first (a system update has to happen
# before anything else benefits from it), then whatever's left, alphabetical
STEP_NAMES=(
	"System update (pacman -Syu)"
	"Firewall (ufw)"
	"Nvidia drivers"
	"SSD trim"
	"Symlink user directories"
	"Load shell rc files"
	"Display manager"
	"Terminal emulator"
	"Window manager (herbstluftwm)"
	"Fonts"
	"Printers (CUPS)"
	"Packages"
	"Apps"
)
STEP_FUNCS=(
	step_system_update
	step_firewall
	step_nvidia
	step_ssd_trim
	step_symlinks
	step_shell_loader
	step_display_manager
	step_terminal
	step_window_manager
	step_fonts
	step_printers
	step_packages
	step_apps
)

# groups: name + how many of the STEP_NAMES entries (taken in order,
# starting where the previous group left off) belong to it
GROUP_NAMES=("System" "User setup" "Desktop" "Software")
GROUP_SIZES=(4 2 5 2)

# STEP_NAMES/STEP_FUNCS are index-paired, and GROUP_SIZES assumes STEP_NAMES
# is laid out as contiguous runs matching GROUP_NAMES in order - none of that
# is enforced by the shape of the data, so a step added/removed/reordered
# without updating all three in lockstep would otherwise fail silently (wrong
# name runs the wrong function, or a step renders in the wrong group)
if (( ${#STEP_NAMES[@]} != ${#STEP_FUNCS[@]} )); then
	echo "quickstart_arch: STEP_NAMES and STEP_FUNCS have different lengths (${#STEP_NAMES[@]} vs ${#STEP_FUNCS[@]})" >&2
	exit 1
fi
groupSizeTotal=0
for groupSize in "${GROUP_SIZES[@]}"; do (( groupSizeTotal += groupSize )); done
if (( groupSizeTotal != ${#STEP_NAMES[@]} )); then
	echo "quickstart_arch: GROUP_SIZES (sum $groupSizeTotal) doesn't cover all of STEP_NAMES (${#STEP_NAMES[@]})" >&2
	exit 1
fi
unset groupSizeTotal groupSize

# --------------------------------
# menu

CHECKED=()
CURSOR_COL=0
CURSOR_ROW=0
GROUP_START=()
GROUP_END=()
COL_KIND_0=()
COL_REF_0=()
COL_KIND_1=()
COL_REF_1=()

initChecked() {
	local i
	for i in "${!STEP_NAMES[@]}"; do CHECKED[i]=1; done
}

# GROUP_START[g]/GROUP_END[g]: the STEP_NAMES index range covered by group g,
# derived from GROUP_SIZES (contiguous, in registry order)
buildGroups() {
	GROUP_START=() GROUP_END=()
	local g start=0 size
	for g in "${!GROUP_SIZES[@]}"; do
		size=${GROUP_SIZES[g]}
		GROUP_START[g]=$start
		GROUP_END[g]=$(( start + size - 1 ))
		start=$(( start + size ))
	done
}

# split the groups across two columns (first half left, second half right),
# each as a navigable row list: a "group" row, then a "step" row per step in
# it, then a "blank" spacer row - this is what the cursor walks per column
buildColumns() {
	COL_KIND_0=() COL_REF_0=()
	COL_KIND_1=() COL_REF_1=()
	local leftCount=$(( (${#GROUP_NAMES[@]} + 1) / 2 ))
	local g s col
	for g in "${!GROUP_NAMES[@]}"; do
		(( g < leftCount )) && col=0 || col=1
		local -n kindArr="COL_KIND_${col}" refArr="COL_REF_${col}"
		kindArr+=(group)
		refArr+=("$g")
		for (( s=GROUP_START[g]; s<=GROUP_END[g]; s++ )); do
			kindArr+=(step)
			refArr+=("$s")
		done
		kindArr+=(blank)
		refArr+=(-1)
	done
}

# all/none/partial, based on the CHECKED state of every step in group g
groupState() {
	local g=$1 s allChecked=1 anyChecked=0
	for (( s=GROUP_START[g]; s<=GROUP_END[g]; s++ )); do
		if [[ ${CHECKED[s]} == 1 ]]; then anyChecked=1; else allChecked=0; fi
	done
	if (( allChecked )); then printf all
	elif (( anyChecked )); then printf partial
	else printf none
	fi
}

toggleGroup() {
	local g=$1 s val=1
	[[ $(groupState "$g") == all ]] && val=0
	for (( s=GROUP_START[g]; s<=GROUP_END[g]; s++ )); do CHECKED[s]=$val; done
}

toggleAll() {
	local i any0=0
	for i in "${!CHECKED[@]}"; do
		[[ ${CHECKED[i]} == 0 ]] && any0=1
	done
	for i in "${!CHECKED[@]}"; do
		CHECKED[i]=$any0
	done
}

# step dir=-1/+1 through rows of the active column, wrapping, until a row
# matching $1 is found - "nonblank" is a plain up/down move (skips only the
# blank spacer rows), "group" jumps to the next/previous group header
# (shift+up/down)
moveCursorScan() {
	local target=$1 dir=$2
	local -n kindArr="COL_KIND_${CURSOR_COL}"
	local len=${#kindArr[@]} tries=0
	while (( tries < len )); do
		CURSOR_ROW=$(( (CURSOR_ROW + dir + len) % len ))
		if [[ $target == group ]]; then
			[[ ${kindArr[CURSOR_ROW]} == group ]] && return
		else
			[[ ${kindArr[CURSOR_ROW]} != blank ]] && return
		fi
		(( tries++ ))
	done
}
moveCursorVert() { moveCursorScan nonblank "$1"; }
moveCursorGroup() { moveCursorScan group "$1"; }

# switch the active column, keeping the same row where possible (clamped,
# nudged off a blank spacer row if it lands on one)
moveCursorCol() {
	local newCol=$1
	(( newCol == CURSOR_COL )) && return
	local -n kindArr="COL_KIND_${newCol}"
	local len=${#kindArr[@]}
	(( len == 0 )) && return
	CURSOR_COL=$newCol
	(( CURSOR_ROW >= len )) && CURSOR_ROW=$(( len - 1 ))
	[[ ${kindArr[CURSOR_ROW]} != blank ]] && return
	local r
	for (( r=CURSOR_ROW; r<len; r++ )); do
		[[ ${kindArr[r]} != blank ]] && { CURSOR_ROW=$r; return; }
	done
	for (( r=CURSOR_ROW; r>=0; r-- )); do
		[[ ${kindArr[r]} != blank ]] && { CURSOR_ROW=$r; return; }
	done
}

# render one row of one column into $CELL_COLORED (with ANSI) and
# $CELL_PLAINLEN (visible character count, for padding before the next
# column - printf's %-*s can't be used here since it pads by byte count and
# would misalign around the escape sequences)
cellRender() {
	local col=$1 row=$2
	local -n kindArr="COL_KIND_${col}" refArr="COL_REF_${col}"
	local kind=${kindArr[row]} ref=${refArr[row]}
	local isCursor=0 mark markColor label
	[[ $col == "$CURSOR_COL" && $row == "$CURSOR_ROW" ]] && isCursor=1
	CELL_COLORED="" CELL_PLAINLEN=0
	case $kind in
		group)
			label=${GROUP_NAMES[ref]}
			case $(groupState "$ref") in
				all)     mark="●"; markColor=$C_OK ;;
				partial) mark="◐"; markColor=$C_NUM ;;
				*)       mark="○"; markColor=$C_DIM ;;
			esac
			if (( isCursor )); then
				CELL_COLORED="  ${C_PROMPT}❯${C_RESET} ${markColor}${mark}${C_RESET}  ${C_PKG}${label}${C_RESET}"
			else
				CELL_COLORED="    ${markColor}${mark}${C_RESET}  ${C_PKG}${label}${C_RESET}"
			fi
			CELL_PLAINLEN=$(( 7 + ${#label} ))
			;;
		step)
			label=${STEP_NAMES[ref]}
			if [[ ${CHECKED[ref]} == 1 ]]; then mark="●"; markColor=$C_CYAN; else mark="○"; markColor=$C_DIM; fi
			if (( isCursor )); then
				CELL_COLORED="    ${C_PROMPT}❯${C_RESET} ${markColor}${mark}${C_RESET}  ${label}"
			else
				CELL_COLORED="      ${markColor}${mark}${C_RESET}  ${label}"
			fi
			CELL_PLAINLEN=$(( 9 + ${#label} ))
			;;
	esac
}

# widest visible row (group or step) in column $1, used to align column two.
# reuses cellRender's own CELL_PLAINLEN rather than re-deriving the "7 +
# label"/"9 + label" formula here too, so the two can't drift out of sync
colWidth() {
	local col=$1 i w=0
	local -n kindArr="COL_KIND_${col}"
	for i in "${!kindArr[@]}"; do
		cellRender "$col" "$i"
		(( CELL_PLAINLEN > w )) && w=$CELL_PLAINLEN
	done
	printf '%d' "$w"
}

renderMenu() {
	clear
	boxHeader "quickstart_arch"
	printf "\n"
	printf "  ${C_DIM}%-9s%-31s%-9s%s${C_RESET}\n" STORAGE "$STORAGE_DIR" USER "$USER_DIR"
	printf "  ${C_DIM}%-9s%-31s%-9s%s${C_RESET}\n" DOWNLOAD "$DOWNLOAD_DIR" PROGRAMS "$PROGRAMS_DIR"
	printf "\n"

	local leftWidth
	leftWidth=$(colWidth 0)

	local maxRows=${#COL_KIND_0[@]}
	(( ${#COL_KIND_1[@]} > maxRows )) && maxRows=${#COL_KIND_1[@]}

	local r pad
	for (( r=0; r<maxRows; r++ )); do
		if (( r < ${#COL_KIND_0[@]} )); then
			cellRender 0 "$r"
			printf '%s' "$CELL_COLORED"
			pad=$(( leftWidth - CELL_PLAINLEN + 3 ))
		else
			pad=$(( leftWidth + 3 ))
		fi
		(( pad < 1 )) && pad=1
		printf '%*s' "$pad" ""
		if (( r < ${#COL_KIND_1[@]} )); then
			cellRender 1 "$r"
			printf '%s' "$CELL_COLORED"
		fi
		printf '\n'
	done
	hr
	printf "${C_PKG}↑/↓/←/→${C_RESET}${C_DIM} move   ${C_RESET}${C_PKG}⇧+↑/↓${C_RESET}${C_DIM} jump group   ${C_RESET}${C_PKG}space${C_RESET}${C_DIM} toggle   ${C_RESET}${C_PKG}a${C_RESET}${C_DIM} toggle all   ${C_RESET}${C_PKG}enter${C_RESET}${C_DIM} start   ${C_RESET}${C_PKG}q${C_RESET}${C_DIM} quit${C_RESET}\n"
}

# run every checked step in menu order, each on its own cleared screen;
# after each one (bar the last) ask whether to continue to the next named
# step, or bail back to the menu
runSelected() {
	local -a queue=()
	local i
	for i in "${!STEP_NAMES[@]}"; do
		[[ ${CHECKED[i]} == 1 ]] && queue+=("$i")
	done
	if [[ ${#queue[@]} -eq 0 ]]; then
		clear
		printf "No steps selected.\n\n"
		read -r -e -p "Press enter to return to the menu: " _
		return
	fi
	local qi idx nextIdx ans total=${#queue[@]}
	for qi in "${!queue[@]}"; do
		idx=${queue[qi]}
		stickyFooterOff
		clear
		# region has to be set up BEFORE anything is drawn, not after:
		# stickyFooterOn's cursor-home side effect would otherwise stomp
		# whatever was already printed (the box header). It stays active
		# through the divider/prompt below too (still visually "this step's
		# page"), and only gets torn down right before the next clear, or
		# before returning to the menu, for the same reason in reverse -
		# resetting it mid-page would jump the cursor to home and stomp the
		# top of the scrollable area instead of continuing where output left off
		stickyFooterOn "$FOOTER_LINES"
		boxHeader "Step $((qi+1)) of $total — ${STEP_NAMES[idx]}"
		printf "\n"
		FOOTER_TEXT="${C_PROMPT}Step $((qi+1)) of $total${C_RESET} — ${STEP_NAMES[idx]}"
		drawFooter
		"${STEP_FUNCS[idx]}"
		CHECKED[idx]=0
		printf "\n"
		hrMuted
		if (( qi < total - 1 )); then
			nextIdx=${queue[qi+1]}
			read -r -e -p "Continue with next step: ${STEP_NAMES[nextIdx]}? ([Y]es / [n]o - return to menu): " ans
			ans=${ans:-Y}
			if [[ ${ans,,} != y ]]; then
				stickyFooterOff
				return
			fi
		else
			read -r -e -p "All selected steps complete. Press enter to return to the menu: " _
		fi
	done
	stickyFooterOff
}

runMenu() {
	initChecked
	buildGroups
	buildColumns
	CURSOR_COL=0
	CURSOR_ROW=0
	local key c
	stty -echo 2>/dev/null
	tput civis 2>/dev/null
	trap 'stty echo 2>/dev/null; tput cnorm 2>/dev/null' RETURN
	while true; do
		renderMenu
		IFS= read -rsn1 key
		if [[ $key == $'\x1b' ]]; then
			# CSI sequences are variable length (eg. plain arrows are
			# "\x1b[A", shift+arrows are "\x1b[1;2A") - keep reading until
			# the final byte (a letter, or ~) that terminates the sequence
			IFS= read -rsn1 -t 0.05 c
			key+=$c
			if [[ $c == '[' ]]; then
				while IFS= read -rsn1 -t 0.05 c; do
					key+=$c
					[[ $c == [A-Za-z~] ]] && break
				done
			fi
		fi
		case "$key" in
			$'\x1b[A') moveCursorVert -1 ;;
			$'\x1b[B') moveCursorVert 1 ;;
			$'\x1b[D') moveCursorCol 0 ;;
			$'\x1b[C') moveCursorCol 1 ;;
			$'\x1b[1;2A'|$'\x1b[a') moveCursorGroup -1 ;;
			$'\x1b[1;2B'|$'\x1b[b') moveCursorGroup 1 ;;
			' ')
				local -n kindArr="COL_KIND_${CURSOR_COL}" refArr="COL_REF_${CURSOR_COL}"
				case ${kindArr[CURSOR_ROW]} in
					group) toggleGroup "${refArr[CURSOR_ROW]}" ;;
					step)
						local si=${refArr[CURSOR_ROW]}
						if [[ ${CHECKED[si]} == 1 ]]; then CHECKED[si]=0; else CHECKED[si]=1; fi
						;;
				esac
				;;
			a|A) toggleAll ;;
			q|Q) break ;;
			''|$'\n'|$'\r')
				stty echo 2>/dev/null
				tput cnorm 2>/dev/null
				runSelected
				stty -echo 2>/dev/null
				tput civis 2>/dev/null
				;;
		esac
	done
	clear
}

# --------------------------------
# locations (gathered up front, unskippable - several steps rely on these)

# show a grey default inline after the prompt; the first real keystroke wipes
# it and starts fresh (readline's read -e can't do type-to-replace, so this
# is a small hand-rolled line editor: append-only plus backspace)
# the shared start of every string in the list, eg. for
# ("/media/Storage" "/media/Stuff") this is "/media/St"
longestCommonPrefix() {
	local -a arr=("$@")
	local prefix=${arr[0]} s
	for s in "${arr[@]:1}"; do
		while [[ ${s:0:${#prefix}} != "$prefix" ]]; do
			prefix=${prefix%?}
			[[ -z $prefix ]] && break
		done
	done
	printf '%s' "$prefix"
}

# redisplay $1 in dim, cursor back at its start - used by promptLocation
# whenever a delete empties its buffer back out, so the field reverts to
# showing the placeholder instead of just sitting blank
showPlaceholder() {
	local text=$1
	printf "${C_DIM}%s${C_RESET}" "$text"
	(( ${#text} > 0 )) && printf "\033[%dD" "${#text}"
}

promptLocation() {
	local label=$1 default=$2
	local -n result=$3
	printf "  ${C_PKG}%s${C_RESET} directory\n" "$label"
	printf "  ${C_PROMPT}❯${C_RESET} ${C_DIM}%s${C_RESET}" "$default"
	(( ${#default} > 0 )) && printf "\033[%dD" "${#default}"

	local buf="" key rest placeholderShown=1

	stty -echo 2>/dev/null
	while true; do
		IFS= read -rsn1 key
		if [[ $key == $'\x1b' ]]; then
			IFS= read -rsn2 -t 0.05 rest
			continue
		elif [[ $key == $'\x7f' || $key == $'\x08' ]]; then
			if (( ${#buf} > 0 )); then
				buf=${buf%?}
				printf '\b \b'
				(( ${#buf} == 0 )) && { showPlaceholder "$default"; placeholderShown=1; }
			fi
			continue
		elif [[ -z $key || $key == $'\n' || $key == $'\r' ]]; then
			break
		elif [[ $key == $'\x17' ]]; then
			# ctrl+w - delete back one path segment, the way it does in a
			# shell: drop any trailing slash, then back to the previous one
			if (( ${#buf} > 0 )); then
				local before=${#buf}
				while [[ $buf == */ ]]; do buf=${buf%/}; done
				while [[ -n $buf && $buf != */ ]]; do buf=${buf%?}; done
				printf "\033[%dD\033[K" "$(( before - ${#buf} ))"
				(( ${#buf} == 0 )) && { showPlaceholder "$default"; placeholderShown=1; }
			fi
			continue
		elif [[ $key == $'\x15' ]]; then
			# ctrl+u - clear the whole line
			if (( ${#buf} > 0 )); then
				printf "\033[%dD\033[K" "${#buf}"
				buf=""
				showPlaceholder "$default"
				placeholderShown=1
			fi
			continue
		elif [[ $key == $'\t' ]]; then
			# cd-style directory completion: single match completes in full
			# (with a trailing / to chain further completions), several
			# matches complete as far as their shared prefix goes, and if
			# that doesn't advance anything, list the candidates like a
			# double-tab would
			local base=$buf
			(( placeholderShown )) && base=$default
			local -a matches
			mapfile -t matches < <(compgen -d -- "$base" 2>/dev/null)
			if (( ${#matches[@]} == 0 )); then
				printf '\a'
			else
				local newText
				if (( ${#matches[@]} == 1 )); then
					newText="${matches[0]}/"
				else
					newText=$(longestCommonPrefix "${matches[@]}")
				fi
				if [[ ${#matches[@]} == 1 || ($newText != "$base" && -n $newText) ]]; then
					if (( placeholderShown )); then
						printf '\033[K'
					else
						printf "\033[%dD\033[K" "${#base}"
					fi
					printf '%s' "$newText"
					buf=$newText
					placeholderShown=0
				else
					printf '\n'
					local m
					for m in "${matches[@]}"; do
						printf '    %s\n' "${m##*/}"
					done
					printf "  ${C_PROMPT}❯${C_RESET} %s" "$base"
					buf=$base
					placeholderShown=0
				fi
			fi
			continue
		fi
		if (( placeholderShown )); then
			printf '\033[K'
			placeholderShown=0
		fi
		buf+="$key"
		printf '%s' "$key"
	done
	stty echo 2>/dev/null
	printf '\n'
	result=${buf:-$default}
	# tab-completing a directory leaves a trailing / (so further tabs can
	# chain into it) - strip it here so downstream "$STORAGE_DIR/User"-style
	# concatenation doesn't end up with a double slash
	[[ $result == */ && $result != / ]] && result=${result%/}
}

promptLocations() {
	clear
	boxHeader "Locations"
	printf "\n"
	promptLocation "STORAGE" "/media/Storage" STORAGE_DIR
	printf "\n"
	promptLocation "USER" "$STORAGE_DIR/User" USER_DIR
	printf "\n"
	promptLocation "DOWNLOAD" "$USER_DIR/Downloads" DOWNLOAD_DIR
	printf "\n"
	promptLocation "PROGRAMS" "$USER_DIR/Programs" PROGRAMS_DIR
}

promptLocations

# child scripts (symlinks.sh etc.) read these from the environment
export STORAGE_DIR USER_DIR DOWNLOAD_DIR PROGRAMS_DIR

cd "$DOWNLOAD_DIR" || exit

runMenu

# easystroke
# read -r -e -p "Install easystroke? ([Y]es - patched / [n]o / from [a]UR): " i && choice=${i:-Y}
# case ${choice,,} in
# 	y) wget http://openartisthq.org/easystroke/patched-easystroke-master.tar.bz2
# 	   tar xvjf patched-easystroke-master.tar.bz2
# 	   cd patched-easystroke-master/easystroke || exit
# 	   make
# 	   cp ./easystroke $PROGRAMS_DIR
# 	   cd $DOWNLOAD_DIR || exit
# 	   ;;
# 	a) installer easystroke ;;
# 	*) ;;
# esac

# sublime
# read -r -e -p "Install sublime-text? ([Y]es / [n]o): " i && choice=${i:-Y}
# case ${choice,,} in
# 	y) curl -O https://download.sublimetext.com/sublimehq-pub.gpg && sudo pacman-key --add sublimehq-pub.gpg && sudo pacman-key --lsign-key 8A8F901A && rm sublimehq-pub.gpg
# 	   echo -e "\n[sublime-text]\nServer = https://download.sublimetext.com/arch/stable/x86_64" | sudo tee -a /etc/pacman.conf
# 	   # NOTE: not installer, as above specifically adds an entry to pacman
# 	   sudo pacman -Sy sublime-text
# 	   ;;
# 	*) ;;
# esac

# unifi
# read -r -e -p "Install unifi? ([Y]es - 5.14.23-1 / [n]o / from [a]UR): " i && choice=${i:-Y}
# case ${choice,,} in
# 	y) installer mongodb-bin jre8-openjdk-headless fontconfig
# 	   mkdir tmp-unifi
# 	   cd tmp-unifi || exit
# 	   wget https://aur.archlinux.org/cgit/aur.git/snapshot/aur-5844bbc6593b9a6a456e9bc42240288ac6301611.tar.gz
# 	   tar xvf aur-5844bbc6593b9a6a456e9bc42240288ac6301611.tar.gz
# 	   cd aur-5844bbc6593b9a6a456e9bc42240288ac6301611 || exit
# 	   makepkg
# 	   local-installer unifi-5.14.23-1-x86_64.pkg.tar.zst
# 	   systemctl enable --now unifi
# 	   cd $DOWNLOAD_DIR || exit
#        rm -r tmp-unifi
#        sudo sed -rie 's/#IgnorePkg/IgnorePkg/' /etc/pacman.conf
#        sudo sed -rie '/^IgnorePkg.*/s/$/ unifi/' /etc/pacman.conf
# 	   ;;
# 	a) installer unifi ;;
# 	*) ;;
# esac

