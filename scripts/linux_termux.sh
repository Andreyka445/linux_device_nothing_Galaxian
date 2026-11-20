#!/data/data/com.termux/files/usr/bin/sh
echo "[*] Launching postmarketOS Phosh in background..."
echo "[*] Android UI will stop now. Logging to /data/pmos_files/phosh.log"
su -c "/system/bin/nohup /data/pmos_files/start_phosh.sh > /data/pmos_files/phosh.log 2>&1 &"
