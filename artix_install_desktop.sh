#!/bin/sh

# ====================================================
#
# Ab hier ist es eigentlich config. Taken from LARBS:
#

set -e

dotfilesrepo="https://github.com/dassi/dotfiles.git"
username="dassi"

# Directory, where the git repositories for compiling will be stored
repodir="/home/$username/.local/src"

installPkg(){
		pacman --noconfirm --needed -S "$1"
}

# Installing from AUR
installPkgAur() {
		echo "$aurinstalled" | grep -q "^$1$" && return
		sudo -u $username yay -S --noconfirm --needed "$1"
}

installAurhelper() {
		# Should be run after repodir is created and var is set.
		sudo -u $username mkdir -p "$repodir/yay-bin"
		pushd "$repodir/yay-bin"
		
		sudo -u $username git clone --depth 1 "https://aur.archlinux.org/yay-bin.git" "$repodir/yay-bin" >/dev/null 2>&1 ||
				{ sudo -u $username git pull --force origin master;}
		
		sudo -u $username makepkg --noconfirm -si >/dev/null 2>&1
		popd
}


gitMakeInstall() {
		progname="$(basename "$1" .git)"
		dir="$repodir/$progname"
		if [ -d "$dir" ]; then
				pushd "$dir"
				sudo -u $username git pull --force origin master;
		else
				sudo -u $username git clone --depth 1 "$1" "$dir" >/dev/null 2>&1
				pushd "$dir"
		fi

		make
		make install

		popd
}


# "Installing the Python package \`$1\` ($n of $total). $1 $2"
installPip() {
		[ -x "$(command -v "pip")" ] || installPkg python-pip >/dev/null 2>&1
		yes | pip install "$1"
}



installationLoop() {
		# ([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) || curl -Ls "$progsfile" | sed '/^#/d' > /tmp/progs.csv
		# total=$(wc -l < /tmp/progs.csv)

		# Remove commented lines
		sed '/^#/d' ./artix_progs.csv > /tmp/progs.csv
		
		aurinstalled=$(pacman -Qqm)
		while IFS=, read -r tag program comment; do
				n=$((n+1))
				case "$tag" in
						"A") installPkgAur "$program" ;;
						"G") gitMakeInstall "$program"  ;;
						"P") installPip "$program"  ;;
						*) installPkg "$program"  ;;
				esac
		done < /tmp/progs.csv ;
}

newPerms() { # Set special sudoers settings for install (or after).
		sed -i "/#LARBS/d" /etc/sudoers
		echo "$* #LARBS" >> /etc/sudoers
}


# Install most basic tools for this script to work
pacman --noconfirm --needed -S curl ca-certificates base-devel git ntp zsh

# Initialize directory for source code from git repos
mkdir -p "$repodir"
chown -R $username:wheel "$(dirname "$repodir")"

# "Refreshing Arch Keyring..."
pacman --noconfirm --needed -S artix-keyring artix-archlinux-support
for repo in extra community multilib; do
		grep -q "^\[$repo\]" /etc/pacman.conf ||
				echo "[$repo]
Include = /etc/pacman.d/mirrorlist-arch" >> /etc/pacman.conf
done
pacman -Sy > /dev/null 2>&1
pacman-key --populate archlinux

# "Synchronizing system time to ensure successful and secure installation of software..."
ntpdate 0.europe.pool.ntp.org

# Allow user to run sudo without password. Since AUR programs must be installed
# in a fakeroot environment, this is required for all builds with AUR.
newPerms "%wheel ALL=(ALL) NOPASSWD: ALL"

# Make pacman and paru colorful and adds eye candy on the progress bar because why not.
grep -q "^Color" /etc/pacman.conf || sed -i "s/^#Color$/Color/" /etc/pacman.conf
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
sed -i "s/^#ParallelDownloads = 8$/ParallelDownloads = 5/" /etc/pacman.conf

# Use all cores for compilation.
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf

# Install the AUR helper tool
installAurhelper

# Install all the software from the CSV list file
installationLoop

# "Finally, installing libxft-bgra to enable color emoji in suckless software without crashes."
# TBD: Not sure if still needed from AUR, better from main?

# TBD AKTIVIERN. Zur Zeit git Problmeme mit https bei gitlab.freedekstop
#sudo -u $username yay --noconfirm --needed -S libxft-bgra-git

# Install the dotfiles in the user's home directory
dir=$(mktemp -d)
chown $username:wheel "$dir" /home/$username
sudo -u $username git clone --recursive -b master --depth 1 --recurse-submodules "$dotfilesrepo" "$dir"
sudo -u $username cp -rfT "$dir" /home/$username

# Delete unused files from dotfiles repo

# # make git ignore deleted LICENSE & README.md files
# pushd /home/$username
# rm -f "README.md" "LICENSE" "FUNDING.yml"
# git update-index --assume-unchanged "/home/$username/README.md" "/home/$username/LICENSE" "/home/$username/FUNDING.yml"
# popd

# # Create default RSS urls file if none exists.
# [ ! -f "/home/$username/.config/newsboat/urls" ] && echo "http://lukesmith.xyz/rss.xml
# https://notrelated.libsyn.com/rss
# https://www.youtube.com/feeds/videos.xml?channel_id=UC2eYFnH61tmytImy1mTYvhA \"~Luke Smith (YouTube)\"
# https://www.archlinux.org/feeds/news/" > "/home/$username/.config/newsboat/urls"


# Make zsh the default shell for the user.
chsh -s /bin/zsh $username
sudo -u $username mkdir -p "/home/$username/.cache/zsh/"

# dbus UUID must be generated for Artix runit.
dbus-uuidgen --ensure

# # Use system notifications for Brave on Artix
# echo "export \$(dbus-launch)" > /etc/profile.d/dbus.sh

# Tap to click
[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && echo 'Section "InputClass"
	Identifier "libinput touchpad catchall"
	MatchIsTouchpad "on"
	MatchDevicePath "/dev/input/event*"
	Driver "libinput"
	# Enable left mouse button by tapping
	Option "Tapping" "on"
EndSection' > /etc/X11/xorg.conf.d/40-libinput.conf

# # Fix fluidsynth/pulseaudio issue.
# grep -q "OTHER_OPTS='-a pulseaudio -m alsa_seq -r 48000'" /etc/conf.d/fluidsynth ||
# 		echo "OTHER_OPTS='-a pulseaudio -m alsa_seq -r 48000'" >> /etc/conf.d/fluidsynth

# # Start/restart PulseAudio.
# killall pulseaudio; sudo -u $username pulseaudio --start

# This line, overwriting the `newperms` command above will allow the user to run
# serveral important commands, `shutdown`, `reboot`, updating, etc. without a password.
newPerms "%wheel ALL=(ALL) ALL #LARBS
%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/packer -Syu,/usr/bin/packer -Syyu,/usr/bin/systemctl restart NetworkManager,/usr/bin/rc-service NetworkManager restart,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/paru,/usr/bin/pacman -Syyuw --noconfirm"


echo "reboot now please!"

