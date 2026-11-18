# Technical Notes: postmarketOS Phosh on Nothing Phone (3a) Lite (Galaxian)

## 1. Hardware Specifications
- **Device:** Nothing Phone (3a) Lite
- **Codename:** `galaxian` / `nothing-galaxian`
- **SoC:** MediaTek MT6878 / Dimensity 7300 (4x Cortex-A78 @ 2.5GHz, 4x Cortex-A55 @ 2.0GHz, Mali-G615 MC2)
- **Kernel:** Android GKI Linux 6.1.134+ / 6.1.162
- **Display:** 6.7" Flexible AMOLED, DRM connector `DSI-1` (`/dev/dri/card0`), 1080x2392 @ 60/120Hz
- **Touchscreen:** FocalTech `fts_ts` on `/dev/input/event3` (major 13, minor 67)
- **Root/Environment:** KernelSU root on stock Nothing OS Android 14/15

---

## 2. Key Engineering Breakthroughs

### A. DRM_MASTER Arbitration on MediaTek Android 14+
Stopping `surfaceflinger` alone does NOT release DRM master on MediaTek MT6878 platforms. The vendor hardware composer daemon retains control:
- Process: `android.hardware.graphics.composer@3.2-service` (Service name: `vendor.hwcomposer-3-2`).
- To safely release DRM master without crashing Android:
  ```sh
  stop vendor.hwcomposer-3-2
  stop surfaceflinger
  pkill -STOP -f "composer@3.2"
  ```
- To restore Android instantly:
  ```sh
  pkill -CONT -f "composer@3.2"
  start vendor.hwcomposer-3-2
  start surfaceflinger
  ```

### B. AMOLED Hardware Backlight on MediaTek MTK-DSI
MediaTek panels do not use standard `/sys/class/backlight` brightness control in raw DRM mode. The hardware controller is exposed via:
- Path: `/sys/devices/platform/display_id/brightnessid`
- Range: `0` (off) to `4095` (peak brightness).
- Recommended comfort value: `2600`.
- To prevent panel timeout sleep: keep alive via a background interval loop.

### C. Touchscreen Integration without udevd
Android lacks standard `udevd`. Wayland compositor `phoc` (via `libinput`) discovers input devices by scanning the character device database in `/run/udev/data/`.
By placing device properties in `/run/udev/data/c13:67`:
```ini
E:ID_INPUT=1
E:ID_INPUT_TOUCHSCREEN=1
E:ID_SEAT=seat0
E:WL_OUTPUT=DSI-1
```
`libinput` immediately detects FocalTech `fts_ts` as an active multi-touch screen.

### D. Power Button Kernel Suspend Isolation
In Android GKI kernels, `KEY_POWER` triggers deep sleep / autosuspend when Android PowerManager is stopped. Because the screen backlight controller does not wake up automatically without Android services, pressing the power button resulted in a panel blackout.
Fix: Do not assign `c13:64`..`c13:68` to `seat0`. The power button is safely ignored by Wayland, preventing accidental system sleep.

### E. Software Rendering Optimization
Without proprietary Mali-G615 OpenCL/Vulkan drivers in pure Linux:
- `WLR_RENDERER=pixman` forces clean software compositing.
- Mode set to `1080x2392@60Hz` cuts CPU rendering throughput in half compared to 120Hz.
- `GSK_RENDERER=cairo` switches GTK4 away from heavy CPU 3D shader emulation to optimized direct 2D blits.
- Setting all 8 CPU governors to `performance` provides 3x smoother responsiveness.

### F. On-Screen Keyboard
`wvkbd-mobintl` operates via Wayland `zwlr_layer_shell_v1` and `zwp_virtual_keyboard_v1`. It has zero GNOME schema dependencies and provides instant, zero-latency touch typing.
