#!/bin/sh
# Installs the patched ath10k driver (DKMS) and the QCA9377 USB firmware.
# Usage: sudo ./install.sh [REGION]     REGION = ce (default, Europe), fcc, ic, as
set -e

NAME=ath10k-qca9377-usb
VER=6.12.107-1
REGION=${1:-ce}
FWDIR=/lib/firmware/ath10k/QCA9377/hw1.1
FWURL=https://raw.githubusercontent.com/erstrom/ath10k-firmware/usb/QCA9377/hw1.0
HERE=$(cd "$(dirname "$0")" && pwd)

[ "$(id -u)" = 0 ] || { echo "Run as root: sudo $0"; exit 1; }

case "$REGION" in
  ce)  BOARD_SHA=5ab99856d4c948ce7bcea092bed85caa26548d5e69948db04619a0d67b4a0cc7 ;;
  fcc) BOARD_SHA=d814f42e5115d0eb16aa68d095c22075f241ac2908c18656ec142fb706241630 ;;
  ic)  BOARD_SHA=b143e03954b5456a81422b685761d1414b639d3f370062880a38732707392725 ;;
  as)  BOARD_SHA=25e2d788715b5e1396f2f3cabaf7b7bf147b9ffe4d8bff621b217f8623febfad ;;
  *) echo "Unknown region '$REGION' (use ce, fcc, ic or as)"; exit 1 ;;
esac
FW_SHA=a11870fe28bc49dde9194a65e8014cbb32ed572fc4009535466d4a4f2e2ed831

# Build tools and headers for the running kernel
if command -v apt-get >/dev/null 2>&1; then
  apt-get install -y dkms build-essential "linux-headers-$(uname -r)"
fi

# Firmware (Qualcomm, not redistributed here): fetched from Erik Stromdahl's
# ath10k-firmware repository and checked against known SHA-256 sums.
# Set FW_SRC=/path/to/dir to use local copies instead of downloading.
mkdir -p "$FWDIR"
fetch() { # $1 = source file name, $2 = destination
  if [ -n "$FW_SRC" ]; then cp "$FW_SRC/$1" "$2"; else curl -fsSL -o "$2" "$FWURL/$1"; fi
}
fetch firmware-usb-5-wusb6100m.bin "$FWDIR/firmware-usb-5.bin"
fetch "eeprom_qca9377_7_1p1_Robin_clpc_$REGION.bin" "$FWDIR/board.bin"
echo "$FW_SHA  $FWDIR/firmware-usb-5.bin" | sha256sum -c -
echo "$BOARD_SHA  $FWDIR/board.bin" | sha256sum -c -

# Driver through DKMS (rebuilt automatically on kernel updates)
dkms remove -m "$NAME" -v "$VER" --all >/dev/null 2>&1 || true
rm -rf "/usr/src/$NAME-$VER"
cp -r "$HERE/dkms" "/usr/src/$NAME-$VER"
dkms add -m "$NAME" -v "$VER"
dkms build -m "$NAME" -v "$VER"
dkms install -m "$NAME" -v "$VER"
depmod -a

echo
echo "Done. Unplug and replug the USB adapter (or reboot) to load the new driver."
