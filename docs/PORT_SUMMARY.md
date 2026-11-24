# Port Status & Hardware Summary: Nothing Phone (3a) Lite

| Subsystem | Status | Driver / Implementation | Notes |
| :--- | :---: | :--- | :--- |
| **Device Model** | 🟢 **Verified** | Nothing Phone (3a) Lite (`galaxian`) | MediaTek Dimensity 7300 Pro 5G (MT6878) |
| **Boot Mode** | 🟢 **Working** | Standalone Android Header v4 `init_boot.img` | Native boot, AVB 1.0 signed, direct PMOS boot |
| **Rootfs Storage** | 🟢 **Working** | `dm-linear` on `/dev/block/by-name/super` | Sector 13914592 (offset 7124271104) / loop fallback |
| **GPU 3D Acceleration** | 🟢 **Working** | Panthor DRM (`panthor.ko`) + Panfrost GLES2 | ARM Mali-G615 MC2 full hardware acceleration |
| **Display Panel** | 🟢 **Working** | MediaTek DRM (`card0-DSI-1`) | 1084x2412 AMOLED, 120Hz refresh rate |
| **Backlight Control** | 🟢 **Working** | Custom `galaxian_backlight.ko` + daemon | Smooth exponential human-eye curve, power-save dimming |
| **Touchscreen** | 🟢 **Working** | FocalTech `fts_ts` (`c13:66`) | Native multi-touch gestures, swipe, tap |
| **On-Screen Keyboard** | 🟢 **Working** | Stevia OSK / `phosh-osk-stevia` | Automatic pop-up on text field focus |
| **Physical Buttons** | 🟢 **Working** | `galaxian_helper_daemon.py` | Power button sleep/wake, Volume Up/Down OSD |
| **Wi-Fi 2.4 & 5 GHz** | 🟢 **Working** | MediaTek Gen4m (`wlan_drv_gen4m_6878.ko`) | Full NetworkManager + wpa_supplicant, DHCP, DNS |
| **Security & Polkit** | 🟢 **Working** | PolicyKit `00-galaxian-user.rules` | Passwordless Wi-Fi connection from Phosh UI |
| **Credentials Storage** | 🟢 **Working** | `gnome-keyring-daemon` Secret Service | Secure Wi-Fi PSK storage in user session bus |
| **Audio Output** | 🟡 *In Progress* | ALSA / MTK AFE / PipeWire | Dummy sink configured; MTK AFE routing pending |
| **Cellular (Modem)** | 🟡 *In Progress* | MediaTek CCCI / ModemManager | Driver loaded; RIL/ModemManager integration WIP |
| **Camera** | 🔴 *Not Working* | MediaTek Camera ISP | Not yet supported in mainline / postmarketOS |
