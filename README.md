# 📱 Nothing Phone (2a) / Phone (3a) Lite: postmarketOS (Phosh Mobile GNOME)

[![postmarketOS](https://img.shields.io/badge/postmarketOS-v24.06%20%2F%20edge-009900?logo=postmarketos&logoColor=white)](https://postmarketos.org/)
[![Device](https://img.shields.io/badge/Device-Nothing%20Phone%20(2a)%20%2F%20Galaxian-black?logo=nothing&logoColor=white)](https://nothing.tech)
[![SoC](https://img.shields.io/badge/SoC-MediaTek%20Dimensity%207200%20%2F%20MT6878-blue)](https://www.mediatek.com/)
[![GPU](https://img.shields.io/badge/GPU%20Acceleration-Panthor%20GLES2%20(Mali--G615)-orange)](https://docs.kernel.org/gpu/panthor.html)
[![Display](https://img.shields.io/badge/AMOLED-1084x2412%20%40%20120Hz-purple)](https://nothing.tech)
[![License](https://img.shields.io/badge/License-GPL--3.0-brightgreen)](LICENSE)

> **Standalone native postmarketOS Linux port running on the Nothing Phone (2a) (`galaxian` / MediaTek Dimensity 7200 / MT6878) with full Wayland GUI, open-source Panthor GPU acceleration, 120 Hz AMOLED display, multi-touch, on-screen keyboard, working Wi-Fi (2.4/5GHz), and physical button control.**

---

## 🌟 Highlights

* 🚀 **Full Hardware 3D Acceleration:** Open-source **Panthor DRM driver** (`/dev/dri/renderD128`) + **Mesa Panfrost GLES2** on ARM Mali-G615 MC2!
* ⚡ **Super Smooth 120 Hz AMOLED:** Native DRM/KMS output (`card0-DSI-1`) rendered at full 1084x2412 @ 120 FPS.
* 📶 **Working Wi-Fi (2.4 & 5 GHz):** Full integration with MediaTek Gen4m connectivity driver, dynamic `/dev/wmtWifi`, NVRAM factory calibration streaming, NetworkManager, and WPA-PSK authentication dialog.
* 🔒 **PolicyKit & Secret Service Integration:** Seamless network connection from Phosh UI with `gnome-keyring-daemon` secret storage.
* 👆 **Flawless Multi-Touch:** FocalTech capacitive touchscreen (`fts_ts`) integrated with `libinput` via seat assignment.
* ⌨️ **On-Screen Keyboard:** Native Stevia virtual keyboard (`phosh-osk-stevia`) popping up automatically on text input focus.
* 💡 **Exponential Backlight & Sleep/Wake:** Custom kernel backlight driver (`galaxian_backlight.ko`) and daemon (`galaxian_helper_daemon.py`) for human-eye perceptual brightness and physical power/volume buttons.
* 📦 **Standalone Boot:** Boots directly from an Android Header v4 signed `init_boot.img` with AVB 1.0 footer without Android or chroot.

---

## 📊 Hardware Status

| Subsystem | Status | Driver / Backend | Details |
| :--- | :---: | :--- | :--- |
| **Boot Mode** | 🟢 **Working** | Android Header v4 `init_boot.img` | Standalone direct boot, AVB 1.0 signed footer |
| **GPU Acceleration** | 🟢 **Working** | Panthor (`panthor.ko`) + Panfrost GLES2 | Mali-G615 MC2 hardware accelerated Wayland & apps |
| **Display (AMOLED)** | 🟢 **Working** | MediaTek DRM (`card0-DSI-1`) | 1084x2412 @ 120 Hz, Bilinear scaling |
| **Backlight Control** | 🟢 **Working** | `galaxian_backlight.ko` + daemon | Smooth exponential human-eye brightness curve |
| **Touchscreen** | 🟢 **Working** | FocalTech `fts_ts` (`c13:66`) | Native multi-touch gestures, swipe, tap |
| **On-Screen Keyboard** | 🟢 **Working** | Stevia OSK (`phosh-osk-stevia`) | Auto-show on input focus, responsive layout |
| **Physical Buttons** | 🟢 **Working** | `galaxian_helper_daemon.py` | Power key sleep/wake, Volume Up/Down OSD |
| **Wi-Fi Networking** | 🟢 **Working** | MediaTek Gen4m (`wlan_drv_gen4m_6878.ko`) | 2.4 & 5 GHz, WPA2/WPA3 password dialog, DHCP, DNS |
| **Mobile Desktop** | 🟢 **Working** | Phosh + Phoc (wlroots) | GNOME Mobile interface, app drawer, notifications |
| **Audio (Sound)** | 🟡 *In Progress* | ALSA / PipeWire | Dummy output working; MTK AFE audio routing WIP |
| **Cellular (Modem)** | 🟡 *In Progress* | MediaTek CCCI / ModemManager | Driver loaded; RIL/ModemManager integration WIP |
| **Camera** | 🔴 *Not Working* | MediaTek Camera ISP | Not yet supported in mainline |

---

## 🚀 Installation & Quick Start

For detailed step-by-step instructions, see **[Installation Guide](docs/INSTALL.md)**.

### Quick Fastboot Flash:

1. **Reboot phone into Fastboot mode:**
   ```bash
   adb reboot bootloader
   ```
   *(Or hold **Volume Down + Power** while powered off)*.

2. **Flash the standalone `init_boot.img`:**
   ```bash
   fastboot flash init_boot images/init_boot.img
   ```

3. **Flash the postmarketOS rootfs image:**
   ```bash
   fastboot flash userdata pmos_rootfs.img
   ```

4. **Reboot:**
   ```bash
   fastboot reboot
   ```

The device will boot directly into postmarketOS Phosh desktop.

---

## 📂 Repository Layout

```
├── docs/                   # Documentation and guides
│   ├── INSTALL.md          # Step-by-step installation guide
│   ├── PORT_SUMMARY.md     # Hardware port status summary
│   └── HARDWARE_NOTES.md   # Deep technical hardware implementation notes
├── images/                 # Pre-built verified boot images
│   └── init_boot.img       # Standalone Header v4 signed boot image (8.38 MB)
├── overlay/                # System files deployed to rootfs /sysroot
│   ├── etc/                # Polkit rules, phoc compositor configs
│   └── usr/bin/            # Wi-Fi bringup, supervisor, keys daemon
├── pmaports/               # postmarketOS package overlay
│   └── device/testing/
│       ├── device-nothing-galaxian/  # Device definition package
│       └── linux-nothing-galaxian/   # Kernel package definition
├── kernel/                 # Custom kernel drivers
│   └── drivers/backlight/  # Galaxian panel backlight kernel module
└── scripts/                # Packaging, flashing, and build scripts
    ├── build_init_boot.sh  # Ramdisk builder + Header v4/AVB packer
    ├── pack_init_boot.py   # Python AVB 1.0 signer and header packer
    ├── init.sh             # Standalone initramfs init script
    └── flash_init_boot.py  # Fastboot & telnet live flasher
```

---

## 🛠 Building `init_boot.img` From Source

To build a fresh `init_boot.img` with custom changes:

```bash
bash scripts/build_init_boot.sh
```

The script will assemble the cpio ramdisk, compress with LZ4, pack the Android Header v4 image, and attach the AVB 1.0 hash footer matching the partition boundary (8,388,608 bytes).

---

## 🙏 Acknowledgements & References
* [postmarketOS Project](https://postmarketos.org/)
* [xxxvik-xakerxxx/nothing-tetris-pmaports](https://github.com/xxxvik-xakerxxx/nothing-tetris-pmaports) (sister device Dimensity 7300 port)
* [Panthor DRM Driver](https://docs.kernel.org/gpu/panthor.html)
