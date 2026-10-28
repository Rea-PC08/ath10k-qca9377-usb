#!/bin/sh
# Removes the patched driver and the firmware installed by install.sh.
set -e
NAME=ath10k-qca9377-usb
VER=6.12.107-1
[ "$(id -u)" = 0 ] || { echo "Run as root: sudo $0"; exit 1; }
dkms remove -m "$NAME" -v "$VER" --all || true
rm -rf "/usr/src/$NAME-$VER" /lib/firmware/ath10k/QCA9377/hw1.1
depmod -a
echo "Removed. Unplug and replug the USB adapter (or reboot)."
