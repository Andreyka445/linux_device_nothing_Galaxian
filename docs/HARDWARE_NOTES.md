# Hardware Implementation Notes: Nothing Phone (3a) Lite (`galaxian`)

## 1. SoC & Kernel Architecture
- **Device:** Nothing Phone (3a) Lite (codename: `galaxian`).
- **SoC:** MediaTek Dimensity 7300 Pro 5G / MT6878 (2x Cortex-A715 @ 2.8 GHz, 6x Cortex-A510 @ 2.0 GHz).
- **GPU:** ARM Mali-G615 MC2 (Valhall architecture).
- **Kernel:** Linux 6.1 (Android 14 GKI) with out-of-tree backported Panthor DRM driver.

## 2. Rootfs Storage & Dynamic Partition Mapping (`super`)
- Android uses dynamic partitions inside `/dev/block/by-name/super`.
- postmarketOS rootfs is mapped as a `dm-linear` target named `pmos_root` located inside `super`:
  - **Start Sector:** `13914592` (byte offset: `7124271104`).
  - **Size:** `4800000` sectors (~2.46 GB).
- Mapping command in `/init`:
  ```sh
  dmsetup create pmos_root --table "0 4800000 linear $SUPER_DEV 13914592"
  ```
- If `dmsetup` mapping is unavailable, a loop device fallback is configured via `losetup -o 7124271104 /dev/loop0 "$SUPER_DEV"`.

## 3. Standalone Boot Sequence (`init_boot.img`)
1. Android Bootloader (LK) verifies and loads `init_boot.img` (Header v4, AVB 1.0 signed footer).
2. Ramdisk `/init` sets up virtual filesystems (`/dev`, `/proc`, `/sys`, `/dev/pts`, `/dev/shm`).
3. Discovers `super` partition, creates `pmos_root` device-mapper linear target, and mounts it to `/sysroot`.
4. Deploys `/etc/galaxian` helper scripts and Polkit rules into `/sysroot` if needed.
5. Loads MediaTek core platform modules, DRM display drivers, and FocalTech touch drivers.
6. Launches `/sysroot/usr/bin/start_phosh_direct.sh` to initialize Panthor GPU and run Phosh.

## 4. Wi-Fi & Connectivity Bringup
- MediaTek connectivity drivers require dynamic character device creation `/dev/wmtWifi`.
- Factory calibration data is extracted from the `nvdata` partition (`/dev/sdc7`) from path `APCFG/APRDEB/WIFI` into `/lib/firmware/WIFI_NVRAM`.
- Python injector `send_nvram.py` streams the calibration buffer with command `WR-BUF:NVRAM` and triggers chip power-on.
- Interface `wlan0` comes up and is managed by NetworkManager.
- PolicyKit rule `00-galaxian-user.rules` allows non-root user `user` to create and activate connections without prompt.
- `gnome-keyring-daemon` provides the `org.freedesktop.secrets` interface over the user session D-Bus bus for password storage.

## 5. Backlight & Hardware Keys
- Hardware panel backlight node is located at `/sys/devices/platform/display_id/brightnessid`.
- Kernel module `galaxian_backlight.ko` exposes a standard Linux sysfs backlight interface (`/sys/class/backlight/panel/brightness`).
- User-space daemon `galaxian_helper_daemon.py`:
  - Listens to power and volume keys via `/dev/input/event*`.
  - Implements an exponential human-eye perceptual brightness curve.
  - Toggles screen sleep / wake via Wayland DPMS and backlight power.
