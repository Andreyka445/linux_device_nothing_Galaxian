#!/usr/bin/env python3
"""
make_phosh_img.py
Generates a 3GB ext4 loop image containing the full postmarketOS Phosh rootfs from pmbootstrap.
Usage: Run inside WSL / Linux with root/sudo.
"""
import os
import subprocess
import sys

SRC_DIR = os.path.expanduser("~/.local/var/pmbootstrap/chroot_rootfs_nothing-galaxian")
OUT_IMG = "/mnt/d/nothing_galaxian/output/pmos_phosh.img"
MNT_POINT = "/tmp/mnt_phosh"

if not os.path.exists(SRC_DIR):
    print(f"[-] Source directory {SRC_DIR} not found! Run pmbootstrap install --ui phosh first.")
    sys.exit(1)

os.makedirs(os.path.dirname(OUT_IMG), exist_ok=True)
os.makedirs(MNT_POINT, exist_ok=True)

print(f"[*] 1. Creating 3GB raw image at {OUT_IMG}...")
subprocess.run(["dd", "if=/dev/zero", f"of={OUT_IMG}", "bs=1M", "count=3072"], check=True)

print("[*] 2. Formatting ext4 filesystem (label: pmOS_root)...")
subprocess.run(["mkfs.ext4", "-F", "-L", "pmOS_root", OUT_IMG], check=True)

print(f"[*] 3. Mounting image to {MNT_POINT}...")
subprocess.run(["sudo", "mount", "-o", "loop", OUT_IMG, MNT_POINT], check=True)

try:
    print("[*] 4. Copying rootfs files (this may take 1-2 minutes)...")
    subprocess.run(f"sudo cp -a {SRC_DIR}/* {MNT_POINT}/", shell=True, check=True)
    print("[+] Copy completed successfully.")
finally:
    print(f"[*] 5. Unmounting {MNT_POINT}...")
    subprocess.run(["sudo", "umount", MNT_POINT], check=True)

print(f"[+] All done! Image ready at {OUT_IMG} ({os.path.getsize(OUT_IMG)} bytes)")
