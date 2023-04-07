#!/bin/bash
# customize-image.sh script to customize for the Recore 3d printer mcu

# Variables
DEFAULT_ROOT_PASSWORD="kamikaze"
DEFAULT_USER_PASSWORD="temppwd"
RECORE_REVISION="a7"
PACKAGES_FOR_INSTALL=("unzip", "libavahi-compat-libdnssd1", "libnss-mdns", "byobu", "htop", "cpufrequtils", "pv")
PACKAGES_FOR_REMOVAL=("smartmontools")
SCRIPT_PATH="/usr/local/bin"

# Build variables
# RELEASE=$1
# LINUXFAMILY=$2
# BOARD=$3
# BUILD_DESKTOP=$4

source /etc/armbian-image-release

# main
Main() {
	linux_preparation
	# if [[ $KIAUH == yes ]]; then
	# 	install_kiauh
	# fi

}

linux_preparation() {
	recore_device_tree
	modify_relase
	fix_haveged
	apt_packages
	user_configuration
	install_recore_scripts
	filesystem
}

recore_device_tree() {
	dtb_path="/boot/dtb/allwinner"
	# We should download the files from somewhere to get them all
	# Glob device tree files
	dtb_files=(/tmp/overlay/dtb_files/*recore*.dtb) # grab the list
	echo "Found ${#dtb_files[@]} files"             # print array length

	# Copy device tree files
	for file in "${dtb_files[@]}"; do
		cp /tmp/overlay/dtb_files/"${file[@]##*/}" "$dtb_path/${file[@]##*/}"
	done
	# symlink revision
	ln -s -f "$dtb_path/sun50i-a64-recore.dtb" "$dtb_path/sun50i-a64-recore-$RECORE_REVISION.dtb"
}

modify_relase() {
	release_file="/etc/armbian-release"
	sed -i "s/Pine64/Recore/g" $release_file
	sed -i "s/pine64/recore/g" $release_file
}

fix_haveged() {
	# why?
	path="/etc/default/haveged"
	sed -i "s/\"-w 1024\"/\"-w 1024 -d 16\"/g" $path
}

apt_packages() {
	apt-get remove --purge --auto-remove --yes $PACKAGES_FOR_REMOVAL
	apt-get install --yes $PACKAGES_FOR_INSTALL
}

user_configuration() {
	# set root password
	chpasswd <<<"root:$DEFAULT_ROOT_PASSWORD"

	# debian user
	useradd -m -s /bin/bash debian
	usermod -aG sudo,tty,dialout debian
	chown -R debian:debian /home/debian
	chpasswd <<<"debian:$DEFAULT_USER_PASSWORD"
	# force password reset
	chage -d 0 debian
	# images
	mkdir /home/debian/images
	chmod 0755 /home/debian/images
	chown debian:debian /home/debian/images

}

install_recore_scripts() {
	recore_scripts_src_path="userpatches/extensions/overlay/recore_scripts"
	# We should download the files from somewhere to get them all
	# Glob scripts
	recore_script_files=("$recore_scripts_src_path"/*) # grab the list
	echo "Found ${#recore_script_files[@]} files"      # print array length
	# Copy device tree files
	for file in "${recore_script_files[@]}"; do
		cp "$recore_scripts_src_path/${file[@]##*/}" "$SCRIPT_PATH/${file[@]##*/}"
		chmod 0755 "$SCRIPT_PATH/${file[@]##*/}"
	done
}

system_settings() {
	# Disable root over ssh
	sed -i "s/^.*PermitRootLogin.*$/#PermitRootLogin/g" /etc/ssh/sshd_config

	# secureTTY
	grep -qxF 'ttyGS0' /etc/securetty || echo 'ttyGS0' >>/etc/securetty
	# modules.d
	grep -qxF 'g_serial' /etc/modules-load.d/modules.conf || echo 'g_serial' >>/etc/modules-load.d/modules.conf
	# console log
	grep -qxF 'extraargs=console=ttyGS0,115200 console=tty1' /boot/armbianEnv.txt || echo 'extraargs=console=ttyGS0,115200 console=tty1' >>/boot/armbianEnv.txt

	# Enable TTY service
	systemctl enable serial-getty@ttyGS0.service
	# Enable ssh
	systemctl enable ssh
}

filesystem() {
	# Create mount directories
	mkdir /mnt/emmc
	mkdir /mnt/usb

	# fstab
	grep -qxF "/dev/sda1 /mnt/usb ext4 ro,defaults,nofail" /etc/fstab || echo "/dev/sda1 /mnt/usb ext4 ro,defaults,nofail" >>/etc/fstab
	grep -qxF "/dev/mmcblk0p1 /mnt/emmc ext4 ro,defaults,nofail" /etc/fstab || echo "/dev/mmcblk0p1 /mnt/emmc ext4 ro,defaults,nofail" >>/etc/fstab

	# Make /boot read only
	sed -i "s/defaults,commit=600,errors=remount-ro 0 2/ro,defaults 0 0/g" /etc/fstab
}

Main "$@"
