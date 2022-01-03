#!/bin/sh

echo "Not a real script, go through the steps manually"
exit

# Artix install Andreas Brodbeck
# See: https://gilyes.com/Installing-Arch-Linux-with-LVM/
# See: https://www.youtube.com/watch?v=nCc_4fSYzRA
# See: https://computingforgeeks.com/install-arch-linux-with-lvm-on-uefi-system/

# login into a live boot artix with root and password artix

loadkeys de_CH-latin1

# find the device to install. E.g. sda
lsblk

# Eine 512MB boot partition & 1 grosse physische Rest-Partition erstellen mit fdisk:
#
# p for print the list
#
# Optional to delete existing: d
# n (to add a new partition)
# p (for primary partition)
# 1 (default partition number)
# (accept default start)
# boot: +512M rest: (accept default end)

# do again for rest, then:
# t (to change partition type)
# 8e (for LVM partition when using MBR)
# i (to verify)
# w (save and quit)
fdisk /dev/sdX

# 

# LVM aufsetzen in der zweiten Partition. LVs erstellen für root und home
pvcreate /dev/sdX2
vgcreate lvm-vg1 /dev/sdX2

# DONT. boot is native partition. lvcreate -L 1G lvm-vg1 -n lv-boot

# Create root partition, for the linux system 
lvcreate -L 30G lvm-vg1 -n lv-root

# Keine swap partition? Wir verwenden ein swap file statt partition

# Create the remaining drive. Use 50% of the free space, keep some space for snapshots
lvcreate -l 50%FREE lvm-vg1 -n lv-home



# UEFI fat32 statt ext4 auf boot wenn UEFI:
mkfs.fat -F32 /dev/sda1
#Bei legacy BIOS: mkfs.ext4 /dev/...
mkfs.ext4 /dev/lvm-vg1/lv-root
mkfs.ext4 /dev/lvm-vg1/lv-home

# Echte Mountpoints vorbereiten auf dem noch live system:
mount /dev/lvm-vg1/lv-root /mnt
mkdir /mnt/boot
mkdir /mnt/home
#mount /dev/lvm-vg1/lv-boot /mnt/boot
mount /dev/sda1 /mnt/boot
mount /dev/lvm-vg1/lv-home /mnt/home


# Install base artix system
basestrap /mnt base base-devel runit elogind-runit linux linux-firmware efibootmgr vim lvm2 lvm2-runit networkmanager networkmanager-runit grub os-prober

# To get early access from SSH to the system
basestrap /mnt openssh openssh-runit

# fstab generation
fstabgen -U /mnt >> /mnt/etc/fstab

# chroot
artix-chroot /mnt /bin/bash

# Order the sources to geographic distance. Nearest first.
# Europe seems to be at the top, so not to bad
vim /etc/pacman.d/mirrorlist

# Set timezone
ln -sf /usr/share/zoneinfo/Europe/Zurich /etc/localtime
hwclock --systohc
vim /etc/locale.gen
# ... and uncomment the used ones

locale-gen
vim /etc/locale.conf
# Inhalt:
# export LANG="en_US.UTF-8"
# export LC_COLLATE="C"

echo "KEYMAP=de_CH-latin1" > /etc/vconsole.conf

# Prepare to autostart networkmanager with runit
ln -s /etc/runit/sv/NetworkManager/ /etc/runit/runsvdir/current

# Hostnamen
vim /etc/hostname

vim /etc/hosts
# 127.0.0.1 localhost
# ::1 localhost
# 127.0.0.1 hostnameXY.localdomain hostnameXY

vim /etc/mkinitcpio.conf
# Dort drin lvm2 ergänzen:
# HOOKS=".... lvm2 filesystems..."

mkinitcpio -p linux


#pacman -S grub 
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

grub-mkconfig -o /boot/grub/grub.cfg

# root password
passwd



useradd -m -g wheel dassi
#mkdir -p /home/dassi
#chown dassi:wheel /home/dassi


passwd dassi
# echo "dassi:asdfafawef" | chpasswd



# exit chroot environment
exit                           
umount -R /mnt
reboot


