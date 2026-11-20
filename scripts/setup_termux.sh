#!/data/data/com.termux/files/usr/bin/sh
# ==============================================================================
# One-click Termux setup: creates 'linux' and 'android' commands
# ==============================================================================

echo "[*] Setting up Termux shortcuts..."
cat << 'EOF' > "$PREFIX/bin/linux"
#!/data/data/com.termux/files/usr/bin/sh
echo "[*] Launching postmarketOS Phosh in background..."
echo "[*] Android UI will stop now. Logging to /data/pmos_files/phosh.log"
su -c "/system/bin/nohup /data/pmos_files/start_phosh.sh > /data/pmos_files/phosh.log 2>&1 &"
EOF
chmod +x "$PREFIX/bin/linux"

cat << 'EOF' > "$PREFIX/bin/android"
#!/data/data/com.termux/files/usr/bin/sh
echo "[*] Restoring Android UI and Mali GPU..."
su -c "/data/pmos_files/stop_phosh.sh"
EOF
chmod +x "$PREFIX/bin/android"

mkdir -p "$HOME/.shortcuts"
cp "$PREFIX/bin/linux" "$HOME/.shortcuts/Linux"
cp "$PREFIX/bin/android" "$HOME/.shortcuts/Android"

echo "[+] Done! You can now type 'linux' or 'android' in Termux."
echo "[+] Or add the Termux:Widget to your home screen for 1-click launch."
