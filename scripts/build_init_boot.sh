#!/bin/bash
# Build script for Nothing Phone (3a) Lite (galaxian / MT6878 / Dimensity 7300 Pro 5G)
# Packs ramdisk with Android Header v4 and AVB 1.0 footer
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${REPO_DIR}/build_initboot_tmp"
OUT_DIR="${REPO_DIR}/images"
OUT_IMG="${OUT_DIR}/init_boot.img"
OUT_RD="${BUILD_DIR}/ramdisk.lz4"

echo "=== Building standalone init_boot.img for Nothing Phone (3a) Lite ==="
mkdir -p "$BUILD_DIR" "$OUT_DIR"

# Stage ramdisk structure
echo "[*] Staging ramdisk..."
mkdir -p "$BUILD_DIR/etc/galaxian" "$BUILD_DIR/bin" "$BUILD_DIR/dev" "$BUILD_DIR/proc" "$BUILD_DIR/sys" "$BUILD_DIR/mnt" "$BUILD_DIR/sysroot" "$BUILD_DIR/modules"

# Copy init script
cp -f "$SCRIPT_DIR/init.sh" "$BUILD_DIR/init"
chmod +x "$BUILD_DIR/init"

# Copy galaxian overlay scripts
cp -f "$REPO_DIR/overlay/usr/bin/"* "$BUILD_DIR/etc/galaxian/"
cp -f "$REPO_DIR/overlay/etc/polkit-1/rules.d/00-galaxian-user.rules" "$BUILD_DIR/etc/galaxian/"
chmod +x "$BUILD_DIR/etc/galaxian/"*.sh "$BUILD_DIR/etc/galaxian/"*.py 2>/dev/null || true

# Pack ramdisk
echo "[*] Compressing cpio ramdisk with lz4 -12..."
cd "$BUILD_DIR"
find . | cpio -H newc -R 0:0 -o | lz4 -l -12 > "$OUT_RD"
echo "[+] Ramdisk packed: $OUT_RD ($(du -h "$OUT_RD" | cut -f1))"

# Package Android Header v4 with AVB 1.0
echo "[*] Packaging Android Boot Header v4 with AVB 1.0 footer..."
python3 "$SCRIPT_DIR/pack_init_boot.py" "$OUT_RD" "$OUT_IMG"
echo "[+] Successfully generated: $OUT_IMG"
