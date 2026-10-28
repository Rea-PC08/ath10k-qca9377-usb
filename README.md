# ath10k USB fix for QCA9377 (Linksys WUSB6100M, USB ID 13b1:0042)

The Linux `ath10k_usb` driver lists the Linksys WUSB6100M but has never worked with it:
the kernel prints *"ath10k USB support is incomplete, don't expect anything to work!"*,
then fails with *"Unsupported hardware version: 0x5020001"*. This repository contains a
patched `ath10k` (based on Linux **6.12.107**) that makes this adapter usable, packaged
with DKMS.

## Result (tested)

Debian 13 (kernel `6.12.107+deb13-amd64`), Dell OptiPlex 3060 Micro, Linksys WUSB6100M:

| Test | Result |
|---|---|
| Detection, WPA2/WPA3 connection, DHCP | OK (2.4 GHz and 5 GHz) |
| 42 MB download from the LAN | 1.1 MB/s (~9 Mbit/s), no stall |
| 7 files, 237 MB in a row + 3 min ping | all complete, 0 % packet loss |
| PC reboot with the adapter plugged in | Wi-Fi comes back and reconnects by itself |
| Reboot with the Ethernet cable unplugged | connects over Wi-Fi only, Xibo player keeps working |

Before the fix: no network interface at all; with only the hardware entry added, the link
froze after about 2 MB.

## What the patch changes

1. **USB hardware entry for QCA9377 hw1.1** (`core.c`). Mainline has PCI and SDIO
   entries only, hence "Unsupported hardware version". Firmware directory: `QCA9377/hw1.1`.
2. **start_once** (`core.c`, `core.h`, `hw.h`, `mac.c`): the USB firmware must keep running
   after the BMI init phase (from Erik Stromdahl's original USB work and the 8devices tree).
3. **Local TX completion** (`usb.c`): this firmware never sends
   `HTT_T2H_MSG_TYPE_TX_COMPL_IND`, so the pending-TX counter filled up and transmission
   stopped after ~26 frames. TX is now completed when the USB transfer completes.
4. **No HTC credit flow on the HTT data endpoint for USB** (`htt.c`): enabling local
   completion also switched on credit flow for that endpoint, which starts at zero credits;
   the firmware returns them only every few seconds, limiting TX to ~1 frame / 3 s.

The full diff against Linux 6.12.107 is in [`patches/`](patches/).

## Install

```sh
git clone https://github.com/Rea-PC08/ath10k-qca9377-usb.git
cd ath10k-qca9377-usb
sudo ./install.sh        # ce (Europe) board data by default; also: fcc, ic, as
```

Then unplug and replug the adapter (or reboot). `install.sh` installs `dkms`,
`build-essential` and the kernel headers, builds the modules through DKMS (rebuilt on
kernel updates) and installs the firmware.

**Firmware**: the firmware and board data are Qualcomm files and are **not** stored in
this repository. `install.sh` downloads them from
[erstrom/ath10k-firmware](https://github.com/erstrom/ath10k-firmware/tree/usb/QCA9377/hw1.0)
(branch `usb`) and checks their SHA-256. Offline: `sudo FW_SRC=/dir/with/files ./install.sh`.

Uninstall: `sudo ./uninstall.sh`.

## Known limits

- Built and tested against **Linux 6.12** only. Other kernel versions may need the patch
  applied to their own `ath10k` source.
- Unloading the driver (`rmmod`) leaves the adapter's firmware running: the adapter must be
  unplugged and replugged before the driver can load again. A PC reboot is fine.
- Changing Wi-Fi power saving while the link is busy (`iw dev ... set power_save ...`) crashed
  the firmware once. Setting it at connection time works: all tests above ran with
  NetworkManager `wifi.powersave=2` (power saving off).
- Latency rises under heavy load (around 250 ms on average during downloads).
- The kernel still prints the "USB support is incomplete" warning; it is harmless here.

## Credits

- Erik Stromdahl: original ath10k USB support and the converted WUSB6100M firmware.
- 8devices ([QCA9377-ath10k-Beans](https://github.com/8devices/QCA9377-ath10k-Beans)):
  QCA9377 USB hardware entry and start_once.
- The Linux ath10k developers.

## License

ISC, like the ath10k driver it is based on (see [LICENSE](LICENSE)). Firmware files are
under their own Qualcomm terms and are not part of this repository.

---

### En bref (français)

Pilote ath10k corrigé pour la clé Wi-Fi USB Linksys WUSB6100M (QCA9377) sous Linux 6.12
(Debian 13). Installation : `sudo ./install.sh`, puis débrancher et rebrancher la clé.
Testé : 1,1 Mo/s, stable sur 237 Mo, reconnexion automatique au redémarrage.
