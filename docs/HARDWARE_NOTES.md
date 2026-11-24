# Hardware Implementation Notes: Nothing Phone (2a) (`galaxian`)

## 1. SoC & Kernel Architecture
- **SoC:** MediaTek Dimensity 7200 / MT6878 (2x Cortex-A715 @ 2.8 GHz, 6x Cortex-A510 @ 2.0 GHz).
- **GPU:** ARM Mali-G615 MC2 (Valhall architecture).
- **Kernel:** Linux 6.1 (Android 14 GKI) with out-of-tree backported Panthor DRM driver.

## 2. Standalone Boot Sequence (`init_boot.img`)
1. Android Bootloader (LK) verifies and loads `init_boot.img` (Header v4, AVB 1.0 signed footer).
2. Ramdisk `/init` sets up virtual filesystems (`/dev`, `/proc`, `/sys`, `/dev/pts`, `/dev/shm`).
3. Discovers and mounts the postmarketOS rootfs block device to `/sysroot`.
4. Deploys `/etc/galaxian` helper scripts and Polkit rules into `/sysroot` if needed.
5. Loads MediaTek core platform modules, DRM display drivers, and FocalTech touch drivers.
6. Launches `/sysroot/usr/bin/start_phosh_direct.sh` to initialize Panthor GPU and run Phosh.

## 3. Wi-Fi & Connectivity Bringup
- MediaTek connectivity drivers require dynamic character device creation `/dev/wmtWifi`.
- Factory calibration data is extracted from the `nvdata` partition (`/dev/sdc7`) from path `APCFG/APRDEB/WIFI` into `/lib/firmware/WIFI_NVRAM`.
- Python injector `send_nvram.py` streams the calibration buffer with command `WR-BUF:NVRAM` and triggers chip power-on.
- Interface `wlan0` comes up and is managed by NetworkManager.
- PolicyKit rule `00-galaxian-user.rules` allows non-root user `user` to create and activate connections without prompt.
- `gnome-keyring-daemon` provides the `org.freedesktop.secrets` interface over the user session D-Bus bus for password storage.

## 4. Backlight & Hardware Keys
- Hardware panel backlight node is located at `/sys/devices/platform/display_id/brightnessid`.
- Kernel module `galaxian_backlight.ko` exposes a standard Linux sysfs backlight interface (`/sys/class/backlight/panel/brightness`).
- User-space daemon `galaxian_helper_daemon.py`:
  - Listens to power and volume keys via `/dev/input/event*`.
  - Implements an exponential human-eye perceptual brightness curve.
  - Toggles screen sleep / wake via Wayland DPMS and backlight power.
