#!/usr/bin/env bash
shopt -s expand_aliases

# --------------------------------
# general setup

# create alias for aur installer
if hash yay 2>/dev/null; then
	alias builder="yay -S --needed"
	alias installer="yay -S --needed"
	alias local-installer="yay -U --needed"
elif hash pamac 2>/dev/null; then
	alias builder="pamac build"
	alias installer="pamac install"
	alias local-installer="pamac install"
fi

# helper functions
printr() { for index in "$@"; do printf "\n\t%s" "$index"; done; printf "\nChoices: "; }
readAndInstall() { read -r line; list=("${line}"); installer ${list[*]} ; }

# variables
read -r -e -p "Location of STORAGE directory [/media/Storage]: " i && STORAGE_DIR=${i:-/media/Storage}
read -r -e -p "Location of USER directory [$STORAGE_DIR/User]: " i && USER_DIR=${i:-$STORAGE_DIR/User}
#read -r -e -p "Location of DEVELOPMENT directory [/media/Storage/Development]: " i && DEVELOPMENT_DIR=${i:-/media/Storage/Development}
read -r -e -p "Location of DOWNLOAD directory [$USER_DIR/Downloads]: " i && DOWNLOAD_DIR=${i:-$USER_DIR/Downloads}
read -r -e -p "Location of PROGRAMS directory [$USER_DIR/Programs]: " i && PROGRAMS_DIR=${i:-$USER_DIR/Programs}

# symlink user directories
read -r -e -p "Symlink user directories? ([Y]es / [n]o): " i && choice=${i:-Y}
case ${choice,,} in
	y) ./symlinks.sh ;;
	*) ;;
esac

# load extra files into ~/.{shell}rc
case $SHELL in
	/bin/bash) ./shell_loader.sh bash ;;
	/bin/zsh)  ./shell_loader.sh zsh ;;
	#*)    echo "Cannot add to ~/.{shell}rc" ;;
esac

cd $DOWNLOAD_DIR || exit

# update pacman
sudo pacman -Syu


# --------------------------------
# system

# nvidia drivers
read -r -e -p "Install nvidia drivers? ([Y]es / [n]o): " i && choice=${i:-Y}
case ${choice,,} in
	y) installer nvidia-inst
	   nvidia-inst
	   yay -Rscu nvidia-inst
	   ;;
	*) ;;
esac

# display manager - ly
read -r -e -p "Install a display manager? ([Y]es / [n]o): " i && choice=${i:-Y}
case ${choice,,} in
	y) echo -n "Which display manager do you want to install:"
	   read -r -e -p \
	   "[1] ly
	    [2] lemurs" j && dm=${j}

	   case ${dm,,} in
	   		1) installer ly
	   		   systemctl enable ly.service
			   ;;
			2) installer lemurs
			   systemctl enable lemurs.service
			   ;;
	   *) ;;
	   esac
	   ;;

	*) ;;
esac

# firewall
read -r -e -p "Install firewall (ufw)? ([Y]es / [n]o): " i && choice=${i:-Y}
case ${choice,,} in
	y) installer ufw
	   systemctl enable --now ufw
	   sudo ufw enable
	   ;;
	*) ;;
esac

# fonts
read -r -e -p "Install additional fonts? ([Y]es / [n]o): " i && choice=${i:-Y}
case ${choice,,} in
	y) echo -n "Which fonts do you want to install:"
	   printr \
	   adobe-source-han-sans-otc-fonts \
	   adobe-source-han-serif-otc-fonts \
	   noto-fonts \
	   noto-fonts-cjk \
	   noto-fonts-tc \
	   ttf-dejavu-nerd \
	   ttf-ubraille \
	   ttf-tw
	   readAndInstall
	   # yay -Rdd ttf-harmonyos-sans
	   ;;
	*) ;;
esac

# printers - cups
read -r -e -p "Setup CUPS for printing? ([Y]es / [n]o): " i && choice=${i:-Y}
case ${choice,,} in
	y) installer cups
	   systemctl enable --now org.cups.cupsd.service
	   ;;
	*) ;;
esac

# sound
#read -r -e -p "Install additional sound packages? ([Y]es / [n]o): " i && choice=${i:-Y}
#case ${choice,,} in
#	y) installer manjaro-pipewire ;;
#	*) ;;
#esac

# ssd trim
read -r -e -p "Enable SSD trim? ([Y]es / [n]o): " i && choice=${i:-Y}
case ${choice,,} in
	y) systemctl enable fstrim.timer ;;
	*) ;;
esac

# terminal
read -r -e -p "Install terminal emulator? ([Y]es / [n]o): " i && choice=${i:-Y}
case ${choice,,} in
	y) echo -n "Which display manager do you want to install:"
	   read -r -e -p \
	   "[1] urxvt
	   [2] other - manual" j && dm=${j}

	   case ${dm,,} in
	   		1) installer rxvt-unicode-truecolor-wide-glyphs
			   ;;
			2) ;;
	   *) ;;
	   esac
	   ;;

	*) ;;
esac

# window manager - herbstluft
read -r -e -p "Install a window manager (herbstluftwm)? ([Y]es / [n]o): " i && choice=${i:-Y}
case ${choice,,} in
	y) installer herbstluftwm
	   installer polybar
	   mkdir -p ~/.config/herbstluftwm
	   cp /etc/xdg/herbstluftwm/autostart ~/.config/herbstluftwm/
	   ;;
	*) ;;
esac


# --------------------------------
# apps and packages

echo -n "Which packages do you want to install:"
printr \
	bambustudio-bin \
	bat \
	blender \
	bottom \
	dragon-drop \
	dropbox \
	easyeffects \
	easystroke \
	eruler-git \
	feh \
	freecad-weekly-appimage \
	fzf \
	gnome-disk-utility \
	gpick \
	gthumb \
	gvfs \
	inkscape \
	joplin-appimage \
	krita \
	micro \
	minecraft-launcher \
	mpv \
	ncdu \
	nnn-nerd \
	numlockx \
	orca-slicer-bin \
	pavucontrol \
	peek \
	physlock \
	picom \
	playerctl \
	rambox-pro-bin \
    rofi \
    rofi-calc \
    rofi-expressvpn-git \
    scrot \
    sublime-text-4 \
    tigervnc \
    tldr \
	unzip \
	visual-studio-code-bin \
	vivaldi \
	xarchiver
readAndInstall

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

# expressvpn
read -r -e -p "Install expressvpn? ([Y]es / [n]o): " i && choice=${i:-Y}
case ${choice,,} in
	y) installer expressvpn
	   systemctl enable --now expressvpn.service
	   expressvpn preferences set auto_connect true
	   expressvpn preferences set network_lock on
	   ;;
	*) ;;
esac

# spotify - pamac without sudo so gpg key is recognised (as not added to sudo keychain!)
read -r -e -p "Install spotify? ([Y]es / [n]o): " i && choice=${i:-Y}
case ${choice,,} in
	y) curl -sS https://download.spotify.com/debian/pubkey_0D811D58.gpg | gpg --import -
	   builder spotify
	   ;;
	*) ;;
esac

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

# teamviewer
read -r -e -p "Install teamviewer? ([Y]es / [n]o): " i && choice=${i:-Y}
case ${choice,,} in
	y) installer teamviewer
	   systemctl enable --now teamviewerd
	   ;;
	*) ;;
esac

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
