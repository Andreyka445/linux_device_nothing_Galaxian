#!/usr/bin/env python3
"""
Android Boot Header v4 Packer & AVB Signer for Nothing Phone (3a) Lite (Galaxian / MT6878)
Packs a compressed cpio ramdisk into an Android Header v4 init_boot.img with AVB 1.0 footer.
"""
import struct
import subprocess
import sys
import os
import shutil

def pack_and_sign_init_boot(ramdisk_path, output_path, total_size=8388608):
    if not os.path.exists(ramdisk_path):
        print(f"Error: {ramdisk_path} does not exist!")
        sys.exit(1)

    tools_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tools")
    avbtool_path = os.path.join(tools_dir, "avbtool.py")
    if not os.path.exists(avbtool_path):
        avbtool_path = "/tmp/avbtool.py"

    with open(ramdisk_path, 'rb') as f:
        ramdisk_data = f.read()
    
    ramdisk_size = len(ramdisk_data)
    print(f"[*] Input ramdisk: {ramdisk_path}")
    print(f"[*] Ramdisk size: {ramdisk_size} bytes ({ramdisk_size / 1024 / 1024:.2f} MB)")
    
    header = bytearray(4096)
    struct.pack_into('<8s', header, 0, b'ANDROID!')
    struct.pack_into('<I', header, 8, 0)
    struct.pack_into('<I', header, 12, ramdisk_size)
    struct.pack_into('<I', header, 16, 0)
    struct.pack_into('<I', header, 20, 1584)
    struct.pack_into('<I', header, 40, 4)
    
    pad_len = (4096 - (ramdisk_size % 4096)) % 4096
    unpadded_image = header + ramdisk_data + (b'\x00' * pad_len)
    
    tmp_path = output_path + ".tmp"
    with open(tmp_path, 'wb') as f:
        f.write(unpadded_image)
        
    print("[*] Adding AVB 1.0 hash footer...")
    cmd = [
        sys.executable, avbtool_path, "add_hash_footer",
        "--image", tmp_path,
        "--partition_size", str(total_size),
        "--partition_name", "init_boot",
        "--algorithm", "NONE",
        "--salt", "436553f64170cf5a945830f2f5ccc51a5da98735609153e5d9710ae10979689a",
        "--prop", "com.android.build.init_boot.os_version:14",
        "--prop", "com.android.build.init_boot.fingerprint:alps/Galaxian_mgvi_64_64only_ww_armv82/mgvi_64_64only_ww_armv82:14/UP1A.231005.007/2610291756:user/release-keys",
        "--prop", "com.android.build.init_boot.security_patch:2026-04-05"
    ]
    subprocess.check_call(cmd)
    
    shutil.move(tmp_path, output_path)
    print(f"[+] Successfully packed and signed init_boot: {output_path} ({os.path.getsize(output_path)} bytes)")

if __name__ == '__main__':
    default_rd = r"D:\nothing_galaxian\output\standalone_ramdisk.lz4"
    default_out = r"D:\nothing_galaxian\output\standalone_init_boot.img"
    
    rd = sys.argv[1] if len(sys.argv) > 1 else default_rd
    out = sys.argv[2] if len(sys.argv) > 2 else default_out
    pack_and_sign_init_boot(rd, out)
