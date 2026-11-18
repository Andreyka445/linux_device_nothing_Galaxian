#!/data/data/com.termux/files/usr/bin/sh
# ==============================================================================
# One-click Termux setup: creates 'linux' command
# ==============================================================================

echo "[*] Setting up Termux shortcut..."
echo "su -c /data/pmos_files/start_phosh.sh" > "$PREFIX/bin/linux"
chmod +x "$PREFIX/bin/linux"

mkdir -p "$HOME/.shortcuts"
echo "su -c /data/pmos_files/start_phosh.sh" > "$HOME/.shortcuts/Linux"
chmod +x "$HOME/.shortcuts/Linux"

echo "[+] Done! You can now type 'linux' in Termux to launch postmarketOS Phosh."
echo "[+] Or add the Termux:Widget to your home screen for 1-click launch."
