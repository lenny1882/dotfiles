#!/usr/bin/env bash

# interactively add a drive to /etc/fstab:
#   list drives -> pick a device -> partition/format if needed -> read its UUID
#   -> create a mount directory -> confirm mount options -> write to fstab
#
# usage: add_drive_fstab.sh [-n|--dry-run]
#   -n  show every step but don't partition, format, mkdir or touch fstab

FSTAB=/etc/fstab
dry_run=false
for arg in "$@"; do
	case $arg in
		-n|--dry-run) dry_run=true ;;
		*) echo "unknown option: $arg" >&2; exit 1 ;;
	esac
done

die() { echo "error: $*" >&2; exit 1; }

# ask "question" [default]; answer lands in $REPLY
ask() {
	local prompt=$1 default=$2
	if [[ -n $default ]]; then read -r -p "$prompt [$default]: " REPLY; REPLY=${REPLY:-$default}
	else read -r -p "$prompt: " REPLY; fi
}

confirm() {
	local answer
	read -r -p "$1 [y/N]: " answer
	[[ $answer == [yY]* ]]
}

# run a command (via sudo unless root); only print it under --dry-run
run() {
	if $dry_run; then echo "  (dry-run) $*"; return 0; fi
	if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

for tool in lsblk blkid findmnt; do
	command -v "$tool" >/dev/null || die "$tool not found"
done

# 1. list drives
echo "== drives =="
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,UUID,MOUNTPOINTS
echo

# 2. pick the device
ask "device to add (eg /dev/sda1, or a whole disk like /dev/sdb)"
dev=$REPLY
[[ -b $dev ]] || die "$dev is not a block device"
[[ -z $(lsblk -nro MOUNTPOINTS "$dev" | tr -d '[:space:]') ]] || die "$dev (or a partition on it) is mounted; unmount it first"

# 3. partition if it's a bare disk
if [[ $(lsblk -ndo TYPE "$dev") == disk ]] && [[ -z $(lsblk -nro NAME "$dev" | tail -n +2) ]]; then
	if [[ -z $(blkid -o value -s TYPE "$dev" 2>/dev/null) ]]; then
		echo "$dev is an empty disk with no partitions."
		# MBR (fdisk) can't address past 2TiB, so bigger disks get GPT via parted
		size=$(lsblk -bndo SIZE "$dev")
		if (( size < 2199023255552 )); then tool=fdisk; else tool=parted; fi
		if confirm "create a single full-size partition on $dev with $tool? (ERASES $dev)"; then
			command -v "$tool" >/dev/null || die "$tool not found"
			if [[ $tool == fdisk ]]; then
				# o = new DOS table, n/p/1 = primary partition 1, blank lines = default start/end, w = write
				printf 'o\nn\np\n1\n\n\nw\n' | run fdisk "$dev"
			else
				run parted -s "$dev" mklabel gpt mkpart primary 0% 100%
			fi
			if ! $dry_run; then
				run partprobe "$dev"; udevadm settle
				dev=$(lsblk -nrpo NAME "$dev" | sed -n 2p)
				[[ -b $dev ]] || die "couldn't find the new partition"
				echo "new partition: $dev"
			else
				dev=${dev}1
			fi
		else
			die "cannot use a disk with no partitions or filesystem"
		fi
	fi
fi

# 4. format if there's no filesystem
fstype=$(blkid -o value -s TYPE "$dev" 2>/dev/null)
if [[ -z $fstype ]]; then
	echo "$dev has no filesystem."
	ask "filesystem to create (ext4, xfs, btrfs, ...)" ext4
	fstype=$REPLY
	command -v "mkfs.$fstype" >/dev/null || die "mkfs.$fstype not found"
	ask "label (optional)"
	label=$REPLY
	echo "about to format $dev as $fstype -- ALL DATA ON IT WILL BE LOST"
	ask "type the device name again to confirm"
	[[ $REPLY == "$dev" ]] || die "confirmation didn't match, nothing changed"
	if [[ -n $label ]]; then run "mkfs.$fstype" -L "$label" "$dev"; else run "mkfs.$fstype" "$dev"; fi
	$dry_run || { udevadm settle; fstype=$(blkid -o value -s TYPE "$dev"); }
fi
echo "filesystem: $fstype"

# 5. pull out the UUID
if $dry_run && [[ -z $(blkid -o value -s UUID "$dev" 2>/dev/null) ]]; then
	uuid=DRY-RUN-UUID
else
	uuid=$(blkid -o value -s UUID "$dev")
	[[ -n $uuid ]] || die "no UUID found for $dev"
fi
echo "UUID: $uuid"
if grep -qs "UUID=$uuid" "$FSTAB"; then
	die "$FSTAB already has an entry for UUID=$uuid"
fi

# 6. mount directory
label=$(blkid -o value -s LABEL "$dev" 2>/dev/null)
ask "mount point" "/mnt/${label:-${dev##*/}}"
mnt=$REPLY
[[ $mnt == /* ]] || die "mount point must be an absolute path"
if findmnt -rn "$mnt" >/dev/null; then die "$mnt already has something mounted"; fi
if grep -qs "^[^#]*[[:space:]]$mnt[[:space:]]" "$FSTAB"; then die "$FSTAB already uses $mnt"; fi
[[ -d $mnt ]] || run mkdir -p "$mnt"

# 7. mount options
#
# what the options mean:
#   defaults  rw, suid, dev, exec, auto, async (so suid/dev/exec are all ON)
#   nofail    boot carries on if the drive is missing
#   exec      allow running programs from the drive (already implied by
#             defaults; stated so the choice is visible in fstab)
#   noatime   don't write a last-read time on every read: fewer writes
#   nosuid    ignore the setuid bit. A setuid-root file on a drive would run
#             as root; with nosuid it runs as you. Matters for drives that
#             may hold files you didn't create
#   nodev     treat device-node files on the drive as plain files, so a
#             crafted drive can't carry a node pointing at /dev/sda
#   x-gvfs-show / x-gvfs-name=<name>
#             show the mount in the file manager sidebar under <name>
#             (spaces must be written as \040 in fstab)
#   noauto + x-systemd.automount
#             mount on first access instead of at boot
#
# which preset to pick:
#   1  a trusted internal/data drive, and the right choice for a drive that
#      holds installed programs. Don't add nosuid/nodev there: apps that ship
#      a setuid helper (eg Electron/Chrome chrome-sandbox), containers,
#      chroots and bundled rootfs trees need suid and dev, and only you write
#      to the drive so the protection buys little. Use ext4/xfs/btrfs (real
#      permissions and symlinks), mount at boot, and say yes to the chown so
#      programs can update themselves. The UUID survives wiping the boot
#      drive, so afterwards you only need to re-add the fstab line (keep a
#      copy in the dotfiles)
#   2  external/removable drives, where the files' origin is unknown.
#      Programs still run (no noexec), but setuid and device files do not.
#      Same as what udisks/"user" mounts apply by default
#   3  custom: choose boot/automount/manual and exec/noexec yourself
#
# nosuid,nodev only blocks privilege escalation through planted files. It
# doesn't stop code running as you (that would need noexec), costs no
# performance, and is reversible with
#   sudo mount -o remount,suid,dev <mountpoint>
echo
echo "options preset:"
echo "  1) defaults,nofail,exec,noatime                          (internal/data drive)"
echo "  2) nosuid,nodev,nofail,x-gvfs-show,x-gvfs-name=<name>    (shows in the file manager)"
echo "  3) custom (choose boot/automount/exec)"
ask "choice" 1
case $REPLY in
	1) opts=defaults,nofail,exec,noatime ;;
	2)
		ask "name to show in the file manager" "${label:-${mnt##*/}}"
		opts=nosuid,nodev,nofail,x-gvfs-show,x-gvfs-name=${REPLY// /\\040}
		;;
	*)
		echo
		echo "when should it mount?"
		echo "  b) at boot (default)"
		echo "  a) on first access (systemd automount; boot never waits on it)"
		echo "  m) manually only"
		ask "choice" b
		when=$REPLY
		if confirm "allow running programs from it (exec)?"; then access=exec; else access=noexec; fi

		case $when in
			a) opts=noauto,x-systemd.automount,x-systemd.device-timeout=10,nofail ;;
			m) opts=noauto ;;
			*) opts=defaults,nofail ;;
		esac
		opts=$opts,$access
		;;
