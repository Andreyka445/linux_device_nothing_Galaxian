#!/bin/bash
# postmarketOS Rootfs creation guide and helper script for Nothing Phone (3a) Lite
set -e

echo "=== postmarketOS Rootfs Instructions for Nothing Phone (3a) Lite ==="
echo "1. Initialize pmbootstrap with aarch64 target:"
echo "   pmbootstrap init"
echo ""
echo "2. Build or install the phosh UI image:"
echo "   pmbootstrap install --ui phosh"
echo ""
echo "3. Export or copy the generated rootfs to your flashing target:"
echo "   pmbootstrap export"
echo ""
echo "4. Overlay the Galaxian hardware scripts into /sysroot:"
echo "   cp -r overlay/* <mount_point>/"
echo ""
echo "5. Flash into super partition:"
echo "   fastboot flash super pmos_super.img"
