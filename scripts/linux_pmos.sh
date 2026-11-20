#!/system/bin/sh
# Launch Phosh in background detached from terminal session
/system/bin/nohup /data/pmos_files/start_phosh.sh > /data/pmos_files/phosh.log 2>&1 &
echo "[+] Phosh launched in background (PID: $!)."
echo "[*] Follow log with: tail -f /data/pmos_files/phosh.log"
