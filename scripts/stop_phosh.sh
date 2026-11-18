#!/system/bin/sh
# ==============================================================================
# Nothing Phone (3a) Lite - Force Return to Android
# ==============================================================================

echo "[*] Killing Linux processes..."
pkill -9 -f "brightnessid" 2>/dev/null
killall -9 phoc phosh wvkbd squeekboard seatd 2>/dev/null

echo "[*] Waking up Android Graphics Subsystem..."
pkill -CONT -f "composer@3.2" 2>/dev/null
start vendor.hwcomposer-3-2
start surfaceflinger

echo "[+] Android successfully restored!"