esac
case $fstype in
	vfat|exfat|ntfs|ntfs3) opts=$opts,uid=$(id -u),gid=$(id -g),umask=022 ;;
esac
echo
echo "options: $opts"
echo "  nofail = boot continues if the drive is missing"
ask "mount options (enter to accept)" "$opts"
opts=$REPLY
case $fstype in ext[234]) pass=2 ;; *) pass=0 ;; esac
line="UUID=$uuid  $mnt  $fstype  $opts  0  $pass"

# 8. write to fstab
echo
echo "line to add to $FSTAB:"
echo "  $line"
confirm "write it?" || die "aborted, $FSTAB untouched"
if $dry_run; then
	echo "(dry-run) would back up $FSTAB and append the line"
	exit 0
fi
backup="$FSTAB.bak.$(date +%Y%m%d%H%M%S)"
run cp "$FSTAB" "$backup"
echo "$line" | run tee -a "$FSTAB" >/dev/null
command -v systemctl >/dev/null && run systemctl daemon-reload

# prove it works; restore the backup if the mount fails
if run mount "$mnt"; then
	echo "mounted $mnt OK (backup of old fstab: $backup)"
	findmnt "$mnt"
	# ext4/xfs/btrfs mount root-owned; hand the top directory to the user
	case $fstype in ext[234]|xfs|btrfs)
		owner=${SUDO_USER:-$(id -un)}
		if confirm "chown $mnt to $owner so you can write to it?"; then run chown "$owner": "$mnt"; fi ;;
	esac
else
	run cp "$backup" "$FSTAB"
	die "mount failed; $FSTAB restored from $backup"
fi
