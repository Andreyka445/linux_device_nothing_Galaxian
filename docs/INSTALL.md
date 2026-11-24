# Installation Guide: postmarketOS on Nothing Phone (2a)

This guide walks you through flashing and running standalone postmarketOS (Phosh Desktop) on the Nothing Phone (2a) / Phone (3a) Lite (`galaxian`).

> [!WARNING]
> Flashing custom operating systems carries inherent risks. Ensure your bootloader is unlocked and you have backed up important data before proceeding.

---

## 📋 Requirements
1. **Device:** Nothing Phone (2a) (`galaxian` / MT6878).
2. **Unlocked Bootloader:** Standard Android bootloader unlocking enabled in Developer Options.
3. **PC Tools:** `fastboot` and `adb` installed.
4. **Partition Images:**
   - `init_boot.img` (provided in [images/init_boot.img](../images/init_boot.img)).
   - `pmos_rootfs.img` (postmarketOS Phosh rootfs image, or built via pmbootstrap).

---

## ⚡ Fastboot Flashing Steps

### Step 1: Boot device into Fastboot mode
With the phone powered off, hold **Volume Down + Power** until the fastboot screen appears. Connect USB cable to your PC.

Verify fastboot detection:
```bash
fastboot devices
```

### Step 2: Flash the Standalone `init_boot.img`
Flash the signed `init_boot.img` to the `init_boot` partition:
```bash
fastboot flash init_boot images/init_boot.img
```
*(If prompted by slot selection, you can flash both slots: `fastboot flash init_boot_a images/init_boot.img` and `fastboot flash init_boot_b images/init_boot.img`)*.

### Step 3: Flash postmarketOS Rootfs
Flash the rootfs image into the target system partition (e.g. `userdata` or `super` partition mapped for PMOS):
```bash
fastboot flash userdata pmos_rootfs.img
```

### Step 4: Reboot into postmarketOS
```bash
fastboot reboot
```

The device will display the postmarketOS boot logo, initialize the Panthor Mali GPU, AMOLED display, and immediately launch the Phosh Wayland desktop with hardware acceleration.

---

## 📶 First Boot & Setup
- **Wi-Fi:** Swipe down from the top bar, tap the Wi-Fi icon, choose your network, and type your password using the on-screen keyboard (Stevia).
- **Display Brightness:** Adjust brightness smoothly using the quick-settings slider.
- **Physical Buttons:** 
  - Power button toggles screen sleep and wake.
  - Volume buttons display volume OSD and adjust audio levels.
- **Terminal Access:** Open Console from the app drawer. User is `user` (default postmarketOS user) with password `1471` (or passwordless sudo if configured).
