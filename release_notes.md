# Technical Release Notes: postmarketOS Phosh with Panthor GPU on Nothing Phone (3a) Lite

## 1. Hardware & Platform Details
- **Device:** Nothing Phone (3a) Lite
- **Codename:** `galaxian` / `nothing-galaxian`
- **SoC:** MediaTek MT6878 / Dimensity 7200 / 7300 (4x Cortex-A78 @ 2.5 GHz, 4x Cortex-A55 @ 2.0 GHz)
- **GPU:** ARM Mali-G615 MC2 (Valhall architecture, CSF v12)
- **Kernel:** Android Generic Kernel Image (GKI) Linux 6.1.134+ / 6.1.162
- **Display:** 6.7" Flexible AMOLED, DRM connector `DSI-1` (`/dev/dri/card0`), 1080x2392 @ 120 Hz
- **Touchscreen:** FocalTech `fts_ts` (`/dev/input/event3`, character node `c13:67`)
- **Root Environment:** KernelSU / APatch / Magisk on stock Nothing OS Android 14/15

---

## 2. Major Engineering Breakthroughs

### A. Full 3D Hardware Acceleration via Panthor & Mesa Panfrost
- Previous state: Software rasterization via `pixman` (heavy CPU load, laggy UI at 60Hz).
- **Current state:** Native open-source `panthor.ko` kernel driver bound to platform device `13000000.mali`.
- **Mesa:** Panfrost GLES2 acceleration on Wayland (`/dev/dri/renderD128` + `/dev/dri/card0`).
- **Display:** Set to native `1080x2392@120Hz` with `bilinear` texture scaling filter in `phoc.ini`.

### B. Dynamic Zero-Reboot GPU Driver Handover
- Android operates on MediaTek's proprietary `mali_kbase_mt6878_r44` driver.
- Linux postmarketOS operates on upstream `panthor` driver.
- The handover pipeline:
  1. Temporarily disable MediaTek GED DVFS (`echo 0 > /sys/module/ged/parameters/gpu_dvfs_enable`) to prevent scheduler race conditions (`ged_eb_work_cb`).
  2. Gracefully stop Android UI (`stop vendor.hwcomposer-3-2`, `stop`).
  3. Poll `lsof /dev/mali*` until 0 open descriptors remain to prevent memory unbind page faults.
  4. Dynamically point kernel firmware path (`/sys/module/firmware_class/parameters/path`) to `/data/local/tmp/panthor` containing compatible CSF microcode (274 KB).
  5. Unbind `13000000.mali` from Mali and bind to `panthor`.
  6. On return to Android: cleanly terminate all chroot and DRM handles, restore `/vendor/firmware` path, rebind Mali, restore SELinux permissions, and re-enable GED DVFS.

### C. Display Power & Wakeup Management
- MediaTek DDIC panel brightness is maintained via `/sys/devices/platform/display_id/brightnessid`.
- During Android restoration, Android framework starts in Doze/Keyguard sleep state.
- Automated restoration executes hardware wakeup:
  - Sets `brightnessid` to 2000.
  - Sends `input keyevent KEYCODE_WAKEUP`.
  - Calls `wm dismiss-keyguard` and menu event 82.

### D. PTY / Terminal Permissions Fix
- Fixed `devpts` mounting in chroot resetting `/dev/pts/ptmx` permissions to `0000`, which previously caused Termux to crash with `java.lang.RuntimeException: Cannot open /dev/ptmx (SIGABRT)`.
- Restoring `chmod 666 /dev/pts/ptmx /dev/ptmx` is now integrated directly into the switch scripts.

---

## 3. Changelog

### v2.0 (Panthor 120Hz Release)
- [x] Switched from CPU `pixman` to hardware `panthor` GLES2 acceleration.
- [x] Bumped display mode from 60Hz to 120Hz (`mode = 1080x2392@120Hz`, `scale-filter = bilinear`).
- [x] Added automated firmware path switching between `/vendor/firmware` and `/data/local/tmp/panthor`.
- [x] Added `lsof /dev/mali*` and `lsof /dev/dri/render*` polling to prevent kernel panics during GPU unbind.
- [x] Added GED DVFS governor deactivation during handover.
- [x] Added display wakeup and keyguard dismissal on Android restoration.
- [x] Added one-click launcher scripts: `linux` (Termux/ADB) and `android` (Phosh/Termux/ADB).
- [x] Fixed Termux PTY crash by enforcing `0666` permissions on `/dev/pts/ptmx`.
